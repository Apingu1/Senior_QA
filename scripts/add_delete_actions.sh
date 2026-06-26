#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python - <<'PY'
from pathlib import Path

backend = Path("backend/app/main.py")
front = Path("frontend/src/App.tsx")

b = backend.read_text()

if '@app.delete("/documents/{document_id}")' not in b:
    doc_delete = '''

@app.delete("/documents/{document_id}")
def delete_document(
    document_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    doc = db.get(KnowledgeDocument, document_id)
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    chunk_count = db.query(DocumentChunk).filter(DocumentChunk.document_id == document_id).count()
    file_to_remove = Path(doc.file_path) if doc.file_path else None
    details = {
        "title": doc.title,
        "document_number": doc.document_number,
        "version": doc.version,
        "source_filename": doc.source_filename,
        "chunks_deleted": chunk_count,
    }

    db.query(DocumentChunk).filter(DocumentChunk.document_id == document_id).delete(synchronize_session=False)
    db.delete(doc)
    db.add(
        AuditEvent(
            event_type="DOCUMENT_DELETED",
            entity_type="knowledge_document",
            entity_id=str(document_id),
            user_id=current_user.id,
            details_json=json.dumps(details, default=str),
        )
    )
    db.commit()

    if file_to_remove and file_to_remove.exists():
        try:
            file_to_remove.unlink()
        except OSError:
            pass

    return {"deleted": True, "id": document_id, "chunks_deleted": chunk_count}
'''
    marker = '\n\n\n@app.post("/documents/search")'
    if marker not in b:
        raise SystemExit("Could not find documents/search marker in backend/app/main.py")
    b = b.replace(marker, doc_delete + marker, 1)
    print("Added DELETE /documents/{document_id}")
else:
    print("Document delete endpoint already present")

if '@app.delete("/tasks/{task_id}")' not in b:
    task_delete = '''

@app.delete("/tasks/{task_id}")
def delete_task(
    task_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    task = db.get(QmsTask, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    question_count = db.query(AgentQuestion).filter(AgentQuestion.task_id == task_id).count()
    output_count = db.query(TaskOutput).filter(TaskOutput.task_id == task_id).count()
    run_count = db.query(AgentRun).filter(AgentRun.task_id == task_id).count()
    details = {
        "task_code": task.task_code,
        "title": task.title,
        "status": task.status,
        "questions_deleted": question_count,
        "outputs_deleted": output_count,
        "agent_runs_deleted": run_count,
    }

    db.query(AgentQuestion).filter(AgentQuestion.task_id == task_id).delete(synchronize_session=False)
    db.query(TaskOutput).filter(TaskOutput.task_id == task_id).delete(synchronize_session=False)
    db.query(AgentRun).filter(AgentRun.task_id == task_id).delete(synchronize_session=False)
    db.delete(task)
    db.add(
        AuditEvent(
            event_type="TASK_DELETED",
            entity_type="qms_task",
            entity_id=str(task_id),
            user_id=current_user.id,
            details_json=json.dumps(details, default=str),
        )
    )
    db.commit()

    return {
        "deleted": True,
        "id": task_id,
        "questions_deleted": question_count,
        "outputs_deleted": output_count,
        "agent_runs_deleted": run_count,
    }
'''
    marker = '\n\n\n@app.post("/tasks/{task_id}/run-agent")'
    if marker not in b:
        raise SystemExit("Could not find run-agent marker in backend/app/main.py")
    b = b.replace(marker, task_delete + marker, 1)
    print("Added DELETE /tasks/{task_id}")
else:
    print("Task delete endpoint already present")

backend.write_text(b)

s = front.read_text()

if "async function deleteDocument(" not in s:
    marker = "  async function load() { setDocs(await api('/documents')) }"
    if marker not in s:
        raise SystemExit("Could not find Documents load() marker in frontend/src/App.tsx")
    insert = marker + '''
  async function deleteDocument(id: number, title: string) {
    if (!window.confirm(`Delete document "${title}" from the knowledge base? This also removes its indexed chunks.`)) return
    setError('')
    setToast('Deleting document...')
    try {
      await api(`/documents/${id}`, { method: 'DELETE' })
      setToast('Document deleted from knowledge base.')
      await load()
    } catch (err: any) {
      setToast('')
      setError(err?.message || 'Document delete failed.')
    }
  }'''
    s = s.replace(marker, insert, 1)
    print("Added document delete UI handler")
else:
    print("Document delete UI handler already present")

s = s.replace(
    "<tr><th>Document</th><th>Version</th><th>Status</th><th>Type</th><th>Chunks</th></tr>",
    "<tr><th>Document</th><th>Version</th><th>Status</th><th>Type</th><th>Chunks</th><th>Actions</th></tr>"
)
s = s.replace(
    "<td>{doc.chunks}</td></tr>)",
    "<td>{doc.chunks}</td><td><button className=\"danger\" onClick={() => deleteDocument(doc.id, doc.title)}>Delete</button></td></tr>)"
)

if "async function deleteTask(" not in s:
    marker = "  async function openTask(id: number) { setSelected(await api(`/tasks/${id}`)) }"
    if marker not in s:
        raise SystemExit("Could not find Tasks openTask() marker in frontend/src/App.tsx")
    insert = marker + '''
  async function deleteTask(id: number, code: string) {
    if (!window.confirm(`Delete task ${code}? This will also delete its related questions, draft outputs and agent runs.`)) return
    setError('')
    setToast('Deleting task...')
    try {
      await api(`/tasks/${id}`, { method: 'DELETE' })
      if (selected?.id === id) setSelected(null)
      setToast('Task and related workflow records deleted.')
      await load()
    } catch (err: any) {
      setToast('')
      setError(err?.message || 'Task delete failed.')
    }
  }'''
    s = s.replace(marker, insert, 1)
    print("Added task delete UI handler")
else:
    print("Task delete UI handler already present")

s = s.replace(
    "<tr><th>Code</th><th>Task</th><th>Status</th><th></th></tr>",
    "<tr><th>Code</th><th>Task</th><th>Status</th><th>Actions</th></tr>"
)
s = s.replace(
    "<td><button onClick={() => openTask(task.id)}>Open</button></td></tr>)",
    "<td><div className=\"button-row\"><button onClick={() => openTask(task.id)}>Open</button><button className=\"danger\" onClick={() => deleteTask(task.id, task.task_code)}>Delete</button></div></td></tr>)"
)

front.write_text(s)
PY

echo "Delete actions added. Rebuild with: bash start.sh"
