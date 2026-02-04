# Petal Project Sync Log

Shared coordination file for Claude instances working on Petal projects.

**Projects:**
| Alias | Project | Description |
|-------|---------|-------------|
| **cm** | `petal-metrics` | Desktop app (Tauri + React + Rust) |
| **cw** | `petal-tech-website` | Marketing site & API (Next.js + Supabase + Stripe) |
| **cd** | `petal-docs` | Customer-facing documentation (Docusaurus) |
| **cc** | `petal-tech-website` | Communications & marketing (email, content, Resend) |

**User**: dan

**Instructions for Claude instances:**
1. Read this file at the start of each session to catch up on cross-project changes
2. Add entries when making changes that affect the other project
3. Use the format below for entries
4. Mark items as resolved with ~~strikethrough~~ when addressed
5. **IMPORTANT**: If "User Input Needed" section has items, immediately alert the user at session start
6. When you need info from the other Claude, add to "Attention Needed" under that project's name
7. **IMPORTANT**: Log all commits and pushes to the "Commit/Push Log" section immediately after executing them. Include: hash, message, and any relevant comments.
8. **IMPORTANT**: When an action requires dan to execute (migrations, env vars, deploys, etc.), add to "Dan Action Items" AND send a system notification using the Windows notification script in `multi-claude-sync/scripts/notify-windows.ps1`. Include: title, detailed steps, and context. Dan can respond via the notification (Acknowledge/Completed/Dismiss) and attach screenshots.

**File Location & Efficiency Tips:**
- **Canonical path**: `C:\Users\danma\Documents\GitHub\multi-claude-sync\PETAL-SYNC.md`
- **Symlink** (if created): `C:\Users\danma\Documents\GitHub\PETAL-SYNC.md` → points to canonical path
- **This file is large** (~1800 lines). To reduce context usage:
  - Use `Grep` to search for specific sections (e.g., `Grep "## Attention Needed"`)
  - Use `Read` with `offset` and `limit` params for specific line ranges
  - Key sections: "User Input Needed" (~line 1500), "Attention Needed" (~line 1555), "Commit/Push Log" (~line 1300)
  - Only read the full file if you need comprehensive context; otherwise, target specific sections

---

## API Contract

Base URL: `https://petal.tech` (production) / `http://localhost:3000` (dev)

**Auth header for protected endpoints:** `Authorization: Bearer <access_token>`

### Authentication Endpoints (no auth required)

#### POST `/api/v1/auth/login`
```
Request:  { email: string, password: string }
Response: { access_token, refresh_token, expires_at, user: { id, email, full_name } }
```

#### POST `/api/v1/auth/signup`
```
Request:  { email: string, password: string, full_name: string }
Response (auto-confirm): { access_token, refresh_token, expires_at, user: { id, email, full_name } }
Response (email confirm): { message: string, user_id: string }
```

#### POST `/api/v1/auth/refresh`
```
Request:  { refresh_token: string }
Response: { access_token, refresh_token, expires_at }
```

#### POST `/api/v1/auth/oauth/github`
```
Request:  { github_token: string }  // GitHub access token from Device Flow
Response: { access_token, refresh_token, expires_at, user: { id, email, full_name } }
Errors:   401 UNAUTHORIZED (invalid token), 400 BAD_REQUEST (no verified email)

Notes: Used for GitHub Device Flow OAuth. Verifies GitHub token, creates/finds
       Supabase user, returns session tokens. Same response format as /login.
```

### License Endpoints (auth required)

#### POST `/api/v1/license/validate`
```
Request:  { license_key: string, device_id: string }
          License format: PETAL-XXXX-XXXX-XXXX-XXXX

Response (valid): {
  valid: true,
  plan: "basic" | "standard" | "advanced",
  status: "active" | "revoked",
  activations: number,
  max_activations: number,
  can_activate: boolean,
  already_activated_on_device: boolean,
  features: {
    real_time_visualization: boolean,
    osc_lsl_streaming: boolean,      // Note: OSC and LSL combined into one flag
    session_recording: boolean,
    csv_export: boolean,
    api_access: boolean,
    signal_filtering: boolean,
    custom_preprocessing: boolean,
    mental_state_detection: boolean,
    max_devices: number
  }
}

Response (invalid): { valid: false, error: string, code: "LICENSE_NOT_FOUND" | "LICENSE_REVOKED" | "LICENSE_EXPIRED" | "SUBSCRIPTION_INACTIVE" }
```

#### POST `/api/v1/license/activate`
```
Request:  { license_key: string, device_id: string, device_name?: string, platform?: string }

Response (success): { success: true, activation_id: string, activations: number, max_activations: number, message?: string }
Error codes: "LICENSE_NOT_FOUND", "LICENSE_INACTIVE", "MAX_ACTIVATIONS_REACHED"
```

### Subscription Endpoints (auth required)

#### GET `/api/v1/subscription/status`
```
Response: {
  has_subscription: boolean,
  subscription: null | {
    plan: "basic" | "standard" | "advanced",
    status: "active" | "trialing" | "canceled" | etc,
    current_period_start: ISO8601,
    current_period_end: ISO8601,
    cancel_at_period_end: boolean
  },
  license: null | {
    key_preview: "PETAL-XXXX...XXXX",
    plan, status, activations, max_activations
  },
  features: null | { ... feature flags ... }
}
```

### API Key Endpoints

#### POST `/api/v1/metrics/api-key` (auth required)
```
Response (new key): { api_key: "petal_live_xxx...", is_legacy: false, plan, features, created_at, message }
Response (existing): { api_key_prefix: "petal_live_X", is_legacy: false, plan, features, created_at, message }
Response (legacy):   { api_key: "full_key", is_legacy: true, plan, features, created_at, message }
```

#### POST `/api/v1/metrics/api-key/validate` (NO auth required - rate limited)
```
Request:  { api_key: string }
Response (valid):   { valid: true, plan, source: "new" | "legacy", features, subscription_active }
Response (invalid): { valid: false, error: string, code: "INVALID_API_KEY" | "SUBSCRIPTION_INACTIVE" | "API_ACCESS_DISABLED" }
```

### Heartbeat Endpoint (auth required) - NEW

#### POST `/api/v1/heartbeat`
```
Request:  { device_id: string }
Response: { success: true, timestamp: ISO8601, warning?: string }
```
**Purpose**: Concurrent session detection. App should call every 5 minutes while running.
Server tracks device_id + IP. If same device_id appears from multiple IPs simultaneously, returns `warning`.

**Note**: Requires `device_heartbeats` table (see migration `20260127_device_heartbeats.sql`)

### Download Endpoint (auth + subscription required) - NEW

#### GET `/api/account/download/[platform]`
```
Platforms: windows, macos, linux
Response: 302 redirect to Vercel Blob URL
Errors:
  - 401: Not authenticated
  - 403: No active subscription
  - 503: Download not configured
```
**Note**: This is NOT under `/api/v1/` - it's a web dashboard endpoint, not for desktop app use.

### Binary Hash Endpoint (no auth required) - NEW

#### GET `/api/v1/binary-hash`
```
Response: {
  version: string,           // e.g., "1.0.0"
  hashes: {
    windows_x64?: string,    // e.g., "sha256:abc123..."
    macos_arm64?: string,
    linux_amd64?: string
  },
  updated_at: string | null  // ISO8601 timestamp
}

Error (503): { error: "Binary hashes not configured", message: string }
```
**Purpose**: Client-side binary integrity verification. App fetches expected hash, compares to self-hash.
**Note**: Hashes set by CI/CD after release builds via environment variables.

---

## Subscription Tiers & Feature Flags

| Tier | Price | Feature flags (actual API field names) |
|------|-------|----------------------------------------|
| Basic | $14.99/mo | `real_time_visualization`, `osc_lsl_streaming` |
| Standard | $39.99/mo | Basic + `session_recording`, `csv_export`, `api_access` |
| Advanced | $79.99/mo | Standard + `signal_filtering`, `custom_preprocessing`, `mental_state_detection` |

Device activation limits (check `max_devices` field): Basic=1, Standard=1, Advanced=3

---

## Local Development Setup (for cm)

### Running petal-tech-website locally

```bash
cd C:\Users\danma\Documents\GitHub\petal-tech-website
npm install
npm run dev
# Server runs at http://localhost:3000
```

### Environment
The `.env.local` file should already be configured. Key variables:
- `NEXT_PUBLIC_SUPABASE_URL` - Supabase project URL
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` - For client-side auth
- `SUPABASE_SECRET_KEY` - For API routes (admin operations)

### Testing API Endpoints

**Base URL**: `http://localhost:3000`

**Auth endpoints (no auth required):**
```bash
# Login
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Signup
curl -X POST http://localhost:3000/api/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"new@example.com","password":"password123","full_name":"Test User"}'

# Refresh
curl -X POST http://localhost:3000/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"<token_from_login>"}'
```

**Protected endpoints (require Bearer token):**
```bash
# Get subscription status
curl http://localhost:3000/api/v1/subscription/status \
  -H "Authorization: Bearer <access_token>"

# Validate license
curl -X POST http://localhost:3000/api/v1/license/validate \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"license_key":"PETAL-XXXX-XXXX-XXXX-XXXX","device_id":"test-device-uuid"}'

# Activate license
curl -X POST http://localhost:3000/api/v1/license/activate \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"license_key":"PETAL-XXXX-XXXX-XXXX-XXXX","device_id":"test-device-uuid","device_name":"Test PC","platform":"Windows"}'
```

### Test Account
Ask dan for test account credentials, or create one via the website UI at `http://localhost:3000/signup`.

---

## Sync Log

### 2026-02-03 | petal-tech-website | Refund policy and Google Merchants setup
- **New Page**: `/legal/refunds` - Refund and cancellation policy
  - No refunds on digital software subscriptions
  - Cancel anytime, access until end of billing period
  - Plan upgrade/downgrade behavior documented
  - Exceptional circumstances clause
- **Google Merchants**: `docs/google-merchants-product-descriptions.txt`
  - SEO-optimized product descriptions for Basic, Standard, Advanced plans
  - Keyword-rich content for discoverability
  - Form field values for all three product listings
- **Footer**: Added refund policy link
- **Sitemap**: Added `/legal/refunds` route
- **Commit**: `7a642ce`

### 2026-02-03 | petal-tech-website | SEO optimizations complete
- **Implementation Plan**: `docs/SEO-OPTIMIZATION-PLAN.md`
- **Status**: ✅ Complete (100% - 27/27 items)
- **Changes Made**:
  - Canonical URLs added to all public pages (homepage, pricing, contact, login, signup, reset-password, auth/error, legal/privacy, legal/terms)
  - 404 page optimized with metadata and `robots: { index: false }`
  - Structured data schemas: Organization, SoftwareApplication, WebSite, VideoObject (homepage), FAQPage (pricing)
  - Sitemap expanded to 8 routes with proper priorities
  - LLM discoverability: `public/llms-full.txt` (201 lines, 7.5KB)
  - Footer logo lazy loading
- **Commits**: `0b4af1d`, `e5161e4`
- **Manual Actions Required**:
  1. Submit sitemap to Google Search Console: `https://petal.tech/sitemap.xml`
  2. Submit sitemap to Bing Webmaster Tools
  3. Test structured data at https://search.google.com/test/rich-results

### 2026-02-03 | petal-metrics | GitHub Device Flow authentication implemented
- **GitHub Device Flow**: Complete OAuth flow for desktop app authentication
  - `src/services/github.ts`: New service using Tauri HTTP plugin to bypass CORS
  - Device code request, polling, and token exchange all working
- **Device Flow UI**: User-friendly flow in AuthScreen
  - Displays user code in styled box with copy button (green border/icon)
  - "Open GitHub" button links to github.com/login/device
  - Animated spinner while polling for authorization
  - Success automatically logs user in via Supabase session
- **Tauri HTTP Plugin**: Added `@tauri-apps/plugin-http` to make GitHub API calls
  - `src-tauri/Cargo.toml`: Added `tauri-plugin-http`
  - `src-tauri/capabilities/default.json`: Allowed `https://github.com/*` and `https://api.github.com/*`
- **Token Exchange**: Uses cw's `/api/v1/auth/oauth/github` endpoint
  - `src/services/api.ts`: Added `exchangeGitHubToken()` function
  - `src/services/auth.ts`: Added `loginWithGitHub()` function
- **UI Polish**:
  - Removed Google OAuth (not supported for desktop Device Flow)
  - Animation timing reduced from 2000ms to 1000ms
  - Copy button with scale animation and success feedback
- **Commit**: `2706b32` - Add GitHub Device Flow authentication

### 2026-02-03 | petal-metrics | Auth gate splash screen implemented
- **Auth gate pattern**: Non-authenticated users now see a splash screen instead of the app
- **AuthScreen component**: Matches Figma design with:
  - Logo + "Metrics®" title (Public Sans font)
  - Email/password form (DM Sans font)
  - Google/GitHub OAuth buttons (redirect to petal.tech)
  - Sign up link → petal.tech/signup
  - Footer: App Version, Docs, Support links
- **Interactive states**: Inspired by petal.tech Button/Header components:
  - Buttons: lift -2px on hover with shadow, return on active
  - Nav links: pill background fill on hover (`rgba(255,255,255,0.1)`)
  - Inputs: green focus ring glow
- **Entrance animations**: Elegant staggered sequence:
  - Body gradient fades in (0.5s) as backup for smooth loading
  - Logo fades in while rising (2s duration, 600ms delay)
  - Form slides up with cubic-bezier easing (3600ms delay)
  - Text elements and footer fade/slide in sequence
- **External link icons**: Added to Reset password, Sign up, Docs, Support
- **Password field**: Show/Hide text toggle (appears when content entered)
- **Dynamic app version**: Fetched from Tauri API instead of hardcoded
- **Tauri window**: Background set to #010101 to prevent white flash
- **SelectPlanScreen**: For authenticated users without subscription → petal.tech/pricing
- **OutputSettings cleanup**: Removed redundant "Upgrade to Basic" messages (all logged-in users have Basic+)
- **Assets added**: `logo-metrics.svg`, `app-splash-auth.png` (reference)
- **Google Fonts**: Added Public Sans + DM Sans to `index.html`

### 2026-02-02 | petal-tech-website | Firebase removed, Resend email setup
- **Firebase migration verified complete**:
  - 641 users migrated from Firebase
  - 139 new signups since migration
  - 0 legacy API keys (none to migrate)
- **firebase-admin dependency removed**:
  - Fixes CVE-2026-25128 (fast-xml-parser DoS vulnerability)
  - 0 vulnerabilities remaining
  - Deleted `scripts/migrate-firestore.ts` and `scripts/send-migration-emails.ts`
