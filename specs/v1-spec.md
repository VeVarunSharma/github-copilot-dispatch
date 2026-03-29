# GitHub Copilot Dispatch — V1 Specification

> Version: 1.0.0-draft
> Last updated: 2026-03-29
> Status: In Development (Phase 1 — MVP)

---

## 1. Product Overview

**GitHub Copilot Dispatch** is an Apple Watch app that brings GitHub Copilot's agentic capabilities to your wrist. Users can launch Copilot coding agent sessions, review and approve pull requests, and manage code tasks — all from an Apple Watch.

The UX mirrors the GitHub Copilot CLI experience (terminal-like feel, timeline events, status indicators) adapted for the Watch form factor.

### 1.1 Target User

Software engineers who use GitHub Copilot and want to:
- Launch and monitor coding agent sessions on the go
- Triage and approve pull requests without opening a laptop
- Stay informed of CI/CD status and agent activity

### 1.2 Design Philosophy

- **CLI-inspired:** Dark terminal aesthetic, monospace output, timeline events
- **Minimal interaction:** Voice dictation, tap-to-approve, pre-configured templates
- **Glanceable:** Status indicators, haptic notifications, complications

---

## 2. Architecture

### 2.1 System Diagram

```
┌──────────────────┐      HTTPS/REST       ┌──────────────────┐      SDK       ┌─────────────┐
│  Apple Watch App │  ←── polling ──→       │  Node.js Backend │  ←─────────→   │  GitHub      │
│  (SwiftUI/watchOS│      JSON              │  (Express + TS)  │  streaming     │  Copilot API │
│   11+)           │                        │                  │  events        │  (@github/   │
└──────────────────┘                        └──────────────────┘  ←─────────→   │  copilot-sdk)│
        │                                           │             Octokit       └─────────────┘
        │ Keychain                                  │                           ┌─────────────┐
        │ (token storage)                           │ In-memory store  ←──────→ │  GitHub API  │
        │                                           │ (sessions, tokens)        │  (REST v3)   │
        │                                           │                           └─────────────┘
        │                                           │
        │                                    ┌──────┴───────┐
        │                                    │  APNs        │
        └──── push notifications ────────────│  (Phase 4)   │
                                             └──────────────┘
```

### 2.2 Frontend — Apple Watch

| Property        | Value                                      |
| --------------- | ------------------------------------------ |
| Language         | Swift 6                                    |
| UI Framework     | SwiftUI                                    |
| Target           | watchOS 11+ (independent, no iPhone companion) |
| Package Manager  | Swift Package Manager                      |
| Auth Storage     | watchOS Keychain                           |
| Communication    | URLSession (polling-based)                 |

### 2.3 Backend — Node.js

| Property          | Value                                    |
| ----------------- | ---------------------------------------- |
| Language           | TypeScript 5.8+                          |
| Runtime            | Node.js 22+                              |
| Framework          | Express.js 5                             |
| Copilot SDK        | `@github/copilot-sdk` (technical preview)|
| GitHub Client      | Octokit 4                                |
| Storage (MVP)      | In-memory (Map-based)                    |
| Storage (future)   | PostgreSQL or SQLite                     |
| Containerization   | Docker (multi-stage build)               |
| Deployment targets | Railway / Fly.io / Azure Container Apps  |

### 2.4 Communication Pattern

The Watch app communicates with the backend via **short-interval polling** over HTTPS REST:

| Context                    | Poll Interval | Endpoint                    |
| -------------------------- | ------------- | --------------------------- |
| Auth pending               | 5 seconds     | `POST /api/auth/poll-token` |
| Session list visible       | 5 seconds     | `GET /api/sessions`         |
| Active session detail      | 3 seconds     | `GET /api/sessions/:id`     |
| Idle / background          | 30 seconds    | `GET /api/sessions`         |

---

## 3. Authentication

### 3.1 GitHub Device Code Flow

