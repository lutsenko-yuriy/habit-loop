#!/usr/bin/env python3
"""Set TestFlight "What's New" release notes via the App Store Connect API.

`testflight_upload.sh` uploads the IPA via `xcrun altool`, which has no
release-notes parameter. Setting the "What's New" text testers see in
TestFlight requires the App Store Connect REST API:

  1. Build a short-lived ES256 JWT from the App Store Connect API key.
  2. Resolve the app's numeric App Store Connect id from its bundle id.
  3. Poll `GET /v1/builds` until the just-uploaded build finishes Apple's
     async processing (`processingState == VALID`).
  4. PATCH (or POST, if none exists yet) the build's `betaBuildLocalizations`
     resource with the release notes.

Runs as an isolated CI job, deliberately separate from `distribute-testflight`
so a failure here (slow processing, transient API error) never blocks that
upload or `version-tag`. Every failure mode below is a soft-fail: this script
always exits 0 except for missing/invalid input (a programming error).

Required env vars:
  APP_STORE_CONNECT_ISSUER_ID   — App Store Connect API issuer ID
  APP_STORE_CONNECT_KEY_ID      — App Store Connect API key ID
  APP_STORE_CONNECT_API_KEY_P8  — Base64-encoded contents of the AuthKey_<KEYID>.p8 file
  BUILD_NUMBER                  — The just-uploaded build's number (resolve-version output)
  VERSION_NAME                  — The just-uploaded build's version name (resolve-version output)
  RELEASE_NOTES                 — Release notes text to set as "What's New" (resolve-version output)

Optional env vars:
  POLL_TIMEOUT_SECONDS  — Max time to wait for the build to finish processing (default 1800 = 30 min)
  POLL_INTERVAL_SECONDS — Delay between poll attempts (default 30)
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

import jwt

API_BASE = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.habitloop.habitLoop"
AUDIENCE = "appstore-connect-v1"
DEFAULT_LOCALE = "en-US"
DEFAULT_POLL_TIMEOUT_SECONDS = 1800
DEFAULT_POLL_INTERVAL_SECONDS = 30
# Apple returns these in addition to PROCESSING/VALID — a build that reaches
# one of them will never become VALID, so polling further is pointless.
TERMINAL_FAILURE_STATES = frozenset({"INVALID", "FAILED", "EXPIRED"})


def build_jwt(issuer_id, key_id, private_key_pem, now=None):
    """Build a short-lived ES256 JWT for the App Store Connect API."""
    now = now or datetime.now(timezone.utc)
    exp = now + timedelta(minutes=15)  # well within Apple's 20-minute limit
    payload = {
        "iss": issuer_id,
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
        "aud": AUDIENCE,
    }
    headers = {"kid": key_id, "alg": "ES256", "typ": "JWT"}
    return jwt.encode(payload, private_key_pem, algorithm="ES256", headers=headers)


def _request(method, url, token, data=None):
    """Issue an authenticated request against the App Store Connect API.

    Isolated in its own function so tests can mock it without any real
    network access.
    """
    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=30) as resp:  # noqa: S310 - fixed HTTPS host
        raw = resp.read()
        return json.loads(raw) if raw else {}


def resolve_app_id(token, bundle_id=BUNDLE_ID):
    """Resolve the numeric App Store Connect app id from its bundle id."""
    url = f"{API_BASE}/apps?filter[bundleId]={bundle_id}"
    result = _request("GET", url, token)
    data = result.get("data", [])
    if not data:
        raise LookupError(f"No App Store Connect app found for bundle id {bundle_id}")
    return data[0]["id"]


def poll_build(
    token_provider,
    app_id,
    build_number,
    version_name,
    timeout_seconds=DEFAULT_POLL_TIMEOUT_SECONDS,
    interval_seconds=DEFAULT_POLL_INTERVAL_SECONDS,
    sleep_fn=time.sleep,
    clock=time.monotonic,
):
    """Poll until the build matching build_number/version_name is VALID, or time out.

    `token_provider` is a zero-arg callable minting a fresh JWT on every call —
    the App Store Connect JWT lives 15 minutes (`build_jwt`) but this poll can
    run up to `timeout_seconds` (default 30 min), so a token captured once at
    the start would expire mid-poll and turn every later request into a 401.

    Returns the build resource dict, or None on timeout/terminal failure
    (soft-fail — the caller just skips the What's New update; the binary
    itself already uploaded fine).
    """
    url = (
        f"{API_BASE}/builds"
        f"?filter[app]={app_id}"
        f"&filter[version]={build_number}"
        f"&filter[preReleaseVersion.version]={version_name}"
        f"&limit=1"
    )
    deadline = clock() + timeout_seconds

    # Inline rather than a shared scripts/lib/poll.py helper: postponed until
    # HAB-181 (Google Play) needs an equivalent loop — Apple's ES256-JWT auth
    # and Google's OAuth2/Edits-API flow differ enough that extracting a
    # shared shape now means guessing ahead of a second real implementation.
    while True:
        try:
            result = _request("GET", url, token_provider())
        except (urllib.error.URLError, urllib.error.HTTPError) as exc:
            # Transient — a single flaky request must not abandon a poll
            # that's designed to patiently ride out a slow/flaky window.
            print(f"WARNING: request failed ({exc}), retrying next interval")
        else:
            data = result.get("data", [])
            if data:
                build = data[0]
                state = build.get("attributes", {}).get("processingState")
                print(f"Build {build_number} processingState={state}")
                if state == "VALID":
                    return build
                if state in TERMINAL_FAILURE_STATES:
                    print(f"WARNING: build reached terminal state {state} — will never become VALID")
                    return None
            else:
                print(f"No build found yet for version={version_name} build={build_number}")

        if clock() >= deadline:
            print(f"WARNING: timed out after {timeout_seconds}s waiting for build to become VALID")
            return None
        sleep_fn(interval_seconds)


def upsert_beta_build_localization(token, build_id, whats_new, locale=DEFAULT_LOCALE):
    """PATCH the existing betaBuildLocalization for `locale`, or POST a new one."""
    url = f"{API_BASE}/builds/{build_id}/betaBuildLocalizations"
    result = _request("GET", url, token)
    existing = next(
        (loc for loc in result.get("data", []) if loc.get("attributes", {}).get("locale") == locale),
        None,
    )

    if existing:
        patch_url = f"{API_BASE}/betaBuildLocalizations/{existing['id']}"
        payload = {
            "data": {
                "type": "betaBuildLocalizations",
                "id": existing["id"],
                "attributes": {"whatsNew": whats_new},
            }
        }
        _request("PATCH", patch_url, token, data=payload)
    else:
        post_url = f"{API_BASE}/betaBuildLocalizations"
        payload = {
            "data": {
                "type": "betaBuildLocalizations",
                "attributes": {"locale": locale, "whatsNew": whats_new},
                "relationships": {"build": {"data": {"type": "builds", "id": build_id}}},
            }
        }
        _request("POST", post_url, token, data=payload)


def main():
    try:
        issuer_id = os.environ["APP_STORE_CONNECT_ISSUER_ID"]
        key_id = os.environ["APP_STORE_CONNECT_KEY_ID"]
        p8_b64 = os.environ["APP_STORE_CONNECT_API_KEY_P8"]
        build_number = os.environ["BUILD_NUMBER"]
        version_name = os.environ["VERSION_NAME"]
        release_notes = os.environ["RELEASE_NOTES"]
    except KeyError as exc:
        print(f"Missing required env var: {exc}", file=sys.stderr)
        return 1

    timeout_seconds = int(os.environ.get("POLL_TIMEOUT_SECONDS", DEFAULT_POLL_TIMEOUT_SECONDS))
    interval_seconds = int(os.environ.get("POLL_INTERVAL_SECONDS", DEFAULT_POLL_INTERVAL_SECONDS))

    try:
        private_key_pem = base64.b64decode(p8_b64)
        token_provider = lambda: build_jwt(issuer_id, key_id, private_key_pem)  # noqa: E731
        app_id = resolve_app_id(token_provider())
        build = poll_build(
            token_provider,
            app_id,
            build_number,
            version_name,
            timeout_seconds=timeout_seconds,
            interval_seconds=interval_seconds,
        )
        if build is None:
            print("Skipping TestFlight What's New update — build did not reach VALID in time.")
            return 0
        if not release_notes.strip():
            print("Release notes are empty — skipping TestFlight What's New update.")
            return 0
        upsert_beta_build_localization(token_provider(), build["id"], release_notes)
        print(f"TestFlight What's New updated for build {build_number}.")
        return 0
    except Exception as exc:  # noqa: BLE001 - soft-fail by design; any API/processing error must not fail the pipeline
        print(f"WARNING: failed to set TestFlight What's New: {exc}", file=sys.stderr)
        return 0


if __name__ == "__main__":
    sys.exit(main())
