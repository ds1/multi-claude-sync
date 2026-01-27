# Multi-Claude Workflow Guide

This document describes how to run multiple Claude Code instances in sync across related projects.

## Overview

When working on interconnected projects (e.g., a desktop app + its backend API), you can run separate Claude instances for each project and have them coordinate through a shared sync file.

**Example Setup:**
| Alias | Project | Description |
|-------|---------|-------------|
| **cf** | `my-frontend` | React frontend app |
| **cb** | `my-backend` | Node.js API server |

**Sync File**: Located in parent directory, accessible to both projects.

---

## Setup Guide

### Step 1: Create the Sync File

Create `SYNC.md` (or `PROJECT-SYNC.md`) in the parent directory of your projects:

```
workspace/
├── SYNC.md                 # Shared sync file
├── my-frontend/            # Project 1
└── my-backend/             # Project 2
```

Use the template in `templates/SYNC.md` as a starting point.

### Step 2: Update Each Project's CLAUDE.md

Add to each project's `CLAUDE.md` (or `.claude/CLAUDE.md`):

```markdown
## Related Projects

### Cross-Project Sync File
Location: `/path/to/workspace/SYNC.md`

**At the start of each session:**
1. Read the sync file to catch up on changes
2. Check "Attention Needed > For [this-project]" for items requiring response
3. **IMPORTANT: If "User Input Needed" has items, alert the user immediately**
4. Check "Commit/Push Log" for recent changes from the other project

**When making changes:**
- Add to Sync Log when modifying anything that affects the other project
- Add to "Attention Needed > For [other-project]" when you need info
- Log all commits and pushes to "Commit/Push Log" immediately after executing
```

### Step 3: Choose Aliases

Pick short, memorable aliases for each Claude instance:

| Pattern | Examples |
|---------|----------|
| `c` + first letter | `cf` (frontend), `cb` (backend) |
| `c` + abbreviation | `cm` (metrics), `cw` (website) |
| Project initials | `api`, `app`, `web` |

Use these in:
- Verbal communication ("cf, check the sync file")
- Commit prefixes (`[cf] Add login form`)
- Sync file entries

---

## Starting a Session

### Open Two Terminals

```bash
# Terminal 1 - Frontend
cd /path/to/my-frontend
claude

# Terminal 2 - Backend
cd /path/to/my-backend
claude
```

### Initialize Each Instance

**For cf (frontend):**
```
Your alias is "cf" (Claude Frontend). I also have "cb" (Claude Backend) running.

Before we begin:
1. Read the sync file: /path/to/SYNC.md
2. Check "Attention Needed > For my-frontend" for items from cb
3. Check "User Input Needed" - alert me immediately if there are items
4. Review "Decisions (Resolved)" for recent architecture decisions
5. Check "Commit/Push Log" for recent changes

Summarize anything important from the sync file, then we can proceed.
```

**For cb (backend):**
```
Your alias is "cb" (Claude Backend). I also have "cf" (Claude Frontend) running.

Before we begin:
1. Read the sync file: /path/to/SYNC.md
2. Check "Attention Needed > For my-backend" for items from cf
3. Check "User Input Needed" - alert me immediately if there are items
4. Review "Decisions (Resolved)" for recent architecture decisions
5. Check "Commit/Push Log" for recent changes

Summarize anything important from the sync file, then we can proceed.
```

---

## Communication

### Talking to Each Claude

Use aliases to be explicit:

```
# To frontend Claude:
"cf, update the login form to use the new API endpoint"

# To backend Claude:
"cb, add rate limiting to the auth endpoints"

# To both (copy-paste to each):
"Check the sync file, I've added a decision that affects both projects"
```

### Shorthand Commands

| Command | Action |
|---------|--------|
| "Check sync" | Claude reads the sync file |
| "Update sync" | Claude adds recent changes to sync log |
| "What does cf/cb need?" | Claude checks Attention Needed section |
| "Log your commit" | Claude adds commit to Commit/Push Log |

### Relaying Between Claudes

When one Claude needs to tell the other something:

1. **Claude adds to sync file** → "Attention Needed > For [other-project]"
2. **You tell the other Claude**: "Check the sync file" or "cf/cb left you a message"
3. **Other Claude reads and responds** in the sync file
4. **Original Claude** can be told to check for the response

---

