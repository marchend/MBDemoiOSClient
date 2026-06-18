# AcmeBank iOS

An iOS 17+ banking app built with Swift 5.10 and SwiftUI.  
This repository currently contains the **bootstrap scaffold** — a runnable Hello World shell. All features are in upcoming PRs.

## Quick Start

```bash
git clone <repo>
cd <repo>
./setup.sh
```

`setup.sh` installs [XcodeGen](https://github.com/yonaskolb/XcodeGen) (via Homebrew if missing), generates `AcmeBank.xcodeproj` from `project.yml`, and opens it in Xcode.

**Manual fallback** (for environments that block shell scripts):
```bash
brew install xcodegen
xcodegen generate
open AcmeBank.xcodeproj
```

## Running Tests

In Xcode: **⌘U**

From the terminal:
```bash
xcodebuild test \
  -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Project File Model

`AcmeBank.xcodeproj` is a **generated artifact** — never commit it. The source of truth is `project.yml`. After any change to `project.yml`, regenerate with:
```bash
xcodegen generate
```

## Tech Stack
- **Platform:** iOS 17+, Swift 5.10
- **UI:** SwiftUI (`@main` App + `WindowGroup`)
- **Architecture:** MVVM + Coordinator (SwiftUI `NavigationStack`) — wired in upcoming PRs
- **Auth:** Okta OIDC (`okta-mobile-swift`) — upcoming PR
- **Networking:** `URLSession` + async/await — upcoming PR
- **Tests:** XCTest (unit) · XCUITest (UI, upcoming PR)
- **Lint:** SwiftLint — upcoming PR

See [CLAUDE.md](CLAUDE.md) for full architecture notes and the deferred work list.
