#!/usr/bin/env python3
"""dispatch_plan.py — Compute build/distribute task flags for the CI pipeline.

For workflow_dispatch events, reads the android/ios/environment/deploy inputs
and emits key=value lines for each task flag. For all other events (push,
pull_request), forces fully-automatic behaviour so existing pipeline behaviour
is completely unchanged.

Usage:
    python3 scripts/ci/dispatch_plan.py \
        --event <event_name> \
        --android <true|false> \
        --ios <true|false> \
        --deploy <true|false> \
        --environment <production|staging>

Output (stdout, one key=value per line):
    build_android=true|false
    build_ios=true|false
    distribute_android=true|false
    distribute_ios=true|false
    group_alias=internal-testers|staging-testers

Exit code: always 0 — never fails the CI pipeline.
"""

from __future__ import annotations

import argparse


def dispatch_plan(
    event: str,
    android: bool,
    ios: bool,
    deploy: bool,
    environment: str,
) -> dict:
    """Return build/distribute flags for the given CI event and inputs."""
    if event != 'workflow_dispatch':
        return {
            'build_android': True,
            'build_ios': True,
            'distribute_android': True,
            'distribute_ios': True,
            'group_alias': 'internal-testers',
        }

    is_production = environment == 'production'
    return {
        'build_android': android,
        'build_ios': ios,
        'distribute_android': android and deploy and is_production,
        'distribute_ios': ios and deploy and is_production,
        'group_alias': 'internal-testers' if is_production else 'staging-testers',
    }


def _to_bool(value: str) -> bool:
    return value.lower() in ('true', '1', 'yes')


def main() -> None:
    parser = argparse.ArgumentParser(description='Compute CI task flags for a workflow_dispatch run.')
    parser.add_argument('--event', required=True, help='GitHub event name (e.g. workflow_dispatch, push)')
    parser.add_argument('--android', default='true', help='Build Android binary? (true/false)')
    parser.add_argument('--ios', default='true', help='Build iOS binary? (true/false)')
    parser.add_argument('--deploy', default='true', help='Deploy to Firebase? (true/false)')
    parser.add_argument('--environment', default='production', help='Target environment (production/staging)')
    args = parser.parse_args()

    plan = dispatch_plan(
        event=args.event,
        android=_to_bool(args.android),
        ios=_to_bool(args.ios),
        deploy=_to_bool(args.deploy),
        environment=args.environment,
    )

    for key, value in plan.items():
        print(f'{key}={str(value).lower() if isinstance(value, bool) else value}')


if __name__ == '__main__':
    main()
