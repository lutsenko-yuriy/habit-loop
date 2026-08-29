import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/profile/analytics/profile_analytics_events.dart';
import 'package:habit_loop/slices/profile/ui/android/enter_name_page_android.dart';
import 'package:habit_loop/slices/profile/ui/generic/display_name_provider.dart';
import 'package:habit_loop/slices/profile/ui/ios/enter_name_page_ios.dart';

/// Maximum accepted display-name length (HAB-232) — caps what eventually
/// reaches notification copy.
const int enterNameMaxLength = 40;

/// Skippable first-launch page asking for the user's first name (HAB-232).
///
/// Shown by [DashboardScreen] on fresh installs, before the onboarding
/// carousel, gated on `!isOnboardingPassed && !isNameEntryShown && flag`.
/// Owns save/skip logic; [EnterNamePageIos]/[EnterNamePageAndroid] are pure
/// chrome.
class EnterNameScreen extends ConsumerStatefulWidget {
  const EnterNameScreen({super.key, required this.onDone});

  /// Called once the page has persisted its outcome (saved or skipped) and
  /// marked `isNameEntryShown` — the caller should stop showing this page.
  final VoidCallback onDone;

  @override
  ConsumerState<EnterNameScreen> createState() => _EnterNameScreenState();
}

class _EnterNameScreenState extends ConsumerState<EnterNameScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(displayNameProvider) ?? '');
    unawaited(
      Future.microtask(
        () => ref.read(analyticsServiceProvider).logScreenView(const EnterNameAnalyticsScreen()),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish({required String? name, required String action}) async {
    if (name != null) {
      await ref.read(displayNameProvider.notifier).setDisplayName(name);
    }
    await ref.read(onboardingPreferenceServiceProvider).markNameEntryShown();
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            DisplayNameEntryCompletedEvent(action: action, nameLength: name?.length),
          ),
    );
    if (!mounted) return;
    widget.onDone();
  }

  Future<void> _onSave() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      await _finish(name: null, action: 'skipped');
      return;
    }
    final capped = trimmed.length > enterNameMaxLength ? trimmed.substring(0, enterNameMaxLength) : trimmed;
    await _finish(name: capped, action: 'saved');
  }

  Future<void> _onSkip() => _finish(name: null, action: 'skipped');

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return EnterNamePageIos(controller: _controller, onSave: _onSave, onSkip: _onSkip);
    }
    return EnterNamePageAndroid(controller: _controller, onSave: _onSave, onSkip: _onSkip);
  }
}
