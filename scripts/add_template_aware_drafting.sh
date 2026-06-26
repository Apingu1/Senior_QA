#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python - <<'PY'
from pathlib import Path

p = Path("backend/app/main.py")
s = p.read_text()

if "def task_format_query" not in s:
    marker = '''def source_payload(chunks: list[DocumentChunk]) -> list[dict[str, Any]]:'''
    helper = '''def is_form_or_template(doc: KnowledgeDocument) -> bool:
    doc_type = (doc.doc_type or "").lower()
    title = (doc.title or "").lower()
    number = (doc.document_number or "").lower()
    return (
        doc_type in {"form", "template", "previous approved example"}
        or "form" in title
        or "template" in title
        or "deviation" in title and "part" in title
        or "form" in number
    )


def task_format_query(task: QmsTask) -> str:
    text = task_context(task).lower()
    parts = [task.title, task.task_type, task.description]

    if "deviation" in text:
        parts.extend([
            "deviation form",
            "deviation template",
            "deviation part 1",
            "initial deviation report",
            "deviation investigation form",
            "event description immediate action impact assessment",
        ])

    if "capa" in text:
        parts.extend(["capa form", "capa template", "corrective preventive action"])

    if "change" in text:
        parts.extend(["change control form", "change control template", "change assessment"])

    if "complaint" in text:
        parts.extend(["complaint form", "complaint investigation template"])

    return " ".join(parts)


def template_chunks_for_task(db: Session, task: QmsTask, limit: int = 6) -> list[DocumentChunk]:
    q_tokens = tokens(task_format_query(task))
    rows = db.query(DocumentChunk).join(KnowledgeDocument).all()
    scored: list[tuple[int, DocumentChunk]] = []

    for chunk in rows:
        doc = chunk.document
        if doc.status.lower() != "current":
            continue
        if not is_form_or_template(doc):
            continue

        searchable = " ".join([
            chunk.content or "",
            doc.title or "",
            doc.document_number or "",
            doc.doc_type or "",
            doc.department or "",
        ])
        score = len(q_tokens & tokens(searchable))

        if "deviation" in task_format_query(task).lower() and "deviation" in searchable.lower():
            score += 6
        if (doc.doc_type or "").lower() == "template":
            score += 3
        if (doc.doc_type or "").lower() == "form":
            score += 2

        if score > 0:
            scored.append((score, chunk))

    scored.sort(key=lambda item: item[0], reverse=True)
    return [chunk for _, chunk in scored[:limit]]


def merge_chunks(primary: list[DocumentChunk], secondary: list[DocumentChunk], limit: int) -> list[DocumentChunk]:
    seen: set[int] = set()
    merged: list[DocumentChunk] = []
    for chunk in primary + secondary:
        if chunk.id in seen:
            continue
        merged.append(chunk)
        seen.add(chunk.id)
        if len(merged) >= limit:
            break
    return merged


'''
    s = s.replace(marker, helper + marker, 1)
    print("Added template-aware retrieval helpers")
else:
    print("Template-aware helpers already present")

old = '''        chunks = search_chunks(db, task_context(task), limit=MAX_RETRIEVAL_CHUNKS)'''
new = '''        format_chunks = template_chunks_for_task(db, task, limit=6)
        evidence_chunks = search_chunks(db, task_context(task), limit=MAX_RETRIEVAL_CHUNKS)
        chunks = merge_chunks(format_chunks, evidence_chunks, limit=MAX_RETRIEVAL_CHUNKS)'''
if old in s:
    s = s.replace(old, new, 1)
    print("Updated agent retrieval to prioritise forms/templates")
else:
    print("Agent retrieval line already patched or not found")

old_prompt = '''- Include a source section listing the documents relied upon.'''
new_prompt = '''- Include a source section listing the documents relied upon.
- If a retrieved source is a Form, Template, or previous approved example, use its headings, field labels and order as the required output structure.
- For any form/template field where the task does not provide enough information, write [Information required] rather than inventing details.
- For deviation tasks, draft in the structure of the retrieved deviation form/template, especially Part 1 / initial report fields where present.'''
if old_prompt in s:
    s = s.replace(old_prompt, new_prompt, 1)
    print("Updated AI prompt with form/template formatting rule")
else:
    print("Prompt rule already patched or not found")

old_prepare = '''Prepare:
1. Draft summary
2. Applicable source basis
3. Draft QA assessment
4. Product quality / patient safety / compliance / data integrity considerations where relevant
5. Proposed QMS wording
6. Missing information and assumptions
7. Human review checklist'''
new_prepare = '''Prepare the output in this priority order:
1. If a Form or Template source is retrieved, reproduce its field order/headings as the main draft structure and populate each relevant field.
2. If no usable Form or Template is retrieved, use a formal QA draft structure.
3. Include applicable source basis.
4. Include missing information and assumptions.
5. Include a human review checklist.
6. Do not create final approval wording.'''
if old_prepare in s:
    s = s.replace(old_prepare, new_prepare, 1)
    print("Updated drafting instruction block")
else:
    print("Drafting instruction block already patched or not found")

old_no_docs = '''No current knowledge-base documents were retrieved for this task. Please upload the relevant SOP/form/guidance or add more task detail so the AI can retrieve the correct documents.'''
new_no_docs = '''No current knowledge-base documents were retrieved for this task. Please upload the relevant SOP/form/template/guidance or add more task detail, including the form number/name, so the AI can retrieve the correct documents.'''
s = s.replace(old_no_docs, new_no_docs)

p.write_text(s)
PY

echo "Template-aware drafting patch applied. Rebuild with: bash start.sh"
