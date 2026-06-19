#!/bin/bash
#
# inject_okta_config.sh
#
# Xcode Run Script build phase that bridges shell environment variables into
# the built app's Info.plist. Reads the four OKTA_* env vars plus API_BASE_URL
# from the calling process and writes either the real value or a recognisable
# sentinel into ${INFOPLIST_PATH} via PlistBuddy (upsert: Set, else Add).
#
# This script NEVER `exit 1`s on missing vars — an unconfigured developer build
# must still compile and run, surfacing the misconfiguration at runtime via
# `OktaConfig.load()` / `APIBaseURLProvider.load()` returning a "not
# configured" result. CI gates against the sentinels separately.
#
# Why PlistBuddy and not `plutil -replace`:
#   The source Info.plist (AcmeBank/Info.plist) declares API_BASE_URL with a
#   sentinel default but does NOT pre-declare the four Okta keys. Xcode copies
#   the source plist to ${TARGET_BUILD_DIR}/${INFOPLIST_PATH} and we Set-or-Add
#   here. `plutil -replace` exits non-zero when the key is missing — which
#   (combined with the trailing `exit 0` below) would silently swallow the
#   failure, leaving the app with no Okta keys in `infoDictionary` and
#   `OktaConfig.load()` returning a misleading "Missing Info.plist key…"
#   diagnostic. PlistBuddy's `Set` upserts when we fall back to `Add` on the
#   missing-entry branch, so every injected key is guaranteed to exist after
#   this script runs.
#
# Build-phase ordering: this is wired as a `postBuildScripts` entry in
# project.yml, which Xcode runs after the standard build phases (including
# Copy Bundle Resources) — i.e. once `${TARGET_BUILD_DIR}/${INFOPLIST_PATH}`
# exists on disk, which is the moment we need it.
#
# Caveat: Xcode passes the calling process's environment to PhaseScriptExecution.
# A var set in `~/.zshrc` only reaches Xcode if Xcode was launched from that
# shell (e.g. `xed .`). For Finder-launched Xcode, use `launchctl setenv`.
# See README.md → "Okta build configuration".

set -u

if [ -z "${INFOPLIST_PATH:-}" ]; then
    echo "warning: INFOPLIST_PATH is unset — inject_okta_config.sh skipped (run inside an Xcode build phase, after Copy Bundle Resources)."
    exit 0
fi

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ ! -f "$PLIST" ]; then
    echo "warning: Info.plist not found at $PLIST — inject_okta_config.sh skipped."
    exit 0
fi

PLISTBUDDY=/usr/libexec/PlistBuddy

inject() {
    local key="$1"
    local var_name="$2"
    local sentinel="$3"
    local value
    if [ -z "${!var_name:-}" ]; then
        value="$sentinel"
        echo "note: $var_name unset — writing sentinel '$sentinel' to $key in Info.plist."
    else
        value="${!var_name}"
    fi
    # Upsert: try Set (works when the key already exists); on failure Add it
    # as a string. This is required because the source Info.plist does not
    # pre-declare the Okta keys.
    "$PLISTBUDDY" -c "Set :$key $value" "$PLIST" 2>/dev/null \
        || "$PLISTBUDDY" -c "Add :$key string $value" "$PLIST"
}

inject OktaIssuer      OKTA_ISSUER       "__OKTA_ISSUER_UNSET__"
inject OktaClientID    OKTA_CLIENT_ID    "__OKTA_CLIENT_ID_UNSET__"
inject OktaRedirectURI OKTA_REDIRECT_URI "__OKTA_REDIRECT_URI_UNSET__"
inject OktaScopes      OKTA_SCOPES       "__OKTA_SCOPES_UNSET__"
inject API_BASE_URL    API_BASE_URL      "__API_BASE_URL_UNSET__"

exit 0
