import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_detail_page_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_break_creation_screen.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_content_transition.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_screen.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_edit_screen.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_screen.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_detail_page_ios.dart';

class PactDetailScreen extends ConsumerStatefulWidget {
  final String pactId;

  const PactDetailScreen({super.key, required this.pactId});

  @override
  ConsumerState<PactDetailScreen> createState() => _PactDetailScreenState();
}

class _PactDetailScreenState extends ConsumerState<PactDetailScreen> {
  // Owned here (not by the stateless platform pages) so _onAdjustAndStartAgain
  // can reset scroll position after returning from the wizard (HAB-202) — the
  // ListView otherwise keeps whatever offset it had before the push, which
  // can leave newly-relevant top-of-list content (e.g. a fresh "Next Pact"
  // link) scrolled out of view.
  final _scrollController = ScrollController();

  // The pact currently displayed (HAB-206). Mutable — chain-link taps swap
  // this in place instead of pushing a new PactDetailScreen route, so the
  // nav stack never grows past however deep the user entered the chain from
  // (see docs/knowledge/notes/HAB-206.md).
  late String _currentPactId;

  // Guards against overlapping chain-link taps. Set for the duration of a
  // swap (data reload + WU3's future transition animation) and checked by
  // _onOpenChainLink so a second tap mid-transition is a no-op rather than
  // interrupting or racing the first.
  bool _isAnimating = false;

  // Tracks the most recent chain-navigation direction so the current pact's
  // content can slide/fade in from the correct side (HAB-206 WU3).
  PactDetailTransitionDirection? _lastDirection;

