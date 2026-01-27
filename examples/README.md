# Examples

Real-world examples of multi-Claude sync in action.

## Petal Technology

A coordinated development workflow for:
- **petal-metrics** (cm) - Desktop app built with Tauri + React + Rust
- **petal-tech-website** (cw) - Marketing site & API built with Next.js + Supabase + Stripe

### Files

- **[PETAL-SYNC.md](./PETAL-SYNC.md)** - Active sync file with:
  - Detailed API contract with request/response formats
  - 4-phase coordinated task list (Auth, License, Streaming, Security)
  - 5 resolved architecture decisions
  - Commit/push log tracking
  - Security hardening documentation

- **[PETAL-WORKFLOW.md](./PETAL-WORKFLOW.md)** - Project-specific workflow guide

### Notable Features

1. **Phased task list** - Tasks organized by feature area with dependencies
2. **Security hardening section** - Detailed threat model and mitigations
3. **API contract** - Complete endpoint documentation with error codes
4. **Decision log** - Architecture decisions with rationale and implementation details
5. **Commit tracking** - Both projects log commits for visibility

### Complexity Level

This is a complex example with:
- Desktop app (Rust backend) + Web API (TypeScript)
- Authentication, licensing, subscription management
- Security concerns (anti-piracy measures)
- Multiple phases of coordinated development

For simpler projects, you may not need all these sections.
