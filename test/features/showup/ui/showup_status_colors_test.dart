import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';
import 'package:habit_loop/features/showup/ui/generic/showup_status_colors.dart';

void main() {
  group('ShowupStatusColors.cupertino', () {
    const colors = ShowupStatusColors.cupertino;

    test('maps done → activeGreen, failed → destructiveRed, pending → systemGrey', () {
      expect(colors.forStatus(ShowupStatus.done), CupertinoColors.activeGreen);
      expect(colors.forStatus(ShowupStatus.failed), CupertinoColors.destructiveRed);
      expect(colors.forStatus(ShowupStatus.pending), CupertinoColors.systemGrey);
    });

    test('overflow is grey while any showup is pending', () {
      expect(colors.overflow(doneCount: 2, failedCount: 1, pendingCount: 1), CupertinoColors.systemGrey);
      expect(colors.overflow(doneCount: 0, failedCount: 0, pendingCount: 4), CupertinoColors.systemGrey);
    });

    test('overflow is green when resolved and done ≥ failed', () {
      expect(colors.overflow(doneCount: 2, failedCount: 2, pendingCount: 0), CupertinoColors.activeGreen);
      expect(colors.overflow(doneCount: 4, failedCount: 0, pendingCount: 0), CupertinoColors.activeGreen);
    });

    test('overflow is red when resolved and failed > done', () {
      expect(colors.overflow(doneCount: 1, failedCount: 3, pendingCount: 0), CupertinoColors.destructiveRed);
    });
  });

  group('ShowupStatusColors.material', () {
    // Build a colorScheme we can assert against.
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00796B));
    final colors = ShowupStatusColors.material(colorScheme);

    test('maps done → secondary, failed → error, pending → onSurfaceVariant', () {
      expect(colors.forStatus(ShowupStatus.done), colorScheme.secondary);
      expect(colors.forStatus(ShowupStatus.failed), colorScheme.error);
      expect(colors.forStatus(ShowupStatus.pending), colorScheme.onSurfaceVariant);
    });

    test('overflow is onSurfaceVariant while any showup is pending', () {
      expect(colors.overflow(doneCount: 2, failedCount: 1, pendingCount: 1), colorScheme.onSurfaceVariant);
    });

    test('overflow is secondary when resolved and done ≥ failed', () {
      expect(colors.overflow(doneCount: 2, failedCount: 2, pendingCount: 0), colorScheme.secondary);
    });

    test('overflow is error when resolved and failed > done', () {
      expect(colors.overflow(doneCount: 1, failedCount: 3, pendingCount: 0), colorScheme.error);
    });
  });
}
