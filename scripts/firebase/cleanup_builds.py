#!/usr/bin/env python3
"""cleanup_builds.py — Delete old Firebase App Distribution releases.

Keeps the N most recent releases per app; deletes the rest.

Required environment variables:
    APP_ID         Firebase App ID (e.g. 1:123456789012:android:abc123)
    ACCESS_TOKEN   Google OAuth2 access token (from: gcloud auth print-access-token)

Optional environment variables:
    KEEP_COUNT     How many recent releases to keep (default: 10)
    DRY_RUN        Set to 'true' to list deletions without executing them

The Firebase App Distribution REST API base is:
    https://firebaseappdistribution.googleapis.com/v1
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


_API_BASE = 'https://firebaseappdistribution.googleapis.com/v1'


def _auth_headers(access_token: str) -> dict[str, str]:
    return {'Authorization': f'Bearer {access_token}'}


def list_releases(app_id: str, access_token: str) -> list[dict]:
    """Return all releases sorted newest-first, following pagination."""
    project_number = app_id.split(':')[1]
    base_url = (
        f'{_API_BASE}/projects/{project_number}/apps/{app_id}/releases'
        f'?pageSize=100&orderBy=createTime%20desc'
    )

    all_releases: list[dict] = []
    page_token: str | None = None

    while True:
        url = base_url
        if page_token:
            url += f'&pageToken={urllib.parse.quote(page_token)}'
        req = urllib.request.Request(url, headers=_auth_headers(access_token))
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
        all_releases.extend(data.get('releases', []))
        page_token = data.get('nextPageToken')
        if not page_token:
            break

    return all_releases


def delete_release(release_name: str, access_token: str) -> None:
    """Delete a single release by its resource name."""
    url = f'{_API_BASE}/{release_name}'
    req = urllib.request.Request(url, method='DELETE', headers=_auth_headers(access_token))
    with urllib.request.urlopen(req) as resp:
        resp.read()


def select_releases_to_delete(releases: list[dict], keep: int) -> list[dict]:
    """Return the tail of releases (oldest) that should be deleted."""
    return releases[keep:]


def main() -> None:
    app_id = os.environ.get('APP_ID')
    access_token = os.environ.get('ACCESS_TOKEN')
    keep = int(os.environ.get('KEEP_COUNT', '10'))
    dry_run = os.environ.get('DRY_RUN', '').lower() == 'true'

    if not app_id:
        print('Error: APP_ID environment variable is required.', file=sys.stderr)
        sys.exit(1)
    if not access_token:
        print('Error: ACCESS_TOKEN environment variable is required.', file=sys.stderr)
        sys.exit(1)

    print(f'Listing releases for app {app_id} …')
    releases = list_releases(app_id, access_token)
    print(f'Found {len(releases)} release(s); keeping most recent {keep}.')

    to_delete = select_releases_to_delete(releases, keep)
    if not to_delete:
        print('Nothing to delete.')
        return

    errors = 0
    for r in to_delete:
        name = r['name']
        display = r.get('displayVersion', '') or name
        if dry_run:
            print(f'[dry-run] Would delete: {display} ({name})')
            continue
        try:
            delete_release(name, access_token)
            print(f'Deleted: {display} ({name})')
        except urllib.error.HTTPError as exc:
            print(f'Error deleting {name}: HTTP {exc.code} {exc.reason}', file=sys.stderr)
            errors += 1

    if errors:
        print(f'{errors} deletion(s) failed.', file=sys.stderr)
        sys.exit(1)

    if dry_run:
        print(f'[dry-run] Would have deleted {len(to_delete)} release(s).')
    else:
        print(f'Cleanup complete — deleted {len(to_delete)} release(s).')


if __name__ == '__main__':
    main()
