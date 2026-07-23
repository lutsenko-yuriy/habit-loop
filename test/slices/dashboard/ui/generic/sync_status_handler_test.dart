import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_ui_state.dart';

void main() {
  group('syncStatusIconDataMaterial', () {
    const expected = {
      SyncUiState.synced: Icons.cloud_done_outlined,
      SyncUiState.degraded: Icons.sync_problem_outlined,
      SyncUiState.suspended: Icons.sync_disabled_outlined,
      SyncUiState.noInternet: Icons.wifi_off_outlined,
      SyncUiState.connecting: Icons.cloud_outlined,
      SyncUiState.notLinked: Icons.cloud_off_outlined,
    };

    for (final entry in expected.entries) {
      testWidgets('returns ${entry.value} for ${entry.key}', (tester) async {
        expect(syncStatusIconDataMaterial(entry.key), entry.value);
      });
    }
  });

  group('syncStatusIconDataCupertino', () {
    const expected = {
      SyncUiState.synced: CupertinoIcons.cloud_fill,
      SyncUiState.degraded: CupertinoIcons.exclamationmark_triangle_fill,
      SyncUiState.suspended: CupertinoIcons.xmark_circle_fill,
      SyncUiState.noInternet: CupertinoIcons.wifi_slash,
      SyncUiState.connecting: CupertinoIcons.cloud,
      SyncUiState.notLinked: CupertinoIcons.cloud_download,
    };

    for (final entry in expected.entries) {
      testWidgets('returns ${entry.value} for ${entry.key}', (tester) async {
        final cupertino = syncStatusIconDataCupertino(entry.key);
        expect(cupertino, entry.value);
        expect(cupertino.fontFamily, CupertinoIcons.cloud.fontFamily);
        expect(cupertino, isNot(equals(syncStatusIconDataMaterial(entry.key))));
      });
    }
  });
}
