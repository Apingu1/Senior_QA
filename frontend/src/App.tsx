import { FormEvent, ReactNode, useEffect, useMemo, useState } from 'react'
import './styles.css'

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

type User = { id: number; username: string; full_name: string; role: string }
type AgentRun = { id: number; run_type: string; status: string; summary: string; started_at: string; finished_at?: string }
type Question = { id: number; task_id?: number; task_code?: string; task_title?: string; question: string; assigned_to: string; status: string; answer: string; created_at: string }
type Source = { document_number?: string; title?: string; version?: string; chunk_index?: number }
type Output = { id: number; task_id: number; task_code: string; task_title: string; title: string; content: string; status: string; sources: Source[]; assumptions: string[]; reviewer_comment: string; created_at: string }
type Task = { id: number; task_code: string; title: string; task_type: string; description: string; priority: string; status: string; due_date?: string | null; created_at: string; updated_at: string; questions?: Question[]; outputs?: Output[]; agent_runs?: AgentRun[] }
type DocumentRow = { id: number; title: string; document_number: string; version: string; status: string; doc_type: string; department: string; source_filename: string; uploaded_at: string; chunks: number }

export default function App() {
  const [token, setToken] = useState(localStorage.getItem('senior_qa_token') || '')
  const [user, setUser] = useState<User | null>(null)
  const [page, setPage] = useState('dashboard')
  const [error, setError] = useState('')
  const [toast, setToast] = useState('')

  async function api(path: string, options: RequestInit = {}) {
    const headers = new Headers(options.headers || {})
    if (!(options.body instanceof FormData)) headers.set('Content-Type', 'application/json')
    if (token) headers.set('Authorization', `Bearer ${token}`)
    const response = await fetch(`${API_BASE}${path}`, { ...options, headers })
    if (!response.ok) {
      const detail = await response.json().catch(() => ({}))
      throw new Error(detail.detail || `Request failed: ${response.status}`)
    }
    return response.json()
  }

  useEffect(() => {
    if (!token) return
    api('/auth/me')
      .then(setUser)
      .catch(() => {
        localStorage.removeItem('senior_qa_token')
        setToken('')
        setUser(null)
      })
  }, [token])

  if (!token) return <LoginScreen setToken={setToken} error={error} setError={setError} />

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">QA</div>
          <div><h1>Senior QA</h1><p>AI Officer Platform</p></div>
        </div>
        <nav>
          {[['dashboard','Dashboard'],['documents','Knowledge Base'],['tasks','Task Board'],['questions','Question Inbox'],['reviews','Review Queue'],['audit','Audit Log']].map(([key,label]) => (
            <button key={key} onClick={() => setPage(key)} className={page === key ? 'active' : ''}>{label}</button>
          ))}
        </nav>
        <div className="user-card">
          <strong>{user?.full_name || user?.username || 'Signed in'}</strong>
          <span>{user?.role || 'QA'}</span>
          <button onClick={() => { localStorage.removeItem('senior_qa_token'); setToken('') }}>Sign out</button>
        </div>
      </aside>

      <main>
        <header className="topbar">
          <div><p className="eyebrow">Phase 3 autonomous draft-support system</p><h2>{pageTitle(page)}</h2></div>
          <div className="status-pill">Human review required for all outputs</div>
        </header>
        {toast && <div className="toast">{toast}</div>}
        {error && <div className="error">{error}</div>}
        {page === 'dashboard' && <Dashboard api={api} setToast={setToast} setError={setError} />}
        {page === 'documents' && <Documents api={api} setToast={setToast} setError={setError} />}
        {page === 'tasks' && <Tasks api={api} setToast={setToast} setError={setError} />}
        {page === 'questions' && <Questions api={api} setToast={setToast} setError={setError} />}
        {page === 'reviews' && <Reviews api={api} setToast={setToast} setError={setError} />}
        {page === 'audit' && <AuditLog api={api} setError={setError} />}
      </main>
    </div>
  )
}

