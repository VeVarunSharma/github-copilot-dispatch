# GitHub Copilot Dispatch

> GitHub Copilot's agentic capabilities on your wrist — an Apple Watch app for launching coding agent sessions, monitoring progress, and managing code on the go.

## Overview

GitHub Copilot Dispatch brings Copilot's AI coding agent to Apple Watch. Launch agent sessions with voice dictation, monitor real-time progress with a terminal-inspired UI, and manage your code workflow — all from your wrist.

### Key Features (MVP)
- 🤖 **Agent Sessions** — Launch Copilot coding agent sessions from your Watch
- 🔐 **GitHub Auth** — Secure Device Code Flow authentication (no browser needed on Watch)
- 📱 **Terminal UI** — CLI-inspired dark theme with real-time agent output
- 🗣️ **Voice Input** — Dictate coding tasks via Watch microphone
- 📊 **Live Status** — Real-time session status with polling updates

### Coming Soon
- PR Review & Approval
- Task Templates & Quick Actions
- Push Notifications & Complications
- Offline Mode

## Architecture

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
        │                                    ┌──────┴───────┐
        │                                    │  APNs        │
        └──── push notifications ────────────│  (Phase 4)   │
                                             └──────────────┘
```

The Watch app communicates with the backend via **short-interval polling** over HTTPS REST:

| Context               | Poll Interval | Endpoint                |
|-----------------------|---------------|-------------------------|
| Auth pending          | 5 seconds     | `POST /api/auth/poll-token` |
| Session list visible  | 5 seconds     | `GET /api/sessions`     |
| Active session detail | 3 seconds     | `GET /api/sessions/:id` |
| Idle / background     | 30 seconds    | `GET /api/sessions`     |

## Tech Stack

| Component  | Technology                            |
|------------|---------------------------------------|
| Watch App  | Swift 6, SwiftUI, watchOS 11+         |
| Backend    | Node.js 22, Express 5, TypeScript 5.8 |
| AI Engine  | `@github/copilot-sdk`                 |
| GitHub API | Octokit 4                             |
| Auth       | GitHub Device Code Flow               |
| Deployment | Docker                                |

## Project Structure

```
├── CopilotDispatch/                   # Apple Watch app (Swift Package)
│   ├── Package.swift
│   ├── Assets.xcassets/
│   └── Sources/
│       ├── App/
│       │   └── CopilotDispatchApp.swift
│       ├── Views/
│       │   ├── HomeView.swift
│       │   ├── AuthView.swift
│       │   ├── SessionListView.swift
│       │   ├── SessionDetailView.swift
│       │   ├── NewSessionView.swift
│       │   └── SettingsView.swift
│       ├── ViewModels/
│       │   ├── AuthViewModel.swift
│       │   ├── SessionsViewModel.swift
│       │   └── NewSessionViewModel.swift
│       ├── Models/
│       │   ├── Session.swift
│       │   └── Repository.swift
│       ├── Components/
│       │   ├── TerminalText.swift
│       │   ├── TimelineEvent.swift
│       │   ├── CopilotButton.swift
│       │   └── StatusBadge.swift
│       ├── Theme/
│       │   ├── GitHubColors.swift
│       │   └── GitHubTypography.swift
│       └── Services/
│           ├── APIClient.swift
│           └── KeychainManager.swift
├── copilot-dispatch-backend/          # Node.js backend
│   ├── package.json
│   ├── tsconfig.json
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── .env.example
│   └── src/
│       ├── index.ts                   # Express app entry point
│       ├── config/
│       │   └── index.ts
│       ├── routes/
│       │   ├── auth.ts                # Device Code Flow endpoints
│       │   ├── repos.ts               # Repository listing
│       │   └── sessions.ts            # Agent session CRUD
│       ├── services/
│       │   ├── copilot.ts             # Copilot SDK integration
│       │   ├── github.ts              # Octokit / GitHub API
│       │   └── sessionStore.ts        # In-memory session storage
│       ├── middleware/
│       │   ├── auth.ts                # Bearer token auth
│       │   └── error.ts              # Error handling & logging
│       └── types/
│           └── index.ts
└── specs/
    └── v1-spec.md                     # Full V1 specification
```

## Getting Started

> **Want to deploy to your Apple Watch?** See [DEPLOYMENT.md](DEPLOYMENT.md) for a complete step-by-step guide covering local deploy and App Store distribution.

### Prerequisites
- Node.js 22+
- Xcode 16+ with watchOS 11 SDK
- GitHub OAuth App (for Device Code Flow)
- GitHub Copilot subscription

### 1. Create a GitHub OAuth App
1. Go to **GitHub Settings → Developer Settings → OAuth Apps → New OAuth App**
2. Set **Application name:** `Copilot Dispatch`
3. Set **Homepage URL:** `http://localhost:3001`
4. Set **Callback URL:** `http://localhost:3001/api/auth/callback`
5. Enable **Device Flow** in the app settings
6. Note your **Client ID** and **Client Secret**

### 2. Backend Setup

```bash
cd copilot-dispatch-backend
cp .env.example .env
# Edit .env with your GitHub OAuth App credentials:
#   GITHUB_CLIENT_ID=your_client_id
#   GITHUB_CLIENT_SECRET=your_client_secret
npm install
npm run dev
```

The backend starts at `http://localhost:3001`. Verify with:

```bash
curl http://localhost:3001/api/health
# → {"status":"ok","service":"copilot-dispatch"}
```

### 3. Docker (Alternative)

```bash
cd copilot-dispatch-backend
docker compose up
```

### 4. Watch App Setup
1. Open `CopilotDispatch/` in Xcode
2. Select your Apple Watch or watchOS Simulator as the target device
3. Update the backend URL in `APIClient.swift` if not using localhost
4. Build and run (**⌘R**)

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/health` | No | Health check |
| `POST` | `/api/auth/device-code` | No | Start device code flow |
| `POST` | `/api/auth/poll-token` | No | Poll for auth token |
| `GET` | `/api/auth/user` | Yes | Get authenticated user |
| `GET` | `/api/repos` | Yes | List user repositories |
| `POST` | `/api/sessions` | Yes | Create agent session |
| `GET` | `/api/sessions` | Yes | List sessions |
| `GET` | `/api/sessions/:id` | Yes | Get session detail |
| `POST` | `/api/sessions/:id/send` | Yes | Send follow-up message |
| `DELETE` | `/api/sessions/:id` | Yes | Cancel session |

## Design System

Built on GitHub's Primer Design System adapted for watchOS:
- **Dark theme** default (matches Copilot CLI aesthetic)
- **SF Mono** for terminal output
- **Primer color tokens** for consistent GitHub branding
- **Haptic feedback** for status changes

## Development

### Backend

```bash
npm run dev    # Start with hot reload (tsx watch)
npm run build  # Compile TypeScript
npm run start  # Run compiled output
npm run lint   # Run ESLint
npm run clean  # Remove dist/
```

### Watch App

Open `CopilotDispatch/` in Xcode, select a watchOS simulator or device, and build and run.

## License

MIT
