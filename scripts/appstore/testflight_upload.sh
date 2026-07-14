#!/usr/bin/env bash
# Uploads a signed IPA to TestFlight (internal testing) via the App Store
# Connect API, using xcrun altool.
#
# Runs alongside, not instead of, Firebase App Distribution (HAB-167) --
# TestFlight requires an app-store-signed IPA, distinct from the ad-hoc IPA
# uploaded to Firebase.
#
# Required env vars:
#   ARTIFACT_PATH            — Path to the app-store-signed IPA file
#   APP_STORE_CONNECT_KEY_ID — App Store Connect API key ID
#   APP_STORE_CONNECT_ISSUER_ID — App Store Connect API issuer ID
#   APP_STORE_CONNECT_API_KEY_P8 — Contents of the AuthKey_<KEYID>.p8 file

set -euo pipefail

# ── Auth ──────────────────────────────────────────────────────────────────────
KEYS_DIR="${HOME}/.appstoreconnect/private_keys"
mkdir -p "$KEYS_DIR"
KEY_FILE="${KEYS_DIR}/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s' "$APP_STORE_CONNECT_API_KEY_P8" > "$KEY_FILE"
chmod 600 "$KEY_FILE"
echo "✓ API key staged"

# ── Upload ────────────────────────────────────────────────────────────────────
FILENAME=$(basename "$ARTIFACT_PATH")
echo "Uploading ${FILENAME} to TestFlight..."
xcrun altool --upload-app \
  -f "$ARTIFACT_PATH" \
  -t ios \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
echo "✓ Uploaded to TestFlight (internal testing)"