function LoginScreen({ setToken, setError, error }: { setToken: (token: string) => void; setError: (error: string) => void; error: string }) {
  const [username, setUsername] = useState('admin')
  const [password, setPassword] = useState('')
  async function submit(e: FormEvent) {
    e.preventDefault(); setError('')
    const response = await fetch(`${API_BASE}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username, password }) })
    if (!response.ok) { setError('Login failed. Check the backend is running and the admin credentials are correct.'); return }
    const data = await response.json()
    localStorage.setItem('senior_qa_token', data.access_token)
    setToken(data.access_token)
  }
  return <div className="login-wrap"><form className="login-card" onSubmit={submit}><div className="brand-mark large">QA</div><h1>Senior QA</h1><p>Controlled AI QA Officer workflow platform.</p>{error && <div className="error">{error}</div>}<label>Username<input value={username} onChange={e => setUsername(e.target.value)} /></label><label>Password<input type="password" value={password} onChange={e => setPassword(e.target.value)} /></label><button className="primary">Sign in</button><small>Use the admin credentials from example.env. Change them before real use.</small></form></div>
}

function Dashboard({ api, setToast, setError }: PageProps) {
  const [data, setData] = useState<any>(null)
  async function load() { setError(''); setData(await api('/dashboard')) }
  async function runNow() { const result = await api('/automation/run-now', { method: 'POST' }); setToast(`Automation run completed. Processed ${result.processed} tasks.`); await load() }
  useEffect(() => { load().catch(e => setError(e.message)) }, [])
  if (!data) return <Panel title="Loading dashboard..." />
  return <div className="stack"><div className="grid cards"><Metric label="Documents" value={data.documents} /><Metric label="Current docs" value={data.current_documents} /><Metric label="Tasks" value={data.tasks} /><Metric label="Open questions" value={data.open_questions} /><Metric label="Awaiting review" value={data.awaiting_review} /></div><Panel title="Autonomous agent"><p>The background worker checks open tasks on the configured interval. Use manual run-now during testing or when you want it to continue all unblocked work immediately.</p><button className="primary" onClick={runNow}>Run autonomous queue now</button></Panel><Panel title="Task status overview"><div className="status-grid">{Object.entries(data.task_counts || {}).map(([status,count]) => <div className="mini-card" key={status}><strong>{String(count)}</strong><span>{status}</span></div>)}</div></Panel><Panel title="Recent agent runs"><table><thead><tr><th>Run</th><th>Type</th><th>Status</th><th>Summary</th></tr></thead><tbody>{(data.recent_runs || []).map((run: AgentRun) => <tr key={run.id}><td>{run.id}</td><td>{run.run_type}</td><td><Badge value={run.status} /></td><td>{run.summary}</td></tr>)}</tbody></table></Panel></div>
}

function Documents({ api, setToast, setError }: PageProps) {
  const [docs, setDocs] = useState<DocumentRow[]>([])
  const [search, setSearch] = useState('')
  const [results, setResults] = useState<any[]>([])
  async function load() { setDocs(await api('/documents')) }
  useEffect(() => { load().catch(e => setError(e.message)) }, [])
  async function upload(e: FormEvent<HTMLFormElement>) { e.preventDefault(); const form = new FormData(e.currentTarget); await api('/documents', { method: 'POST', body: form }); e.currentTarget.reset(); setToast('Document uploaded and indexed.'); await load() }
  async function runSearch(e: FormEvent) { e.preventDefault(); setResults(await api('/documents/search', { method: 'POST', body: JSON.stringify({ query: search, include_superseded: false }) })) }
  return <div className="stack two-col"><Panel title="Upload QMS document / guidance copy"><form className="form-grid" onSubmit={upload}><label>Title<input name="title" required placeholder="Deviation Management SOP" /></label><label>Document number<input name="document_number" placeholder="ES.SOP.012" /></label><label>Version<input name="version" placeholder="V01" /></label><label>Status<select name="status" defaultValue="current"><option value="current">Current</option><option value="draft">Draft</option><option value="superseded">Superseded</option></select></label><label>Type<select name="doc_type" defaultValue="SOP"><option>SOP</option><option>Form</option><option>Policy</option><option>Guidance</option><option>Template</option><option>Previous Approved Example</option></select></label><label>Department<input name="department" placeholder="QA / QC / Production" /></label><label>Effective date<input name="effective_date" type="date" /></label><label>Review date<input name="review_date" type="date" /></label><label className="full">File<input name="file" type="file" accept=".pdf,.docx,.txt,.md,.csv" required /></label><button className="primary full">Upload and index</button></form></Panel><Panel title="Knowledge search"><form onSubmit={runSearch} className="inline-form"><input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search SOPs, forms and guidance..." /><button>Search</button></form><div className="search-results">{results.map((r, idx) => <div className="result" key={idx}><strong>{r.document_number} {r.title} v{r.version}</strong><span>{r.status} - chunk {r.chunk_index}</span><p>{r.content}</p></div>)}</div></Panel><Panel title="Uploaded knowledge base" wide><table><thead><tr><th>Document</th><th>Version</th><th>Status</th><th>Type</th><th>Chunks</th></tr></thead><tbody>{docs.map(doc => <tr key={doc.id}><td><strong>{doc.document_number || 'N/A'}</strong><br />{doc.title}</td><td>{doc.version}</td><td><Badge value={doc.status} /></td><td>{doc.doc_type}</td><td>{doc.chunks}</td></tr>)}</tbody></table></Panel></div>
}

function Tasks({ api, setToast, setError }: PageProps) {
  const [tasks, setTasks] = useState<Task[]>([])
  const [selected, setSelected] = useState<Task | null>(null)
  async function load() { setTasks(await api('/tasks')) }
  async function openTask(id: number) { setSelected(await api(`/tasks/${id}`)) }
  useEffect(() => { load().catch(e => setError(e.message)) }, [])
  async function createTask(e: FormEvent<HTMLFormElement>) { e.preventDefault(); const form = new FormData(e.currentTarget); const due = String(form.get('due_date') || ''); const payload = { title: String(form.get('title') || ''), task_type: String(form.get('task_type') || ''), description: String(form.get('description') || ''), priority: String(form.get('priority') || 'Medium'), due_date: due || null }; const created = await api('/tasks', { method: 'POST', body: JSON.stringify(payload) }); e.currentTarget.reset(); setToast('Task created and assigned to AI.'); await load(); await openTask(created.id) }
  async function runAgent(id: number) { const detail = await api(`/tasks/${id}/run-agent`, { method: 'POST' }); setSelected(detail); await load(); setToast('Agent run completed or blocked with questions.') }
  return <div className="stack"><Panel title="Create QMS task"><form className="form-grid" onSubmit={createTask}><label>Title<input name="title" required placeholder="Draft investigation for deviation DEV-2026-001" /></label><label>Task type<select name="task_type" defaultValue="Deviation draft"><option>Deviation draft</option><option>CAPA draft</option><option>Change control assessment</option><option>SOP gap review</option><option>Supplier qualification review</option><option>Audit checklist</option><option>Complaint investigation draft</option><option>General QA review</option></select></label><label>Priority<select name="priority" defaultValue="Medium"><option>Low</option><option>Medium</option><option>High</option><option>Critical</option></select></label><label>Due date<input name="due_date" type="date" /></label><label className="full">Description / task brief<textarea name="description" rows={6} placeholder="Add the QMS record details, required output, known facts, document numbers, product/batch details and any specific questions." /></label><button className="primary full">Create and assign to AI</button></form></Panel><div className="split"><Panel title="Task board"><table><thead><tr><th>Code</th><th>Task</th><th>Status</th><th></th></tr></thead><tbody>{tasks.map(task => <tr key={task.id}><td>{task.task_code}</td><td><strong>{task.title}</strong><br /><span>{task.task_type}</span></td><td><Badge value={task.status} /></td><td><button onClick={() => openTask(task.id)}>Open</button></td></tr>)}</tbody></table></Panel><Panel title="Task detail">{!selected && <p>Select a task to view agent questions, outputs and run history.</p>}{selected && <div className="detail"><div className="detail-head"><div><h3>{selected.task_code}</h3><h2>{selected.title}</h2><Badge value={selected.status} /></div><button className="primary" onClick={() => runAgent(selected.id)}>Run agent</button></div><p>{selected.description}</p><h4>Questions</h4>{(selected.questions || []).map(q => <div className="sub-card" key={q.id}><Badge value={q.status} /><p>{q.question}</p>{q.answer && <blockquote>{q.answer}</blockquote>}</div>)}<h4>Outputs</h4>{(selected.outputs || []).map(out => <div className="output" key={out.id}><div className="output-title"><strong>{out.title}</strong><Badge value={out.status} /></div><pre>{out.content}</pre><h5>Sources</h5><ul>{(out.sources || []).map((s, idx) => <li key={idx}>{s.document_number || 'N/A'} - {s.title} v{s.version}, chunk {s.chunk_index}</li>)}</ul></div>)}<h4>Agent runs</h4>{(selected.agent_runs || []).map(run => <div className="sub-card" key={run.id}><Badge value={run.status} /><strong>{run.run_type}</strong><p>{run.summary}</p></div>)}</div>}</Panel></div></div>
}

function Questions({ api, setToast, setError }: PageProps) {
  const [questions, setQuestions] = useState<Question[]>([])
  const [answers, setAnswers] = useState<Record<number, string>>({})
  async function load() { setQuestions(await api('/questions')) }
  useEffect(() => { load().catch(e => setError(e.message)) }, [])
  async function submitAnswer(id: number) { await api(`/questions/${id}/answer`, { method: 'POST', body: JSON.stringify({ answer: answers[id] || '' }) }); setToast('Question answered. Task returned to AI queue.'); await load() }
  return <Panel title="Missing-information question inbox"><div className="question-list">{questions.map(q => <div className="question-card" key={q.id}><div><strong>{q.task_code} - {q.task_title}</strong> <Badge value={q.status} /></div><p>{q.question}</p>{q.status === 'Open' ? <><textarea rows={4} placeholder="Answer for the AI agent..." value={answers[q.id] || ''} onChange={e => setAnswers({ ...answers, [q.id]: e.target.value })} /><button className="primary" onClick={() => submitAnswer(q.id)}>Submit answer</button></> : <blockquote>{q.answer}</blockquote>}</div>)}</div></Panel>
}

function Reviews({ api, setToast, setError }: PageProps) {
  const [outputs, setOutputs] = useState<Output[]>([])
  const [comments, setComments] = useState<Record<number, string>>({})
  async function load() { setOutputs(await api('/reviews')) }
  useEffect(() => { load().catch(e => setError(e.message)) }, [])
  async function review(id: number, decision: 'accept' | 'reject' | 'rework') { await api(`/outputs/${id}/review`, { method: 'POST', body: JSON.stringify({ decision, comment: comments[id] || '' }) }); setToast(`Output marked as ${decision}.`); await load() }
  return <Panel title="Human review queue"><div className="review-list">{outputs.map(out => <div className="output" key={out.id}><div className="output-title"><div><strong>{out.task_code} - {out.task_title}</strong><p>{out.title}</p></div><Badge value={out.status} /></div><pre>{out.content}</pre><textarea rows={3} placeholder="Reviewer comment / reason..." value={comments[out.id] || ''} onChange={e => setComments({ ...comments, [out.id]: e.target.value })} /><div className="button-row"><button className="primary" onClick={() => review(out.id, 'accept')}>Accept draft</button><button onClick={() => review(out.id, 'rework')}>Return for rework</button><button className="danger" onClick={() => review(out.id, 'reject')}>Reject</button></div></div>)}</div></Panel>
}

function AuditLog({ api, setError }: { api: (path: string, options?: RequestInit) => Promise<any>; setError: (message: string) => void }) {
  const [events, setEvents] = useState<any[]>([])
  useEffect(() => { api('/audit?limit=100').then(setEvents).catch(e => setError(e.message)) }, [])
  return <Panel title="Audit / run log"><table><thead><tr><th>Time</th><th>Event</th><th>Entity</th><th>Details</th></tr></thead><tbody>{events.map(event => <tr key={event.id}><td>{new Date(event.created_at).toLocaleString()}</td><td>{event.event_type}</td><td>{event.entity_type} {event.entity_id}</td><td><code>{JSON.stringify(event.details)}</code></td></tr>)}</tbody></table></Panel>
}

type PageProps = { api: (path: string, options?: RequestInit) => Promise<any>; setToast: (message: string) => void; setError: (message: string) => void }
function Panel({ title, children, wide = false }: { title: string; children?: ReactNode; wide?: boolean }) { return <section className={`panel ${wide ? 'wide' : ''}`}><h3>{title}</h3>{children}</section> }
function Metric({ label, value }: { label: string; value: number }) { return <div className="metric"><strong>{value}</strong><span>{label}</span></div> }
function Badge({ value }: { value: string }) { const cls = useMemo(() => `badge ${String(value).toLowerCase().replaceAll(' ', '-')}`, [value]); return <span className={cls}>{value}</span> }
function pageTitle(page: string) { return ({ dashboard: 'Dashboard', documents: 'Knowledge Base', tasks: 'Task Board', questions: 'Question Inbox', reviews: 'Review Queue', audit: 'Audit Log' } as Record<string, string>)[page] || 'Senior QA' }
