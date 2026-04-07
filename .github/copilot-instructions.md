# Copilot Instructions

## Architecture

This is an Apple Watch app backed by a Node.js server that provides access to GitHub Copilot's coding agent.

```
Apple Watch (SwiftUI) → REST polling → Express/TS backend → @github/copilot-sdk → GitHub API
```

**Two independent codebases live in one repo:**

- `CopilotDispatch/` — Swift 6 watchOS 11 app (SwiftPM, no external deps)
- `copilot-dispatch-backend/` — Node.js 22 + Express 5 + TypeScript 5.8

The Watch app polls the backend at short intervals (3–5s active, 30s idle). The backend holds sessions in memory (no database). The Copilot SDK requires `--experimental-sqlite` at runtime.

## Backend (`copilot-dispatch-backend/`)

### Commands

```bash
cd copilot-dispatch-backend
npm run dev      # tsx watch with --experimental-sqlite
npm run build    # tsc
npm run start    # node --experimental-sqlite --env-file=.env dist/index.js
npm run lint     # eslint src/
npm run clean    # rm -rf dist/
```

No test runner is configured.

### Key conventions

- **ES Modules throughout** — `"type": "module"` in package.json, `NodeNext` module resolution. Local imports use `.js` extensions even in `.ts` source files.
- **Config** (`src/config/index.ts`) — reads env vars with fallback defaults; no validation. Missing GitHub OAuth creds trigger dev/mock mode automatically.
- **Error handling** — `AppError` class + centralized `errorHandler` middleware. Routes use `try/catch` with `next(error)`. Auth routes are an exception: they return JSON errors directly.
- **Auth middleware** — validates `Authorization: Bearer <token>` against GitHub API, then sets `req.user` and `req.token` on the Express request.
- **Session IDs** — prefixed `sess_` + truncated UUID.
- **API response fields** — always camelCase, even when wrapping GitHub's snake_case API.
- **Copilot SDK** — loaded dynamically. If unavailable, the backend falls back to mock sessions with simulated progress events. This is intentional for local dev.
- **Routes** are thin wrappers; business logic lives in `src/services/`. The `pulls` router uses `mergeParams: true` and mounts under `/api/repos/:owner/:repo/pulls`.

### Environment variables

Required: `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`
Optional: `GH_TOKEN` (dev fallback), `PORT` (default 3001), `BASE_URL`, `NODE_ENV`

## Watch App (`CopilotDispatch/`)

### Build

Open `CopilotDispatch/` in Xcode 16+, target a watchOS 11 simulator or device, ⌘R to build and run. This is a SwiftPM executable target, not an Xcode project with multiple targets.

### Key conventions

- **Observation framework, not Combine** — all view models use `@Observable` (not `ObservableObject`/`@Published`). Views bind with `@Bindable` or `@State`.
- **`@MainActor` on all view models** — ensures UI-state mutations are main-thread safe.
- **`APIClient` is an actor** — singleton (`APIClient.shared`) with actor isolation for thread-safe network state. All API methods are `async throws`.
- **Mixed MVVM** — `AuthViewModel`, `SessionsViewModel`, `NewSessionViewModel`, `PRListViewModel` are dedicated view models. Detail screens (`SessionDetailView`, `PRDetailView`) manage state directly with `@State` rather than a view model.
- **Polling** — implemented as long-running `Task` loops with `Task.sleep(for:)`. Started in `.task`/`.onAppear`, cancelled in `.onDisappear`.
- **Naming** — `*Model` for domain types, `*ViewModel` for view models, `*View` for screens, `*Response`/`*Request` for API DTOs.
- **Theme system** — `GitHubColors`, `GitHubTypography`, `GitHubSpacing` constants. Always use these instead of raw colors/fonts. Dark theme is default.
- **Error handling** — typed errors (`APIError`, `KeychainError`) in the service layer. Views display `error.localizedDescription`. Non-fatal errors are often swallowed with retry affordance.
- **Keychain** — `KeychainManager.shared` stores the GitHub token with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

## Types

Both codebases define their own parallel type hierarchies. The backend's canonical types are in `src/types/index.ts`; the Watch app's are in `Sources/Models/`. Status enums and API shapes must stay in sync manually — there is no codegen.

## Deployment

- **Staging** — pushes to `develop/v1` or `staging` branch trigger deploy to Azure Web App (`copilot-dispatch-staging`)
- **Production** — pushes to `main` trigger deploy to Azure Web App (`copilot-dispatch-prod`)
- Both workflows build with `npm ci && npm run build`, then zip and deploy via `az webapp deploy`.

## Specs

`specs/v1-spec.md` and `specs/v1.1-spec.md` contain the full product specifications. Consult these when implementing new features to ensure alignment with the intended design.
