# Senior QA — AI QA Officer Platform

Senior QA is a controlled AI-assisted pharmaceutical Quality Assurance workflow platform.

It is designed as a **GxP-supporting draft and decision-support tool**, not as the live QMS/eQMS and not as an approval system. The AI can read uploaded copies of SOPs, forms, procedures and external guidance, generate draft QMS outputs, ask missing-information questions, and route work for human QA review.

## Phase 3 scope included

- FastAPI backend
- PostgreSQL database
- React/TypeScript frontend
- Docker Compose stack
- Login/RBAC baseline
- Knowledge base document upload
- PDF/DOCX/TXT text extraction
- Document chunking and searchable knowledge base
- QA task board
- AI task runner
- Missing-information question queue
- Draft output generation
- Human review queue
- Agent run/audit log
- Autonomous scheduled worker for open tasks
- Safe fallback drafting mode when no OpenAI API key is configured

## Intended operating model

```text
Upload controlled copies of SOPs/forms/guidance
        ↓
Create QMS task
        ↓
AI retrieves relevant knowledge-base documents
        ↓
AI drafts output or asks structured questions
        ↓
Human answers questions / reviews draft
        ↓
Reviewer accepts, rejects, or sends back for rework
```

The AI must not approve, close, release, reject, or make final GMP decisions.

## Quick start

```bash
cp .env.example .env
# add OPENAI_API_KEY if you want live AI drafting

docker compose -f infra/docker-compose.yml up --build
```

Then open:

- Frontend: http://localhost:5173
- API docs: http://localhost:8080/docs

Default login from `.env.example`:

- Username: `admin`
- Password: `ChangeMe123!`

Change these before any real use.

## Main modules

```text
backend/app/auth          Login and current-user endpoints
backend/app/documents     Upload and search SOPs/forms/guidance
backend/app/tasks         Task board and AI task execution
backend/app/questions     Missing-information workflow
backend/app/reviews       Draft output review workflow
backend/app/audit         Event/run logging
frontend/src              React dashboard and user interface
```

## Important compliance note

This scaffold is not a validated GxP system. It is a starting point for an internal AI QA drafting assistant. Before using it in a regulated process, perform a documented risk assessment, define an AI-use SOP, verify security/data integrity controls, test intended workflows, and keep human approval outside the AI.
