#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python - <<'PY'
from pathlib import Path

backend = Path("backend/app/main.py")
frontend = Path("frontend/src/App.tsx")
styles = Path("frontend/src/styles.css")

b = backend.read_text()

# ---------------------------------------------------------------------------
# Backend: add document metadata update schema and PATCH endpoint
# ---------------------------------------------------------------------------
if "class DocumentUpdate(BaseModel):" not in b:
    marker = """class AnswerQuestionIn(BaseModel):
    answer: str
"""
    insert = """class DocumentUpdate(BaseModel):
    title: Optional[str] = None
    document_number: Optional[str] = None
    version: Optional[str] = None
    status: Optional[str] = None
    doc_type: Optional[str] = None
    department: Optional[str] = None
    effective_date: Optional[date] = None
    review_date: Optional[date] = None


class AnswerQuestionIn(BaseModel):
    answer: str
"""
    if marker not in b:
        raise SystemExit("Could not find AnswerQuestionIn marker for backend schema insertion")
    b = b.replace(marker, insert, 1)
    print("Added DocumentUpdate schema")
else:
    print("DocumentUpdate schema already present")

if '@app.patch("/documents/{document_id}")' not in b:
    marker = '''

@app.post("/documents/search")
def document_search('''
    endpoint = '''

@app.patch("/documents/{document_id}")
def update_document_metadata(
    document_id: int,
    payload: DocumentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    doc = db.get(KnowledgeDocument, document_id)
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    before = {
        "title": doc.title,
        "document_number": doc.document_number,
        "version": doc.version,
        "status": doc.status,
        "doc_type": doc.doc_type,
        "department": doc.department,
        "effective_date": doc.effective_date,
        "review_date": doc.review_date,
    }

    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(doc, field, value)

    after = {
        "title": doc.title,
        "document_number": doc.document_number,
        "version": doc.version,
        "status": doc.status,
        "doc_type": doc.doc_type,
        "department": doc.department,
        "effective_date": doc.effective_date,
        "review_date": doc.review_date,
    }

    db.commit()
    db.refresh(doc)
    audit(
        db,
        "DOCUMENT_METADATA_UPDATED",
        "knowledge_document",
        doc.id,
        current_user,
        {"before": before, "after": after},
    )

    return {
        "id": doc.id,
        "title": doc.title,
        "document_number": doc.document_number,
        "version": doc.version,
        "status": doc.status,
        "doc_type": doc.doc_type,
        "department": doc.department,
        "effective_date": doc.effective_date,
        "review_date": doc.review_date,
        "source_filename": doc.source_filename,
        "uploaded_at": doc.uploaded_at,
        "chunks": len(doc.chunks),
    }
'''
    if marker not in b:
        raise SystemExit("Could not find documents/search marker for backend endpoint insertion")
    b = b.replace(marker, endpoint + marker, 1)
    print("Added PATCH /documents/{document_id}")
else:
    print("Document update endpoint already present")

backend.write_text(b)

# ---------------------------------------------------------------------------
# Frontend: replace Documents component with edit modal enabled version
# ---------------------------------------------------------------------------
s = frontend.read_text()

s = s.replace(
    "type DocumentRow = { id: number; title: string; document_number: string; version: string; status: string; doc_type: string; department: string; source_filename: string; uploaded_at: string; chunks: number }",
    "type DocumentRow = { id: number; title: string; document_number: string; version: string; status: string; doc_type: string; department: string; effective_date?: string | null; review_date?: string | null; source_filename: string; uploaded_at: string; chunks: number }"
)

start = s.find("function Documents(")
end = s.find("\n\nfunction Tasks(")
if start == -1 or end == -1:
    raise SystemExit("Could not locate Documents component boundaries in frontend/src/App.tsx")

