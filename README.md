# Senior QA — AI QA Officer Platform

Senior QA is a controlled AI-assisted pharmaceutical Quality Assurance workflow platform.

It is designed as a **GxP-supporting draft and decision-support tool**, not as the live QMS/eQMS and not as an approval system. The AI can read uploaded copies of SOPs, forms, procedures and external guidance, generate draft QMS outputs, ask missing-information questions, and route work for human QA review.

## Phase 3 scope included

- FastAPI backend
- PostgreSQL database
- React/TypeScript frontend
- Docker Compose stack
- Login/session baseline
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
- Safe fallback drafting mode when no AI API value is configured

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
cp example.env .env
docker compose -f infra/docker-compose.yml up --build
```

Then open:

- Frontend: http://localhost:5173
- API docs: http://localhost:8000/docs
- Health check: http://localhost:8000/health

Default local login is defined in `example.env`.

Change the default admin password and local development values before any real use.

## Main modules

```text
backend/app/main.py       FastAPI app, models, task engine, document indexing and agent worker
frontend/src/App.tsx      React dashboard and workflow screens
frontend/src/styles.css   UI styling
infra/docker-compose.yml  Local development stack
docs/Phase_3_Runbook.md   Setup and operating runbook
docs/System_Design.md     Architecture and workflow design
```

## How the autonomous part works

The background worker starts with the API and periodically checks tasks in these statuses:

- New
- Assigned to AI
- In Progress
- Returned for Rework

It will stop and ask questions if key information is missing. When questions are answered, the task is returned to the AI queue. When a draft is produced, the task moves to human review.

## Important compliance note

This scaffold is not a validated GxP system. It is a starting point for an internal AI QA drafting assistant. Before using it in a regulated process, perform a documented risk assessment, define an AI-use SOP, verify security/data integrity controls, test intended workflows, and keep human approval outside the AI.