## Sync File Sections

### API Contract

Document all API endpoints with exact request/response formats:

```markdown
### POST `/api/auth/login`
Request:  { email: string, password: string }
Response: { access_token: string, user: { id, email, name } }
Error:    { error: string, code: "INVALID_CREDENTIALS" | "USER_NOT_FOUND" }
```

### Coordinated Task List

Shared task tracking with ownership and dependencies:

```markdown
| ID | Task | Owner | Status | Deps | Notes |
|----|------|-------|--------|------|-------|
| A1 | Implement login API | cb | [x] | - | Complete |
| A2 | Build login form | cf | [~] | A1 | In progress |
| A3 | Add session management | cb | [ ] | A1 | Not started |
```

Legend: `[ ]` Not started | `[~]` In progress | `[x]` Complete | `[!]` Blocked

### Commit/Push Log

Track all commits and pushes:

```markdown
### my-frontend (cf)
| Date | Type | Hash | Message | Notes |
|------|------|------|---------|-------|
| 2026-01-27 | commit | `abc123` | [cf] Add login form | Completes A2 |
| 2026-01-27 | push | - | origin/main | 3 commits |

### my-backend (cb)
| Date | Type | Hash | Message | Notes |
|------|------|------|---------|-------|
| 2026-01-27 | commit | `def456` | [cb] Add rate limiting | Security hardening |
```

### Decisions (Resolved)

Document finalized decisions with rationale:

```markdown
### 1. Authentication Method
- **Decision**: JWT with refresh tokens
- **Rationale**: Stateless, works well with multiple frontends
- **Implementation**: Access token (15min), refresh token (7 days)
- **Decided**: 2026-01-27
```

### User Input Needed

Items requiring YOUR decision (Claude alerts you):

```markdown
1. **Database choice** - PostgreSQL vs MySQL? Need decision before proceeding with schema.
```

### User Action Items

Tasks that require the user (not Claude) to execute. Claude sends a system notification when adding items.

```markdown
## User Action Items

*Pending actions that require user to execute. Claude: send system notification when adding items.*

### Pending

| Item | Action | Context | Added |
|------|--------|---------|-------|
| Run migration | Execute `migrations/001.sql` | Required for new API endpoint | 2026-01-27 |
| Set env var | Add `API_KEY=xxx` to Vercel | Needed for production deploy | 2026-01-27 |

### Completed
*(move items here when done)*
```

**When to use:** Database migrations, environment variable setup, external service configuration, deployment steps, or any action requiring access/permissions Claude doesn't have.

**Process:**
1. Claude adds item to "User Action Items > Pending" table
2. Claude sends system notification with action + context
3. User executes the action
4. User (or Claude) moves item to "Completed"

### Attention Needed

Inter-Claude communication:

```markdown
### For my-frontend (from backend)
- **2026-01-27**: New `/api/users/profile` endpoint ready - see API Contract

### For my-backend (from frontend)
- **2026-01-27**: Need CORS configured for localhost:3000
```

---

## Workflow Examples

### Example 1: API Change

**Scenario:** Backend Claude changes an API response format.

1. **cb** updates API Contract section with new format
2. **cb** adds to "Attention Needed > For my-frontend":
   ```markdown
   - **2026-01-27**: Breaking change to /api/users - see API Contract
   ```
3. **You** tell cf: "Check the sync file, cb made an API change"
4. **cf** reads sync file, updates frontend code
5. **cf** adds to Sync Log confirming the update
6. **cf** marks the Attention item as resolved with ~~strikethrough~~

### Example 2: Architecture Decision

**Scenario:** Need to decide on state management.

1. **Either Claude** adds to "User Input Needed":
   ```markdown
   1. **State management** - Redux vs Zustand vs Context API?
   ```
2. **Both Claudes** alert you about pending decision
3. **You** ask each Claude for their perspective
4. **You** make the decision
5. **Either Claude** moves to "Decisions (Resolved)" with details

### Example 3: Parallel Development

**Scenario:** Both Claudes working on related features.

1. **You** create tasks in Coordinated Task List with dependencies
2. **cb** works on API endpoints (no dependencies)
3. **cf** sees A2 depends on A1, waits or works on other tasks
4. **cb** marks A1 complete, logs commit
5. **You** tell cf: "A1 is done, you can proceed with A2"
6. **cf** implements frontend, logs commit