new_documents = r'''function Documents({ api, setToast, setError }: PageProps) {
  const [docs, setDocs] = useState<DocumentRow[]>([])
  const [search, setSearch] = useState('')
  const [results, setResults] = useState<any[]>([])
  const [editing, setEditing] = useState<DocumentRow | null>(null)
  const [editForm, setEditForm] = useState({
    title: '',
    document_number: '',
    version: '',
    status: 'current',
    doc_type: 'SOP',
    department: '',
    effective_date: '',
    review_date: ''
  })

  async function load() { setDocs(await api('/documents')) }
  useEffect(() => { load().catch(e => setError(e.message)) }, [])

  async function upload(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    setError('')
    setToast('Uploading document...')

    const formElement = e.currentTarget
    const form = new FormData(formElement)
    const file = form.get('file') as File | null

    if (!file || !file.name) {
      setToast('')
      setError('Please choose a file before uploading.')
      return
    }

    try {
      await api('/documents', { method: 'POST', body: form })
      formElement.reset()
      setToast('Document uploaded and indexed.')
      await load()
    } catch (err: any) {
      setToast('')
      setError(err?.message || 'Document upload failed. Check the backend logs for details.')
    }
  }

  async function runSearch(e: FormEvent) {
    e.preventDefault()
    setError('')
    try {
      setResults(await api('/documents/search', { method: 'POST', body: JSON.stringify({ query: search, include_superseded: false }) }))
    } catch (err: any) {
      setError(err?.message || 'Knowledge search failed.')
    }
  }

  function openEdit(doc: DocumentRow) {
    setError('')
    setEditing(doc)
    setEditForm({
      title: doc.title || '',
      document_number: doc.document_number || '',
      version: doc.version || '',
      status: doc.status || 'current',
      doc_type: doc.doc_type || 'SOP',
      department: doc.department || '',
      effective_date: doc.effective_date ? String(doc.effective_date).slice(0, 10) : '',
      review_date: doc.review_date ? String(doc.review_date).slice(0, 10) : ''
    })
  }

  function setEditField(field: string, value: string) {
    setEditForm(prev => ({ ...prev, [field]: value }))
  }

  async function saveEdit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    if (!editing) return

    setError('')
    setToast('Saving document metadata...')

    const payload = {
      ...editForm,
      effective_date: editForm.effective_date || null,
      review_date: editForm.review_date || null
    }

    try {
      await api(`/documents/${editing.id}`, { method: 'PATCH', body: JSON.stringify(payload) })
      setEditing(null)
      setToast('Document metadata updated.')
      await load()
    } catch (err: any) {
      setToast('')
      setError(err?.message || 'Document update failed.')
    }
  }

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
      setError(err?.message || 'Document delete failed. Make sure the delete patch has been applied.')
    }
  }

  return <div className="stack two-col">
    <Panel title="Upload QMS document / guidance copy"><form className="form-grid" onSubmit={upload}><label>Title<input name="title" required placeholder="Deviation Management SOP" /></label><label>Document number<input name="document_number" placeholder="ES.SOP.012" /></label><label>Version<input name="version" placeholder="V01" /></label><label>Status<select name="status" defaultValue="current"><option value="current">Current</option><option value="draft">Draft</option><option value="superseded">Superseded</option></select></label><label>Type<select name="doc_type" defaultValue="SOP"><option>SOP</option><option>Form</option><option>Policy</option><option>Guidance</option><option>Template</option><option>Previous Approved Example</option></select></label><label>Department<input name="department" placeholder="QA / QC / Production" /></label><label>Effective date<input name="effective_date" type="date" /></label><label>Review date<input name="review_date" type="date" /></label><label className="full">File<input name="file" type="file" accept=".pdf,.docx,.txt,.md,.csv" required /></label><button className="primary full">Upload and index</button></form></Panel>

    <Panel title="Knowledge search"><form onSubmit={runSearch} className="inline-form"><input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search SOPs, forms and guidance..." /><button>Search</button></form><div className="search-results">{results.map((r, idx) => <div className="result" key={idx}><strong>{r.document_number} {r.title} v{r.version}</strong><span>{r.status} - chunk {r.chunk_index}</span><p>{r.content}</p></div>)}</div></Panel>

    <Panel title="Uploaded knowledge base" wide><table><thead><tr><th>Document</th><th>Version</th><th>Status</th><th>Type</th><th>Chunks</th><th>Actions</th></tr></thead><tbody>{docs.map(doc => <tr key={doc.id}><td><strong>{doc.document_number || 'N/A'}</strong><br />{doc.title}<br /><span>{doc.department || ''}</span></td><td>{doc.version}</td><td><Badge value={doc.status} /></td><td>{doc.doc_type}</td><td>{doc.chunks}</td><td><div className="button-row"><button onClick={() => openEdit(doc)}>Edit</button><button className="danger" onClick={() => deleteDocument(doc.id, doc.title)}>Delete</button></div></td></tr>)}</tbody></table></Panel>

    {editing && <div className="modal-backdrop" role="dialog" aria-modal="true">
      <form className="modal-card" onSubmit={saveEdit}>
        <div className="modal-head"><div><p className="eyebrow">Knowledge Base</p><h3>Edit document variables</h3></div><button type="button" onClick={() => setEditing(null)}>Close</button></div>
        <div className="form-grid">
          <label>Title<input value={editForm.title} onChange={e => setEditField('title', e.target.value)} required /></label>
          <label>Document number<input value={editForm.document_number} onChange={e => setEditField('document_number', e.target.value)} /></label>
          <label>Version<input value={editForm.version} onChange={e => setEditField('version', e.target.value)} /></label>
          <label>Status<select value={editForm.status} onChange={e => setEditField('status', e.target.value)}><option value="current">Current</option><option value="draft">Draft</option><option value="superseded">Superseded</option></select></label>
          <label>Type<select value={editForm.doc_type} onChange={e => setEditField('doc_type', e.target.value)}><option>SOP</option><option>Form</option><option>Policy</option><option>Guidance</option><option>Template</option><option>Previous Approved Example</option></select></label>
          <label>Department<input value={editForm.department} onChange={e => setEditField('department', e.target.value)} /></label>
          <label>Effective date<input type="date" value={editForm.effective_date} onChange={e => setEditField('effective_date', e.target.value)} /></label>
          <label>Review date<input type="date" value={editForm.review_date} onChange={e => setEditField('review_date', e.target.value)} /></label>
        </div>
        <div className="modal-actions"><button type="button" onClick={() => setEditing(null)}>Cancel</button><button className="primary">Save changes</button></div>
        <small>This updates metadata only. The uploaded file and indexed chunks are not changed.</small>
      </form>
    </div>}
  </div>
}'''

s = s[:start] + new_documents + s[end:]
frontend.write_text(s)
print("Replaced Documents component with edit modal enabled version")

# ---------------------------------------------------------------------------
# CSS: modal styling
# ---------------------------------------------------------------------------
css = styles.read_text()
if ".modal-backdrop" not in css:
    css += r'''

.modal-backdrop {
  position: fixed;
  inset: 0;
  z-index: 100;
  background: rgba(17, 26, 43, 0.55);
  display: grid;
  place-items: center;
  padding: 24px;
}

.modal-card {
  width: min(860px, 100%);
  max-height: 90vh;
  overflow: auto;
  background: white;
  border: 1px solid #e4e9f3;
  border-radius: 26px;
  padding: 24px;
  box-shadow: 0 28px 90px rgba(17,26,43,.28);
  display: grid;
  gap: 18px;
}

.modal-head, .modal-actions {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: center;
}

.modal-head h3 {
  margin: 0;
  font-size: 1.35rem;
}

.modal-actions {
  justify-content: flex-end;
}
'''
    styles.write_text(css)
    print("Added modal CSS")
else:
    print("Modal CSS already present")
PY

echo "Document edit modal patch applied. Rebuild with: bash start.sh"
