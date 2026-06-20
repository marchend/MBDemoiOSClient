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

## Okta build configuration

The app reads its Okta OIDC configuration AND the BFF base URL from
`Info.plist` at runtime via `OktaConfig.load()` and
`APIBaseURLProvider.load()` respectively. Those `Info.plist` values are
**injected at build time** by `Scripts/inject_okta_config.sh` (an Xcode Run
Script build phase, ordered after Copy Bundle Resources) which reads five
shell environment variables and writes either the real value or a
recognisable `__*_UNSET__` sentinel.

### Required environment variables

| Env var             | Info.plist key    | Example                                       |
|---------------------|-------------------|-----------------------------------------------|
| `OKTA_ISSUER`       | `OktaIssuer`      | `https://acme.okta.com/oauth2/default`        |
| `OKTA_CLIENT_ID`    | `OktaClientID`    | `0oa1234567890abcdef`                         |
| `OKTA_REDIRECT_URI` | `OktaRedirectURI` | `com.acmebank.mobile:/callback`               |
| `OKTA_SCOPES`       | `OktaScopes`      | `openid profile offline_access`               |
| `API_BASE_URL`      | `API_BASE_URL`    | `https://bff.acmebank.com/`                   |

The build does NOT fail when these vars are unset — the script writes
sentinel strings instead. At runtime, `OktaConfig.load()` returns
`.notConfigured(reason:)` and `APIBaseURLProvider.load()` throws
`APIError.invalidConfiguration` at the first request. CI gates against the
sentinels separately.

### Three ways to make Xcode see the vars

Xcode's `PhaseScriptExecution` runs build-phase scripts with the **calling
process's environment** — so where you set the vars depends on how you
launched Xcode.

**1. GUI-launched Xcode (Spotlight / Dock):** set them with `launchctl
setenv` so the LaunchServices-spawned Xcode inherits them. These persist
until reboot (use a LaunchAgent for permanence):

```bash
launchctl setenv OKTA_ISSUER       'https://acme.okta.com/oauth2/default'
launchctl setenv OKTA_CLIENT_ID    '0oa1234567890abcdef'
launchctl setenv OKTA_REDIRECT_URI 'com.acmebank.mobile:/callback'
launchctl setenv OKTA_SCOPES       'openid profile offline_access'
launchctl setenv API_BASE_URL      'https://bff.acmebank.com/'
```

**2. Shell-launched Xcode (`~/.zshrc` + `xed .`):** export the vars in
your shell rc, then open Xcode from that shell so it inherits the env:

```bash
# ~/.zshrc
export OKTA_ISSUER='https://acme.okta.com/oauth2/default'
export OKTA_CLIENT_ID='0oa1234567890abcdef'
export OKTA_REDIRECT_URI='com.acmebank.mobile:/callback'
export OKTA_SCOPES='openid profile offline_access'
export API_BASE_URL='https://bff.acmebank.com/'

# then, in a fresh shell:
xed .
```

**3. `xcodebuild` from CI or terminal:** export the vars in the same
shell that invokes `xcodebuild` (e.g. as `env:` keys in a GitHub Actions
job, or secrets piped via `export`):

```bash
export OKTA_ISSUER='...'
export OKTA_CLIENT_ID='...'
export OKTA_REDIRECT_URI='...'
export OKTA_SCOPES='...'
export API_BASE_URL='...'
xcodebuild build -scheme AcmeBank -destination 'platform=iOS Simulator,name=iPhone 16'
```

> **PhaseScriptExecution env-var caveat:** xcconfig `$(VAR)` references do
> NOT interpolate shell env — they chain other Xcode build settings, so
> the obvious-looking xcconfig path silently ships an app with empty
> values. The Run Script phase is the only path that bridges shell env
> → Info.plist reliably.

## Running UI tests locally with real Okta credentials

The XCUITest target `AcmeBankUITests` (declared in `project.yml`, source
files arrive in a later PR) drives the login flow against the real Okta
tenant. It reads two additional env vars from `ProcessInfo` at test time:

| Env var               | Purpose                              |
|-----------------------|--------------------------------------|
| `OKTA_TEST_USERNAME`  | Test-account username to type in     |
| `OKTA_TEST_PASSWORD`  | Test-account password to type in     |

Run from the terminal (with all build vars exported — the five from
above PLUS the two test vars):

```bash
export OKTA_ISSUER='...'
export OKTA_CLIENT_ID='...'
export OKTA_REDIRECT_URI='...'
export OKTA_SCOPES='...'
export API_BASE_URL='...'
export OKTA_TEST_USERNAME='test.user@example.com'
export OKTA_TEST_PASSWORD='...'

xcodebuild test \
  -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AcmeBankUITests
```

When the test env vars are unset the UI tests `XCTSkip` themselves
rather than fail — local dev builds without credentials still pass.

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
- **Networking:** `URLSession` + async/await via `APIClient` (Core/Networking, implemented)
- **Tests:** XCTest (unit) · XCUITest (UI, upcoming PR)
- **Lint:** SwiftLint — upcoming PR

See [CLAUDE.md](CLAUDE.md) for full architecture notes and the deferred work list.