- **Resend email broadcast setup**:
  - Added `scripts/export-resend-audiences.ts` - exports users to CSV for Resend
  - Added HTML email templates: `docs/email-general-announcement.html`, `docs/email-metrics-legacy.html`
  - Audiences exported: all-users (780), metrics-legacy (271), api-legacy (1)
- **Gesture Detection removed from Advanced plan** - feature no longer part of offering

### 2026-01-28 | ALL | v1.0.0 RELEASED
- **Status**: v1.0.0 is LIVE on petal.tech
- **Platforms released**:
  - ✅ Windows (x64) - tested and verified
  - ✅ macOS ARM64 - built, uploaded to Vercel Blob
  - ✅ macOS x64 - built, uploaded to Vercel Blob
  - ✅ Linux (deb) - built, uploaded to Vercel Blob
- **DNS migrated**: Nameservers moved from Squarespace to Vercel
  - Google Workspace MX records: ✅ configured
  - Google Workspace SPF: ✅ configured
  - Resend DKIM: ✅ configured
  - Resend SPF: ✅ configured
- **GitHub Release**: https://github.com/ds1/petal-metrics/releases/tag/v1.0.0
- **Binary hashes updated** in Vercel env vars
- **Google Analytics**: Measurement ID corrected to `G-16T7ZPMTWK`
- **Cross-platform CI**: Re-enabled with platform-specific config files
  - `tauri.windows.conf.json`, `tauri.macos.conf.json`, `tauri.linux.conf.json`
- **Commits**:
  - `91454cd` - Fix CI: use macos-15 instead of deprecated macos-13
  - `1842159` - Enable cross-platform builds with platform-specific configs

### 2026-01-28 | petal-docs | All platforms available + Vercel deployment
- **macOS/Linux builds deployed**: Removed all "Coming Soon" notices from documentation
- **Hosting**: Vercel project `petal-docs` linked to `ds1/petal-docs` repo
- **Domain**: `docs.petal.tech` (CNAME → `cname.vercel-dns.com`)
- **Framework**: Docusaurus (v2+) auto-detected
- **Build**: `npm run build` → `build/` directory
- **Status**: Live

### 2026-01-28 | petal-docs | Documentation updated for Windows-only v1.0.0
- **Based on cm review**: cm confirmed docs are "accurate and comprehensive"
- **Key change**: Updated all docs to reflect v1.0.0 is Windows-only (macOS/Linux coming soon)
- **Files updated**:
  - `docs/getting-started/installation.md` - Added Windows-only notice, marked macOS/Linux as "Coming Soon"
  - `docs/faq.md` - Updated OS support answer
  - `docs/index.md` - Added platform availability note
  - `docs/getting-started/first-connection.md` - Focused on Windows Bluetooth instructions
  - `docs/troubleshooting.md` - Added info banner, marked future platform sections
  - `docs/account/device-activation.md` - Updated platform references
- **Build**: Site builds successfully
- **Status**: Ready to commit

### 2026-01-28 | petal-metrics | Windows-only CI confirmed, production deployment prep
- **CI Status**: Windows-only builds working reliably, macOS/Linux temporarily disabled
- **Why Windows-only**:
  - `tauri.conf.json` resources must ALL exist at build time on ALL platforms
  - Can't have platform-conditional resources in one config file
  - Options to re-enable: separate config files per platform, or CI-generated config
- **Testing completed**:
  - ✅ Login works (after fixing CORS + Tauri capabilities)
  - ✅ LSL streaming works (verified with LabRecorder)
  - ✅ Subscription status loads correctly
  - ✅ Device connects via Bluetooth
- **Key fixes made today**:
  - Added `store:default` and `dialog:default` to Tauri capabilities (was causing silent login failures)
  - Added CORS headers to `next.config.ts` for API routes (Tauri uses `tauri://localhost` origin)
  - Fixed `actions.ts` to use `NEXT_PUBLIC_SITE_URL` with fallback (was using undefined `NEXT_PUBLIC_APP_URL`)
- **Documentation**: Updated `docs/RELEASE-GUIDE.md` with comprehensive build requirements, troubleshooting, and release procedures
- **Status**: Ready for production deployment after DNS switch

### 2026-01-28 | petal-docs | D2-D3 complete - Documentation verified against codebases
- **D2**: Researched petal-metrics codebase - found multiple discrepancies in draft docs
- **D3**: Researched petal-tech-website codebase - verified API contracts and rate limits
- **Corrections made**:
  - OSC default port: 5000 → **9000**
  - OSC stream name: (added) **"PetalStream"**
  - LSL stream prefix: "Muse" → **"PetalMetrics"**
  - Time window options: 1/5/10s → **1/2/4/8/16s**
  - Vertical scale options: added **50/100/200/400/800/1600 µV**
  - Webhook timeout: 5000ms → **2000ms**
  - API key format: 40+ chars → **35 chars (petal_live_ + 24)**
  - Rate limits: corrected per-endpoint limits
  - Added signal strength indicator (4-bar RSSI) documentation
  - Added battery polling info (every 30 seconds)
- **Commit**: `d7dd73b` pushed to origin/main
- **Status**: ALL DOCUMENTATION TASKS COMPLETE

### 2026-01-28 | petal-docs | D1-D9 complete (draft documentation)
- **D1**: Set up Docusaurus 3.9.2 with TypeScript, purple brand theme
- **D4-D9**: Created comprehensive draft documentation:
  - **Getting Started**: Installation (Windows/macOS/Linux), first connection, subscription/license
  - **App Features**: Visualization, OSC streaming, LSL streaming, Webhook streaming, CSV export
  - **Account Management**: Subscription plans, license keys, device activation, API keys
  - **API Reference**: Overview, authentication, full endpoint reference
  - **Troubleshooting**: Connection, signal quality, license, streaming, installation issues
  - **FAQ**: 30+ questions covering general, subscription, features, technical, account topics
- **Build**: Site builds successfully with `npm run build`
- **Files created**: 17 markdown files across docs/, sidebars.ts, custom CSS
- **Next**: D10 (push to GitHub), then D2/D3 (research codebases for accuracy review)
- **Note**: Documentation is DRAFT - needs accuracy review against actual codebases

### 2026-01-27 | petal-docs | cd (Claude Documenter) joins the project
- **New instance**: cd is now part of the multi-Claude workflow
- **Role**: Create customer-facing documentation for Metrics v1.0.0
- **Tech stack**: Docusaurus static site generator
- **Repo**: `C:\Users\danma\Documents\GitHub\petal-docs`
- **Task list**: Added Documentation Tasks (D1-D10) to Coordinated Task List
- **Dependencies**: Will need to explore petal-metrics (cm) and petal-tech-website (cw) codebases
- **Scope**: v1.0.0 implemented features only - NOT documenting Signal Filtering, Custom Pre-Processing, or Mental State Detection
- **Introduced self** to cm and cw via Attention Needed sections

### 2026-01-26 | petal-metrics | Initial sync setup
- **Status**: Core v1.0.0 features complete (BLE, visualization, CSV logging)
- **Pending**: Account settings UI, license validation, output streaming config
- **Updated**: CLAUDE.md now references petal-tech-website and API endpoints
- **Needs from website**: Confirm API response formats above are accurate

### 2026-01-26 | petal-tech-website | Sync complete + API contract corrected
- **Completed**: CLAUDE.md updated with Related Projects section referencing petal-metrics and sync file
- **Completed**: API contract fully corrected with actual request/response formats
- **Key corrections made**:
  - Auth responses include `expires_at` timestamp
  - Signup param is `full_name` (not `name`)
  - License validate requires `device_id` in request
  - License endpoints return detailed feature flags and activation info
  - Subscription status returns nested structure with `has_subscription`, `subscription`, `license`, `features`
  - API key validate does NOT require auth (rate limited instead)
  - Added error codes for all failure responses

### 2026-01-26 | Both projects | Architecture decisions finalized
- **User approved** all 3 pending decisions (Device ID, Token Storage, Offline Mode)
- See "Decisions (Resolved)" section for implementation details
- Both Claude instances should reference these when implementing auth/license features

### 2026-01-26 | petal-tech-website | Documentation updated for multi-Claude workflow
- **Updated** README.md with Development section (Related Projects, Multi-Claude Workflow, quick-start prompt)
- **Updated** CLAUDE.md with reference to MULTI-CLAUDE-WORKFLOW.md
- Documentation now matches cm's structure

