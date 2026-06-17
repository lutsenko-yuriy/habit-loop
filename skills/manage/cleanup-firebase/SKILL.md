---
name: cleanup-firebase
effort: RAPID
reasoning: MECHANICAL
output_style: CONCISE
description: Delete old Firebase App Distribution builds, keeping the N most recent per platform. Requires gcloud CLI authenticated and FIREBASE_ANDROID_APP_ID / FIREBASE_IOS_APP_ID set in the environment or CLAUDE.local.md.
---

Delete old Firebase App Distribution releases locally using `scripts/firebase/cleanup_builds.py`.

---

## Prerequisites

Before running, verify:

1. `gcloud` CLI is installed and authenticated:
   ```bash
   gcloud auth login   # if not already authenticated
   ```
2. `FIREBASE_ANDROID_APP_ID` and `FIREBASE_IOS_APP_ID` are available in the environment.
   If not set, read them from `CLAUDE.local.md` (or ask the user to provide them).

## Steps

### 1. Parse arguments

Extract `N` (number of releases to keep) from `$ARGUMENTS`. Default to **10** if not supplied.
Also check for `--dry-run` flag — if present, set `DRY_RUN=true`.

### 2. Confirm with the user

Show a one-line summary of what will happen and wait for confirmation:

> "About to delete all but the {N} most recent Firebase builds on both Android and iOS.
> Dry run: {yes/no}. Proceed?"

Do not proceed without explicit confirmation.

### 3. Obtain an access token

```bash
ACCESS_TOKEN=$(gcloud auth print-access-token)
```

If this fails (gcloud not configured), instruct the user to run `gcloud auth login` and retry.

### 4. Run cleanup for Android

```bash
APP_ID="$FIREBASE_ANDROID_APP_ID" \
ACCESS_TOKEN="$ACCESS_TOKEN" \
KEEP_COUNT="{N}" \
DRY_RUN="{true|false}" \
python3 scripts/firebase/cleanup_builds.py
```

Report the output to the user.

### 5. Run cleanup for iOS

```bash
APP_ID="$FIREBASE_IOS_APP_ID" \
ACCESS_TOKEN="$ACCESS_TOKEN" \
KEEP_COUNT="{N}" \
DRY_RUN="{true|false}" \
python3 scripts/firebase/cleanup_builds.py
```

Report the output to the user.

### 6. Report back

Summarise: how many releases were deleted per platform, or what would have been deleted in dry-run mode.
