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
      void Function()? onAbout,
      bool languageSelectionEnabled = true,
      bool networkSyncEnabled = true,
      bool aboutScreenEnabled = true,
    }) =>
        buildDashboardActions(
          onRcOverridesPressed: onRc ?? () {},
          onSyncStatusPressed: onSync ?? () {},
          onLanguagePickerPressed: onLang ?? () {},
          onCreatePactPressed: onCreate ?? () {},
          onAboutPressed: onAbout ?? () {},
          languageSelectionEnabled: languageSelectionEnabled,
          networkSyncEnabled: networkSyncEnabled,
          aboutScreenEnabled: aboutScreenEnabled,
        );

    test('always includes createPact', () {
      final actions = makeActions();
      expect(actions.any((a) => a.type == DashboardActionType.createPact), isTrue);
    });

    test('includes syncStatus when networkSyncEnabled is true', () {
      final actions = makeActions(networkSyncEnabled: true);
      expect(actions.any((a) => a.type == DashboardActionType.syncStatus), isTrue);
    });

    test('omits syncStatus when networkSyncEnabled is false', () {
      final actions = makeActions(networkSyncEnabled: false);
      expect(actions.any((a) => a.type == DashboardActionType.syncStatus), isFalse);
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

    test('includes about when aboutScreenEnabled is true', () {
      final actions = makeActions(aboutScreenEnabled: true);
      expect(actions.any((a) => a.type == DashboardActionType.about), isTrue);
    });

    test('omits about when aboutScreenEnabled is false', () {
      final actions = makeActions(aboutScreenEnabled: false);
      expect(actions.any((a) => a.type == DashboardActionType.about), isFalse);
    });

    test('about descriptor has Key(about-button)', () {
      final about = makeActions().firstWhere((a) => a.type == DashboardActionType.about);
      expect(about.key, const Key('about-button'));
    });

    test('onPressed callbacks are wired to provided functions', () {
      bool rcCalled = false, syncCalled = false, langCalled = false, aboutCalled = false;
      final actions = makeActions(
        onRc: () => rcCalled = true,
        onSync: () => syncCalled = true,
        onLang: () => langCalled = true,
        onAbout: () => aboutCalled = true,
      );
      actions.firstWhere((a) => a.type == DashboardActionType.rcOverrides).onPressed();
      actions.firstWhere((a) => a.type == DashboardActionType.syncStatus).onPressed();
      actions.firstWhere((a) => a.type == DashboardActionType.languagePicker).onPressed();
      actions.firstWhere((a) => a.type == DashboardActionType.about).onPressed();
      expect(rcCalled, isTrue);
      expect(syncCalled, isTrue);
      expect(langCalled, isTrue);
      expect(aboutCalled, isTrue);
    });
  });
}
