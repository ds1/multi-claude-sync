# Multi-Claude Workflow Guide

This document describes how to run multiple Claude Code instances in sync across related projects.

## Overview

When working on interconnected projects (e.g., a desktop app + its backend API), you can run separate Claude instances for each project and have them coordinate through a shared sync file.

**Current Setup:**
| Alias | Project | Description |
|-------|---------|-------------|
| **cm** | `petal-metrics` | Desktop app (Tauri/React/Rust) |
| **cw** | `petal-tech-website` | Web platform (Next.js/Supabase/Stripe) |

**Sync File**: `C:\Users\danma\Documents\GitHub\PETAL-SYNC.md`

---

## User Setup Guide

### First-Time Setup

If starting fresh or adding this workflow to new projects:

#### Step 1: Create the Sync File

Create `PETAL-SYNC.md` (or `PROJECT-SYNC.md`) in the parent directory of your projects:

```
C:\Users\danma\Documents\GitHub\
├── PETAL-SYNC.md           # Shared sync file
├── MULTI-CLAUDE-WORKFLOW.md # This guide
├── petal-metrics/          # Project 1
└── petal-tech-website/     # Project 2
```

**Minimum sync file template:**
```markdown
# Project Sync Log

**Projects:**
- `project-1` - Description
- `project-2` - Description

**Instructions for Claude instances:**
1. Read this file at the start of each session
2. Check "Attention Needed" for items from the other project
3. If "User Input Needed" has items, alert the user immediately
4. Add entries when making changes that affect the other project

---

## User Input Needed
(none)

---

## Attention Needed

### For project-1 (from project-2)
- (none)

### For project-2 (from project-1)
- (none)

---

## Sync Log

### YYYY-MM-DD | project-name | Description
- Details here
```

#### Step 2: Update Each Project's CLAUDE.md

Add to each project's `.claude/CLAUDE.md` (or create it):

```markdown
## Related Projects

### Cross-Project Sync File
Location: `C:\Users\danma\Documents\GitHub\PETAL-SYNC.md`

**At the start of each session:**
1. Read the sync file to catch up on changes
2. Check "Attention Needed > For [this-project]" for items requiring response
3. **IMPORTANT: If "User Input Needed" has items, alert the user immediately**

**When making changes:**
- Add to Sync Log when modifying anything that affects the other project
- Add to "Attention Needed > For [other-project]" when you need info

### Multi-Claude Workflow Guide
Full documentation: `C:\Users\danma\Documents\GitHub\MULTI-CLAUDE-WORKFLOW.md`
```

#### Step 3: Update Each Project's README.md

Add a Development section with the quick-start prompt (see examples below).

### Starting a New Session

#### Option A: Two Terminal Windows

```bash
# Terminal 1 (cm - Metrics)
cd C:\Users\danma\Documents\GitHub\petal-metrics
claude

# Terminal 2 (cw - Website)
cd C:\Users\danma\Documents\GitHub\petal-tech-website
claude
```

#### Option B: VS Code with Multiple Terminals

1. Open VS Code
2. Open two terminal panes (split)
3. Run `claude` in each, pointed at different project directories

### Talking to Each Claude

Use the aliases to keep track:

```
# To cm (Metrics Claude):
"cm, check the sync file - cw made some API changes"

# To cw (Website Claude):
"cw, I need you to update the subscription endpoint"

# To both (copy-paste to each):
"Check the sync file, I've added a new decision that needs input from both of you"
```

### Relaying Information Between Claudes

When one Claude needs to tell the other something:

1. **Claude adds to sync file** → "Attention Needed > For [other-project]"
2. **You tell the other Claude**: "Check the sync file" or "cm/cw left you a message"
3. **Other Claude reads and responds** in the sync file
4. **Original Claude** can be told to check for the response

**Shorthand commands you can use:**
- "Check sync" - Claude reads the sync file
- "Update sync" - Claude adds their recent changes to the sync log
- "What does cw/cm need?" - Claude checks Attention Needed section

---

## Quick Start

### 1. Open Two Claude Code Instances

