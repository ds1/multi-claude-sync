# Project Sync Log

Shared coordination file for Claude instances working on related projects.

**Projects:**
| Alias | Project | Description |
|-------|---------|-------------|
| **cf** | `my-frontend` | Frontend app (React/Vue/etc.) |
| **cb** | `my-backend` | Backend API (Node/Python/etc.) |

**User**: your-name

**Instructions for Claude instances:**
1. Read this file at the start of each session to catch up on cross-project changes
2. Add entries when making changes that affect the other project
3. Use the format below for entries
4. Mark items as resolved with ~~strikethrough~~ when addressed
5. **IMPORTANT**: If "User Input Needed" section has items, immediately alert the user at session start
6. When you need info from the other Claude, add to "Attention Needed" under that project's name
7. **IMPORTANT**: Log all commits and pushes to the "Commit/Push Log" section immediately after executing them

---

## API Contract

Base URL: `https://api.example.com` (production) / `http://localhost:3001` (dev)

**Auth header for protected endpoints:** `Authorization: Bearer <access_token>`

### Authentication Endpoints

#### POST `/api/auth/login`
```
Request:  { email: string, password: string }
Response: { access_token: string, refresh_token: string, user: { id, email, name } }
Errors:   { error: string, code: "INVALID_CREDENTIALS" | "USER_NOT_FOUND" }
```

#### POST `/api/auth/signup`
```
Request:  { email: string, password: string, name: string }
Response: { user: { id, email, name }, message: string }
Errors:   { error: string, code: "EMAIL_EXISTS" | "VALIDATION_ERROR" }
```

*(Add more endpoints as needed)*

---

## Coordinated Task List

*Shared task list for parallel work. Update status as you work. Mark blockers clearly.*

### Legend
- `[ ]` Not started | `[~]` In progress | `[x]` Complete | `[!]` Blocked
- **Owner**: cf, cb, user, or both
- **Deps**: Dependencies on other tasks

### Phase 1: Authentication

| ID | Task | Owner | Status | Deps | Notes |
|----|------|-------|--------|------|-------|
| A1 | Implement login API | cb | [ ] | - | |
| A2 | Implement signup API | cb | [ ] | - | |
| A3 | Build login form | cf | [ ] | A1 | |
| A4 | Build signup form | cf | [ ] | A2 | |
| A5 | Add auth state management | cf | [ ] | A1 | |

*(Add more phases/tasks as needed)*

### Current Focus

**cf**: (describe current work)

**cb**: (describe current work)

---

## Commit/Push Log

*Log all commits and pushes here immediately after executing them.*

### my-frontend (cf)

| Date | Type | Hash | Message | Notes |
|------|------|------|---------|-------|
| | | | | |

### my-backend (cb)

| Date | Type | Hash | Message | Notes |
|------|------|------|---------|-------|
| | | | | |

---

## Sync Log

### YYYY-MM-DD | project-name | Brief description
- Details of changes made
- Files modified
- Impact on other project

---

## Decisions (Resolved)

*Finalized decisions for implementation reference*

### 1. Example Decision
- **Decision**: Description of what was decided
- **Rationale**: Why this choice was made
- **Implementation**: How to implement
- **Decided**: YYYY-MM-DD

---

## Breaking Changes Queue

*List API changes here that require updates in the other project*

(none currently)

---

## Questions / Decisions Needed

*Cross-project questions that need discussion or user input*

(none currently)

---

## User Input Needed

*Items here require a decision from the user. Claude instances: alert the user immediately at session start if this section has items.*

(none currently)

---

## User Action Items

*Pending actions that require user to execute. Claude instances: send system notification when adding items here.*

### Pending

| Item | Action | Context | Added |
|------|--------|---------|-------|
| | | | |

### Completed
*(move items here when done)*

---

## Attention Needed

*Flag items here when you need the other project's Claude to review/respond. Check your section at session start.*

### For my-frontend (from backend)
- (none)

### For my-backend (from frontend)
- (none)

---

## Sprint Retrospectives

*At end of work sessions, both Claude instances summarize accomplishments and cross-review for accuracy.*

### YYYY-MM-DD | Sprint/Session Name

**cf summary:**
- Features built: ...
- Files created: ...
- Decisions made: ...

**cb review of cf summary:**
- Accurate / Corrections needed: ...

**cb summary:**
- Features built: ...
- Files created: ...
- Decisions made: ...

**cf review of cb summary:**
- Accurate / Corrections needed: ...

**Consensus:** (Both agree on final record)

**Meta-accomplishments:** (Process improvements, not just code)