The Watch has no browser, so authentication uses [GitHub's Device Code Flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow):

```
┌─────────┐                  ┌──────────┐                  ┌────────┐
│  Watch   │                  │  Backend  │                  │ GitHub  │
└────┬─────┘                  └─────┬─────┘                  └────┬───┘
     │  POST /api/auth/device-code  │                             │
     │ ───────────────────────────→ │  POST /login/device/code    │
     │                              │ ──────────────────────────→ │
     │                              │  { device_code, user_code,  │
     │                              │    verification_uri }       │
     │                              │ ←────────────────────────── │
     │  { user_code,                │                             │
     │    verification_uri }        │                             │
     │ ←─────────────────────────── │                             │
     │                              │                             │
     │  [User enters code on        │                             │
     │   phone/computer]            │                             │
     │                              │                             │
     │  POST /api/auth/poll-token   │                             │
     │  { device_code }             │  POST /login/oauth/access   │
     │ ───────────────────────────→ │ ──────────────────────────→ │
     │                              │  { access_token }           │
     │  { access_token }            │ ←────────────────────────── │
     │ ←─────────────────────────── │                             │
     │                              │                             │
     │  [Store token in Keychain]   │                             │
```

### 3.2 Required OAuth Scopes

| Scope       | Purpose                              |
| ----------- | ------------------------------------ |
| `repo`      | Read/write access to repositories    |
| `user`      | Read user profile                    |
| `read:org`  | List org repos                       |
| `copilot`   | Access Copilot features              |

### 3.3 Token Storage

- **Watch:** Stored in watchOS Keychain via `KeychainManager`
- **Backend:** Passed per-request in `Authorization: Bearer <token>` header; not stored server-side

---

## 4. API Specification

Base URL: `https://<backend-host>/api`

All protected endpoints require `Authorization: Bearer <github_access_token>` header.

### 4.1 Auth Endpoints

#### `POST /api/auth/device-code`

Initiate GitHub Device Code Flow.

**Request:** (empty body)

**Response `200`:**
```json
{
  "userCode": "ABCD-1234",
  "verificationUri": "https://github.com/login/device",
  "expiresIn": 900,
  "interval": 5
}
```

#### `POST /api/auth/poll-token`

Poll for completed authentication.

**Request:**
```json
{
  "deviceCode": "device_code_from_initiation"
}
```

**Response `200` (success):**
```json
{
  "accessToken": "gho_xxxxxxxxxxxx",
  "tokenType": "bearer",
  "scope": "repo,user,read:org,copilot"
}
```

**Response `202` (still pending):**
```json
{
  "status": "authorization_pending"
}
```

#### `GET /api/auth/user`

Get authenticated user info. **Protected.**

**Response `200`:**
```json
{
  "login": "octocat",
  "name": "The Octocat",
  "avatarUrl": "https://avatars.githubusercontent.com/u/1?v=4"
}
```

---

### 4.2 Session Endpoints

#### `POST /api/sessions`

Create a new Copilot agent session. **Protected.**

**Request:**
```json
{
  "repo": "owner/repo-name",
  "prompt": "Fix the failing test in src/utils.test.ts",
  "model": "claude-sonnet-4.5"
}
```

**Response `201`:**
```json
{
  "id": "sess_abc123",
  "status": "pending",
  "repo": "owner/repo-name",
  "prompt": "Fix the failing test in src/utils.test.ts",
  "model": "claude-sonnet-4.5",
  "events": [],
  "createdAt": "2026-03-29T00:00:00Z",
  "updatedAt": "2026-03-29T00:00:00Z"
}
```

#### `GET /api/sessions`

List active/recent sessions. **Protected.**

**Query params:**
- `status` (optional): `pending`, `running`, `completed`, `failed`, `cancelled`
- `limit` (optional, default: 20)

**Response `200`:**
```json
{
  "sessions": [
    {
      "id": "sess_abc123",
      "status": "running",
      "repo": "owner/repo-name",
      "prompt": "Fix the failing test...",
      "model": "claude-sonnet-4.5",
      "eventCount": 12,
      "createdAt": "2026-03-29T00:00:00Z",
      "updatedAt": "2026-03-29T00:01:30Z"
    }
  ]
}
```

#### `GET /api/sessions/:id`

Get session detail with buffered output events. **Protected.**

**Query params:**
- `sinceEvent` (optional): Only return events after this index (for incremental polling)

**Response `200`:**
```json
{
  "id": "sess_abc123",
  "status": "running",
  "repo": "owner/repo-name",
  "prompt": "Fix the failing test in src/utils.test.ts",
  "model": "claude-sonnet-4.5",
  "events": [
    {
      "index": 0,
      "type": "status_change",
      "content": "Session started",
      "timestamp": "2026-03-29T00:00:01Z"
    },
    {
      "index": 1,
      "type": "message_delta",
      "content": "Looking at the test file...",
      "timestamp": "2026-03-29T00:00:05Z"
    },
    {
      "index": 2,
      "type": "tool_call",
      "content": "Reading src/utils.test.ts",
      "timestamp": "2026-03-29T00:00:08Z"
    }
  ],
  "pullRequestUrl": null,
  "createdAt": "2026-03-29T00:00:00Z",
  "updatedAt": "2026-03-29T00:00:08Z"
}
```

#### `POST /api/sessions/:id/send`

Send a follow-up message to an active session. **Protected.**

**Request:**
```json
{
  "message": "Also add a test for the edge case with null input"
}
```

**Response `200`:**
```json
{
  "status": "message_sent"
}
```

#### `DELETE /api/sessions/:id`

Cancel/stop a running session. **Protected.**

**Response `200`:**
```json
{
  "id": "sess_abc123",
  "status": "cancelled"
}
```

---

### 4.3 Repository Endpoints

#### `GET /api/repos`

List authenticated user's repositories. **Protected.**

**Query params:**
- `sort` (optional): `updated` (default), `name`, `created`
- `limit` (optional, default: 30)

**Response `200`:**
```json
{
  "repositories": [
    {
      "fullName": "owner/repo-name",
      "name": "repo-name",
      "owner": "owner",
      "description": "A cool project",
      "language": "TypeScript",
      "updatedAt": "2026-03-28T12:00:00Z",
      "isPrivate": false
    }
  ]
}
```

---

### 4.4 Pull Request Endpoints (Phase 2)

#### `GET /api/repos/:owner/:repo/pulls`

List open pull requests. **Protected.**

**Query params:**
- `state` (optional): `open` (default), `closed`, `all`
- `limit` (optional, default: 20)

**Response `200`:**
```json
{
  "pullRequests": [
    {
      "number": 42,
      "title": "Fix utils test edge case",
      "author": "copilot[bot]",
      "branch": "copilot/fix-42",
      "baseBranch": "main",
      "additions": 15,
      "deletions": 3,
      "changedFiles": 2,
      "ciStatus": "success",
      "createdAt": "2026-03-29T00:05:00Z",
      "updatedAt": "2026-03-29T00:10:00Z"
    }
  ]
}
```

#### `GET /api/repos/:owner/:repo/pulls/:number`

Get PR details with AI-generated summary. **Protected.**

**Response `200`:**
```json
{
  "number": 42,
  "title": "Fix utils test edge case",
  "author": "copilot[bot]",
  "body": "This PR fixes...",
  "branch": "copilot/fix-42",
  "baseBranch": "main",
  "additions": 15,
  "deletions": 3,
  "changedFiles": 2,
  "ciStatus": "success",
  "mergeable": true,
  "aiSummary": "This PR adds null-input handling to the parseConfig utility and includes 2 new test cases covering the edge case.",
  "files": [
    {
      "filename": "src/utils.ts",
      "status": "modified",
      "additions": 5,
      "deletions": 1
    },
    {
      "filename": "src/utils.test.ts",
      "status": "modified",
      "additions": 10,
      "deletions": 2
    }
  ],
  "checks": [
    {
      "name": "CI / test",
      "status": "completed",
      "conclusion": "success"
    }
  ],
  "createdAt": "2026-03-29T00:05:00Z",
  "updatedAt": "2026-03-29T00:10:00Z"
}
```

#### `POST /api/repos/:owner/:repo/pulls/:number/review`

Submit a review. **Protected.**

**Request:**
```json
{
  "event": "APPROVE",
  "body": "Looks good! 👍"
}
```

`event` values: `APPROVE`, `REQUEST_CHANGES`, `COMMENT`

**Response `200`:**
```json
{
  "status": "review_submitted",
  "event": "APPROVE"
}
```

#### `PUT /api/repos/:owner/:repo/pulls/:number/merge`

Merge a PR. **Protected.**

**Request:**
```json
{
  "mergeMethod": "squash"
}
```

`mergeMethod` values: `merge`, `squash`, `rebase`

**Response `200`:**
```json
{
  "status": "merged",
  "sha": "abc123def456"
}
```

#### `GET /api/repos/:owner/:repo/pulls/:number/status`

Get CI/check status for a PR. **Protected.**

**Response `200`:**
```json
{
  "state": "success",
  "checks": [
    {
      "name": "CI / test",
      "status": "completed",
      "conclusion": "success"
    },
    {
      "name": "CI / lint",
      "status": "completed",
      "conclusion": "success"
    }
  ]
}
```

---

### 4.5 Task Template Endpoints (Phase 3)

#### `GET /api/templates`

List saved task templates. **Protected.**

**Response `200`:**
```json
{
  "templates": [
    {
      "id": "tmpl_001",
      "name": "Fix Issue",
      "prompt": "Fix issue #{issue_number} in {repo}",
      "icon": "wrench",
      "createdAt": "2026-03-28T00:00:00Z"
    }
  ]
}
```

#### `POST /api/templates`

Create a task template. **Protected.**

**Request:**
```json
{
  "name": "Add Tests",
  "prompt": "Add comprehensive unit tests for {file_path}",
  "icon": "checkmark.circle"
}
```

#### `POST /api/tasks/from-issue`

Launch agent session from a GitHub issue. **Protected.**

**Request:**
```json
{
  "repo": "owner/repo",
  "issueNumber": 42,
  "model": "claude-sonnet-4.5"
}
```

#### `POST /api/tasks/from-template`

Launch agent session from a template. **Protected.**

**Request:**
```json
{
  "templateId": "tmpl_001",
  "variables": {
    "repo": "owner/repo",
    "issue_number": "42"
  },
  "model": "claude-sonnet-4.5"
}
```

---

### 4.6 Notification Endpoints (Phase 4)

#### `POST /api/devices`

Register device for push notifications. **Protected.**

**Request:**
```json
{
  "deviceToken": "apns_device_token_hex",
  "platform": "watchos"
}
```

#### `GET /api/notifications`

List recent notifications. **Protected.**

**Response `200`:**
```json
{
  "notifications": [
    {
      "id": "notif_001",
      "type": "session_completed",
      "title": "Agent completed",
      "body": "Session for owner/repo finished — PR #42 opened",
      "read": false,
      "createdAt": "2026-03-29T00:10:00Z"
    }
  ]
}
```

---

## 5. Data Models

### 5.1 Session

| Field          | Type               | Description                                    |
| -------------- | ------------------ | ---------------------------------------------- |
| `id`           | `string`           | Unique session ID (e.g., `sess_abc123`)        |
| `userId`       | `string`           | GitHub username of session owner                |
| `status`       | `SessionStatus`    | Current session state                          |
| `repo`         | `string`           | Repository full name (`owner/repo`)            |
| `prompt`       | `string`           | Initial task description                       |
| `model`        | `string`           | AI model used                                  |
| `events`       | `SessionEvent[]`   | Ordered list of session events                 |
| `pullRequestUrl` | `string \| null` | URL of created PR (if any)                     |
| `error`        | `string \| null`   | Error message (if failed)                      |
| `createdAt`    | `string` (ISO)     | Session creation timestamp                     |
| `updatedAt`    | `string` (ISO)     | Last update timestamp                          |

### 5.2 SessionStatus (enum)

| Value        | Description                        |
| ------------ | ---------------------------------- |
| `pending`    | Session created, not yet started   |
| `running`    | Agent actively working             |
| `completed`  | Agent finished successfully        |
| `failed`     | Agent encountered an error         |
| `cancelled`  | User cancelled the session         |

### 5.3 SessionEvent

| Field       | Type     | Description                                  |
| ----------- | -------- | -------------------------------------------- |
| `index`     | `number` | Sequential event index (for incremental polling) |
| `type`      | `string` | Event type (see below)                       |
| `content`   | `string` | Event content/message                        |
| `timestamp` | `string` | ISO timestamp                                |

**Event types:**

| Type              | Description                                     |
| ----------------- | ----------------------------------------------- |
| `status_change`   | Session status changed                          |
| `message_delta`   | Partial assistant message (streamed text)       |
| `message_complete`| Complete assistant message                      |
| `tool_call`       | Agent invoked a tool (e.g., file read/write)    |
| `tool_result`     | Result of a tool invocation                     |
| `error`           | An error occurred                               |
| `pr_opened`       | Pull request was opened                         |

### 5.4 Repository

| Field         | Type      | Description                    |
| ------------- | --------- | ------------------------------ |
| `fullName`    | `string`  | `owner/repo-name`             |
| `name`        | `string`  | Repository name                |
| `owner`       | `string`  | Repository owner               |
| `description` | `string`  | Repo description               |
| `language`    | `string`  | Primary language               |
| `updatedAt`   | `string`  | Last push/update               |
| `isPrivate`   | `boolean` | Visibility                     |

### 5.5 User

| Field       | Type     | Description              |
| ----------- | -------- | ------------------------ |
| `login`     | `string` | GitHub username           |
| `name`      | `string` | Display name              |
| `avatarUrl` | `string` | Profile avatar URL        |

---

## 6. Watch App Screens

### 6.1 Auth Screen

Shown when no token is stored in Keychain.

```
┌──────────────────────────┐
│                          │
│     🔐 Sign In           │
│                          │
│   Enter this code on     │
│   github.com/login/device│
│                          │
│   ┌──────────────────┐   │
│   │   ABCD-1234      │   │
│   └──────────────────┘   │
│                          │
│   Waiting for auth...    │
│   ◌ ◌ ◌ (spinner)       │
│                          │
└──────────────────────────┘
```

- Large, prominent display of `user_code`
- Instructions text
- Auto-polling with spinner
- Success haptic + transition to Home on completion

### 6.2 Home Screen

Main dashboard after authentication.

```
┌──────────────────────────┐
│  ◆ Copilot Dispatch      │
│                          │
│  ┌─────────────────────┐ │
│  │ 🟢 2 agents running │ │
│  └─────────────────────┘ │
│                          │
│  [+ New Session]         │
│  [📋 Sessions]           │
│  [⚙️ Settings]           │
│                          │
│  Recent:                 │
│  ✅ Fix #42  2m ago      │
│  🟢 Add tests  running   │
│                          │
└──────────────────────────┘
```

- Copilot branding with accent color
- Active agent count with pulse animation
- Quick action navigation buttons
- Recent activity timeline

### 6.3 Session List

```
┌──────────────────────────┐
│  Sessions                │
│                          │
│  🟢 Add unit tests       │
│     owner/repo  running  │
│                          │
│  ✅ Fix issue #42         │
│     owner/repo  2m ago   │
│                          │
│  🔴 Refactor utils        │
│     owner/repo  failed   │
│                          │
│  🟡 Code review           │
│     owner/repo  pending  │
│                          │
└──────────────────────────┘
```

- Status indicator (colored dot) per session
- Repo name + relative time
- Tap → Session Detail
- Swipe left → Cancel (with confirmation)

### 6.4 Session Detail

Terminal-inspired output view.

```
┌──────────────────────────┐
│  Fix issue #42    🟢     │
│  owner/repo              │
│                          │
│ ┌────────────────────┐   │
│ │ > Reading issue #42│   │
│ │ > Analyzing code...│   │
│ │ > Editing utils.ts │   │
│ │ > Running tests... │   │
│ │ > All tests pass ✓ │   │
│ │ > Opening PR #43   │   │
│ └────────────────────┘   │
│                          │
│ [💬 Message] [⏹ Cancel]  │
│                          │
└──────────────────────────┘
```

- Dark background, monospace font (SF Mono)
- Auto-scrolling terminal output
- Status badge in top-right
- Action buttons at bottom
- "View PR" button appears when PR is opened

### 6.5 New Session Screen

```
┌──────────────────────────┐
│  New Session             │
│                          │
│  Repository:             │
│  ┌────────────────────┐  │
│  │ owner/repo-name  ▾ │  │
│  └────────────────────┘  │
│                          │
│  Task:                   │
│  ┌────────────────────┐  │
│  │ 🎤 Dictate...      │  │
│  └────────────────────┘  │
│                          │
│  ┌────────────────────┐  │
│  │    🚀 Launch       │  │
│  └────────────────────┘  │
│                          │
└──────────────────────────┘
```

- Repo picker (scrollable list, recent repos first)
- Voice dictation button (primary input method on Watch)
- Launch button with haptic confirmation (`.success`)

### 6.6 PR Review Screen (Phase 2)

```
┌──────────────────────────┐
│  PR #42                  │
│  Fix utils edge case     │
│  copilot[bot] → main     │
│                          │
│  +15  -3   2 files       │
│                          │
│  🤖 AI Summary:          │
│  Adds null handling to   │
│  parseConfig, 2 new tests│
│                          │
│  CI: ✅ All checks pass  │
│                          │
│ [✅ Approve] [🔀 Merge]  │
│ [💬 Comment] [❌ Changes] │
│                          │
└──────────────────────────┘
```

### 6.7 Settings Screen

```
┌──────────────────────────┐
│  Settings                │
│                          │
│  👤 octocat              │
│     The Octocat          │
│                          │
│  [Sign Out]              │
│                          │
└──────────────────────────┘
```

---

## 7. Design System — Primer for watchOS

### 7.1 Color Tokens

| Token          | Hex       | Usage                           |
| -------------- | --------- | ------------------------------- |
| `background`   | `#0d1117` | App background                  |
| `surface`      | `#161b22` | Cards, elevated surfaces        |
| `surfaceHover` | `#1c2129` | Pressed/highlighted surfaces    |
| `border`       | `#30363d` | Borders, dividers               |
| `borderMuted`  | `#21262d` | Subtle borders                  |
| `text`         | `#e6edf3` | Primary text                    |
| `textMuted`    | `#8b949e` | Secondary text                  |
| `textSubtle`   | `#6e7681` | Tertiary text                   |
| `green`        | `#3fb950` | Success, active, additions      |
| `red`          | `#f85149` | Error, failure, deletions       |
| `blue`         | `#58a6ff` | Info, links                     |
| `purple`       | `#bc8cff` | Copilot accent                  |
| `yellow`       | `#d29922` | Warning, pending                |
| `orange`       | `#d18616` | Alert                           |

### 7.2 Typography

| Style           | Font        | Size | Weight    | Usage                  |
| --------------- | ----------- | ---- | --------- | ---------------------- |
| `title`         | SF Pro      | 20pt | Bold      | Screen titles          |
| `headline`      | SF Pro      | 17pt | Semibold  | Section headers        |
| `body`          | SF Pro      | 15pt | Regular   | Body text              |
| `caption`       | SF Pro      | 13pt | Regular   | Timestamps, metadata   |
| `terminal`      | SF Mono     | 13pt | Regular   | Agent output           |
| `terminalBold`  | SF Mono     | 13pt | Bold      | Terminal emphasis       |
| `code`          | SF Mono     | 12pt | Regular   | Inline code            |

### 7.3 Spacing Tokens

| Token  | Value | Usage                    |
| ------ | ----- | ------------------------ |
| `xs`   | 4pt   | Inline spacing           |
| `sm`   | 8pt   | Component internal       |
| `md`   | 12pt  | Between components       |
| `lg`   | 16pt  | Section spacing          |
| `xl`   | 24pt  | Screen edge padding      |

### 7.4 Corner Radius

| Element  | Radius |
| -------- | ------ |
| Cards    | 8pt    |
| Buttons  | 12pt   |
| Badges   | 4pt    |

### 7.5 Haptic Feedback

| Event                 | Haptic Type                    |
| --------------------- | ------------------------------ |
| Session launched      | `.success` (WKHapticType)      |
| Session completed     | `.notification`                |
| Session failed        | `.failure`                     |
| PR approved/merged    | `.success`                     |
| Button tap            | `.click`                       |
| Error                 | `.failure`                     |

### 7.6 Animations

| Animation           | Spec                                  |
| ------------------- | ------------------------------------- |
| Running agent pulse | 0.8s ease-in-out, opacity 0.6→1.0, ∞ |
| Screen transitions  | `.slide` (default NavigationStack)    |
| Status change       | `.easeInOut(duration: 0.3)`           |
| Terminal text       | Append with `.transition(.opacity)`   |

### 7.7 SF Symbols Mapping

| Concept           | SF Symbol                     |
| ----------------- | ----------------------------- |
| Copilot / AI      | `sparkles`                    |
| Terminal / Session | `terminal`                    |
| Repository        | `folder`                      |
| Branch            | `arrow.triangle.branch`       |
| Pull Request      | `arrow.triangle.pull`         |
| Success           | `checkmark.circle.fill`       |
| Failure           | `xmark.circle.fill`           |
| Running           | `circle.fill` (green)         |
| Pending           | `clock`                       |
| Cancel            | `stop.circle`                 |
| Settings          | `gearshape`                   |
| Voice dictation   | `mic.fill`                    |
| Send message      | `paperplane.fill`             |
| Merge             | `arrow.triangle.merge`        |
| Approve           | `hand.thumbsup.fill`          |
| Add / New         | `plus.circle.fill`            |

---

## 8. Reusable Components

### 8.1 StatusBadge

Displays session or CI status as a colored dot with label.

**Props:** `status: SessionStatus`

| Status     | Color    | Icon                        |
| ---------- | -------- | --------------------------- |
| `pending`  | Yellow   | `clock`                     |
| `running`  | Green    | `circle.fill` (pulsing)     |
| `completed`| Green    | `checkmark.circle.fill`     |
| `failed`   | Red      | `xmark.circle.fill`         |
| `cancelled`| Gray     | `stop.circle`               |

### 8.2 TerminalText

Monospace scrollable text view for agent output.

- Font: SF Mono 13pt
- Background: `#0d1117`
- Text color: `#e6edf3`
- Auto-scrolls to bottom on new content
- Max height: 60% of screen

### 8.3 TimelineEvent

A single row in an activity timeline.

- Left: colored dot (status color)
- Center: event description text
- Right: relative timestamp
- Inspired by GitHub CLI timeline output

### 8.4 CopilotButton

Branded action button with GitHub styling.

- Background: Copilot purple (`#bc8cff`) for primary
- Background: Surface (`#161b22`) for secondary
- Corner radius: 12pt
- Haptic feedback on tap

---

## 9. Phased Delivery

### Phase 1 — MVP (Current)

| Feature                  | Status      |
| ------------------------ | ----------- |
| Backend scaffold         | In Progress |
| GitHub Device Code auth  | Planned     |
| Agent session CRUD API   | Planned     |
| Copilot SDK integration  | Planned     |
| Repository listing API   | Planned     |
| Watch auth flow UI       | Planned     |
| Watch home screen        | Planned     |
| Watch session list       | Planned     |
| Watch session detail     | Planned     |
| Watch new session        | Planned     |
| Watch settings           | Planned     |

### Phase 2 — PR Review & Approval

- PR list and detail API endpoints
- AI-generated PR summary (via Copilot SDK)
- PR review submission (approve/request changes/comment)
- PR merge from Watch
- CI status display
- Watch PR list and detail screens

### Phase 3 — Code on the Go

- Task template CRUD API
- Launch agent from GitHub issue
- Launch agent from saved template
- File diff viewer (simplified for Watch)
- Quick action buttons ("Fix this issue", "Add tests", etc.)

### Phase 4 — Notifications & Complications

- APNs push notification service
- Device registration endpoint
- Push on: agent complete, PR needs review, CI failure
- watchOS Complications (active agent count, latest PR status)
- Background app refresh (every 5 minutes)

### Phase 5 — Persistence & Polish

- Replace in-memory store with PostgreSQL/SQLite
- Offline mode (cache last-known state, queue actions)
- Token refresh flow
- Advanced settings (default repo, model preference)
- Performance optimization (< 2s API response time)

---

## 10. Non-Functional Requirements

### 10.1 Security

| Requirement                 | Implementation                             |
| --------------------------- | ------------------------------------------ |
| Token storage               | watchOS Keychain (encrypted at rest)        |
| Transport security          | HTTPS only (TLS 1.3)                       |
| Token handling              | Never logged, never stored server-side      |
| Auth token refresh          | Phase 5 (manual re-auth for MVP)           |
| CORS                        | Restricted to known origins                |
| Rate limiting               | Respect GitHub API rate limits (5000/hr)   |

### 10.2 Performance

| Metric                      | Target                                     |
| --------------------------- | ------------------------------------------ |
| API response time           | < 2 seconds (p95)                          |
| Watch app launch            | < 1 second to interactive                  |
| Session creation            | < 3 seconds to first event                 |
| Polling overhead            | < 1KB per poll response (when no changes)  |

### 10.3 Accessibility

| Requirement                 | Implementation                             |
| --------------------------- | ------------------------------------------ |
| VoiceOver                   | All interactive elements labeled            |
| Dynamic Type                | All text scales with system setting          |
| Contrast ratios             | WCAG AA minimum (4.5:1 for text)           |
| Haptic feedback             | Accompanies all status changes              |
| Reduce Motion               | Respect system setting, disable pulse anim |

### 10.4 Reliability

| Requirement                 | Implementation                             |
| --------------------------- | ------------------------------------------ |
| Graceful degradation        | Show cached data when offline (Phase 5)    |
| Error display               | User-friendly error messages on Watch      |
| Retry logic                 | Automatic retry (3x) for transient failures|
| Health check                | `GET /api/health` endpoint                 |

---

## 11. File Structure Summary

```
github-copilot-dispatch/
├── README.md
├── specs/
│   └── v1-spec.md                        # This document
├── copilot-dispatch-backend/
│   ├── src/
│   │   ├── index.ts
│   │   ├── config/
│   │   │   └── index.ts
│   │   ├── routes/
│   │   │   ├── auth.ts
│   │   │   ├── sessions.ts
│   │   │   └── repos.ts
│   │   ├── services/
│   │   │   ├── copilot.ts
│   │   │   ├── github.ts
│   │   │   └── sessionStore.ts
│   │   ├── middleware/
│   │   │   ├── auth.ts
│   │   │   └── error.ts
│   │   └── types/
│   │       └── index.ts
│   ├── Dockerfile
│   ├── package.json
│   ├── tsconfig.json
│   └── .env.example
└── CopilotDispatch/
    ├── Package.swift
    ├── Sources/
    │   ├── App/
    │   │   └── CopilotDispatchApp.swift
    │   ├── Models/
    │   │   ├── Session.swift
    │   │   └── Repository.swift
    │   ├── Views/
    │   │   ├── HomeView.swift
    │   │   ├── AuthView.swift
    │   │   ├── SessionListView.swift
    │   │   ├── SessionDetailView.swift
    │   │   ├── NewSessionView.swift
    │   │   └── SettingsView.swift
    │   ├── ViewModels/
    │   │   ├── AuthViewModel.swift
    │   │   ├── SessionsViewModel.swift
    │   │   └── NewSessionViewModel.swift
    │   ├── Services/
    │   │   ├── APIClient.swift
    │   │   └── KeychainManager.swift
    │   ├── Components/
    │   │   ├── StatusBadge.swift
    │   │   ├── TimelineEvent.swift
    │   │   ├── TerminalText.swift
    │   │   └── CopilotButton.swift
    │   └── Theme/
    │       ├── GitHubColors.swift
    │       └── GitHubTypography.swift
    └── Assets.xcassets/
        └── Contents.json
```

---

## 12. Open Questions

1. **Copilot SDK stability:** The SDK is in technical preview — API may change. Plan for adapter pattern to isolate SDK changes.
2. **Model selection:** Should the Watch expose model choice to users, or use a backend default?
3. **Session limits:** How many concurrent sessions per user? (Likely limited by Copilot subscription tier.)
4. **PR merge protection:** Should we require CI checks to pass before allowing merge from Watch?
5. **Offline queuing (Phase 5):** Which actions should be queueable offline? (New session, PR review, cancel?)
