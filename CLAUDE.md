# AcmeBank iOS — Project Context

## Overview
AcmeBank is an iOS 17+ banking app built with Swift 5.10 and SwiftUI. It will
let customers view accounts, review transactions, initiate transfers, and manage
cards — backed by Okta OIDC authentication and a REST BFF API. The login screen
UI is now implemented; auth integration and the rest of the feature set follow
in separate PRs.

## Tech Stack
| Item | Value |
|---|---|
| Platform | iOS 17+ |
| Language | Swift 5.10 |
| UI Framework | SwiftUI |
| Architecture | MVVM + Coordinator (SwiftUI `NavigationStack`) |
| Auth | Okta OIDC via `okta-mobile-swift` (`OktaDirectAuth`) |
| Networking | `URLSession` + async/await (deferred) |
| Dependency Injection | Constructor injection; no service locator |
| Project files | XcodeGen (`project.yml`) — never hand-craft `.pbxproj` |
| Test framework | XCTest (unit) + XCUITest (`AcmeBankUITests` target) |
| Minimum Xcode | 16.0 |
| Bundle ID | `com.acmebank.mobile` |

## How to Run Locally
```bash
./setup.sh   # installs XcodeGen if missing, generates .xcodeproj, opens in Xcode
```
Manual fallback:
```bash
brew install xcodegen
xcodegen generate
open AcmeBank.xcodeproj
```

## How to Run Tests
In Xcode: **⌘U**

From the terminal (after `xcodegen generate`):
```bash
xcodebuild test \
  -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Okta build configuration
The four `OKTA_*` shell env vars (`OKTA_ISSUER`, `OKTA_CLIENT_ID`,
`OKTA_REDIRECT_URI`, `OKTA_SCOPES`) are injected into `Info.plist` at build
time by `Scripts/inject_okta_config.sh` (a Run Script build phase ordered
after Copy Bundle Resources) and read at runtime by
`AcmeBank/Core/Config/OktaConfig.swift`. The build NEVER fails on missing
vars — the script writes `__OKTA_*_UNSET__` sentinels and `OktaConfig.load()`
returns `.notConfigured(reason:)`. UI tests additionally read
`OKTA_TEST_USERNAME` / `OKTA_TEST_PASSWORD` from `ProcessInfo` in the test
runner (NOT the app bundle). Full setup recipes + the `PhaseScriptExecution`
env-var caveat live in [README.md → Okta build configuration](README.md#okta-build-configuration).

## Key Directory Structure
```
project.yml                  # XcodeGen spec — source of truth for the project
setup.sh                     # Post-clone one-shot materialisation
Scripts/
└── inject_okta_config.sh    # Run Script build phase: env vars → Info.plist
AcmeBank/
├── App/
│   ├── AcmeBankApp.swift    # @main SwiftUI entry — builds AppCoordinator + RootView
│   ├── AppCoordinator.swift # Composition root: owns UserSession? + AuthServicing
│   └── RootView.swift       # Auth-state switcher: LoginView vs LandingView
├── Core/
│   ├── Auth/
│   │   ├── UserSession.swift       # Codable session value type (implemented)
│   │   ├── KeychainStore.swift     # SecItem wrapper, kSecUseDataProtectionKeychain (implemented)
│   │   ├── IDTokenDecoder.swift    # JWT payload decoder (implemented)
│   │   ├── AuthService.swift       # DirectAuth signIn + refresh-token grant (implemented)
│   │   └── AuthService+Okta.swift  # OktaDirectAuth adapter for DirectAuthFlow (implemented)
│   └── Config/
│       └── OktaConfig.swift # Runtime loader for Info.plist Okta keys
├── Theme/
│   └── AcmeBankTheme.swift  # Brand colors (acmeNavy #1B2A4A) + font helpers
├── Features/
│   ├── Landing/
│   │   └── LandingView.swift       # Post-sign-in welcome screen (UserSession-driven)
│   └── Login/
│       ├── LoginViewModel.swift    # ObservableObject form state + closures
│       ├── LoginView.swift         # Root login screen composing sub-views
│       └── Views/
│           ├── OktaHeaderView.swift     # Top domain-indicator strip
│           ├── AcmeBankLogoView.swift   # Hexagonal navy logo with "A"
│           ├── ErrorBannerView.swift    # Inline error banner (nil = hidden)
│           ├── OktaFooterView.swift     # "Secured by Okta" footer strip
│           └── OpenAccountPlaceholderView.swift  # "Coming soon" stub
├── Resources/
│   └── Assets.xcassets/     # AppIcon stub (implemented)
├── AcmeBank.entitlements    # Keychain access group boilerplate (implemented)
└── PrivacyInfo.xcprivacy    # Privacy manifest (implemented)
AcmeBankTests/
├── AcmeBankTests.swift      # Bootstrap smoke test (implemented)
├── App/
│   ├── AppCoordinatorTests.swift   # Cold-launch refresh paths + signOut
│   └── RootViewTests.swift         # Auth-state branch rendering
├── Core/
│   ├── Auth/
│   │   ├── UserSessionTests.swift     # Codable round-trip + equality
│   │   ├── KeychainStoreTests.swift   # Store/load/clear + data-protection flag
│   │   ├── IDTokenDecoderTests.swift  # JWT decode happy + rejection paths
│   │   └── AuthServiceTests.swift     # signIn + refresh with injected fakes
│   └── Config/
│       └── OktaConfigTests.swift # Unit tests for OktaConfig.load
└── Features/
    ├── Landing/
    │   └── LandingViewTests.swift     # Display name + email render contract
    └── Login/
        ├── LoginViewModelTests.swift    # Unit tests for ViewModel logic
        └── LoginViewSnapshotTests.swift # Structural render tests (UIHostingController)