  @override
  void initState() {
    super.initState();
    _currentPactId = widget.pactId;
    unawaited(
      Future.microtask(() {
        unawaited(
          ref.read(analyticsServiceProvider).logScreenView(const PactDetailAnalyticsScreen()),
        );
        // Invalidate so load() always samples the real current time, not a
        // cached value from a previous navigation or app start. Mirrors the
        // ref.invalidate(showupDetailNowProvider) pattern in ShowupDetailScreen.
        ref.invalidate(pactDetailNowProvider);
        unawaited(
          ref.read(pactDetailViewModelProvider(_currentPactId).notifier).load(),
        );
      }),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onOpenTimeline() async {
    if (!mounted) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => PactTimelineScreen(pactId: _currentPactId),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PactTimelineScreen(pactId: _currentPactId),
        ),
      );
    }
  }

  Future<void> _onStartBreak() async {
    final result = await Navigator.of(context).push<bool>(
      defaultTargetPlatform == TargetPlatform.iOS
          ? CupertinoPageRoute<bool>(
              builder: (_) => PactBreakCreationScreen(pactId: _currentPactId, source: 'pact_detail'),
            )
          : MaterialPageRoute<bool>(
              builder: (_) => PactBreakCreationScreen(pactId: _currentPactId, source: 'pact_detail'),
            ),
    );

    // Reload pact detail if a break was created, so activeBreak reflects it.
    if (result == true && mounted) {
      ref.invalidate(pactDetailNowProvider);
      unawaited(
        ref.read(pactDetailViewModelProvider(_currentPactId).notifier).load(),
      );
    }
  }

  /// Navigates to a chain-linked pact (HAB-202) by swapping [_currentPactId]
  /// in place (HAB-206) — no push, so a single PactDetailScreen route stays
  /// mounted regardless of how far the user bounces between "Previous Pact"
  /// and "Next Pact" links; the system back button always exits directly to
  /// wherever this screen was originally opened from.
  ///
  /// No-ops while [_isAnimating] is already true — a second tap mid-swap
  /// (data reload today; also the WU3 transition animation once it lands)
  /// is ignored rather than interrupting or racing the first.
  Future<void> _onOpenChainLink(String targetPactId, {required String direction}) async {
    if (_isAnimating) return;

    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            PactChainLinkTappedEvent(pactId: _currentPactId, direction: direction),
          ),
    );

    ref.invalidate(pactDetailNowProvider);
    setState(() {
      _isAnimating = true;
    });

    await ref.read(pactDetailViewModelProvider(targetPactId).notifier).load();
    if (!mounted) return;

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    setState(() {
      _currentPactId = targetPactId;
      _lastDirection = switch (direction) {
        'previous' => PactDetailTransitionDirection.toPredecessor,
        'next' => PactDetailTransitionDirection.toSuccessor,
        _ => null,
      };
    });

    await Future<void>.delayed(PactDetailContentTransition.duration);
    if (!mounted) return;

    setState(() {
      _isAnimating = false;
    });
  }

  /// Opens the pact-creation wizard pre-filled from this (finished) pact
  /// (HAB-202). On return, the config is reset and the detail screen reloads
  /// so a newly-created successor's "Next Pact" link appears immediately.
  Future<void> _onAdjustAndStartAgain() async {
    final pact = ref.read(pactDetailViewModelProvider(_currentPactId)).pact;
    if (pact == null) return;

    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            PactAdjustAndStartAgainTappedEvent(
              pactId: pact.id,
              pactStatus: pact.status == PactStatus.completed ? 'completed' : 'stopped',
            ),
          ),
    );

    final today = ref.read(pactDetailNowProvider);
    final prefillBuilder = await ref.read(pactChainServiceProvider).buildPrefillFor(pact, today: today);
    if (!mounted) return;

    ref.read(pactCreationConfigProvider.notifier).state = PactCreationConfig(
      predecessorPactId: pact.id,
      prefillBuilder: prefillBuilder,
    );
    ref.invalidate(pactCreationViewModelProvider);

    await Navigator.of(context).push<void>(
      defaultTargetPlatform == TargetPlatform.iOS
          ? CupertinoPageRoute<void>(builder: (_) => const PactCreationScreen())
          : MaterialPageRoute<void>(builder: (_) => const PactCreationScreen()),
    );

    // Reset so a later blank creation doesn't inherit a stale prefill —
    // Riverpod forbids a provider from clearing its own state during
    // another provider's build() (see pactCreationConfigProvider's doc comment).
    ref.read(pactCreationConfigProvider.notifier).state = null;

    if (!mounted) return;
    // Whatever now belongs at the top of the list (the "Next Pact" link on
    // success, or nothing new on cancel) must actually be visible — the
    // ListView otherwise keeps its pre-push scroll offset indefinitely,
    // since this is the same screen instance throughout.
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    ref.invalidate(pactDetailNowProvider);
    unawaited(
      ref.read(pactDetailViewModelProvider(_currentPactId).notifier).load(),
    );
  }

  Future<void> _onEditPact() async {
    final result = await Navigator.of(context).push<bool>(
      defaultTargetPlatform == TargetPlatform.iOS
          ? CupertinoPageRoute<bool>(builder: (_) => PactEditScreen(pactId: _currentPactId))
          : MaterialPageRoute<bool>(builder: (_) => PactEditScreen(pactId: _currentPactId)),
    );

    // Reload pact detail if the edit was saved successfully.
    if (result == true && mounted) {
      ref.invalidate(pactDetailNowProvider);
      unawaited(
        ref.read(pactDetailViewModelProvider(_currentPactId).notifier).load(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pactDetailViewModelProvider(_currentPactId));
    final flags = ref.watch(featureFlagsProvider);

    Future<void> onStopPact(String? reason) async {
      // Invalidate so stopPact() samples the real current time even if the
      // screen has been open for an extended period.
      ref.invalidate(pactDetailNowProvider);
      await ref.read(pactDetailViewModelProvider(_currentPactId).notifier).stopPact(reason);
    }

    Future<void> onSaveNote(String note) async {
      await ref.read(pactDetailViewModelProvider(_currentPactId).notifier).saveNote(note);
    }

    Future<void> onArchivePact(bool archive) async {
      await ref
          .read(pactDetailViewModelProvider(_currentPactId).notifier)
          .archivePact(archive, source: 'detail_screen');
    }

    Future<void> onStopBreak() async {
      ref.invalidate(pactDetailNowProvider);
      await ref.read(pactDetailViewModelProvider(_currentPactId).notifier).stopBreak();
    }

    // "Take a break" is only offered while no break already blocks a new one
    // (HAB-195) — an active break shows the "Resume pact" banner instead (WU5.2).
    final onStartBreak = flags.pactBreaksEnabled && state.activeBreak == null ? _onStartBreak : null;

    // Chain links (HAB-202) — hidden unless the toggle is on and the linked
    // pact actually exists.
    final onOpenPreviousPact = flags.pactChainingEnabled && state.predecessorPact != null
        ? () => _onOpenChainLink(state.predecessorPact!.id, direction: 'previous')
        : null;
    final onOpenNextPact = flags.pactChainingEnabled && state.successorPact != null
        ? () => _onOpenChainLink(state.successorPact!.id, direction: 'next')
        : null;

    // "Adjust and start again" (HAB-202) — only for a finished pact with no
    // successor yet; once a successor exists, "Next Pact" takes its place.
    final onAdjustAndStartAgain = flags.pactChainingEnabled &&
            state.pact != null &&
            state.pact!.status != PactStatus.active &&
            state.successorPact == null
        ? _onAdjustAndStartAgain
        : null;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return PactDetailPageIos(
        state: state,
        onStopPact: onStopPact,
        onSaveNote: onSaveNote,
        onArchivePact: onArchivePact,
        onEditPact: _onEditPact,
        pactTimelineEnabled: flags.pactTimelineEnabled,
        onOpenTimeline: _onOpenTimeline,
        onStartBreak: onStartBreak,
        onStopBreak: onStopBreak,
        pactChainingEnabled: flags.pactChainingEnabled,
        onOpenPreviousPact: onOpenPreviousPact,
        onOpenNextPact: onOpenNextPact,
        onAdjustAndStartAgain: onAdjustAndStartAgain,
        scrollController: _scrollController,
        contentId: _currentPactId,
        transitionDirection: _lastDirection,
      );
    }
    return PactDetailPageAndroid(
      state: state,
      onStopPact: onStopPact,
      onSaveNote: onSaveNote,
      onArchivePact: onArchivePact,
      onEditPact: _onEditPact,
      pactTimelineEnabled: flags.pactTimelineEnabled,
      onOpenTimeline: _onOpenTimeline,
      onStartBreak: onStartBreak,
      onStopBreak: onStopBreak,
      pactChainingEnabled: flags.pactChainingEnabled,
      onOpenPreviousPact: onOpenPreviousPact,
      onOpenNextPact: onOpenNextPact,
      onAdjustAndStartAgain: onAdjustAndStartAgain,
      scrollController: _scrollController,
      contentId: _currentPactId,
      transitionDirection: _lastDirection,
    );
  }
}
