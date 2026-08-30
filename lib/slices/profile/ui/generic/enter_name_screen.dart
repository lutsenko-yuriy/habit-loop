import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/profile/analytics/profile_analytics_events.dart';
import 'package:habit_loop/slices/profile/ui/android/enter_name_page_android.dart';
import 'package:habit_loop/slices/profile/ui/generic/display_name_provider.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_constants.dart';
import 'package:habit_loop/slices/profile/ui/ios/enter_name_page_ios.dart';

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

  // Guards against a double-tap firing two saves/skips (double-counted
  // analytics event, duplicate write) while the first one is still in flight.
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final seed = ref.read(displayNameProvider) ?? '';
    _controller = TextEditingController(text: seed)..selection = TextSelection.collapsed(offset: seed.length);
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
    var resolvedAction = action;
    if (name != null) {
      try {
        await ref.read(displayNameProvider.notifier).setDisplayName(name);
      } catch (_) {
        // Never strand the user on this screen over a transient DB failure —
        // degrade to "skipped" so isNameEntryShown still gets marked and onDone fires.
        resolvedAction = 'skipped';
      }
    }
    await ref.read(onboardingPreferenceServiceProvider).markNameEntryShown();
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            DisplayNameEntryCompletedEvent(
              action: resolvedAction,
              // .characters.length (grapheme clusters), not .length (UTF-16 code
              // units) — matches the unit enterNameMaxLength/_capToMaxLength cap in.
              nameLength: resolvedAction == 'saved' ? name?.characters.length : null,
            ),
          ),
    );
    if (!mounted) return;
    widget.onDone();
  }

  Future<void> _onSave() async {
    if (_submitting) return;
    _submitting = true;
    try {
      final trimmed = _controller.text.trim();
      if (trimmed.isEmpty) {
        await _finish(name: null, action: 'skipped');
        return;
      }
      // The platform bodies' LengthLimitingTextInputFormatter only caps typed
      // input — a name arriving via sync or seeded straight into the
      // controller (initState) bypasses it, so cap again here defensively.
      await _finish(name: capToMaxNameLength(trimmed), action: 'saved');
    } finally {
      _submitting = false;
    }
  }

  Future<void> _onSkip() async {
    if (_submitting) return;
    _submitting = true;
    try {
      await _finish(name: null, action: 'skipped');
    } finally {
      _submitting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return EnterNamePageIos(controller: _controller, onSave: _onSave, onSkip: _onSkip);
    }
    return EnterNamePageAndroid(controller: _controller, onSave: _onSave, onSkip: _onSkip);
  }
}