```bash
# Terminal 1 - cm (Claude Metrics)
cd C:\Users\danma\Documents\GitHub\petal-metrics
claude

# Terminal 2 - cw (Claude Website)
cd C:\Users\danma\Documents\GitHub\petal-tech-website
claude
```

### 2. Initial Prompt for Each Instance

**For cm (petal-metrics):**
```
Your alias is "cm" (Claude Metrics). I also have "cw" (Claude Website) running on petal-tech-website.

Before we begin:
1. Read the cross-project sync file: C:\Users\danma\Documents\GitHub\PETAL-SYNC.md
2. Check "Attention Needed > For petal-metrics" for any items from cw
3. Check "User Input Needed" - if there are items, alert me immediately
4. Review "Decisions (Resolved)" for any recent architecture decisions

Summarize anything important from the sync file, then we can proceed.
```

**For cw (petal-tech-website):**
```
Your alias is "cw" (Claude Website). I also have "cm" (Claude Metrics) running on petal-metrics.

Before we begin:
1. Read the cross-project sync file: C:\Users\danma\Documents\GitHub\PETAL-SYNC.md
2. Check "Attention Needed > For petal-tech-website" for any items from cm
3. Check "User Input Needed" - if there are items, alert me immediately
4. Review "Decisions (Resolved)" for any recent architecture decisions

Summarize anything important from the sync file, then we can proceed.
```

---

## Sync File Structure

The `PETAL-SYNC.md` file contains these sections:

| Section | Purpose |
|---------|---------|
| **API Contract** | Detailed request/response formats for all endpoints |
| **Subscription Tiers** | Feature flags and pricing for each tier |
| **Decisions (Resolved)** | Finalized architecture decisions with implementation details |
| **Sync Log** | Chronological log of cross-project changes |
| **Breaking Changes Queue** | API changes that require updates in the other project |
| **Questions / Decisions Needed** | Open questions requiring discussion |
| **User Input Needed** | Items requiring YOUR decision (Claude alerts you) |
| **Attention Needed** | Inter-Claude communication (each checks their section) |

---

## Communication Protocols

### Claude-to-Claude Communication

When one Claude needs information from the other:

1. Add item to "Attention Needed > For [other-project]" in sync file
2. The other Claude checks this section at session start
3. Response is added below the item or in a new sync log entry
4. Original item is marked with ~~strikethrough~~ when resolved

**Example:**
```markdown
### For petal-metrics (from website)
- **2026-01-26**: Need to know the expected device_id format for license activation
  - **Response**: UUID v4 generated on first run, persisted locally
```

### Claude-to-User Communication

When Claude needs a decision from you:

1. Claude adds item to "User Input Needed" section
2. Both Claude instances alert you at session start if items exist
3. You make the decision
4. Claude moves item to "Decisions (Resolved)" with full details

### User-to-Both-Claudes Communication

When you need to inform both Claude instances of something:

1. Add entry to "Sync Log" section with date and details
2. Or add to "Breaking Changes Queue" if it's an API change
3. Both Claudes will see it when they read the sync file

---

## Workflow Examples

### Example 1: API Change

**Scenario:** Website Claude needs to change an API response format.

1. **Website Claude** adds to "Breaking Changes Queue":
   ```markdown
   - **2026-01-27**: `/api/v1/subscription/status` now returns `features` as array instead of object
     - Old: `features: { visualization: true, ... }`
     - New: `features: ["visualization", "recording", ...]`
     - Reason: Simpler to check with `.includes()`
   ```

2. **Website Claude** adds to "Attention Needed > For petal-metrics":
   ```markdown
   - **2026-01-27**: Breaking change in subscription status response - see Breaking Changes Queue
   ```

3. **You** inform Metrics Claude: "Check the sync file, there's a breaking change"

4. **Metrics Claude** reads sync file, updates TypeScript types and handling code

5. **Metrics Claude** adds to Sync Log:
   ```markdown
   ### 2026-01-27 | petal-metrics | Updated for subscription API change
   - Updated `SubscriptionStatus` type in `src/types/subscription.ts`
   - Updated `useSubscription` hook to handle array-based features
   ```