AcmeBankUITests/
├── AcmeBankUITestsHelpers.swift       # oktaIsConfigured() + OKTA_TEST_* env reads
├── SignInToLandingUITests.swift       # End-to-end sign-in → LandingView (skipped when unconfigured)
└── NotConfiguredBannerUITests.swift   # Tap Sign In → "Okta is not configured" banner

# Planned (not yet created — added by feature PRs):
AcmeBank/
├── Core/Networking/         # APIClient, APIRouter, APIError, RequestInterceptor (deferred)
├── Core/Notifications/      # AppNotification, NotificationPublisher (deferred)
├── Core/Extensions/         # Decimal+Currency, Date+Greeting, String+Initials (deferred)
├── Domain/Models/           # Account, Transaction, Customer, TransferRequest (deferred)
├── Domain/Repositories/     # Protocol definitions (deferred)
├── Data/Remote/             # API repository implementations (deferred)
├── Data/Mock/               # Mock repository implementations (deferred)
├── Features/Home/           # HomeView, HomeViewModel, HomeCoordinator (deferred)
├── Features/Accounts/       # (deferred)
├── Features/Transfer/       # (deferred)
└── Features/Cards/          # (deferred)
AcmeBankTests/
└── Features/Home/           # HomeViewModelTests (deferred)
```

## Planned Architecture (from spec)

### MVVM + Coordinator (SwiftUI NavigationStack)
- **View** — SwiftUI `View` struct; renders `@Published` state; zero business logic.
- **ViewModel** — `final class: ObservableObject`; holds `@Published` state; calls repos; posts
  `AppNotification`s; no SwiftUI imports.
- **Coordinator** — `ObservableObject`; owns `NavigationPath`; creates child View+VM pairs;
  drives push/sheet/fullScreenCover declaratively. The top-level `AppCoordinator`
  is implemented (auth-state switcher); feature coordinators are *(deferred)*.
- **Repository protocols** — `Domain/`; concrete implementations in `Data/`. *(deferred)*

### Composition root (PR 4)
- `AcmeBankApp` builds the `AppCoordinator` once at launch via `@StateObject`,
  passing `OktaConfig.load()`, a real `AuthService` (or `nil` on the
  `.notConfigured` build path), and a shared `KeychainStore`.
- `AppCoordinator` is `@MainActor`-isolated and owns
  `@Published var session: UserSession?`. On init, if `.configured` AND
  `KeychainStore.loadRefreshToken()` returns non-nil, it kicks off a
  cold-launch `Task` that calls `authService.refresh(refreshToken:)` and
  assigns the result to `session`. Failure leaves `session == nil` and
  the app shows `LoginView`.
- `RootView` is the only place in the project that switches on
  `coordinator.session`. `nil` → `LoginView` (wired with the coordinator's
  `AuthServicing` + `OktaConfig`; `onAuthenticated` writes the session
  back to the coordinator). Non-nil → `LandingView(session:)`.
- `LandingView` is a deliberately minimal welcome screen that renders
  `Welcome, {session.displayName}` and `session.email` with accessibility
  identifiers `welcomeGreeting` / `welcomeEmail` — the same identifiers
  the XCUITest end-to-end test in `AcmeBankUITests` queries.

### Login screen (UI in PR 1; AuthService wiring in PR 3)
- `LoginViewModel` — pure Swift, no SwiftUI import. `@Published` properties: `username`,
  `password`, `keepSignedIn`, `isPasswordVisible`, `errorMessage`, `isSigningIn`.
  Computed `isSignInEnabled`. Constructor-injects `AuthServicing?` (nil on the
  `.notConfigured` build path), `OktaConfig`, and `onAuthenticated: (UserSession) -> Void`.
  Closure injection: `onNeedHelp()`. `signInTapped()` launches `performSignIn()` —
  which guards `.configured`, then guards `!isSigningIn`, calls
  `authService.signIn(...)`, and on success invokes `onAuthenticated(session)`.
  `AuthError` cases map to verbatim user-facing copy in one private static
  table (`invalidCredentials` → "Incorrect username or password. Please try
  again.", `network` → "Couldn't reach Okta — check your connection and try
  again.", `mfaRequired` → "MFA is required but not supported in this build.").
  Editing `username` or `password` clears `errorMessage` (via `didSet`
  delegating to `usernameDidChange()` / `passwordDidChange()`).
- `LoginView` — accepts injected `LoginViewModel` via `init(viewModel:)` for testability;
  wraps content in `NavigationStack`; composes `OktaHeaderView` + scroll body + `OktaFooterView`.
  Username / password `TextField`s and the Sign-In button are `.disabled(viewModel.isSigningIn)`;
  the button label is swapped for a `ProgressView` while `isSigningIn`.
- Brand color `Color.acmeNavy` = `#1B2A4A` defined in `AcmeBank/Theme/AcmeBankTheme.swift`.

