#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python - <<'PY'
from pathlib import Path

p = Path("frontend/src/App.tsx")
s = p.read_text()

old = """  async function createTask(e: FormEvent<HTMLFormElement>) { e.preventDefault(); const form = new FormData(e.currentTarget); const due = String(form.get('due_date') || ''); const payload = { title: String(form.get('title') || ''), task_type: String(form.get('task_type') || ''), description: String(form.get('description') || ''), priority: String(form.get('priority') || 'Medium'), due_date: due || null }; const created = await api('/tasks', { method: 'POST', body: JSON.stringify(payload) }); e.currentTarget.reset(); setToast('Task created and assigned to AI.'); await load(); await openTask(created.id) }"""

new = """  async function createTask(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    setError('')
    setToast('Creating task...')

    const formElement = e.currentTarget
    const form = new FormData(formElement)
    const due = String(form.get('due_date') || '')
    const payload = {
      title: String(form.get('title') || '').trim(),
      task_type: String(form.get('task_type') || '').trim(),
      description: String(form.get('description') || '').trim(),
      priority: String(form.get('priority') || 'Medium'),
      due_date: due || null
    }

    if (!payload.title) {
      setToast('')
      setError('Please enter a task title.')
      return
    }

    if (!payload.task_type) {
      setToast('')
      setError('Please select a task type.')
      return
    }

    try {
      const created = await api('/tasks', { method: 'POST', body: JSON.stringify(payload) })
      formElement.reset()
      setToast('Task created and assigned to AI.')
      await load()
      await openTask(created.id)
    } catch (err: any) {
      setToast('')
      setError(err?.message || 'Task creation failed. Check backend logs for details.')
    }
  }"""

if old not in s:
    print("Expected task creation handler was not found. The file may already be patched or has changed.")
else:
    s = s.replace(old, new)
    p.write_text(s)
    print("Patched task creation UI error handling.")
PY

echo "Done. Now rebuild with: bash start.sh"
