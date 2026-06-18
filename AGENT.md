# AcmeBank iOS — Project Context

## Overview
AcmeBank is an iOS 17+ banking app built with Swift 5.10 and SwiftUI. It will
let customers view accounts, review transactions, initiate transfers, and manage
cards — backed by Okta OIDC authentication and a REST BFF API. This repo contains
only the bootstrap scaffold today; all feature work follows in separate PRs.

## Tech Stack
| Item | Value |
|---|---|
| Platform | iOS 17+ |
| Language | Swift 5.10 |
| UI Framework | SwiftUI |
| Architecture | MVVM + Coordinator (SwiftUI `NavigationStack`) |
| Auth | Okta OIDC via `okta-mobile-swift` (deferred) |
| Networking | `URLSession` + async/await (deferred) |
| Dependency Injection | Constructor injection; no service locator |
| Project files | XcodeGen (`project.yml`) — never hand-craft `.pbxproj` |
| Test framework | XCTest (unit) + XCUITest (UI, deferred) |
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

## Key Directory Structure
```
project.yml                  # XcodeGen spec — source of truth for the project
setup.sh                     # Post-clone one-shot materialisation
AcmeBank/
├── App/
│   └── AcmeBankApp.swift    # @main SwiftUI entry (implemented)
├── ContentView.swift        # Hello World placeholder (implemented)
├── Resources/
│   └── Assets.xcassets/     # AppIcon stub (implemented)
├── AcmeBank.entitlements    # Keychain access group boilerplate (implemented)
└── PrivacyInfo.xcprivacy    # Privacy manifest (implemented)
AcmeBankTests/
└── AcmeBankTests.swift      # Bootstrap smoke test (implemented)

# Planned (not yet created — added by feature PRs):
AcmeBank/
├── App/
│   ├── RootView.swift       # auth-state switcher (deferred)
│   └── AppCoordinator.swift # root coordinator (deferred)
├── Core/Auth/               # AuthService, KeychainStore, UserSession (deferred)
├── Core/Networking/         # APIClient, APIRouter, APIError, RequestInterceptor (deferred)
├── Core/Notifications/      # AppNotification, NotificationPublisher (deferred)
├── Core/Extensions/         # Decimal+Currency, Date+Greeting, String+Initials (deferred)
├── Domain/Models/           # Account, Transaction, Customer, TransferRequest (deferred)
├── Domain/Repositories/     # Protocol definitions (deferred)
├── Data/Remote/             # API repository implementations (deferred)
├── Data/Mock/               # Mock repository implementations (deferred)
├── Features/Login/          # LoginView, LoginViewModel, LoginCoordinator (deferred)
├── Features/Home/           # HomeView, HomeViewModel, HomeCoordinator (deferred)
├── Features/Accounts/       # (deferred)
├── Features/Transfer/       # (deferred)
├── Features/Cards/          # (deferred)
└── DesignSystem/            # Colors, Typography, Assets (deferred)
AcmeBankTests/
├── Core/Auth/               # AuthServiceTests (deferred)
├── Features/Login/          # LoginViewModelTests (deferred)
└── Features/Home/           # HomeViewModelTests (deferred)
AcmeBankUITests/             # XCUITest target for critical flows (deferred)
```

## Planned Architecture (from spec)

### MVVM + Coordinator (SwiftUI NavigationStack)
- **View** — SwiftUI `View` struct; renders `@Published` state; zero business logic. *(deferred)*
- **ViewModel** — `final class: ObservableObject`; holds `@Published` state; calls repos; posts
  `AppNotification`s; no SwiftUI imports. *(deferred)*
- **Coordinator** — `ObservableObject`; owns `NavigationPath`; creates child View+VM pairs;
  drives push/sheet/fullScreenCover declaratively. *(deferred)*
- **Repository protocols** — `Domain/`; concrete implementations in `Data/`. *(deferred)*

### Coordinator tree *(deferred)*
```
AppCoordinator
  └── LoginCoordinator   (full-screen, no session)
  └── TabBarCoordinator  (root TabView after login)
        ├── HomeCoordinator
        ├── TransferCoordinator
        ├── CardsCoordinator
        └── MoreCoordinator
```

### Authentication — Okta OIDC *(deferred)*
`AuthService` → browser-based OIDC → decode ID-token claims → persist tokens
via `KeychainStore` → return `UserSession`. `RequestInterceptor` refreshes
tokens before every network request; expired session posts
`AppNotification.sessionExpired`.

**Keychain note:** all `SecItem*` calls MUST include
`kSecUseDataProtectionKeychain: true` to work in CI simulator builds
(`CODE_SIGNING_ALLOWED=NO`). The entitlements file covers signed-device
builds; the flag covers the simulator path.

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
- Okta OIDC authentication (`okta-mobile-swift` 2.x) — future PR
- AppCoordinator / RootView (auth-state switching) — future PR
- LoginCoordinator + Login feature — future PR
- Home Dashboard feature (BFF `GET /v1/home`, `HomeDashboard` model) — future PR
- Accounts, Transfer, Cards features — future PRs
- Networking layer (APIClient / APIRouter / APIError / RequestInterceptor) — future PR
- Domain models (Account, Transaction, Customer, TransferRequest) — future PR
- Repository protocols + remote + mock implementations — future PRs
- Design system tokens (Colors, Typography) — future PR
- Internal notification system (AppNotification, NotificationPublisher) — future PR
- XCUITest target + critical-flow UI tests — future PR
- SwiftLint (`.swiftlint.yml`) + CI `-warnings-as-errors` xcconfig — future PR
- CI/CD GitHub Actions workflow (`ios-build.yml`) — future PR
- `Okta.plist` / `Okta.plist.example` — future PR (alongside AuthService)
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
