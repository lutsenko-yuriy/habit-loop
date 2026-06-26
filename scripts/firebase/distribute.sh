#!/usr/bin/env bash
# Uploads a build artifact to Firebase App Distribution via the REST API.
#
# Required env vars:
#   APP_ID               — Firebase app ID (e.g. 1:123456789:android:abc)
#   ARTIFACT_PATH        — Path to the APK or IPA file
#   SERVICE_ACCOUNT_JSON — Contents of the GCP service account JSON
#   RELEASE_NOTES        — Release notes text
#   GROUP_ALIAS          — Firebase tester group alias (e.g. internal-testers)

set -euo pipefail

# ── Auth ──────────────────────────────────────────────────────────────────────
SA_FILE=$(mktemp)
trap 'rm -f "$SA_FILE"' EXIT
printf '%s' "$SERVICE_ACCOUNT_JSON" > "$SA_FILE"
gcloud auth activate-service-account --key-file="$SA_FILE" --quiet
ACCESS_TOKEN=$(gcloud auth print-access-token)
echo "✓ Authenticated"

# ── Upload ────────────────────────────────────────────────────────────────────
PROJECT_NUMBER=$(echo "$APP_ID" | cut -d: -f2)
BASE="https://firebaseappdistribution.googleapis.com"
FILENAME=$(basename "$ARTIFACT_PATH")

echo "Uploading ${FILENAME}..."
UPLOAD=$(curl -sf -X POST \
  "${BASE}/upload/v1/projects/${PROJECT_NUMBER}/apps/${APP_ID}/releases:upload" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "X-Goog-Upload-File-Name: ${FILENAME}" \
  -H "X-Goog-Upload-Protocol: raw" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"${ARTIFACT_PATH}")
echo "Upload response: ${UPLOAD}"

OP_NAME=$(echo "$UPLOAD" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")
echo "Operation: ${OP_NAME}"

# ── Poll for completion (up to 90 s) ─────────────────────────────────────────
RELEASE_NAME=""
for i in $(seq 1 30); do
  POLL=$(curl -sf "${BASE}/v1/${OP_NAME}" -H "Authorization: Bearer ${ACCESS_TOKEN}")
  if echo "$POLL" | python3 -c "import json,sys; sys.exit(0 if json.load(sys.stdin).get('done') else 1)" 2>/dev/null; then
    RELEASE_NAME=$(echo "$POLL" | python3 -c "import json,sys; print(json.load(sys.stdin)['response']['release']['name'])")
    echo "✓ Processed: ${RELEASE_NAME}"
    break
  fi
  echo "  Still processing... (${i}/30)"
  sleep 3
done
[[ -n "$RELEASE_NAME" ]] || { echo "Timed out waiting for upload to process" >&2; exit 1; }

# ── Release notes ─────────────────────────────────────────────────────────────
NOTES_JSON=$(python3 -c "import json,os; print(json.dumps(os.environ['RELEASE_NOTES']))")
curl -sf -X PATCH \
  "${BASE}/v1/${RELEASE_NAME}?updateMask=releaseNotes.text" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"releaseNotes\":{\"text\":${NOTES_JSON}}}" > /dev/null
echo "✓ Release notes updated"

# ── Distribute ────────────────────────────────────────────────────────────────
curl -sf -X POST \
  "${BASE}/v1/${RELEASE_NAME}:distribute" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"groupAliases\":[\"${GROUP_ALIAS}\"]}" > /dev/null
echo "✓ Distributed to ${GROUP_ALIAS}"
