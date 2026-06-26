#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python - <<'PY'
from pathlib import Path

p = Path("frontend/src/App.tsx")
s = p.read_text()

old = """  async function upload(e: FormEvent<HTMLFormElement>) { e.preventDefault(); const form = new FormData(e.currentTarget); await api('/documents', { method: 'POST', body: form }); e.currentTarget.reset(); setToast('Document uploaded and indexed.'); await load() }"""

new = """  async function upload(e: FormEvent<HTMLFormElement>) {
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
  }"""

if old not in s:
    print("Expected upload handler was not found. The file may already be patched or has changed.")
else:
    s = s.replace(old, new)
    p.write_text(s)
    print("Patched document upload UI error handling.")
PY

echo "Done. Now rebuild with: bash start.sh"