6. **Metrics Claude** marks the Breaking Changes item as resolved

### Example 2: Architecture Decision

**Scenario:** Need to decide on a new feature implementation.

1. **Either Claude** adds to "Questions / Decisions Needed":
   ```markdown
   1. **Session recording format**: What format should we use for cloud-synced EEG sessions?
      - Options: Raw CSV, compressed binary, or structured JSON?
      - Metrics perspective: (pending)
      - Website perspective: (pending)
   ```

2. **Either Claude** adds to "User Input Needed":
   ```markdown
   1. **Session recording format** - Need user decision (see Questions #1)
   ```

3. **Both Claudes** alert you about the pending decision

4. **You** ask each Claude for their perspective

5. **Each Claude** adds their recommendation to the question

6. **You** make the decision

7. **Either Claude** moves to "Decisions (Resolved)" with full details

---

## Tips for Effective Multi-Claude Work

### Do's

- **Start each session** by having Claude read the sync file
- **Be explicit** about which project you're discussing
- **Use the sync file** for anything that affects both projects
- **Document decisions** with enough detail for implementation
- **Keep the sync log updated** so future sessions have context

### Don'ts

- **Don't assume** one Claude knows what happened in the other's session
- **Don't make API changes** without documenting in Breaking Changes Queue
- **Don't resolve decisions** without recording the rationale
- **Don't let the sync file get stale** - clean up resolved items periodically

---

## Ideas for Improvement

### Current Limitations

1. **Manual notification**: You must tell each Claude when the sync file is updated
2. **No real-time sync**: Each Claude only sees changes when they read the file
3. **Context loss**: New sessions don't have previous conversation context

### Potential Improvements

#### 1. File Watcher Notification (Requires tooling)
```bash
# Hypothetical: A file watcher that notifies Claude when sync file changes
# Could be implemented with a custom MCP server
watchman-wait . --pattern "PETAL-SYNC.md" | while read; do
  echo "[SYNC FILE UPDATED] - Check PETAL-SYNC.md for changes"
done
```

#### 2. Custom MCP Server for Shared State
Build an MCP server that provides:
- Shared key-value store accessible by both Claude instances
- Real-time notifications when values change
- Message queue for inter-Claude communication

```typescript
// Hypothetical MCP server tools
tools: [
  "sync_read",      // Read from shared state
  "sync_write",     // Write to shared state
  "sync_subscribe", // Get notified of changes
  "sync_message",   // Send message to other Claude
]
```

#### 3. Webhook/Polling System
- Claude periodically checks sync file for changes (e.g., every N messages)
- Or: User can say "check sync" to trigger a re-read

#### 4. Git-Based Sync
- Each Claude commits sync file changes
- Pull before reading, commit after writing
- Git history provides audit trail

#### 5. Session Handoff Document
When ending a session, Claude writes a `SESSION-HANDOFF.md` with:
- What was accomplished
- What's in progress
- What needs attention next
- Relevant file changes

Next session can start by reading this handoff document.

---

## File Locations

| File | Purpose |
|------|---------|
| `C:\Users\danma\Documents\GitHub\PETAL-SYNC.md` | Shared sync file |
| `C:\Users\danma\Documents\GitHub\MULTI-CLAUDE-WORKFLOW.md` | This guide |
| `petal-metrics\.claude\CLAUDE.md` | Metrics project context + sync instructions |
| `petal-tech-website\CLAUDE.md` | Website project context + sync instructions |

---

## Maintenance

### Periodic Cleanup

Every few sessions, clean up the sync file:
1. Remove ~~strikethrough~~ resolved items older than 2 weeks
2. Archive old sync log entries to a separate `SYNC-ARCHIVE.md` if needed
3. Verify API Contract section matches actual implementations
4. Review "Decisions (Resolved)" for any that need revisiting

### Adding New Projects

To add a third project to the sync:
1. Add project to the "Projects" list at top of sync file
2. Add "For [new-project]" subsection under "Attention Needed"
3. Create CLAUDE.md in the new project with sync file instructions
4. Document any API contracts between new project and existing ones
