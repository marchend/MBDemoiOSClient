# Bootstrap Plan — AcmeBank iOS

## In scope (this PR)

### Project name + tech stack
- **App name:** AcmeBank
- **Platform:** iOS 17+, Swift 5.10, SwiftUI
- **Architecture:** MVVM + Coordinator (NavigationStack) — skeleton only
- **Project files:** XcodeGen (`project.yml`) — never a hand-crafted `.pbxproj`
- **Test framework:** XCTest (unit) in `AcmeBankTests`
- **Minimum Xcode:** 16.0
- **Bundle ID:** `com.acmebank.mobile`

### Directory structure (bootstrap only)

```
AcmeBank/
├── App/
│   └── AcmeBankApp.swift          # @main SwiftUI App entry (WindowGroup)
├── ContentView.swift              # Hello World placeholder screen
└── Resources/
    └── Assets.xcassets/
        ├── Contents.json
        └── AppIcon.appiconset/
            └── Contents.json

AcmeBankTests/
└── AcmeBankTests.swift            # One trivial test (proves XCTest works)

project.yml                        # XcodeGen spec (sources glob — no hand-crafted pbxproj)
setup.sh                           # One-shot: brew install xcodegen && xcodegen generate && open .xcodeproj
.gitignore                         # Ignores generated .xcodeproj, DerivedData, .DS_Store, etc.
bootstrap_plan.md
CLAUDE.md
AGENT.md
README.md
AcmeBank/AcmeBank.entitlements     # Keychain access group stub
AcmeBank/PrivacyInfo.xcprivacy     # Privacy manifest stub
```

### Files this PR creates
Every file directly supports the Hello World (app launches, shows "AcmeBank" label):
- `project.yml` — XcodeGen spec for AcmeBank + AcmeBankTests targets
- `AcmeBank/App/AcmeBankApp.swift` — SwiftUI `@main` entry point
- `AcmeBank/ContentView.swift` — single `Text("AcmeBank")` screen
- `AcmeBank/Resources/Assets.xcassets/…` — asset catalog with AppIcon stub
- `AcmeBank/AcmeBank.entitlements` — Keychain access group boilerplate
- `AcmeBank/PrivacyInfo.xcprivacy` — privacy manifest
- `AcmeBankTests/AcmeBankTests.swift` — one XCTest proving the target links
- `setup.sh` — post-clone materialisation script
- `.gitignore` — standard iOS/XcodeGen ignore rules
- `CLAUDE.md` / `AGENT.md` — project context for agents (identical content)
- `README.md` — developer quick-start

### How to run locally
```bash
./setup.sh   # installs XcodeGen if missing, runs xcodegen generate, opens .xcodeproj in Xcode
```
Manual fallback:
```bash
brew install xcodegen
xcodegen generate
open AcmeBank.xcodeproj
```

### How to run tests
In Xcode: ⌘U  
Or from terminal (after `xcodegen generate`):
```bash
xcodebuild test -scheme AcmeBank -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Definition of Hello World
The app launches in the iOS Simulator and displays a single SwiftUI screen with the text **"AcmeBank"** centred on screen. One XCTest passes, confirming `ContentView` initialises and the test target links correctly against the app module.

---

## Out of scope — deferred to future work

- **Okta OIDC Authentication** (`okta-mobile-swift` SDK, `AuthService`, `KeychainStore`, `UserSession`) — future PR
- **AppCoordinator / RootView / LoginCoordinator** (auth-state switching, NavigationStack routing) — future PR
- **Login feature** (`LoginView`, `LoginViewModel`, `LoginCoordinator`) — future PR
- **Home Dashboard feature** (`HomeView`, `HomeViewModel`, `HomeCoordinator`, sub-views) — future PR
- **Accounts, Transfer, Cards features** — future PRs
- **Networking layer** (`APIClient`, `APIRouter`, `APIError`, `RequestInterceptor`) — future PR
- **Domain models** (`Account`, `Transaction`, `Customer`, `TransferRequest`) — future PR
- **Repository protocols** (`AccountRepositoryProtocol`, etc.) — future PR
- **Remote API repositories** (`AccountAPIRepository`, etc.) — future PR
- **Mock data repositories** (`MockAccountRepository`, etc.) — future PR
- **Design system** (`Colors.swift`, `Typography.swift`, `Assets.xcassets` tokens) — future PR
- **Internal notifications** (`AppNotification`, `NotificationPublisher`, `NotificationKey`) — future PR
- **XCUITest target & flows** (Login, Transfer, sign-out end-to-end) — future PR
- **SwiftLint** (`.swiftlint.yml`, CI `-warnings-as-errors` xcconfig) — future PR
- **CI/CD workflow** (`ios-build.yml`, xcconfig injection of `API_BASE_URL` / Okta config) — future PR
- **Okta.plist / Okta.plist.example** — future PR (alongside AuthService)
- **`Core/` layer** (extensions: `Decimal+Currency`, `Date+Greeting`, `String+Initials`) — future PR
- **TabBarCoordinator**, **MoreCoordinator**, **CardsCoordinator**, **TransferCoordinator** — future PRs
