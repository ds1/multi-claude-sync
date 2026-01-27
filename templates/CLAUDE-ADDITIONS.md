# CLAUDE.md Additions for Multi-Claude Sync

Add this section to each project's `CLAUDE.md` file to enable cross-project synchronization.

---

## Template (copy and customize)

```markdown
## Related Projects

This project is part of a multi-project workspace with coordinated Claude instances.

### Cross-Project Sync File
Location: `/path/to/workspace/SYNC.md`

**At the start of each session:**
1. Read the sync file to catch up on changes from the other project
2. Check "Attention Needed > For [this-project-name]" for items requiring response
3. **IMPORTANT: If "User Input Needed" has items, alert the user immediately**
4. Review "Commit/Push Log" for recent changes from the other project
5. Review "Decisions (Resolved)" for any new architecture decisions

**When making changes that affect the other project:**
1. Update the relevant section in the sync file (API Contract, Task List, etc.)
2. Add to "Attention Needed > For [other-project-name]" if the other Claude needs to take action
3. Log all commits to "Commit/Push Log" immediately after executing

**Commit convention:** Use `[alias]` prefix for commits (e.g., `[cf] Add login form`)

### Related Project
- **[other-project-name]** (`/path/to/other-project`) - Brief description
- Run by Claude instance with alias: `[other-alias]`

### Multi-Claude Workflow Guide
Full documentation: `/path/to/workspace/WORKFLOW-GUIDE.md` or see multi-claude-sync repo
```

---

## Example: Frontend Project

```markdown
## Related Projects

This project is part of a multi-project workspace with coordinated Claude instances.

### Cross-Project Sync File
Location: `C:\Users\dan\workspace\SYNC.md`

**At the start of each session:**
1. Read the sync file to catch up on changes from the backend
2. Check "Attention Needed > For my-frontend" for items requiring response
3. **IMPORTANT: If "User Input Needed" has items, alert the user immediately**
4. Review "Commit/Push Log" for recent backend commits
5. Review "Decisions (Resolved)" for any new architecture decisions

**When making changes that affect the backend:**
1. Update the relevant section in the sync file
2. Add to "Attention Needed > For my-backend" if cb needs to take action
3. Log all commits to "Commit/Push Log" immediately after executing

**Commit convention:** Use `[cf]` prefix for commits (e.g., `[cf] Add login form`)

### Related Project
- **my-backend** (`C:\Users\dan\workspace\my-backend`) - Node.js API server
- Run by Claude instance with alias: `cb`

### Multi-Claude Workflow Guide
Full documentation: `C:\Users\dan\workspace\WORKFLOW-GUIDE.md`
```

---

## Example: Backend Project

```markdown
## Related Projects

This project is part of a multi-project workspace with coordinated Claude instances.

### Cross-Project Sync File
Location: `C:\Users\dan\workspace\SYNC.md`

**At the start of each session:**
1. Read the sync file to catch up on changes from the frontend
2. Check "Attention Needed > For my-backend" for items requiring response
3. **IMPORTANT: If "User Input Needed" has items, alert the user immediately**
4. Review "Commit/Push Log" for recent frontend commits
5. Review "Decisions (Resolved)" for any new architecture decisions

**When making changes that affect the frontend:**
1. Update the API Contract section in the sync file
2. Add to "Attention Needed > For my-frontend" if cf needs to take action
3. Log all commits to "Commit/Push Log" immediately after executing

**Commit convention:** Use `[cb]` prefix for commits (e.g., `[cb] Add rate limiting`)

### Related Project
- **my-frontend** (`C:\Users\dan\workspace\my-frontend`) - React frontend app
- Run by Claude instance with alias: `cf`

### Multi-Claude Workflow Guide
Full documentation: `C:\Users\dan\workspace\WORKFLOW-GUIDE.md`
```

---

## Placement

Add this section to your project's `CLAUDE.md` file, typically:
- At the end of the file, or
- After the "Project Overview" section

The file location varies by project:
- Root: `CLAUDE.md`
- Hidden: `.claude/CLAUDE.md`
- Config: `.claude/config/CLAUDE.md`

Check your existing project structure and follow the convention.
