# Senior QA Phase 3 Runbook

## 1. Purpose

This runbook explains how to start and test the Phase 3 Senior QA AI Officer platform.

The platform is designed for controlled draft-support work only. It is not the live QMS and does not approve, close, release or reject regulated records.

## 2. Start the stack

From the repository root:

```bash
cp example.env .env
# Optional: export OPENAI_API_KEY in your shell or add it to your local .env setup

docker compose -f infra/docker-compose.yml up --build
```

Open:

- Frontend: http://localhost:5173
- Backend health: http://localhost:8000/health
- Backend docs: http://localhost:8000/docs

## 3. Login

The default local admin is configured in `example.env`.

Change the admin password and local environment values before any real use.

## 4. Build the knowledge base

Go to **Knowledge Base** and upload controlled copies of:

- Internal SOPs
- Forms
- Templates
- Policies
- External guidance
- Previous approved examples, if you want the AI to learn house style

Use metadata carefully:

- `current` = eligible for normal task retrieval
- `draft` = searchable but should not be treated as approved
- `superseded` = retained but excluded from default task retrieval

## 5. Create tasks

Go to **Task Board** and create a task such as:

```text
Title: Draft investigation for deviation DEV-2026-001
Task type: Deviation draft
Description: Include product, batch, event, date, initial action, impact and expected output.
```

New tasks are automatically assigned to AI.

## 6. AI workflow

The agent does the following:

1. Reads the task brief.
2. Searches current knowledge-base documents.
3. Checks for obvious missing information.
4. Either asks questions or prepares a draft output.
5. Routes the draft to human review.

## 7. Missing information

If the agent needs additional facts, it creates questions in **Question Inbox**.

When all open questions for a task are answered, the task is returned to `Assigned to AI`, ready for the autonomous worker or manual run.

## 8. Autonomous worker

The backend starts a scheduled worker when `AUTONOMOUS_WORKER_ENABLED=true`.

It checks tasks in these statuses:

- New
- Assigned to AI
- In Progress
- Returned for Rework

It then attempts to continue the work. You can also press **Run autonomous queue now** on the dashboard.

## 9. Review queue

Drafts go to **Review Queue**.

Reviewer decisions:

- Accept draft = task moves to `Human Approved`
- Return for rework = task moves back to AI queue
- Reject = task closes as rejected

This is only the application review state. Any actual GMP approval should still happen in your controlled QMS process.

## 10. Audit log

The audit log records key events:

- Logins
- Document uploads
- Task creation/updates
- Agent runs
- Question answers
- Output reviews

## 11. Known MVP limitations

This Phase 3 scaffold deliberately keeps the design simple:

- No live eQMS connection
- No SharePoint integration yet
- No electronic signatures
- No formal validated workflow engine
- Basic keyword/chunk retrieval rather than full vector search
- Basic local session handling
- No user management UI yet

These are suitable next-phase enhancements once the core workflow is proven.