---

## Best Practices

### Do

- Start each session by reading the sync file
- Log commits immediately after making them
- Be explicit about which project you're discussing
- Document decisions with enough detail for implementation
- Use strikethrough to mark resolved items
- Keep the API Contract section accurate

### Don't

- Assume one Claude knows what happened in the other's session
- Make API changes without updating the contract
- Skip logging commits (breaks the audit trail)
- Let "User Input Needed" items sit unaddressed
- Resolve decisions without recording rationale

---

## Pre-Push Alignment Review

Before pushing commits, both Claude instances should verify their changes are compatible.

### Process

1. **List unpushed commits** - Each Claude lists their pending commits in the Commit/Push Log
2. **Create alignment table** - One Claude creates a cross-project compatibility check:

```markdown
| Area | Project A | Project B | Aligned? |
|------|-----------|-----------|----------|
| Auth endpoints | Existing API | Consumes via auth.ts | ✓ |
| Feature flags | Updated names | Updated types | ✓ |
| New endpoint | Created /api/foo | Will consume | ✓ |
```

3. **Cross-confirm** - Other Claude reviews and confirms:
```markdown
**cm**: ✅ CONFIRMED ALIGNED. Verified:
- auth.ts correctly calls endpoints
- Types match API contract
Ready to push.
```

4. **Coordinated push** - Both push after confirmation

### Why This Works

- Catches API contract drift before it ships
- Creates audit trail of compatibility verification
- Zero integration conflicts when both sides confirm

---

## Sprint Retrospective

At the end of a work session or sprint, conduct a cross-review:

### Process

1. **Each Claude summarizes** - Both instances write a summary of accomplishments
2. **Cross-review** - Share summaries between instances for review
3. **Corrections & additions** - Each Claude notes corrections or additions to the other's summary
4. **Reach consensus** - Iterate until both agree on the facts
5. **Record in sync file** - Final summary becomes the official record

### What to Include in Summaries

- Features built (by project)
- Key decisions made
- Files created/modified
- Process improvements established
- What's remaining
- Commit/push stats

### Benefits

- **Accuracy** - Two perspectives catch omissions
- **Completeness** - Each Claude knows their own work best
- **Alignment** - Confirms both sides have the same understanding
- **Documentation** - Creates comprehensive record for future sessions

### Example Cross-Review

```markdown
**cw's summary**: [detailed summary]

**cm's review**:
- Accurate overall
- Correction: Rust build is DONE, not pending
- Addition: Decision #1 should note hardware-bound ID enhancement
- Missing: Client-side heartbeat sender as remaining item

**cw's response**:
- Corrections accepted
- Updated remaining items table

**Result**: Consensus reached, both summaries combined form complete record
```

### Meta-Insight

The retrospective often reveals the "meta-accomplishment" - not just what code shipped, but what process improvements were made. In multi-Claude work, the coordination system itself is a deliverable.

---

## Troubleshooting

### "Claude doesn't know about recent changes"

Claude instances don't automatically see sync file updates. Tell them:
- "Check the sync file"
- "cf/cb updated the sync file, read it"

### "Sync file is getting too long"

Periodically clean up:
1. Remove ~~strikethrough~~ items older than 2 weeks
2. Archive old Sync Log entries
3. Summarize completed task sections

### "Conflicting edits to sync file"

If both Claudes edit simultaneously:
1. One Claude's changes may be overwritten
2. Have the affected Claude re-read and re-add their changes
3. Consider having only one Claude edit at a time for complex updates

---

## Advanced: Future Improvements

### MCP Server for Real-Time Sync

A custom MCP server could provide:
- Shared key-value store
- Real-time change notifications
- Message queue for inter-Claude communication

### Git-Based Sync

- Each Claude commits sync file changes
- Pull before reading, commit after writing
- Git history provides audit trail

### File Watcher

A background process that notifies Claude when sync file changes:
```bash
# Hypothetical
watchman-wait . --pattern "SYNC.md" | while read; do
  notify-claude "Sync file updated"
done
```

---

## File Reference

| File | Purpose |
|------|---------|
| `SYNC.md` | Shared sync file (in workspace root) |
| `WORKFLOW-GUIDE.md` | This guide |
| `project/CLAUDE.md` | Project-specific context + sync instructions |