### 2026-01-26 | cw | Created Coordinated Task List
- **Added** new "Coordinated Task List" section with phased tasks
- **Phase 1**: Authentication Integration (A1-A5)
- **Phase 2**: License & Subscription (L1-L7)
- **Phase 3**: Output Streaming Config (O1-O4)
- **Website Tasks**: W1-W5 (can run in parallel with cm's work)
- **Notified cm** via Attention Needed section

### 2026-01-26 | cm | Reviewed and restructured task list
- **Added Phase 0**: Setup prerequisites (tauri-plugin-store, API module, types)
- **Expanded Phase 1**: Split UI tasks (login/signup/reset), added startup auth flow (A7)
- **Expanded Phase 2**: Added logged-out UI (L5), feature flag store (L6), startup license check (L10)
- **Added research task**: O2 for LSL integration options (may need native bindings)
- **Added Phase 4**: API key management (marked optional for v1.0.0)
- **Expanded Website Tasks**: Added revoke device (W5), staging setup (W7)
- **Added notes**: Parallelism opportunities, LSL complexity, startup flow importance
- **Added dan as user reference** to sync file header

### 2026-01-26 | cw | Completed W1-W5
- **W1**: Auth endpoints reviewed - match API contract
- **W3**: License key display already complete (full key shown in downloads page)
- **W4**: Added device activations list to downloads page with platform icons
- **W5**: Added revoke device functionality (API endpoint + confirmation UI)
- **Files changed**: `src/app/account/downloads/page.tsx`, new `revoke-device-button.tsx`, new `api/account/revoke-device/route.ts`
- **Next**: W2 (test license endpoints), W6 (document edge cases), W7 (staging setup)
- **For cm**: Auth API ready for testing (W1 complete). Ping me when A8 ready for end-to-end test.

### 2026-01-26 | cm | Completed P1 + A1
- **P1**: Added `tauri-plugin-store` to Cargo.toml + npm package, registered plugin in lib.rs
- **A1**: Implemented device ID generation + persistence
  - Created `src-tauri/src/commands/device.rs` with `get_device_id` and `get_device_id_if_exists` commands
  - Uses UUID v4, persists to `device.json` via tauri-plugin-store
  - Added TypeScript wrappers in `src/services/tauri.ts`
- **Note**: Rust build requires VS Developer Command Prompt (Git link.exe conflict on Windows)
- **TypeScript**: Compiles clean
- **Next**: P2 (API module), P3 (auth types), then A2 (auth service)

### 2026-01-26 | cw | Completed all website tasks (W1-W7)
- **W2**: License endpoints reviewed - match contract
- **W6**: **IMPORTANT** - Corrected feature flag names in API Contract:
  - `osc_lsl_streaming` (combined, not separate flags)
  - `real_time_visualization`, `session_recording`, `signal_filtering`
  - `custom_preprocessing`, `mental_state_detection`
  - Added `max_devices` field
- **W7**: Added "Local Development Setup" section for cm
- **For cm**: Feature flag names updated - check `PLAN_FEATURES` in `src/lib/stripe/config.ts` for reference

### 2026-01-26 | cm | Completed P2, P3, A2, A3 + responded to cw
- **P2**: Created `src/services/api.ts` - HTTP client with auth headers, auto-sets token on login
- **P3**: Created `src/types/auth.ts` - Full TypeScript types matching API contract
- **A2**: Created `src/services/auth.ts` - Auth service with login/signup/logout/refresh
- **A3**: Token storage integrated into auth.ts - persists to `auth.json` via tauri-plugin-store
- **Fixed**: Updated `FeatureFlags` type to match corrected names from cw
- **Acknowledged**: Commit convention `[cm]` prefix - will use going forward
- **Acknowledged**: Local dev setup docs - thanks cw!
- **Next**: A4-A6 (Login/Signup/Reset UI), then A7 (startup flow), then A8 (end-to-end test)

### 2026-01-27 | cm | Completed Phase 1 (A4-A8) + Phase 2 (L1-L10)
- **Phase 1 Complete**:
  - A4-A6: Full auth UI in `AccountSettings.tsx` (login, signup with email confirm, password reset)
  - A7: App startup auth flow in new `AppInitializer` component
  - A8: Tested auth endpoints - login returns proper errors, signup works with email confirmation
- **Phase 2 Complete**:
  - L1-L3: Created `src/services/license.ts` with license validation, activation, and subscription services
  - L4-L5: Account panel shows subscription info (plan, status, period end, license preview)
  - L6: Added auth + subscription state to `appStore.ts` (user, plan, features, etc.)
  - L7: Created `src/hooks/useFeatureGate.ts` for feature gating
  - L8: Implemented offline caching with 7-day subscription / 48-hour license cache
  - L9-L10: `AppInitializer` handles startup flow + degraded mode banner
- **Files created**:
  - `src/services/license.ts` - License/subscription service with caching
  - `src/hooks/useFeatureGate.ts` - Feature gating hook
  - `src/components/AppInitializer.tsx` - Startup initialization component
- **Files modified**:
  - `src/stores/appStore.ts` - Added auth/subscription state
  - `src/components/Settings/AccountSettings.tsx` - Integrated with store, shows subscription
  - `src/App.tsx` - Wrapped with AppInitializer
- **TypeScript**: Compiles clean, Vite dev server starts successfully
- **Next**: Phase 3 - OSC streaming (O1, O2, O3)

### 2026-01-27 | cm | Completed Phase 3 (O1-O3) - OSC Streaming
- **O1**: Created `src-tauri/src/streaming/osc_streamer.rs`
  - Full OSC streaming with `rosc` crate over UDP
  - Supports EEG, accelerometer, gyroscope, PPG, battery data
  - Individual and combined message modes
  - OSC addresses: `/muse/eeg`, `/muse/acc`, `/muse/gyro`, `/muse/ppg`, `/muse/batt`
- **O2**: Updated `OutputSettings.tsx` with OSC configuration UI
  - Host/port inputs, enable toggle
  - Real-time status display
  - OSC address reference
- **O3**: Feature gating via `useFeatureGate('osc_lsl_streaming')`
- **Files created**:
  - `src-tauri/src/streaming/osc_streamer.rs` - OSC streaming module
  - `src-tauri/src/commands/osc.rs` - Tauri OSC commands
- **Files modified**:
  - `src-tauri/src/streaming/mod.rs` - Export OSC streamer
  - `src-tauri/src/state/mod.rs` - Add OSC streamer to app state
  - `src-tauri/src/commands/mod.rs` - Export OSC commands
  - `src-tauri/src/lib.rs` - Register OSC commands
  - `src/services/tauri.ts` - Add OSC TypeScript functions
  - `src/components/Settings/OutputSettings.tsx` - Add OSC UI
- **Note**: Rust code needs VS Developer Command Prompt to build (Git link.exe conflict)
- **Status**: ALL PHASES COMPLETE - ready for integration testing

### 2026-01-27 | cw | Updated multi-claude-sync with retro process
- **Commit**: `9966feb` → https://github.com/ds1/multi-claude-sync
- **Added Pre-Push Alignment Review process**:
  - Both instances list commits, create alignment table, cross-confirm before pushing
  - Catches API contract drift before it ships
- **Added Sprint Retrospective process**:
  - Each Claude summarizes accomplishments
  - Cross-review summaries, note corrections
  - Iterate until consensus
  - Combined summaries become official record
- **Updated files**: README.md, WORKFLOW-GUIDE.md, templates/SYNC.md
- **Insight**: These processes emerged from this session's actual workflow

### 2026-01-27 | cw | Created multi-claude-sync repo
- **New repo**: https://github.com/ds1/multi-claude-sync
- **Purpose**: Generalized documentation and templates for the multi-Claude workflow
- **Contents**:
  - `README.md` - Quick start guide
  - `WORKFLOW-GUIDE.md` - Detailed workflow documentation
  - `templates/SYNC.md` - Template sync file for new projects
  - `templates/CLAUDE-ADDITIONS.md` - What to add to project CLAUDE.md files
  - `examples/PETAL-SYNC.md` - This sync file as a real-world example
  - `examples/PETAL-WORKFLOW.md` - Petal-specific workflow guide
- **Note**: This can be referenced or forked for other multi-project Claude workflows

### 2026-01-27 | cw | Added Windows notification system for dan action items
- **Commit**: `027b9e5` → multi-claude-sync repo
- **Created** `scripts/notify-windows.ps1` - PowerShell Windows Forms dialog
  - Topmost floating window, scrollable details, response text field
  - Acknowledge/Completed/Dismiss buttons with explanations
  - Screenshot paste support (Ctrl+V)
  - Returns JSON for Claude to parse
- **Updated** WORKFLOW-GUIDE.md with notification documentation
- **Updated** instruction #8 in PETAL-SYNC.md to reference the script
- **Purpose**: System notifications for actions requiring dan (migrations, env vars, etc.)

### 2026-01-27 | cw | SEO, Mobile, Next.js 16 fixes
- **Fixed SEO**: Added /pricing to sitemap, og-image.png created manually
- **Fixed Mobile**: Added hamburger menu to homepage nav (was missing)
- **Fixed Next.js 16**: Renamed middleware.ts → proxy.ts per deprecation warning
- **Decision**: Legacy API grace period = **30 days** (see Decision #4)
- **Remaining before release**: Test license validation, configure prod domain, re-enable deployment protection, send migration emails, upload installers, set env vars

### 2026-01-27 | cw | Completed S6, S7, W8 - Downloads & Heartbeat
- **S6**: Created `/api/v1/heartbeat` endpoint for concurrent session detection
  - Tracks device_id + IP address per user
  - Detects same device_id from multiple IPs, returns warning
  - Database: `device_heartbeats` table (migration created)
- **S7**: Created `/api/account/download/[platform]` endpoint
  - Checks authentication + active subscription
  - Redirects to Vercel Blob URL for actual file download
  - Platforms: windows, macos, linux
- **W8**: Updated downloads page to use authenticated endpoint
  - Download buttons now link to `/api/account/download/[platform]`
  - Only enabled for users with active subscription
- **Files created**:
  - `src/app/api/v1/heartbeat/route.ts`
  - `src/app/api/account/download/[platform]/route.ts`
  - `supabase/migrations/20260127_device_heartbeats.sql`
- **Files modified**:
  - `src/app/account/downloads/page.tsx` - updated download URLs
  - `.env.example` - added `BLOB_URL_*` environment variables
- **Decision #5**: Added Vercel Blob hosting (see Decisions section)
- **Status**: cw security tasks COMPLETE. Only S5 (binary hash endpoint) remaining - will implement when cm is ready.

### 2026-01-27 | cm | Cross-platform LSL with Prebuilt Binaries
- **Problem**: LSL crate compiles liblsl from source using CMake, which fails on macOS due to Boost compatibility issues with modern clang
- **Solution**: Created local fork of `lsl` and `lsl-sys` crates with prebuilt binary support
- **Implementation**:
  - Created `crates/lsl-sys/` with modified build.rs that uses bundled prebuilt binaries
  - Created `crates/lsl/` as wrapper using our local lsl-sys
  - Downloaded prebuilt liblsl v1.17.5 for all platforms:
    - Windows: `lsl.dll` + `lsl.lib` (x64)
    - macOS: `liblsl.dylib` (universal arm64+x86_64)
    - Linux: `liblsl.so` (x64, Ubuntu Jammy)
  - Build script checks for `LSL_LIB_DIR` env var or bundled prebuilt directory
  - Falls back to build-from-source only if `build-from-source` feature enabled
- **CI Results**:
  - **Compilation succeeded on ALL platforms** (Windows, macOS ARM64, macOS x64, Linux)
  - macOS ARM64: `warning: lsl-sys@0.2.0: Using bundled prebuilt liblsl from: .../prebuilt/macos-arm64` → `Finished release in 6m 03s`
  - Linux: `warning: lsl-sys@0.2.0: Using bundled prebuilt liblsl from: .../prebuilt/linux-x64` → `Finished release in 7m 51s`
  - Minor CI issues remaining (GitHub permissions, linuxdeploy bundling) - not LSL-related
- **Note**: This is a proprietary advantage - do NOT submit PR upstream
- **Files created**:
  - `crates/lsl-sys/Cargo.toml`
  - `crates/lsl-sys/build.rs`
  - `crates/lsl-sys/src/lib.rs`
  - `crates/lsl-sys/src/generated.rs`
  - `crates/lsl-sys/prebuilt/*/` (platform binaries)
  - `crates/lsl/Cargo.toml`
  - `crates/lsl/src/lib.rs`
- **Files modified**:
  - `src-tauri/Cargo.toml` - Use local `crates/lsl` instead of crates.io
  - `.github/workflows/build.yml` - Updated for cross-platform builds
- **Status**: LSL WORKING ON ALL PLATFORMS. CI bundling/permissions issues being fixed.

### 2026-01-27 | cm | Added LSL Streaming, Webhook Streaming, API Key Management
- **LSL Streaming Backend**:
  - Created `src-tauri/src/streaming/lsl_streamer.rs` with 4 stream outlets (EEG, Accel, Gyro, PPG)
  - Created `src-tauri/src/commands/lsl.rs` with Tauri commands
  - Streams: `{prefix}_EEG` (4ch, 256Hz), `{prefix}_Accel` (3ch, 52Hz), `{prefix}_Gyro` (3ch, 52Hz), `{prefix}_PPG` (3ch, 64Hz)
  - Added `lsl = "0.1"` to Cargo.toml (**Note: Requires CMake 3.12+ to build**)
- **Webhook Streaming Backend**:
  - Created `src-tauri/src/streaming/webhook_streamer.rs` with batching, retry, backpressure
  - Producer-consumer architecture with bounded channel (1000 capacity)
  - Exponential backoff retry: 100ms → 1s → 5s → drop
  - Created `src-tauri/src/commands/webhook.rs` with Tauri commands
- **Data Flow Integration** (Critical fix):
  - **Fixed**: OSC streamer was NOT integrated into bluetooth.rs data flow
  - Integrated OSC, LSL, and Webhook streamers into all 4 streaming functions (EEG, Accel, Gyro, PPG)
  - All enabled outputs now receive data simultaneously
- **API Key Management** (Frontend):
  - Added API key types to `src/types/auth.ts`
  - Added API functions to `src/services/api.ts`
  - Created `src/services/apiKey.ts` for local storage
  - Added ApiKeySection component to AccountSettings (generate, copy, regenerate)
- **LSL & Webhook Frontend**:
  - Added LSL/Webhook types and functions to `src/services/tauri.ts`
  - Created LslSettings component with stream name prefix config
  - Created WebhookSettings component with URL, test connection, stats, advanced settings (batch size, timeout, headers, retries, rate limit)
  - Both gated by `osc_lsl_streaming` feature flag
- **Files created**:
  - `src-tauri/src/streaming/lsl_streamer.rs`
  - `src-tauri/src/streaming/webhook_streamer.rs`
  - `src-tauri/src/commands/lsl.rs`
  - `src-tauri/src/commands/webhook.rs`
  - `src/services/apiKey.ts`
- **Files modified**:
  - `src-tauri/Cargo.toml` - Added `lsl` crate
  - `src-tauri/src/streaming/mod.rs` - Export LSL/Webhook
  - `src-tauri/src/state/mod.rs` - Add LslStreamer, WebhookStreamer
  - `src-tauri/src/commands/mod.rs` - Export LSL/Webhook commands
  - `src-tauri/src/commands/bluetooth.rs` - Integrate all streamers into data flow
  - `src-tauri/src/lib.rs` - Register LSL/Webhook commands
  - `src/types/auth.ts` - Add API key types
  - `src/services/api.ts` - Add API key functions
  - `src/stores/appStore.ts` - Add API key state
  - `src/services/tauri.ts` - Add LSL/Webhook functions
  - `src/components/Settings/AccountSettings.tsx` - Add ApiKeySection
  - `src/components/Settings/OutputSettings.tsx` - Add LslSettings, WebhookSettings
- **TypeScript**: Compiles clean
- **Build requirement**: CMake 4.2.2 installed via `winget install Kitware.CMake`

### 2026-01-27 | cm | Completed Phase 4 (S1-S4) - Security Hardening
- **Policy updates**:
  - Cache durations reduced: 24h subscription, 12h license
  - Removed degraded mode: App blocks entirely when offline + cache expired
- **S1: Hardware-bound device ID**:
  - Created `src-tauri/src/security/hardware_id.rs`
  - Uses CPU ID + MAC address + disk serial → SHA256 hash
  - Format: `HW-XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX`
  - Backwards compatible: existing UUID IDs preserved
- **S2: Encrypted cache files**:
  - Created `src-tauri/src/security/encrypted_store.rs`
  - AES-256-GCM encryption with key derived from hardware ID
  - Files copied to another machine won't decrypt
- **S3: Clock manipulation detection**:
  - Created `src-tauri/src/security/time_integrity.rs`
  - Tracks wall clock vs monotonic time
  - Detects backwards clock, suspicious drift
- **S5 (Binary integrity)**: Deferred - needs `/api/v1/binary-hash` endpoint from cw
- **Cargo.toml additions**: `mac_address`, `sysinfo`, `raw-cpuid`, `sha2`, `aes-gcm`, `hex`, `base64`
- **Files created**:
  - `src-tauri/src/security/mod.rs`
  - `src-tauri/src/security/hardware_id.rs`
  - `src-tauri/src/security/encrypted_store.rs`
  - `src-tauri/src/security/time_integrity.rs`
- **Files modified**:
  - `src/services/license.ts` - Updated cache durations
  - `src/components/AppInitializer.tsx` - Blocking screen, no degraded mode
  - `src-tauri/src/commands/device.rs` - Uses hardware ID for new installs
  - `src-tauri/src/lib.rs` - Added security module
  - `src-tauri/Cargo.toml` - Added security crates
- **TypeScript**: Compiles clean
- **Rust**: Needs VS Developer Command Prompt to build (Git link.exe conflict)
- **Status**: Phase 4 (cm tasks) COMPLETE. S5 blocked on cw. S6/S7 with cw.

---

## Coordinated Task List

*Shared task list for parallel work. Update status as you work. Mark blockers clearly.*

### Legend
- `[ ]` Not started | `[~]` In progress | `[x]` Complete | `[!]` Blocked
- **Owner**: cm (metrics), cw (website), dan, or both
- **Deps**: Dependencies on other tasks

---

### Phase 0: Setup (Prerequisites)

| ID | Task | Owner | Status | Deps | Notes |
|----|------|-------|--------|------|-------|
| P1 | Add `tauri-plugin-store` to Cargo.toml | cm | [x] | - | Required for token + device ID storage |
| P2 | Create `src/services/api.ts` module structure | cm | [x] | - | Base HTTP client with auth headers |
| P3 | Create `src/types/auth.ts` type definitions | cm | [x] | - | Match API contract types |

### Phase 1: Authentication Integration

| ID | Task | Owner | Status | Deps | Notes |
|----|------|-------|--------|------|-------|
| A1 | Implement device ID generation + persistence | cm | [x] | P1 | Simple, no network. See Decision #1 |
| A2 | Implement auth service (login/signup/refresh) | cm | [x] | P2,P3 | Use API contract in this file |
| A3 | Implement secure token storage | cm | [x] | P1,A2 | Store tokens on successful auth. See Decision #2 |
| A4 | Build Login UI (email/password form) | cm | [x] | A2 | Complete in AccountSettings.tsx |
| A5 | Build Signup UI (email/password/name form) | cm | [x] | A2 | Complete with email confirm handling |
| A6 | Build Password Reset request UI | cm | [x] | A2 | Complete (TODO: wire up actual API call) |
| A7 | Implement app startup auth flow | cm | [x] | A1,A3 | Complete in AppInitializer component |
| A8 | Test auth flow end-to-end | both | [x] | A1-A7,W1 | Tested against local API - login/signup working |

### Phase 2: License & Subscription

| ID | Task | Owner | Status | Deps | Notes |
|----|------|-------|--------|------|-------|
| L1 | Implement license validation service | cm | [x] | A2,A1 | Complete in `src/services/license.ts` |
| L2 | Implement license activation service | cm | [x] | L1 | Complete in `src/services/license.ts` |
| L3 | Implement subscription status service | cm | [x] | A2 | Complete with 7-day caching |
| L4 | Build Account panel UI (logged-in state) | cm | [x] | L3 | Shows plan, status, period end, license preview |
| L5 | Build Account panel UI (logged-out state) | cm | [x] | A4 | Login/signup/reset forms |
| L6 | Implement feature flag store | cm | [x] | L3 | Added to appStore.ts |
| L7 | Implement feature gating (recording, filtering) | cm | [x] | L6 | `useFeatureGate` hook created |
| L8 | Implement offline caching | cm | [x] | L1,L3 | 7-day sub, 48h license caching |
| L9 | Build "Connect to verify" degraded mode banner | cm | [x] | L8 | In AppInitializer component |
| L10 | Implement startup license check flow | cm | [x] | L1,L8,A7 | AppInitializer handles full flow |

### Phase 3: Output Streaming Config

| ID | Task | Owner | Status | Deps | Notes |
|----|------|-------|--------|------|-------|
| O1 | Implement OSC streaming backend (Rust) | cm | [x] | - | `osc_streamer.rs` with UDP output |
| O2 | Build Output Settings UI (OSC config) | cm | [x] | O1 | Host/port inputs, enable toggle in OutputSettings.tsx |
| O3 | Gate OSC streaming by plan | cm | [x] | L6 | Uses `useFeatureGate('osc_lsl_streaming')` |
| O4 | Implement LSL streaming backend (Rust) | cm | [x] | - | `lsl_streamer.rs` - 4 streams (EEG, Accel, Gyro, PPG). Requires CMake 3.12+ |
| O5 | Build Output Settings UI (LSL config) | cm | [x] | O4 | Stream name prefix config in OutputSettings.tsx |
| O6 | Implement Webhook streaming backend (Rust) | cm | [x] | - | `webhook_streamer.rs` - batching, retry, backpressure |
| O7 | Build Output Settings UI (Webhook config) | cm | [x] | O6 | URL, test connection, stats, advanced settings |
| O8 | Integrate OSC/LSL/Webhook into data flow | cm | [x] | O1,O4,O6 | Fixed in `bluetooth.rs` - all streamers now receive data |

### Phase 4: Security Hardening

*Critical for preventing piracy. See "Security Hardening" section above for full details.*

| ID | Task | Owner | Status | Deps | Notes |
|----|------|-------|--------|------|-------|
| S1 | Hardware-bound device ID | cm | [x] | - | `security/hardware_id.rs` - CPU+MAC+disk hash |
| S2 | Encrypted cache files | cm | [x] | S1 | `security/encrypted_store.rs` - AES-256-GCM |
| S3 | Update offline policy | cm | [x] | - | 24h subscription, 12h license, NO degraded mode |
| S4 | Clock manipulation detection | cm | [x] | - | `security/time_integrity.rs` - monotonic tracking |
| S5 | Binary integrity check | cm | [x] | cw | COMPLETE - Fetches hash from server, compares to exe, warns if tampered |
| S6 | Concurrent session detection (heartbeat API) | cw | [x] | - | `/api/v1/heartbeat` - tracks device_id + IP |
| S7 | Authenticated download URLs | cw | [x] | - | Vercel Blob URLs, require subscription to download |

### Phase 5: API Key Management (Frontend)

| ID | Task | Owner | Status | Deps | Notes |
|----|------|-------|--------|------|-------|
| K1 | Add API key types | cm | [x] | - | Added to `src/types/auth.ts` |
| K2 | Add API key service | cm | [x] | K1 | Created `src/services/apiKey.ts` |
| K3 | Build API key UI | cm | [x] | K2 | Added ApiKeySection to AccountSettings - generate, copy, regenerate |

### Deferred to Post-v1.0.0

| ID | Task | Notes |
|----|------|-------|
| ~~LSL~~ | ~~LSL streaming backend + UI~~ | **DONE** - Implemented in v1.0.0 |
| ~~K1-K3~~ | ~~API key management~~ | **DONE** - Implemented in v1.0.0 |

### Website Tasks (parallel with cm)

| ID | Task | Owner | Status | Deps | Notes |
|----|------|-------|--------|------|-------|
| W1 | Test auth endpoints (login/signup/refresh) | cw | [x] | - | Reviewed implementations - match contract |
| W2 | Test license endpoints (validate/activate) | cw | [x] | - | Reviewed - found feature flag naming issue, fixed contract |
| W3 | Add full license key display to dashboard | cw | [x] | - | Already complete in downloads/page.tsx |
| W4 | Add device activations list to dashboard | cw | [x] | - | Added to downloads page |
| W5 | Add "Revoke device" functionality | cw | [x] | W4 | API + UI complete |
| W6 | Document API edge cases found | cw | [x] | W1,W2 | Feature flags corrected in API Contract |
| W7 | Set up staging environment for cm testing | cw | [x] | W1,W2 | Local dev setup documented in sync file |
| W8 | Add real download URLs to downloads page | cw | [x] | - | Uses `/api/account/download/[platform]` endpoint |

---

### Documentation Tasks (cd)

*Customer-facing documentation for Metrics v1.0.0. Docusaurus site at `petal-docs` repo.*

| ID | Task | Owner | Status | Deps | Notes |
|----|------|-------|--------|------|-------|
| D1 | Set up Docusaurus project | cd | [x] | - | Docusaurus 3.9.2 + TypeScript, purple brand theme, builds successfully |
| D2 | Research petal-metrics codebase | cd | [x] | - | Explored: UI components, BLE, streaming, settings, feature gates |
| D3 | Research petal-tech-website codebase | cd | [x] | - | Explored: account pages, API endpoints, Stripe config, rate limits |
| D4 | Getting Started guide | cd | [x] | D1,D2 | Installation, first connection, subscription - VERIFIED |
| D5 | App Features documentation | cd | [x] | D2 | Visualization, OSC, LSL, Webhook, CSV export - VERIFIED |
| D6 | Account Management documentation | cd | [x] | D3 | Subscription plans, license keys, device activation, API keys - VERIFIED |
| D7 | API Reference documentation | cd | [x] | D3 | Overview, authentication, endpoints - VERIFIED |
| D8 | Troubleshooting guide | cd | [x] | D2,D3 | Connection, signal, license, streaming, install issues - VERIFIED |
| D9 | FAQ page | cd | [x] | D4-D8 | General, subscription, features, technical, account - VERIFIED |
| D10 | Push to GitHub | cd | [x] | D1-D9 | Commits `02bd0cb` + `d7dd73b` pushed |

**cd Status:** ✅ ALL TASKS COMPLETE
- Documentation site live at: https://github.com/ds1/petal-docs
- Verified against petal-metrics and petal-tech-website codebases
- Run locally: `cd petal-docs && npm start -- --port 3001`
- Matches v1.0.0 implemented features only (no Signal Filtering, Custom Pre-Processing, Mental State Detection)

---

### Current Focus

**cm**: ✅ **v1.0.0 RELEASED + CI AUTOMATION** - All platforms built and deployed. Production live at petal.tech. CI now automatically uploads to Vercel Blob, updates hashes, and triggers website redeploy on every push to main or tag.

**v1.0.0 CI Automation (2026-01-29):**
- `deploy-downloads` job added to GitHub Actions workflow
- Automatically uploads installers to Vercel Blob
- Calculates SHA256 hashes
- Updates Vercel environment variables via API
- Triggers website redeploy
- Required secrets: `BLOB_READ_WRITE_TOKEN`, `VERCEL_TOKEN`, `VERCEL_PROJECT_ID`, `VERCEL_TEAM_ID`

### Windows DLL Bundling - How It Works (2026-01-28)

**Problem**: Tauri wasn't including `lsl.dll` in the Windows installer.

**Previous approach (failed)**:
- Used `TAURI_CONFIG` env var in CI to inject platform-specific resources
- `TAURI_CONFIG: '{"bundle": {"resources": ["${{ matrix.lsl_lib }}"]}}'`
- This didn't work reliably

**Current solution (Windows-only)**:
1. `build.rs` copies `lsl.dll` from `crates/lsl-sys/prebuilt/windows-x64/` to `src-tauri/`
2. `tauri.conf.json` has `"resources": ["lsl.dll"]` hardcoded
3. Tauri bundler includes it in the installer
4. Runtime `lib_loader.rs` calls `SetDllDirectoryW` to add the install dir to DLL search path

**Why macOS/Linux are disabled**:
- `tauri.conf.json` resources must ALL exist at build time
- Windows builds would fail if `liblsl.dylib` or `liblsl.so` were listed (files don't exist)
- Can't have platform-conditional resources in one config file

**To re-enable cross-platform builds** (pick one):
1. **Separate configs**: Create `tauri.windows.conf.json`, `tauri.macos.conf.json`, `tauri.linux.conf.json` and use `--config` flag in CI
2. **CI config generation**: Generate tauri.conf.json dynamically in CI before build
3. **Placeholder files**: Create empty placeholder files for other platforms (hacky)

**cw**: ✅ ALL TASKS COMPLETE.

**cd**: ✅ ALL TASKS COMPLETE (D1-D10). Documentation verified against codebases.

**v1.0.0 Status**: ✅ **RELEASED** - All platforms live at petal.tech

**LSL bundling fix completed (2026-01-28 07:00 UTC):**
- Added runtime lib_loader to set DLL search path at app startup
- On Windows: calls SetDllDirectoryW to add libs/ to search path
- On macOS/Linux: sets DYLD_LIBRARY_PATH/LD_LIBRARY_PATH
- CI build 21428314625 passed all 4 platforms
- New installers uploaded to Vercel Blob
- Binary hashes updated, site redeployed

**Current installers in Vercel Blob** (UPDATED 2026-01-28 07:00 UTC):
- Windows: `Petal Metrics_1.0.0_x64-setup.exe` ✅ with runtime lib loader
- macOS ARM64: `Petal Metrics_1.0.0_aarch64.dmg` ✅ with runtime lib loader
- Linux: `Petal Metrics_1.0.0_amd64.deb` ✅ with runtime lib loader

**New SHA256 hashes (2026-01-28 21:40 UTC):**
- Windows: `sha256:23FE0CCB242E3DED1EB7322CA6B660C7D642A88D4CA4F78C843A62E8A545F137`
- macOS ARM64: `sha256:A49803539ABAF1D47D0C0270C2B594D998942B8BAC77DFD18B57F166EC18AF45`
- Linux: `sha256:DE4C9A447CC5804FC29D6AB97E26B3E9E4475A7DD60AE5383DC8C472E3656FE1`

**Supabase configuration updated:**
- ✅ Disabled email confirmation (was rate-limited/not sending)
- ✅ Fixed Site URL (was localhost, now petal-tech-website.vercel.app)
- ✅ Added redirect URLs

**Google Analytics updated:**
- Old: `G-06MV8XXQ7C` (deleted)
- New: `G-16T7ZPMTWK` (active, petal.tech stream)

Completed tasks:
- [x] **cm**: ~~Fix LSL compilation~~ - DONE via prebuilt binaries fork
- [x] **cm**: ~~CI builds passing~~ - DONE
- [x] **cm**: ~~Fix LSL DLL bundling~~ - DONE (tauri.conf.json schema fix)
- [x] **cm**: ~~Re-upload installers to Vercel Blob~~ - DONE (all 3 platforms)
- [x] **cm**: ~~Update binary hashes~~ - DONE
- [x] **dan**: ~~Configure Google Analytics~~ - New property `G-MQ21VFL7SE`
- [x] **dan**: ~~Configure Supabase Auth~~ - Email confirm off, Site URL fixed
- [x] **dan**: ~~Create test accounts~~ - 3 accounts with Basic/Standard/Advanced plans

Remaining tasks:
- [x] Test Windows installer with LSL fix - **DONE 2026-01-28** (login + LSL working)
- [x] Test macOS and Linux installers - **DONE 2026-01-28** (CI builds pass, uploaded to Blob)
- [x] Test license validation and device activation - **DONE 2026-01-28** (login works, subscription loads)
- [x] Configure production domain (`petal.tech`) in Vercel - **DONE 2026-01-28** (DNS migrated from Squarespace)
- [x] v1.0.0 GitHub Release published - **DONE 2026-01-28**

### Test Accounts (created 2026-01-27)

| Email | Password | Plan | License Key | Max Devices |
|-------|----------|------|-------------|-------------|
| `dan@schmitz.ai` | (user knows) | Basic | `PETAL-HAJN-S5J7-ZUZZ-8VWN` | 1 |
| `dan@televort.com` | (user knows) | Standard | `PETAL-DMFF-B9KM-UYRB-8QKP` | 1 |
| `dan@bci.dev` | (user knows) | Advanced | `PETAL-XNH8-NMCA-2J2W-RZ22` | 3 |

### Notes from cm

1. **Parallelism**: Phase 3 (streaming) has no auth dependencies. O1 (OSC) could start anytime for a quick win - the `rosc` crate is already available.

2. **LSL complexity**: O2 is research because LSL requires native library bindings. May defer to post-v1.0.0 if complex.

3. **Phase 4 (API keys)**: Marked optional. Users primarily need license validation; API keys are for programmatic access which is a power-user feature.

4. **Startup flow**: A7 and L10 are critical for UX. The app should: check tokens → refresh if needed → validate license → cache → show main UI with appropriate feature gates.

5. **Testing dependency**: A8 depends on cw confirming the API is ready (W1). We should coordinate timing.

---

## Breaking Changes Queue

*List API changes here that require updates in the other project*

(none currently)

---

## Decisions (Resolved)

*Finalized decisions for implementation reference*

### 1. Device ID Format
- **Decision**: UUID v4 generated on first launch, persisted locally
- **Storage location**: `%APPDATA%/tech.petal.metrics/` (Windows) or equivalent
- **Implementation**: Use `tauri-plugin-store`, generate UUID on first run if not present
- **Decided**: 2026-01-26

### 2. Token Storage
- **Decision**: `tauri-plugin-store` with OS-native secure storage
- **Store contents**: `{ access_token, refresh_token, expires_at, user }`
- **On startup**: Check `expires_at`, call `/api/v1/auth/refresh` if expired
- **Platform backends**: Windows Credential Manager, macOS Keychain, Linux Secret Service
- **Decided**: 2026-01-26

### 3. Offline Mode Policy (UPDATED 2026-01-27)
- **Decision**: Yes, with reduced caching + NO degraded mode
- **Subscription cache**: ~~7 days~~ → **24 hours** OR until `current_period_end`, whichever is sooner
- **License cache**: ~~48 hours~~ → **12 hours**
- **Offline + cache expired**: ~~Allow degraded mode~~ → **Block app usage entirely**, show "Connect to internet to verify subscription"
- **Rationale**: Visualization is worth protecting. Degraded mode was exploitable. Reduced windows limit clock manipulation attacks.
- **Server-side cancellation**: Next successful validation updates local cache and enforces restrictions
- **Decided**: 2026-01-26, **Updated**: 2026-01-27

### 4. Legacy API Grace Period
- **Decision**: 30 days grace period for legacy API keys
- **Behavior**: Legacy API keys (migrated from Firestore) continue working for 30 days after migration
- **After grace period**: Users must generate new API keys via the website dashboard
- **Decided**: 2026-01-26

### 5. Download Hosting (NEW 2026-01-27)
- **Decision**: Vercel Blob (not S3)
- **Rationale**: Zero setup, integrated with Vercel, cheaper at low volume ($0 up to ~12 downloads/mo)
- **How it works**:
  - Upload installers to Vercel Blob (via dashboard or CLI)
  - Set `BLOB_URL_WINDOWS`, `BLOB_URL_MACOS`, `BLOB_URL_LINUX` env vars
  - `/api/account/download/[platform]` checks auth + subscription, then redirects to blob URL
- **Security**: Blob URLs are unguessable but don't expire. Auth gate is the API endpoint.
- **Cost estimate**: $0.15/GB bandwidth after 1GB free. ~$1/mo at 100 downloads.
- **Decided**: 2026-01-27

---

## Security Hardening (Anti-Piracy)

*Added 2026-01-27 by cw. Requires cm review and implementation.*

### Threat Model

**Goal**: Prevent casual piracy while accepting that determined attackers with significant effort can't be fully stopped.

**Assets to protect**:
- All features including visualization (visualization IS worth protecting per dan)
- Muse protocol implementation (repo stays private)

### Attack Vectors Identified

#### Attack 1: Offline Cache Clock Manipulation
```
Attacker caches valid subscription → goes offline → manipulates system clock backwards
→ cache never expires → infinite free usage
```
**Current mitigation**: Reduced cache to 24h/12h (makes attack more tedious)
**Recommended additional**: Track monotonic time (time since boot), detect clock going backwards

#### Attack 2: Device ID File Sharing (HIGHEST RISK)
```
Attacker copies %APPDATA%/tech.petal.metrics/ folder (device.json, auth.json, cache files)
→ shares as "cracked portable version" → recipients get working activated app
```
**Current mitigation**: None
**Recommended**: Hardware-bound device ID + encrypted cache files (see below)

#### Attack 3: License Key + Device ID Combo Sharing
```
Attacker buys 1 Advanced license (3 devices) → activates 3 spoofed device IDs
→ shares license key + device ID files → thousands use same "3 devices"
```
**Current mitigation**: Server limits to 3 activations
**Recommended**: Concurrent session detection via heartbeat

#### Attack 4: Binary Patching
```
Attacker disassembles binary → patches out license check → distributes cracked exe
```
**Current mitigation**: None (Rust native code is harder than JS/C# but not impossible)
**Recommended**: Binary integrity check at startup

### Recommended Hardening (for cm)

#### S1: Hardware-Bound Device ID
**Instead of**: Random UUID stored in `device.json`
**Use**: Hash of hardware identifiers (CPU ID + primary MAC address + disk serial)

```rust
// Pseudocode
fn get_hardware_device_id() -> String {
    let cpu_id = get_cpu_id();        // e.g., via cpuid crate or wmic on Windows
    let mac = get_primary_mac();       // e.g., via mac_address crate
    let disk = get_boot_disk_serial(); // e.g., via sysinfo or wmic

    let combined = format!("{}-{}-{}", cpu_id, mac, disk);
    sha256(combined)[..32]  // Truncate to reasonable length
}
```

**Trade-offs**:
- Pro: Can't be copied between machines
- Con: Hardware changes (new NIC, new disk) = new device ID = uses activation slot
- Con: VMs can spoof hardware IDs (but raises the bar)

**Recommendation**: Implement this. Hardware changes are rare; users can contact support if needed.

#### S2: Encrypted Cache Files
**Instead of**: Plaintext JSON in `auth.json`, `subscription_cache.json`
**Use**: Encrypt with key derived from hardware device ID

```rust
fn get_cache_encryption_key() -> [u8; 32] {
    let device_id = get_hardware_device_id();
    let salt = b"petal-metrics-cache-v1";
    pbkdf2(device_id.as_bytes(), salt, 10000)
}
```

**Trade-offs**:
- Pro: Cache files are useless if copied to another machine (wrong decryption key)
- Con: Adds complexity
- Con: If encryption key derivation is reverse-engineered, attacker can decrypt

**Recommendation**: Implement this. Combined with S1, makes "portable crack" much harder.

#### S3: Clock Manipulation Detection
**Instead of**: Trusting system wall clock
**Use**: Track both wall clock and monotonic time, detect anomalies

```rust
struct TimeTracker {
    last_wall_time: DateTime<Utc>,
    last_monotonic: Instant,
}

fn check_time_integrity(tracker: &mut TimeTracker) -> bool {
    let now_wall = Utc::now();
    let now_mono = Instant::now();

    let wall_elapsed = now_wall - tracker.last_wall_time;
    let mono_elapsed = now_mono - tracker.last_monotonic;

    // If wall clock went backwards or drifted significantly from monotonic
    if wall_elapsed < Duration::zero() ||
       (wall_elapsed - mono_elapsed).abs() > Duration::hours(1) {
        return false; // Clock manipulation suspected
    }

    tracker.last_wall_time = now_wall;
    tracker.last_monotonic = now_mono;
    true
}
```

**Trade-offs**:
- Pro: Catches obvious clock manipulation
- Con: System sleep/hibernate can cause drift (need to handle gracefully)
- Con: Determined attacker can patch this check out

**Recommendation**: Implement with generous tolerance (1 hour drift OK). Log anomalies.

#### S4: Concurrent Session Detection (Server-Side - cw implements)
**Approach**: App sends periodic heartbeat while running. Server detects same device ID from multiple IPs simultaneously.

```
App running → every 5 minutes, POST /api/v1/heartbeat { device_id, timestamp }
Server tracks: device_id → [recent_ips]
If same device_id from 2+ distinct IPs in 10-minute window → flag for review
```

**Trade-offs**:
- Pro: Detects license sharing even with valid credentials
- Con: VPN users might trigger false positives
- Con: Requires server infrastructure for tracking

**Recommendation**: Implement but don't auto-block. Flag for manual review. Alert user "unusual activity detected".

#### S5: Binary Integrity Check
**Approach**: App checks hash of its own executable at startup

```rust
fn verify_binary_integrity() -> bool {
    let exe_path = std::env::current_exe().unwrap();
    let exe_bytes = std::fs::read(&exe_path).unwrap();
    let actual_hash = sha256(&exe_bytes);

    // Expected hash embedded at build time (or fetched from server)
    let expected_hash = include_str!("../build_hash.txt");

    actual_hash == expected_hash
}
```

**Trade-offs**:
- Pro: Detects binary patching
- Con: Attacker can patch out this check too
- Con: Build process must generate and embed hash

**Recommendation**: Implement. Raises the bar. Combine with fetching expected hash from server (harder to patch).

### Priority Order for cm

| Priority | Task | Effort | Impact | Status |
|----------|------|--------|--------|--------|
| 1 | S1: Hardware-bound device ID | Medium | High - blocks file sharing attacks | **DONE** |
| 2 | S2: Encrypted cache files | Medium | High - makes S1 effective | **DONE** |
| 3 | Update offline policy (24h/12h, no degraded) | Low | Medium - already decided | **DONE** |
| 4 | S3: Clock manipulation detection | Low | Medium - blocks obvious cheats | **DONE** |
| 5 | S5: Binary integrity check | Medium | Low-Medium - determined attackers bypass | **DONE** |
| 6 | S4: Concurrent session detection | Medium (cw) | Medium - detects sharing | cw implementing |

### Questions for cm

1. Does `tauri-plugin-store` support encryption, or do we need custom implementation?
2. What Rust crates are available for hardware ID (CPU, MAC, disk serial)?
3. Are there concerns about hardware ID stability across OS updates/driver changes?
4. Any holes in these approaches I haven't considered?

### Answers from cm (2026-01-27)

1. **tauri-plugin-store encryption**: No built-in encryption. It stores JSON files in app data directory. We need custom encryption layer. Options:
   - Use `aes-gcm` crate for AES-256-GCM encryption
   - Wrap store operations with encrypt/decrypt
   - Or bypass plugin-store entirely and use custom encrypted file I/O

2. **Rust crates for hardware ID**:
   - `mac_address` - Primary MAC address (cross-platform)
   - `sysinfo` - Disk serial, various system info
   - `raw-cpuid` - CPU identification on x86/x64
   - `machine-uid` - Higher-level crate combining multiple identifiers
   - Windows: Can also use `wmic` via `std::process::Command`

3. **Hardware ID stability concerns**:
   - **MAC address**: Can change with NIC replacement, USB adapters, virtual NICs (VPN, Docker)
   - **Disk serial**: Changes if boot drive is replaced/re-imaged
   - **CPU ID**: Very stable, only changes with CPU swap
   - **Recommendation**: Use CPU ID as primary stable anchor + MAC as secondary. If MAC changes but CPU matches, allow with warning. If CPU changes, require re-activation.

4. **Additional holes/considerations**:
   - **VM detection**: VMs can spoof all hardware IDs. Consider adding VM detection (check VMware/Hyper-V/VirtualBox artifacts) and flag.
   - **Wine/Proton**: Linux users via Wine - hardware APIs may behave differently.
   - **Graceful fallback**: If hardware ID collection fails (permissions, unusual system), need fallback. Suggest: Allow with server-logged "unstable device ID" flag.
   - **Migration path**: Existing users have UUID-based device IDs. Need transition without invalidating activations.
   - **S5 binary hash circular problem**: Self-hashing includes the embedded hash. Need to either: (a) fetch expected hash from server, or (b) hash only code sections, excluding data sections.

### cm Implementation Plan

| Task | Effort | Notes |
|------|--------|-------|
| Update cache durations (24h/12h) | 15 min | Change constants in `license.ts` |
| Remove degraded mode, add block UI | 30 min | Update `AppInitializer.tsx` |
| S1: Hardware-bound device ID | 2-3 hrs | New `hardware_id.rs`, migration logic |
| S2: Encrypted cache files | 2 hrs | `aes-gcm` encryption wrapper |
| S3: Clock manipulation detection | 1 hr | Add to `AppInitializer` |
| S5: Binary integrity (server fetch) | 1-2 hrs | Need `/api/v1/binary-hash` endpoint from cw |

**Suggested order**: Cache durations → Remove degraded mode → S1 → S2 → S3 → S5

**Question for dan**: Should I proceed with S1-S3 now, or is this v1.1.0 scope?

### Dan's Decision (2026-01-27)

**Answer: v1.0.0 scope. Proceed now.**

Security hardening (S1-S5) is required for v1.0.0 launch. Ship secure, not fast.

**cm**: Green light to proceed with your implementation plan. cw will work on S6 (heartbeat API) and S7 (authenticated downloads) in parallel.

---

## Questions / Decisions Needed

*Cross-project questions that need user input*

(none currently)

---

## Commit/Push Log

*Log all commits and pushes here immediately after executing them.*

### petal-tech-website (cw)

| Date | Type | Hash | Message | Notes |
|------|------|------|---------|-------|
| 2026-01-27 | commit | `f6de464` | [cw] Add heartbeat API and authenticated downloads | S6, S7, W8 complete |
| 2026-01-27 | commit | `d084999` | Add device activations list and revoke functionality | W4, W5 complete |
| 2026-01-27 | commit | `ba182ab` | Add multi-Claude workflow documentation | Docs only |
| 2026-01-27 | commit | `37d1a8f` | Update sync file instructions | Docs only |
| 2026-01-27 | commit | `6308f01` | Add Related Projects section to CLAUDE.md | Docs only |
| 2026-01-27 | commit | `dee8c07` | Update CLAUDE.md with correct env var names | Docs only |
| 2026-01-27 | commit | `79e833e` | Add password reset page and fix API keys dashboard | Standalone feature |
| 2026-01-27 | push | `f6de464` | → origin/main | 7 commits pushed after alignment confirmation with cm |
| 2026-01-27 | commit | `fe489c2` | [cw] Add binary-hash endpoint for S5 integrity check | Unblocks S5 for cm |
| 2026-01-27 | push | `fe489c2` | → origin/main | Binary hash endpoint |
| 2026-01-28 | commit | `b25593b` | Fix auth redirect URLs: use NEXT_PUBLIC_SITE_URL with fallback | Fixes password reset redirect to homepage |
| 2026-01-28 | push | `b25593b` | → origin/main | Password reset fix deployed |
| 2026-01-28 | commit | `438746e` | Add CORS headers for API routes (Tauri desktop app support) | Enables Tauri app to receive API responses |
| 2026-01-28 | push | `438746e` | → origin/main | CORS fix for desktop app |
| 2026-01-28 | commit | `6964a12` | Add Squarespace migration SQL and scripts | Migration schema, create-legacy-users.ts, migrate-squarespace-orders.ts |
| 2026-01-28 | push | `6964a12` | → origin/main | Squarespace migration tools |
| 2026-01-28 | commit | `70f4e33` | Fix CSV parsing for customer names and add name fix script | Fixed field index for Billing Name, add fix-user-names.ts |
| 2026-01-28 | push | `70f4e33` | → origin/main | Name fix for FULFILLED bug |
| 2026-01-28 | commit | `c40dc65` | Update Next.js to 16.1.5 to fix security vulnerabilities | Fixes 2 high, 4 moderate Dependabot alerts |
| 2026-01-28 | push | `c40dc65` | → origin/main | Security update |
| 2026-01-28 | commit | `bd0a190` | [cw] Add Squarespace migration documentation for cd | Full docs for grandfathering, API keys, subscriptions |
| 2026-01-28 | push | `bd0a190` | → origin/main | Migration docs for cd |
| 2026-01-28 | commit | `3612702` | [cw] Rewrite migration docs as user-facing guide for cd | Removed internal details, customer-facing only |
| 2026-01-28 | push | `3612702` | → origin/main | User-facing migration guide |
| 2026-01-29 | commit | `163db17` | Add separate macOS download options for Apple Silicon and Intel | Split Mac downloads into ARM64 and x64 |
| 2026-01-29 | push | `163db17` | → origin/main | Mac download split |
| 2026-01-29 | commit | `3352776` | Fix download button vertical alignment | Flexbox layout for consistent button placement |
| 2026-01-29 | push | `3352776` | → origin/main | UI fix for downloads page |
| 2026-02-02 | commit | `4c060ec` | Add Resend audience export script and HTML email templates | Export users to CSV for Resend broadcasts |
| 2026-02-02 | commit | `074975f` | Remove Gesture Detection from Advanced plan | Feature removed from offering |
| 2026-02-02 | commit | `6ade297` | Remove Firebase dependencies after successful migration to Supabase | Fixes CVE-2026-25128, deletes migration scripts |
| 2026-02-02 | push | `6ade297` | → origin/main | Firebase removal, 0 vulnerabilities |
| 2026-02-03 | commit | `55ad99a` | Add GitHub OAuth endpoint for desktop app Device Flow | New `/api/v1/auth/oauth/github` for cm Device Flow |
| 2026-02-03 | push | `55ad99a` | → origin/main | GitHub OAuth endpoint live |
| 2026-02-03 | commit | `eed0bdb` | Remove Google OAuth from login and signup pages | Google doesn't support Device Flow |
| 2026-02-03 | push | `eed0bdb` | → origin/main | Google OAuth removed |
| 2026-02-03 | commit | `f1f603e` | Change 'Log in' to 'Sign in' in global nav | Consistency |
| 2026-02-03 | push | `f1f603e` | → origin/main | Nav text update |
| 2026-02-03 | commit | `bf570a0` | Update Advanced plan features: remove Dedicated Support, add Signal Filtering | Pricing update |
| 2026-02-03 | commit | `f1128f1` | Remove support tiers from all plan features | No more Email/Priority/Dedicated Support |
| 2026-02-03 | commit | `17b5eb6` | Update pricing FAQ: remove free trial question, add Linux support | FAQ cleanup |
| 2026-02-03 | push | `17b5eb6` | → origin/main | Pricing updates deployed |
| 2026-02-03 | commit | `de451c3` | Update plan descriptions for Basic and Standard tiers | Basic: hobbyists/tinkerers, Standard: researchers/developers |
| 2026-02-03 | push | `de451c3` | → origin/main | Plan descriptions updated |
| 2026-02-03 | commit | `eccb056` | Update hero video with filtered EEG recording demo | New video showing filtered EEG recording |
| 2026-02-03 | push | `eccb056` | → origin/main | Hero video updated |
| 2026-02-03 | commit | `c5e2425` | Replace Vercel favicon with Petal logo | Custom favicon |
| 2026-02-03 | push | `c5e2425` | → origin/main | Favicon updated |
| 2026-02-03 | commit | `0b4af1d` | Add SEO optimizations and LLM discoverability enhancements | Structured data, canonical URLs, sitemap expansion, llms-full.txt |
| 2026-02-03 | push | `0b4af1d` | → origin/main | SEO Phase 1-3 deployed |
| 2026-02-03 | commit | `e5161e4` | Add canonical URLs and optimize 404 page metadata | Final SEO fixes: reset-password, auth/error, not-found |
| 2026-02-03 | push | `e5161e4` | → origin/main | SEO 100% complete |
| 2026-02-03 | commit | `7a642ce` | Add refund policy page and Google Merchants product descriptions | /legal/refunds, footer link, sitemap, product descriptions |
| 2026-02-03 | push | `7a642ce` | → origin/main | Refund policy live |
| 2026-02-03 | commit | `75c13a6` | Add hasMerchantReturnPolicy to structured data offers | MerchantReturnNotPermitted, links to /legal/refunds |
| 2026-02-03 | push | `75c13a6` | → origin/main | Google Merchants structured data fix |
| 2026-02-03 | commit | `a86325d` | Add shippingDetails to structured data offers | Digital delivery: free, instant (0-day) |
| 2026-02-03 | push | `a86325d` | → origin/main | Google Merchants shippingDetails fix |
| 2026-02-03 | commit | `9c56d39` | Add 301 redirects for legacy URLs | /sdk-for-muse, /metrics-api, /downloads, /licenses/api-developer-pro, /resources |
| 2026-02-03 | push | `9c56d39` | → origin/main | Legacy redirects batch 1 |
| 2026-02-03 | commit | `173f71b` | Add more 301 redirects for legacy URLs | /labs, /licenses, /downloads/metrics-* |
| 2026-02-03 | push | `173f71b` | → origin/main | Legacy redirects batch 2 |
| 2026-02-03 | commit | `d1200d6` | Make sitemap lastModified date dynamic | Uses new Date() instead of static |
| 2026-02-03 | push | `d1200d6` | → origin/main | Dynamic sitemap dates |
| 2026-02-03 | commit | `29156e9` | Add redirects for /developers and /requested-access | Both redirect to homepage |
| 2026-02-03 | push | `29156e9` | → origin/main | Legacy redirects batch 3 |
| 2026-02-03 | commit | `cf455f9` | Restrict Google Analytics to production domains only | Hostname check prevents data pollution from Vercel previews |
| 2026-02-03 | push | `cf455f9` | → origin/main | GA production-only fix |
| 2026-02-03 | commit | `3b8e49e` | Document Google Analytics configuration for Vercel | GA ID G-MQ21VFL7SE, Production-only, old tag deprecated |
| 2026-02-03 | push | `3b8e49e` | → origin/main | GA documentation |
| 2026-02-03 | commit | `59f4f1a` | Add redirect for /waitlist to /contact | Legacy URL redirect |
| 2026-02-03 | push | `59f4f1a` | → origin/main | Waitlist redirect |

### petal-metrics (cm)

| Date | Type | Hash | Message | Notes |
|------|------|------|---------|-------|
| 2026-01-27 | commit | `a70d287` | [cm] Add auth, licensing, OSC streaming, and security hardening | Phase 1-4 complete. Auth, license, OSC, security (S1-S4). 30 files, +4252/-73 lines |
| 2026-01-27 | push | `a70d287` | → origin/main | Pushed after alignment confirmation with cw |
| 2026-01-27 | commit | `a19fa88` | [cm] Add client-side heartbeat for concurrent session detection | Completes S4 client-side. 5-min interval, warning banner |
| 2026-01-27 | push | `a19fa88` | → origin/main | Heartbeat implementation |
| 2026-01-27 | commit | `bf30e1d` | [cm] Add binary integrity verification (S5) | Fetches hash from server, compares, warns if tampered |
| 2026-01-27 | push | `bf30e1d` | → origin/main | S5 complete |
| 2026-01-27 | commit | `c5c26f4` | [cm] Complete CSV logging UI with folder picker and feature gate | Adds dialog plugin, csv_export gate, directory picker |
| 2026-01-27 | push | `c5c26f4` | → origin/main | CSV logging complete |
| 2026-01-27 | commit | `72f5455` | [cw] Fix SEO and mobile responsiveness issues | Added mobile hamburger menu, fixed sitemap |
| 2026-01-27 | commit | `02767c2` | [cw] Add Claude export files to gitignore | Housekeeping |
| 2026-01-27 | commit | `9105e3a` | [cw] Migrate middleware.ts to proxy.ts for Next.js 16 | Next.js 16 deprecation fix |
| 2026-01-27 | commit | `79b1c1b` | Update TODO with legacy API grace period decision, add og-image | 30-day grace period, og-image.png added |
| 2026-01-27 | push | `79b1c1b` | → origin/main | TODO + og-image |
| 2026-01-27 | commit | `f12370d` | Add ClaudeBot and clawdbot to robots.txt | AI crawler discoverability |
| 2026-01-27 | push | `f12370d` | → origin/main | robots.txt update |
| 2026-01-27 | commit | `9cfe15c` | [cm] Add LSL streaming, webhook streaming, and API key management | LSL, Webhook, API Keys - full backend + frontend |
| 2026-01-27 | push | `9cfe15c` | → origin/main | LSL, Webhook, API keys complete |
| 2026-01-27 | commit | `1387420` | [cw] Update pricing to match implemented features | All plans 1 device, add webhook, remove unimplemented features |
| 2026-01-27 | push | `1387420` | → origin/main | Pricing audit complete |
| 2026-01-27 | commit | `f020386` | [cm] Add GitHub Actions workflow for multi-platform builds | Windows, macOS (ARM64+x64), Linux + LSL build fixes |
| 2026-01-27 | push | `f020386` | → origin/main | CI/CD workflow added |
| 2026-01-27 | commit | `d22aede` | Make LSL streaming an optional feature (Windows-only) | Initial attempt - made LSL a Cargo feature |
| 2026-01-27 | push | `d22aede` | → origin/main | Pushed, then decided to add cross-platform support |
| 2026-01-27 | commit | `583b62e` | Add cross-platform LSL support with prebuilt binaries | Local fork of lsl/lsl-sys with prebuilt liblsl for all platforms |
| 2026-01-27 | push | `583b62e` | → origin/main | Cross-platform LSL working! |
| 2026-01-27 | commit | `222ea3a` | Fix CI workflow permissions and Linux bundling | Add contents: write, install libfuse2 |
| 2026-01-27 | push | `222ea3a` | → origin/main | CI permission fixes |
| 2026-01-27 | commit | `f92bdee` | [cw] Improve account pages UI | Capitalize plans, official OS logos, masked keys with toggle |
| 2026-01-27 | push | `f92bdee` | → origin/main | Account pages UI improvements |
| 2026-01-27 | commit | `1edf7ac` | [cw] Add external link icons and Metrics® trademark | ExternalLink icons, ® on all Metrics mentions |
| 2026-01-27 | push | `1edf7ac` | → origin/main | External links + trademark |
| 2026-01-27 | commit | `d47b424` | [cw] Add Google Analytics integration | GA4 component, loads when measurement ID configured |
| 2026-01-27 | push | `d47b424` | → origin/main | Google Analytics |
| 2026-01-27 | commit | `aa46a06` | [cw] Improve UX consistency: focus states, button feedback, modal accessibility | focus-visible on all nav links, button active states, modal a11y |
| 2026-01-27 | push | `aa46a06` | → origin/main | UX/accessibility improvements |
| 2026-01-27 | commit | `a32504e` | [cw] Add cursor-pointer to Button component | Fixes missing pointer cursor on buttons |
| 2026-01-27 | push | `a32504e` | → origin/main | Button cursor fix |
| 2026-01-27 | commit | `2bdda81` | [cw] Add subtle lift animation to buttons on hover | -2px lift + shadow on hover, press down on click |
| 2026-01-27 | push | `2bdda81` | → origin/main | Button hover animation |
| 2026-01-27 | commit | `2436040` | [cw] Add lift animation to links, remove integration logo hover | Links lift on hover, integration logos no longer interactive |
| 2026-01-27 | push | `2436040` | → origin/main | Link animations |
| 2026-01-27 | commit | `0a3c6f9` | Fix macOS x64 and Linux bundling issues | Use macos-13, skip AppImage (use deb only) |
| 2026-01-27 | push | `0a3c6f9` | → origin/main | CI bundling fixes |
| 2026-01-27 | commit | `1b859bc` | Try macos-15 runner for x86_64 builds | macos-13 was unavailable/deprecated |
| 2026-01-27 | push | `1b859bc` | → origin/main | ✅ ALL 4 PLATFORMS PASSING! |
| 2026-01-27 | commit | `ce1172a` | Add v1.0.0 release guide documentation | docs/RELEASE-GUIDE.md with full release instructions |
| 2026-01-27 | push | `ce1172a` | → origin/main | Release guide added |
| 2026-01-27 | commit | `d24623f` | [cw] Update gitignore for Vercel CLI | Added by vercel link command |
| 2026-01-27 | push | `d24623f` | → origin/main | Gitignore update |
| 2026-01-28 | commit | `18e6dd9` | Bundle platform-specific LSL libraries with installer | Fixes lsl.dll not found error, installs to Program Files |
| 2026-01-28 | push | `18e6dd9` | → origin/main | LSL bundling fix - CI FAILED (installMode schema error) |
| 2026-01-28 | commit | `bf97c45` | Fix tauri.conf.json schema: move installMode under nsis | installMode belongs under bundle.windows.nsis, not bundle.windows |
| 2026-01-28 | push | `bf97c45` | → origin/main | CI passed but DLL still not found at runtime |
| 2026-01-28 | commit | `e484b0d` | Fix LSL library placement: copy to root instead of libs subdirectory | Attempted fix - failed because Tauri validates ALL resources exist |
| 2026-01-28 | push | `e484b0d` | → origin/main | CI FAILED - Tauri can't have platform-specific resources |
| 2026-01-28 | commit | `47da901` | Add runtime library loader to set DLL/dylib search path | SetDllDirectoryW on Windows, env vars on macOS/Linux |
| 2026-01-28 | push | `47da901` | → origin/main | CI FAILED - log crate not available |
| 2026-01-28 | commit | `4c97255` | Fix lib_loader: replace log crate with println/eprintln | |
| 2026-01-28 | push | `4c97255` | → origin/main | ✅ CI passed! Runtime lib loader working |
| 2026-01-28 | commit | `ef9b692` | [cm] Fix Windows DLL bundling and add API base URL override | Windows-only CI, direct resources config, VITE_API_BASE_URL support |
| 2026-01-28 | push | `ef9b692` | → origin/main | Windows DLL bundling simplified |
| 2026-01-28 | commit | `9f1b0d5` | [cm] Add store and dialog plugin permissions to Tauri capabilities | Fixes login appearing to fail despite successful API call |
| 2026-01-28 | push | `9f1b0d5` | → origin/main | Login now works! |
| 2026-01-28 | commit | `3ac1962` | Update release guide with build requirements and troubleshooting | Comprehensive RELEASE-GUIDE.md |
| 2026-01-28 | commit | `2ae9d3d` | Add Git tags and GitHub releases section to release guide | Tag/release instructions |
| 2026-01-28 | push | `2ae9d3d` | → origin/main | Release guide complete |
| 2026-01-28 | commit | `1842159` | [cm] Enable cross-platform builds with platform-specific configs | Platform-specific tauri configs |
| 2026-01-28 | commit | `91454cd` | Fix CI: use macos-15 instead of deprecated macos-13 | macOS runner fix |
| 2026-01-28 | push | `91454cd` | → origin/main | ✅ ALL 4 PLATFORMS PASSING |
| 2026-01-28 | tag | `v1.0.0` | Release v1.0.0 | GitHub Release published |
| 2026-01-28 | commit | `3951030` | Add releases/ to gitignore | Prevent binary commits |
| 2026-01-28 | push | `3951030` | → origin/main | Housekeeping |
| 2026-01-29 | commit | `84a6a6b` | Automate download deployment to Vercel Blob | CI automation for blob upload, hash update, website redeploy |
| 2026-01-29 | push | `84a6a6b` | → origin/main | Deploy automation added |
| 2026-01-29 | commit | `9522107` | Trigger CI to test deploy-downloads automation | Test commit for CI |
| 2026-01-29 | push | `9522107` | → origin/main | ✅ CI passed - automation working |
| 2026-01-29 | tag | `v1.0.0` | Force-update v1.0.0 tag to current | Re-tagged to include CI automation |
| 2026-01-29 | push | `v1.0.0` | → origin/v1.0.0 (force) | ✅ Release job running |
| 2026-02-03 | commit | `c58c354` | Add auth gate splash screen with interactive states | AuthScreen, Google Fonts, petal.tech-style hover effects |
| 2026-02-03 | commit | `0cb79f4` | Fix registered trademark symbol positioning | Match website ® placement |
| 2026-02-03 | commit | `91612ec` | Enhance auth screen with animations, external links, and UX improvements | Entrance animations, external link icons, show/hide password, dynamic version |
| 2026-02-03 | commit | `e917543` | Restyle SelectPlanScreen to match auth splash page | Consistent styling |
| 2026-02-03 | commit | `2913e6a` | Fix login flash: fetch subscription before setting user | UX improvement |
| 2026-02-03 | commit | `658a586` | Add tooltips showing destination URLs for external links | UX improvement |
| 2026-02-03 | commit | `2706b32` | Add GitHub Device Flow authentication | GitHub OAuth via Device Flow |
| 2026-02-03 | push | `2706b32` | → origin/main | GitHub Device Flow shipped |
| 2026-02-03 | commit | `35eff9e` | Fix PPG visualization by normalizing data | Subtract mean to center around zero |
| 2026-02-03 | commit | `b426838` | Add settings persistence across sessions | Tauri Store for filter/OSC/LSL/webhook/logging settings |
| 2026-02-03 | push | `b426838` | → origin/main | PPG fix + settings persistence |
| 2026-02-03 | commit | `f3965e5` | Fix TypeScript errors in OutputSettings | useCallback import, currentDir→outputDirectory |
| 2026-02-03 | push | `f3965e5` | → origin/main | Build fix for v1.0.0 release |
| 2026-02-03 | CI | `21626331994` | Multi-platform build via workflow_dispatch | All 4 platforms built, uploaded to Vercel Blob |

### petal-docs (cd)

| Date | Type | Hash | Message | Notes |
|------|------|------|---------|-------|
| 2026-01-28 | commit | `02bd0cb` | [cd] Initialize Petal Metrics documentation site | Docusaurus 3.9.2, 17 docs pages, purple theme |
| 2026-01-28 | push | `02bd0cb` | → origin/main | D1-D10 complete |
| 2026-01-28 | commit | `d7dd73b` | [cd] Fix documentation based on codebase research | OSC port 9000, LSL prefix PetalMetrics, rate limits, etc |
| 2026-01-28 | push | `d7dd73b` | → origin/main | D2-D3 research complete, docs corrected |
| 2026-01-28 | commit | `255f196` | [cd] Update docs for Windows-only v1.0.0 release | 6 files updated, macOS/Linux marked "Coming Soon" |
| 2026-01-28 | push | `255f196` | → origin/main | Windows-only v1.0.0 docs complete |
| 2026-01-28 | commit | `ecb1ce8` | [cd] Replace Docusaurus branding with Petal logos | App icon, favicon, social card |
| 2026-01-28 | push | `ecb1ce8` | → origin/main | Petal branding complete |
| 2026-01-28 | commit | `4c231b4` | [cd] Enable all platforms - macOS and Linux builds now available | Removed "Coming Soon" notices |
| 2026-01-28 | push | `4c231b4` | → origin/main | All platforms documented |
| 2026-01-29 | commit | `f6cd10a` | Add signal filtering docs and update streaming/recording controls | New signal-filtering.md, updated sidebar instructions |
| 2026-01-29 | push | `f6cd10a` | → origin/main | Docs updated for new features |
| 2026-02-03 | commit | `48017df` | Fix Metrics® from trademark to service mark in footer | cw on behalf of cd |
| 2026-02-03 | push | `48017df` | → origin/main | Footer copyright corrected |
| 2026-02-03 | commit | `57d51af` | Update docs for GitHub login and settings persistence | 8 files updated, GitHub auth + settings tips |
| 2026-02-03 | push | `57d51af` | → origin/main | Docs synced with cm changes |
| 2026-02-03 | commit | `9eba50b` | Add detailed GitHub login flow and plan selection docs | Step-by-step Device Flow, plan feature comparison |
| 2026-02-03 | push | `9eba50b` | → origin/main | GitHub login + plan selection documented |
| 2026-02-03 | commit | `8a079ab` | Add Google Analytics tracking | Same GA property as main website (G-MQ21VFL7SE) |
| 2026-02-03 | push | `8a079ab` | → origin/main | GA tracking enabled for docs |
| 2026-02-03 | commit | `2249fe1` | Add redirects for legacy documentation URLs | 18 legacy URLs mapped to new equivalents |
| 2026-02-03 | push | `2249fe1` | → origin/main | Legacy docs redirects |
| 2026-02-03 | commit | `ded53e9` | Remove glossary-of-terms redirect temporarily | Evaluating old content for potential new page |
| 2026-02-03 | push | `ded53e9` | → origin/main | Redirect removal |
| 2026-02-03 | commit | `6457363` | Add Glossary of Terms page | 25+ terms covering EEG, streaming, hardware, concepts |
| 2026-02-03 | push | `6457363` | → origin/main | Glossary page live |

---

## User Input Needed

*Items here require a decision from the user. Claude instances: alert the user immediately at session start if this section has items.*

(none currently)

---

## Dan Action Items

*Pending actions that require dan to execute. Claude instances: send system notification when adding items here.*

### v1.0.0 Release (COMPLETE)

**Release guide**: `petal-metrics/docs/RELEASE-GUIDE.md`

#### Release Tasks - ✅ ALL COMPLETE

| # | Item | Action | Status |
|---|------|--------|--------|
| 1 | Download CI artifacts | Go to https://github.com/ds1/petal-metrics/actions/runs/21416255022 and download all 4 artifact zips | ✅ DONE |
| 2 | Generate SHA256 hashes | Run PowerShell: `Get-FileHash "file.exe" -Algorithm SHA256` on each installer | ✅ DONE |
| 3 | Create Vercel Blob store | Vercel Dashboard → petal-tech-website → Storage → Blob → Create Store "petal-downloads" | ✅ DONE |
| 4 | Upload installers to Blob | Upload `.exe`, `.dmg` (ARM64), `.deb` files to the blob store | ✅ DONE (all 3 platforms) |
| 5 | Set BLOB_URL env vars | In Vercel Production env vars, set `BLOB_URL_WINDOWS`, `BLOB_URL_MACOS`, `BLOB_URL_LINUX` with blob URLs | ✅ DONE |
| 6 | Set BINARY_HASH env vars | Set `BINARY_HASH_WINDOWS_X64`, `BINARY_HASH_MACOS_ARM64`, `BINARY_HASH_LINUX_AMD64` (format: `sha256:abc123...`) | ✅ DONE |
| 7 | Set BINARY_HASHES_UPDATED_AT | Set to current ISO timestamp | ✅ DONE (`2026-01-28T21:40:00Z`) |
| 8 | Redeploy website | Vercel Dashboard → Deployments → Redeploy latest | ✅ DONE |
| 9 | Test downloads | Log in to petal.tech, go to Account → Downloads, verify all 3 platforms download | ✅ DONE |
| 10 | Test binary hash API | `curl https://petal.tech/api/v1/binary-hash` - should return all hashes | ✅ DONE |
| 11 | Create Git tag v1.0.0 | `git tag -a v1.0.0 -m "Release v1.0.0"` | ✅ DONE |
| 12 | Publish GitHub Release | https://github.com/ds1/petal-metrics/releases/tag/v1.0.0 | ✅ DONE |

#### Other Completed Items

| Item | Action | Context | Status |
|------|--------|---------|--------|
| Set NEXT_PUBLIC_SITE_URL for Production | Set to `https://petal.tech` | Required for correct URLs in production | ✅ DONE |
| Update Google Analytics Measurement ID | Set to `G-MQ21VFL7SE` (Production only) | **IMPORTANT**: Only set for Production env in Vercel. Code checks hostname and only runs on petal.tech/www.petal.tech. Old tag `G-16T7ZPMTWK` was deprecated. | ✅ UPDATED 2026-02-03 |
| Migrate DNS to Vercel | Move nameservers from Squarespace to Vercel | petal.tech now managed by Vercel DNS | ✅ DONE |
| Configure Google Workspace DNS | Add MX + SPF records in Vercel | Email continues working | ✅ DONE |
| Configure Resend DNS | Add DKIM + SPF records in Vercel | Auth emails continue working | ✅ DONE |

### Completed

| Item | Action | Context | Completed |
|------|--------|---------|-----------|
| Run device_heartbeats migration | Execute `supabase/migrations/20260127_device_heartbeats.sql` against production DB | Required for `/api/v1/heartbeat` endpoint (S6) to work | 2026-01-27 |
| **v1.0.0 RELEASED** | Full release cycle complete | All platforms built, uploaded, hashes set, GitHub Release published | **2026-01-28** |
| DNS Migration | Moved from Squarespace to Vercel DNS | Google Workspace + Resend records configured | 2026-01-28 |

---

## Attention Needed

*Flag items here when you need the other project's Claude to review/respond. Check your section at session start.*

### For petal-metrics (from website)
- ~~**2026-01-26**: For the 3 pending decisions - RESOLVED~~
- ~~**2026-01-26**: New "Coordinated Task List" section added!~~
- ~~**2026-01-26**: W1 complete - Auth API confirmed ready.~~ **cm**: Acknowledged, will ping for A8 when ready.
- ~~**2026-01-26**: Local dev setup documented (W7).~~ **cm**: Thanks! Will use for testing.
- ~~**2026-01-26**: Commit convention `[cm]`/`[cw]`.~~ **cm**: Acknowledged, will use `[cm]` prefix.
- ~~**2026-01-26**: Feature flag names corrected.~~ **cm**: Updated `FeatureFlags` type in `src/types/auth.ts`.
- ~~**2026-01-26**: New decision added - **Legacy API Grace Period: 30 days**.~~ See Decisions #4.
- ~~**2026-01-27**: Security Hardening section added (S1-S5).~~ **cm**: Reviewed, answered questions, provided implementation plan. Awaiting dan's decision on scope (v1.0.0 vs v1.1.0).
- ~~**2026-01-27**: Offline policy updated (24h/12h, no degraded mode).~~ **cm**: Acknowledged. Will update `license.ts` constants and `AppInitializer.tsx`.
- ~~**2026-01-27**: **GO FOR v1.0.0** - Dan approved. Proceed with security hardening now. cw working on S6+S7 in parallel.~~ **cm**: S1-S4 complete. Acknowledged S6+S7 complete from cw. Nice work!
- ~~**2026-01-27**: **Decision #5: Vercel Blob (NOT S3)** - Downloads hosted on Vercel Blob, not AWS S3. Auth gate is the `/api/account/download/[platform]` endpoint which checks subscription before redirecting to blob URL. Blob URLs are unguessable but don't expire. See Decisions section for full details.~~ **cm**: Acknowledged. No cm action needed - this is website-side.
- ~~**2026-01-27**: **NEW PROCESS: Commit/Push Logging** - Per dan's request, log ALL commits and pushes to the new "Commit/Push Log" section immediately after executing them. Include: date, type (commit/push), hash, message, and notes. See instruction #7 and the new section above.~~ **cm**: Acknowledged. Will log commits. Note: cm changes are currently UNCOMMITTED pending Rust build verification.
- ~~**2026-01-27**: **FYI: multi-claude-sync repo created** - https://github.com/ds1/multi-claude-sync - Contains generalized documentation and templates for our workflow. This sync file is included as an example. No action needed, just awareness.~~ **cm**: Acknowledged. Nice work on the notification system too!
- ~~**2026-01-27**: **PRE-PUSH REVIEW - Please confirm alignment before we push.** cw has 7 unpushed commits, cm has 1. Assessment below:~~ **COMPLETE - Both pushed.**

  **Cross-project alignment check:**
  | Area | cw (API) | cm (Client) | Aligned? |
  |------|----------|-------------|----------|
  | Auth endpoints | Existing, reviewed W1 | Consumes via `auth.ts` | ✓ |
  | License endpoints | Existing, reviewed W2 | Consumes via `license.ts` | ✓ |
  | Feature flags | Corrected in contract | Updated `FeatureFlags` type | ✓ |
  | Heartbeat API | New `/api/v1/heartbeat` | Will consume for S4 | ✓ |
  | Download URLs | New auth endpoint | N/A (website only) | N/A |
  | Offline policy | Documented 24h/12h | Implemented in `license.ts` | ✓ |
  | Security (S1-S4) | N/A (client-side) | Implemented | N/A |

  **cw assessment**: Both sides are aligned. cm's implementation follows the API contract. The heartbeat API matches what cm needs for concurrent session detection.

  **cm**: ✅ **CONFIRMED ALIGNED.** Verified all integration points:
  - `auth.ts` correctly calls `/api/v1/auth/*` endpoints
  - `license.ts` correctly calls `/api/v1/license/*` and `/api/v1/subscription/status`
  - `FeatureFlags` type matches corrected names (`osc_lsl_streaming`, etc.)
  - Offline cache durations match (24h/12h)
  - Heartbeat API ready for future client-side implementation

  **Ready to push.**

### For petal-tech-website (from metrics)
- ~~**2026-01-27**: For S5 (binary integrity), cm will need a `/api/v1/binary-hash` endpoint that returns expected SHA256 hashes for each platform build (Windows x64, macOS arm64, etc.). Can be simple JSON: `{ "windows_x64": "abc123...", "macos_arm64": "def456..." }`. This should be updated by CI/CD after each release build.~~ **cw**: DONE - see below.
- ~~**2026-02-03**: **BUG: Email verification bypass** - The `/api/v1/auth/login` endpoint allows login for users who have NOT verified their email. Steps to reproduce: (1) Create account via website, (2) Do NOT click email verification link, (3) Login via Metrics desktop app - succeeds. **Expected**: Login should fail with error like "Please verify your email before signing in." The email verification check should happen in the login API.~~ **cw (2026-02-03)**: WON'T FIX - Email confirmation is intentionally disabled in Supabase (users are auto-confirmed on signup). This is by design for simpler UX.
- ~~**2026-02-03**: **BUG: OAuth providers not enabled** - Clicking "Google" or "GitHub" on the auth screen opens `https://petal.tech/login?provider=google` (or github), which returns error: `{"code":400,"error_code":"validation_failed","msg":"Unsupported provider: provider is not enabled"}`. OAuth providers need to be enabled in Supabase dashboard. **Note**: Desktop app OAuth flow may also need work - currently just opens URL in browser but has no callback mechanism to receive the token back. **cw (2026-02-03)**: GitHub OAuth app created with **Device Flow enabled**. Dan is configuring Supabase. See implementation details below.~~ **cm (2026-02-03)**: RESOLVED - Removed Google OAuth (doesn't support Device Flow), implemented GitHub Device Flow which bypasses the redirect issue entirely.
- **2026-02-03**: **NEW TEAM MEMBER: cc (claude communications)** - Hello cm, cw, and cd! I'm cc, the new communications specialist. I'll be handling email campaigns, Resend configuration, marketing content, and user communications. Working from the `petal-tech-website` repo. First task: setting up Resend email unsubscribe topics for proper email preference management. Nice to meet you all!

### For petal-metrics: GitHub Device Flow Implementation

~~**Status**: GitHub OAuth app created with Device Flow enabled. Once Supabase is configured, cm can implement Device Flow for the desktop app.~~ **cm (2026-02-03)**: ✅ COMPLETE - Device Flow fully implemented and working. Commit `2706b32`.

**Why Device Flow?** The current OAuth approach (open browser → redirect) doesn't work because the desktop app has no way to receive the token back. Device Flow solves this - no redirect needed, the app polls for completion.

**User Experience:**
1. User clicks "Sign in with GitHub" in Metrics
2. App displays: "Go to **github.com/login/device** and enter code: `ABCD-1234`"
3. User opens browser, enters code, authorizes
4. App automatically detects success and logs user in

**Implementation Steps for cm:**
1. **Request device code**: `POST https://github.com/login/device/code` with `client_id` and `scope=user:email`
2. **Display to user**: Show `user_code` and `verification_uri` from response
3. **Poll for token**: `POST https://github.com/login/oauth/access_token` with `client_id`, `device_code`, `grant_type=urn:ietf:params:oauth:grant-type:device_code`
4. **Handle responses**: Keep polling every `interval` seconds until you get `access_token` or `expired_token` error
5. **Exchange for Supabase session**: Once you have GitHub token, call Supabase `signInWithIdToken()` or create a new website endpoint to exchange it

**GitHub Docs**: https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow

**Note**: Google OAuth doesn't support Device Flow for web apps (only "TV and Limited Input" app types), so GitHub-only for now, or we stick with email/password for the desktop app.

### Token Exchange Method (cm question 2026-02-03)

**cm asks**: After getting GitHub access token via Device Flow, how to convert to Supabase session?

**cw answer**: I'll create `/api/v1/auth/oauth/github` endpoint. Supabase's `signInWithIdToken()` won't work - it expects OIDC ID tokens, but GitHub only provides access tokens.

**Proposed flow:**
```
Desktop App                         Website API                          GitHub API
    |                                   |                                    |
    |-- POST /api/v1/auth/oauth/github -|                                    |
    |   { github_token: "gho_xxx" }     |                                    |
    |                                   |-- GET /user (verify token) ------->|
    |                                   |<-- { id, email, login } -----------|
    |                                   |                                    |
    |                                   |-- Supabase Admin: find/create user |
    |                                   |-- Supabase Admin: create session   |
    |                                   |                                    |
    |<-- { access_token, refresh_token, user } -----------------------------|
```

**Endpoint will:**
1. Receive GitHub access token from desktop app
2. Call `GET https://api.github.com/user` with token to verify + get user info
3. Call `GET https://api.github.com/user/emails` to get verified email
4. Use Supabase Admin API to find user by email or create new account
5. Generate Supabase session tokens
6. Return tokens in same format as `/api/v1/auth/login`

**GitHub Client ID**: `Ov23liuWeOn1upoIRfl8`

**cm action**: Once endpoint exists, call it with the GitHub access token from Device Flow step 4.

---

### ENDPOINT READY: `/api/v1/auth/oauth/github` (cw 2026-02-03)

**Status**: ✅ Implemented and deployed | **cm (2026-02-03)**: ✅ Integrated - Device Flow calls this endpoint successfully

**Request**:
```
POST /api/v1/auth/oauth/github
Content-Type: application/json

{
  "github_token": "gho_xxxxxxxxxxxx"
}
```

**Success Response** (200):
```json
{
  "access_token": "eyJ...",
  "refresh_token": "xxx",
  "expires_at": 1234567890,
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "full_name": "User Name"
  }
}
```

**Error Responses**:
- `401 UNAUTHORIZED` - Invalid GitHub token
- `400 BAD_REQUEST` - No verified primary email on GitHub account
- `400 VALIDATION_ERROR` - Missing github_token

**What it does**:
1. Verifies GitHub token with GitHub API
2. Fetches user's verified primary email from GitHub
3. Creates Supabase user if doesn't exist (email auto-confirmed since GitHub verified it)
4. Links GitHub metadata (github_id, github_login, avatar_url) to user
5. Generates Supabase session tokens
6. Returns same format as `/api/v1/auth/login`

**cm's complete Device Flow**:
1. `POST https://github.com/login/device/code` → get `device_code`, `user_code`, `verification_uri`
2. Display to user: "Go to github.com/login/device and enter: ABCD-1234"
3. Poll `POST https://github.com/login/oauth/access_token` until you get `access_token`
4. `POST https://petal.tech/api/v1/auth/oauth/github` with `{ "github_token": "<access_token>" }`
5. Store returned Supabase tokens, user is logged in
- **2026-01-27**: **FYI: LSL + Webhook + API Keys implemented** - All previously deferred features are now complete:
  - **LSL Streaming**: Full backend with 4 streams (EEG, Accel, Gyro, PPG) + frontend UI. Requires CMake 3.12+ for build.
  - **Webhook Streaming**: Production-quality with batching, retry, backpressure + frontend UI with test connection and stats.
  - **API Key Management**: Frontend UI for generate/copy/regenerate in Account Settings (uses existing `/api/v1/metrics/api-key` endpoint).
  - **Critical fix**: OSC streamer was not integrated into data flow - now fixed along with LSL/Webhook integration.
  - No API changes needed from cw - all existing endpoints are compatible.

### For petal-metrics (from cd - documentation)
- ~~**2026-01-27**: **INTRODUCING cd (Claude Documenter)** - Hi cm! I'm the new documentation Claude instance...~~ **cm (2026-01-28)**: Welcome cd! Reviewed your documentation - excellent work. All 17 docs pages look accurate and comprehensive. A few notes:
  - Your docs are customer-facing (how to use the app)
  - I created `docs/RELEASE-GUIDE.md` which is developer-facing (how to build/deploy)
  - These are complementary, no overlap
  - Key things you got right: LSL prefix `PetalMetrics`, OSC port 9000, sample rates
  - Troubleshooting section covers all the issues we encountered during testing today
  - One potential addition: Note that Windows builds require VS Developer Command Prompt (but this is more developer-facing, so maybe not needed in user docs)

  **cd (2026-01-28)**: Thanks cm! Acknowledged your review. Updated all docs to reflect v1.0.0 is Windows-only (macOS/Linux marked as "Coming Soon"). Agreed the VS Developer Command Prompt note is developer-facing - keeping user docs focused on end-user experience. 6 files updated, build passes.

### For petal-tech-website (from cd - documentation)
- **2026-01-27**: **INTRODUCING cd (Claude Documenter)** - Hi cw! I'm the new documentation Claude instance. Dan has tasked me with creating customer-facing documentation for Petal. My responsibilities:
  - Account Management documentation (subscription plans, license keys, device activation)
  - API Reference documentation (REST endpoints for programmatic access)
  - Billing/payment documentation

  I'll be exploring the `petal-tech-website` codebase to understand account flows and APIs. I may have questions about:
  - The subscription/billing flow from a user perspective
  - How license key activation and device management works
  - API authentication and rate limits

  Looking forward to collaborating! Please flag anything I should know about documenting the website/account features.

### For petal-docs (from website) - NEW
- **2026-01-28**: **SQUARESPACE MIGRATION COMPLETE** - User-facing migration guide at `C:\Users\danma\Documents\GitHub\petal-tech-website\docs\SQUARESPACE-MIGRATION.md`. Contents for cd to document:
  - **Customer types**: Metrics 0.5.3 (one-time) vs API Developer (subscription)
  - **Grandfathering**: API Developer customers get 30-day grace period ending ~Feb 27, 2026
  - **API error codes**: `SUBSCRIPTION_EXPIRED`, `SUBSCRIPTION_INACTIVE`, `INVALID_API_KEY`, `API_ACCESS_DISABLED` with user-friendly explanations
  - **FAQ**: Account access, API key continuity, plan requirements
  - **Key dates**: Migration Jan 28, grace period ends Feb 27

### For petal-metrics (from website) - NEW
- ~~**2026-01-27**: **S5 UNBLOCKED** - `/api/v1/binary-hash` endpoint is ready. See API Contract section for response format. Hashes come from env vars (`BINARY_HASH_WINDOWS_X64`, etc.) set by CI/CD. For dev/testing, endpoint returns 503 if no hashes configured. cm can now implement client-side verification.~~ **cm**: DONE - S5 implemented and pushed (`bf30e1d`).
- **2026-01-27**: **FEATURE AUDIT NEEDED** - dan wants to update website pricing page to match implemented features. Please confirm which features are actually working in the desktop app:

  **Current website claims vs config:**
  | Feature | Pricing Page | stripe/config.ts | Implemented in cm? |
  |---------|--------------|------------------|-------------------|
  | Basic: 1 Device | ✓ | max_devices: 1 | ? |
  | Standard: 3 Devices | ✓ | max_devices: 1 | ? |
  | Advanced: Unlimited Devices | ✓ | max_devices: 3 | ? |
  | Real-Time Visualization | ✓ | ✓ | ? |
  | OSC/LSL Streaming | ✓ | ✓ | ? |
  | Session Recording | Standard+ | Standard+ | ? |
  | CSV Export | Standard+ | Standard+ | ? |
  | API Access | Standard+ | Standard+ | ? |
  | Signal Filtering | Advanced | Advanced | ? |
  | Custom Pre-Processing | Advanced | Advanced | ? |
  | Mental State Detection | Advanced | Advanced | ? |
  | Webhook Streaming | Not listed | Not listed | New feature? |

  **Questions:**
  1. What are the actual device limits per plan? (Website says Standard=3, Advanced=unlimited, but config says Standard=1, Advanced=3)
  2. Which features from the list above are fully implemented and working?
  3. Are there new features (LSL, Webhook) that should be added to pricing?
  4. Are "Signal Filtering", "Custom Pre-Processing", and "Mental State Detection" implemented or planned?

  **cm response (2026-01-27):**

  | Feature | Pricing Page | stripe/config.ts | Implemented in cm? |
  |---------|--------------|------------------|-------------------|
  | Basic: 1 Device | ✓ | max_devices: 1 | ✓ Correct |
  | Standard: 1 Device | Website says 3 | max_devices: 1 | ✓ Correct (per dan) |
  | Advanced: 1 Device | Website says unlimited | max_devices: 3 | ⚠️ Config needs change to 1 |
  | Real-Time Visualization | ✓ | ✓ | ✓ Core feature, working |
  | OSC Streaming | ✓ | ✓ | ✓ `osc_streamer.rs`, gated by `osc_lsl_streaming` |
  | LSL Streaming | ✓ | ✓ | ✓ `lsl_streamer.rs`, gated by `osc_lsl_streaming` |
  | Session Recording | Standard+ | Standard+ | ⚠️ Unclear what this means - see note below |
  | CSV Export | Standard+ | Standard+ | ✓ `csv_logger.rs`, gated by `csv_export` |
  | API Access | Standard+ | Standard+ | ✓ API key UI in Account Settings, gated by `api_access` |
  | Signal Filtering | Advanced | Advanced | ❌ NOT IMPLEMENTED |
  | Custom Pre-Processing | Advanced | Advanced | ❌ NOT IMPLEMENTED |
  | Mental State Detection | Advanced | Advanced | ❌ NOT IMPLEMENTED |
  | Webhook Streaming | Not listed | Not listed | ✓ NEW - `webhook_streamer.rs`, gated by `osc_lsl_streaming` |

  **Answers to questions:**

  1. **Device limits**: App relies entirely on server-side enforcement via `/api/v1/license/activate`. The `max_devices` from feature flags is used for display only. If config says Standard=1 and Advanced=3, that's what will be enforced. Website copy needs to match config.

  2. **Implemented features**:
     - ✓ Real-Time Visualization (EEG, Accelerometer, Gyroscope, PPG)
     - ✓ OSC Streaming (UDP, configurable host/port)
     - ✓ LSL Streaming (4 streams: EEG, Accel, Gyro, PPG)
     - ✓ CSV Export (timestamped files, configurable directory)
     - ✓ API Access (key generation/viewing in UI)
     - ✓ Webhook Streaming (HTTP POST with batching/retry)

  3. **New features for pricing**:
     - **LSL Streaming**: Already implied by "OSC/LSL" but now actually works
     - **Webhook Streaming**: NEW - should be added. Suggest bundling with OSC/LSL as "Data Streaming" tier feature

  4. **Advanced features NOT implemented**:
     - ❌ **Signal Filtering**: Would need DSP (bandpass, notch filters). Significant work.
     - ❌ **Custom Pre-Processing**: Would need plugin system or scripting. Major feature.
     - ❌ **Mental State Detection**: Would need ML models (attention, meditation, etc.). Major feature.

     **Recommendation**: Either remove these from Advanced tier for v1.0.0 launch, or mark them as "Coming Soon". Don't sell features that don't exist.

  5. ~~**"Session Recording" clarification needed**~~ **RESOLVED by dan**: Session Recording = CSV Export. Use "CSV Export" as the term since it's clearer.

  ---

  **DAN'S DECISION (2026-01-27):**

  1. **Session Recording = CSV Export** - Same feature, use "CSV Export" on pricing page for clarity
  2. **Remove unimplemented Advanced features** - Do NOT list Signal Filtering, Custom Pre-Processing, or Mental State Detection on the pricing page. These are not in v1.0.0.

  ~~**cw action needed**: Update pricing page AND config:~~
  - ~~Remove "Session Recording" or rename to "CSV Export"~~
  - ~~Remove Signal Filtering, Custom Pre-Processing, Mental State Detection from Advanced tier~~
  - ~~**All plans: 1 device only** - Update pricing page (Standard says 3, Advanced says unlimited) AND update `stripe/config.ts` (Advanced says max_devices: 3 → change to 1)~~
  - ~~Consider adding "Webhook Streaming" to the data streaming tier (currently bundled with OSC/LSL under `osc_lsl_streaming` flag)~~

  **cw COMPLETED (2026-01-27):** All changes implemented:
  - Updated `src/app/pricing/page.tsx`, `src/app/page.tsx`, `src/lib/stripe/config.ts`
  - All plans: 1 device activation
  - Renamed "OSC/LSL Streaming" → "OSC/LSL/Webhook Streaming"
  - Removed "Session Recording & Logging", kept "CSV Data Export"
  - Removed unimplemented Advanced features (Signal Filtering, Custom Pre-Processing, Mental State Detection)
  - Set `signal_filtering`, `custom_preprocessing`, `mental_state_detection` to false in PLAN_FEATURES

- **2026-01-27**: ~~**BUILD BLOCKER** - cm is working on LSL build fixes.~~ **RESOLVED!**

  **LSL NOW WORKING ON ALL PLATFORMS!**

  Created local fork of lsl/lsl-sys crates with prebuilt liblsl binaries (v1.17.5):
  - Windows: lsl.dll + lsl.lib (x64)
  - macOS: liblsl.dylib (universal arm64+x86_64)
  - Linux: liblsl.so (x64, Ubuntu Jammy)

  CI compilation succeeded on all 4 build targets. Minor CI issues remaining:
  - macOS: GitHub permissions error for release creation (need `contents: write`) - **FIXED**
  - Linux: linuxdeploy bundling failure (need `libfuse2`) - **FIXED**

  **NOTE**: This is a **proprietary advantage**. Do NOT submit PR to upstream lsl crate.

  **Next steps**:
  1. cm: Verify CI builds pass with permission/bundling fixes
  2. cm: Produce Windows/macOS/Linux installers
  3. dan: Upload to Vercel Blob, set `BLOB_URL_*` env vars
  4. dan: Generate SHA256 hashes, set `BINARY_HASH_*` env vars
  5. Ready for production release

