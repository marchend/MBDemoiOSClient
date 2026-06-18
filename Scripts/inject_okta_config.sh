#!/bin/bash
#
# inject_okta_config.sh
#
# Xcode Run Script build phase that bridges shell environment variables into
# the built app's Info.plist. Reads four OKTA_* env vars from the calling
# process and writes either the real value or a recognisable sentinel into
# ${INFOPLIST_PATH} via `plutil -replace`.
#
# This script NEVER `exit 1`s on missing vars — an unconfigured developer build
# must still compile and run, surfacing the misconfiguration at runtime via
# `OktaConfig.load()` returning `.notConfigured(...)`. CI gates against the
# sentinels separately.
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
    plutil -replace "$key" -string "$value" "$PLIST"
}

inject OktaIssuer      OKTA_ISSUER       "__OKTA_ISSUER_UNSET__"
inject OktaClientID    OKTA_CLIENT_ID    "__OKTA_CLIENT_ID_UNSET__"
inject OktaRedirectURI OKTA_REDIRECT_URI "__OKTA_REDIRECT_URI_UNSET__"
inject OktaScopes      OKTA_SCOPES       "__OKTA_SCOPES_UNSET__"

exit 0
