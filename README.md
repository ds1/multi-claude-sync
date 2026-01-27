# Multi-Claude Sync

A coordination system for running multiple Claude Code instances across related projects.

## The Problem

When working on interconnected projects (e.g., a desktop app + its backend API), each Claude Code instance operates independently with no awareness of the other. This leads to:

- API contracts getting out of sync
- Duplicate or conflicting implementations
- Lost context between sessions
- Manual copy-pasting of decisions between instances

## The Solution

A shared sync file and workflow that enables:

- **Cross-project coordination** - Both instances read/write to a shared sync file
- **API contract documentation** - Single source of truth for request/response formats
- **Decision tracking** - Architecture decisions documented with rationale
- **Inter-Claude communication** - Attention flags when one instance needs info from the other
- **Commit/push logging** - Track changes across both projects

## Quick Start

### 1. Set Up the Sync File

Place `SYNC.md` in the parent directory of your projects:

```
your-workspace/
├── SYNC.md                 # Shared sync file
├── project-frontend/       # Project 1
└── project-backend/        # Project 2
```

Copy `templates/SYNC.md` and customize for your projects.

### 2. Update Each Project's CLAUDE.md

Add sync file instructions to each project. See `templates/CLAUDE-ADDITIONS.md`.

### 3. Start Both Instances

```bash
# Terminal 1
cd project-frontend
claude

# Terminal 2
cd project-backend
claude
```

### 4. Initialize Each Session

Give each Claude its alias and point it to the sync file:

```
Your alias is "cf" (Claude Frontend). I also have "cb" (Claude Backend) running.

Before we begin:
1. Read the sync file: /path/to/SYNC.md
2. Check "Attention Needed > For [this-project]" for items from the other instance
3. Check "User Input Needed" - alert me immediately if there are items
4. Review recent entries in "Sync Log" and "Commit/Push Log"

Summarize anything important, then we can proceed.
```

## Documentation

- **[WORKFLOW-GUIDE.md](./WORKFLOW-GUIDE.md)** - Detailed guide for the multi-Claude workflow
- **[templates/SYNC.md](./templates/SYNC.md)** - Template sync file to customize
- **[templates/CLAUDE-ADDITIONS.md](./templates/CLAUDE-ADDITIONS.md)** - What to add to each project's CLAUDE.md
- **[examples/](./examples/)** - Real-world examples

## Key Concepts

### Aliases

Give each Claude instance a short alias (e.g., `cm`, `cw`, `cf`, `cb`) to:
- Keep track of which instance you're talking to
- Reference in the sync file
- Use in commit prefixes (e.g., `[cm] Add auth flow`)

### Sync File Sections

| Section | Purpose |
|---------|---------|
| **API Contract** | Request/response formats for all endpoints |
| **Coordinated Task List** | Shared tasks with status and dependencies |
| **Commit/Push Log** | Track commits and pushes from both projects |
| **Decisions (Resolved)** | Finalized architecture decisions |
| **User Input Needed** | Items requiring YOUR decision |
| **Attention Needed** | Inter-Claude communication |

### Communication Flow

```
Claude A needs info from Claude B:
1. Claude A adds to "Attention Needed > For Project B"
2. You tell Claude B: "Check the sync file"
3. Claude B reads, responds in sync file
4. You tell Claude A: "Check the sync file for response"
```

### Pre-Push Alignment Review

Before pushing, verify both sides are compatible:

1. Each Claude lists unpushed commits in Commit/Push Log
2. One Claude creates alignment table (API → Client mappings)
3. Other Claude confirms: "✅ CONFIRMED ALIGNED"
4. Both push after confirmation

This catches API contract drift before it ships. Zero integration conflicts when both sides verify.

### Sprint Retrospective

At end of session, conduct cross-review:

1. Each Claude writes summary of accomplishments
2. Share summaries between instances for review
3. Each notes corrections/additions to the other's summary
4. Iterate until consensus reached
5. Combined summaries become official record

**Why this matters:** Two perspectives catch omissions. The retro often reveals the "meta-accomplishment" - not just code shipped, but process improvements made.

## Tips

- **Start every session** by having Claude read the sync file
- **Log commits immediately** after making them
- **Use the sync file** for anything affecting both projects
- **Be explicit** about which project/Claude you're addressing
- **Clean up periodically** - archive old resolved items

## Contributing

This workflow evolved from real multi-project development. If you have improvements or variations that work well, contributions are welcome.

## License

MIT