### Coordinator tree *(below AppCoordinator is deferred)*
```
AppCoordinator          (implemented — auth-state switcher)
  └── LoginView         (no session)
  └── LandingView       (session present; TabBarCoordinator lands later)
```

### Authentication — Okta OIDC (Core/Auth integration layer implemented in PR 2)
- `AuthServicing` protocol exposes `signIn(username:password:keepSignedIn:)` and
  `refresh(refreshToken:)`. UI calls go through this protocol — never the SDK directly.
- `AuthService` uses `OktaDirectAuth.DirectAuthenticationFlow` via the
  `DirectAuthFlow` seam: `flow.start(username, with: .password(password))`
  (no `.primary(...)` wrapper). Refresh-token grant hits Okta's
  `<issuer>/v1/token` endpoint via a `TokenRefreshTransport` seam (default
  `URLSession.shared`).
- `IDTokenDecoder` decodes the JWT payload (no signature verification —
  out of scope; the IdP/SDK has already validated it).
- `KeychainStore` writes `id_token`, `access_token`, `refresh_token` under
  the same service identifier. **Every** `SecItem*` call includes
  `kSecUseDataProtectionKeychain: true` so the simulator (CI,
  `CODE_SIGNING_ALLOWED=NO`) can read/write items; the entitlements file
  covers signed-device builds.
- Refresh token is persisted **iff** `keepSignedIn == true`. On any
  refresh-grant failure, AuthService clears the keychain so a stale
  refresh token doesn't keep retrying.
- Post-success failures (JWT decode, keychain write) are typed: keychain
  writes are best-effort (cache miss), JWT decode failures map to
  `AuthError.unknown`. **Never** let a `KeychainError` or
  `IDTokenDecoder.DecodeError` escape `signIn` as an untyped error — the
  UI's `catch let e as AuthError` would miss it and show a misleading
  network-error banner even though Okta succeeded.

### Networking *(deferred)*
`APIClient` wraps `URLSession` with `async/await`; decodes with
`.convertFromSnakeCase` + `.iso8601`; maps HTTP errors to typed `APIError`.
Base URL read from `Info.plist` key `API_BASE_URL` (injected by CI xcconfig).

### Internal notifications *(deferred)*
`NotificationCenter` with typed `AppNotification` names. Subscribe only in
coordinators/root views — never inside a ViewModel.

### Design system *(deferred)*
`DesignSystem/Colors.swift` (named `Color` extensions), `Typography.swift`
(named `Font` extensions). All fonts must scale with Dynamic Type.

## Deferred Work
- LoginCoordinator (NavigationPath) — future PR
- Home Dashboard feature (BFF `GET /v1/home`, `HomeDashboard` model) — future PR
- Accounts, Transfer, Cards features — future PRs
- Networking layer (APIClient / APIRouter / APIError / RequestInterceptor) — future PR
- Domain models (Account, Transaction, Customer, TransferRequest) — future PR
- Repository protocols + remote + mock implementations — future PRs
- Internal notification system (AppNotification, NotificationPublisher) — future PR
- SwiftLint (`.swiftlint.yml`) + CI `-warnings-as-errors` xcconfig — future PR
- CI/CD GitHub Actions workflow (`ios-build.yml`) — future PR
- Core extensions (Decimal+Currency, Date+Greeting, String+Initials) — future PR
- TabBarCoordinator, MoreCoordinator, CardsCoordinator, TransferCoordinator — future PRs

## Git Workflow

> **Default PR target branch: `develop`.** Every feature/refactor/docs PR
> opens against `develop`. PRs are only opened against `qa`, `uat`, or
> `main` for explicit promotion PRs.

**Branch model (`develop` → `qa` → `uat` → `main`):**

| Branch  | Role                                 | Receives PRs from              | Promotes to |
|---------|--------------------------------------|--------------------------------|-------------|
| develop | Default integration branch           | feature branches               | qa          |
| qa      | First quality gate                   | develop (promotion PR)         | uat         |
| uat     | Pre-prod acceptance                  | qa (promotion PR)              | main        |
| main    | Production / release tags            | uat (promotion PR)             | tagged only |

All feature PRs MUST target `develop`. Never open a feature PR against
`qa`, `uat`, or `main`. Promotions happen via dedicated promotion PRs.
