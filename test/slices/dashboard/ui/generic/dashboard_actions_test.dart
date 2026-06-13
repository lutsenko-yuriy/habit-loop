import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_actions.dart';

void main() {
  group('buildDashboardActions', () {
    List<DashboardActionDescriptor> makeActions({
      void Function()? onRc,
      void Function()? onSync,
      void Function()? onLang,
      void Function()? onCreate,
      bool languageSelectionEnabled = true,
    }) =>
        buildDashboardActions(
          onRcOverridesPressed: onRc ?? () {},
          onSyncStatusPressed: onSync ?? () {},
          onLanguagePickerPressed: onLang ?? () {},
          onCreatePactPressed: onCreate ?? () {},
          languageSelectionEnabled: languageSelectionEnabled,
        );

    test('always includes syncStatus and createPact', () {
      final actions = makeActions();
      expect(actions.any((a) => a.type == DashboardActionType.syncStatus), isTrue);
      expect(actions.any((a) => a.type == DashboardActionType.createPact), isTrue);
    });

    test('includes languagePicker when languageSelectionEnabled is true', () {
      final actions = makeActions(languageSelectionEnabled: true);
      expect(actions.any((a) => a.type == DashboardActionType.languagePicker), isTrue);
    });

    test('omits languagePicker when languageSelectionEnabled is false', () {
      final actions = makeActions(languageSelectionEnabled: false);
      expect(actions.any((a) => a.type == DashboardActionType.languagePicker), isFalse);
    });

    test('includes rcOverrides in debug mode', () {
      expect(kDebugMode, isTrue, reason: 'test environment must be a debug build');
      final actions = makeActions();
      expect(actions.any((a) => a.type == DashboardActionType.rcOverrides), isTrue);
    });

    test('rcOverrides descriptor has Key(remote-config-debug-button)', () {
      final rc = makeActions().firstWhere((a) => a.type == DashboardActionType.rcOverrides);
      expect(rc.key, const Key('remote-config-debug-button'));
    });

    test('syncStatus descriptor has Key(sync-status-button)', () {
      final sync = makeActions().firstWhere((a) => a.type == DashboardActionType.syncStatus);
      expect(sync.key, const Key('sync-status-button'));
    });

    test('languagePicker descriptor has Key(language-picker-button)', () {
      final lang = makeActions().firstWhere((a) => a.type == DashboardActionType.languagePicker);
      expect(lang.key, const Key('language-picker-button'));
    });

    test('createPact descriptor has Key(create-pact-button)', () {
      final create = makeActions().firstWhere((a) => a.type == DashboardActionType.createPact);
      expect(create.key, const Key('create-pact-button'));
    });

    test('onPressed callbacks are wired to provided functions', () {
      bool rcCalled = false, syncCalled = false, langCalled = false;
      final actions = makeActions(
        onRc: () => rcCalled = true,
        onSync: () => syncCalled = true,
        onLang: () => langCalled = true,
      );
      actions.firstWhere((a) => a.type == DashboardActionType.rcOverrides).onPressed();
      actions.firstWhere((a) => a.type == DashboardActionType.syncStatus).onPressed();
      actions.firstWhere((a) => a.type == DashboardActionType.languagePicker).onPressed();
      expect(rcCalled, isTrue);
      expect(syncCalled, isTrue);
      expect(langCalled, isTrue);
    });
  });
}
