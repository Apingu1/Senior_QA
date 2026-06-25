# Senior QA System Design

## System intent

Senior QA is an internal AI-assisted pharmaceutical Quality Assurance drafting and workflow platform.

It helps the QA team upload controlled copies of SOPs, forms, templates and guidance, create QMS tasks, allow the AI assistant to prepare draft outputs, raise missing-information questions, and route drafts for human review.

The platform is not the live QMS and is not intended to make final regulated decisions.

## Phase 3 architecture

```text
React Frontend
    ↓
FastAPI Backend
    ↓
PostgreSQL Database
    ↓
Uploaded document storage
    ↓
Document chunk search
    ↓
AI drafting service
    ↓
Human review queue
```

## Core data objects

- KnowledgeDocument: uploaded copy of SOP, form, guidance, policy, template or example.
- DocumentChunk: searchable text chunk extracted from an uploaded document.
- QmsTask: task assigned to the AI QA assistant.
- AgentQuestion: structured question raised when more information is required.
- TaskOutput: draft prepared by the AI for human review.
- AgentRun: record of a manual or scheduled AI run.
- AuditEvent: event log entry for user and AI activity.

## Agent workflow

1. Read the task brief.
2. Retrieve relevant current documents from the knowledge base.
3. Check whether key information is missing.
4. Ask structured questions where needed.
5. Prepare a draft output when enough information is available.
6. List sources, assumptions and missing information.
7. Send the draft to the review queue.

## Autonomous workflow

The scheduled worker processes tasks in these statuses:

- New
- Assigned to AI
- In Progress
- Returned for Rework

The worker does not continue tasks that are waiting for human information or review.

## Human review model

All AI outputs are draft only. A competent QA reviewer must accept, return for rework, or reject the draft in the platform before any external use.

Any formal approval should still happen in the controlled QMS process used by the business.

## Suggested next phase controls

- User management UI
- Role and permission matrix
- Document replacement/versioning workflow
- Word/PDF export
- Configurable task templates
- Full vector search
- Prompt/version control
- AI use SOP
- Risk assessment
- Test scripts
- Periodic output quality review
- Backup and restore tooling
