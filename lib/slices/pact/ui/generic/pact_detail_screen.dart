import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_detail_page_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_break_creation_screen.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_edit_screen.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_screen.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_detail_page_ios.dart';

class PactDetailScreen extends ConsumerStatefulWidget {
  final String pactId;

  /// The pact id of whatever detail screen pushed this one, if any (HAB-202).
  ///
  /// `null` when this screen was opened from the pact list (or any other
  /// non-chain-link entry point). Used by [_onOpenChainLink] to decide
  /// whether tapping a chain link should pop back to an existing page
  /// instance or push a new one — see the navigation-stack rule in
  /// `docs/knowledge/notes/HAB-202.md`.
  final String? cameFromPactId;

  const PactDetailScreen({super.key, required this.pactId, this.cameFromPactId});

  @override
  ConsumerState<PactDetailScreen> createState() => _PactDetailScreenState();
}

class _PactDetailScreenState extends ConsumerState<PactDetailScreen> {
  @override
  void initState() {
    super.initState();
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
          ref.read(pactDetailViewModelProvider(widget.pactId).notifier).load(),
        );
      }),
    );
  }

  Future<void> _onOpenTimeline() async {
    if (!mounted) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => PactTimelineScreen(pactId: widget.pactId),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PactTimelineScreen(pactId: widget.pactId),
        ),
      );
    }
  }

  Future<void> _onStartBreak() async {
    final result = await Navigator.of(context).push<bool>(
      defaultTargetPlatform == TargetPlatform.iOS
          ? CupertinoPageRoute<bool>(
              builder: (_) => PactBreakCreationScreen(pactId: widget.pactId, source: 'pact_detail'),
            )
          : MaterialPageRoute<bool>(
              builder: (_) => PactBreakCreationScreen(pactId: widget.pactId, source: 'pact_detail'),
            ),
    );

    // Reload pact detail if a break was created, so activeBreak reflects it.
    if (result == true && mounted) {
      ref.invalidate(pactDetailNowProvider);
      unawaited(
        ref.read(pactDetailViewModelProvider(widget.pactId).notifier).load(),
      );
    }
  }

  /// Navigates to a chain-linked pact (HAB-202). Pops back to an existing
  /// page instance if [targetPactId] matches [cameFromPactId] — i.e. the user
  /// is bouncing back the way they came — otherwise pushes a new screen.
  /// This keeps the back stack from growing unbounded when the user bounces
  /// between "Previous Pact" and "Next Pact" links.
  Future<void> _onOpenChainLink(String targetPactId, {required String direction}) async {
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            PactChainLinkTappedEvent(pactId: widget.pactId, direction: direction),
          ),
    );

    if (targetPactId == widget.cameFromPactId) {
      Navigator.of(context).pop();
      return;
    }

    await Navigator.of(context).push<void>(
      defaultTargetPlatform == TargetPlatform.iOS
          ? CupertinoPageRoute<void>(
              builder: (_) => PactDetailScreen(pactId: targetPactId, cameFromPactId: widget.pactId),
            )
          : MaterialPageRoute<void>(
              builder: (_) => PactDetailScreen(pactId: targetPactId, cameFromPactId: widget.pactId),
            ),
    );
  }

  Future<void> _onEditPact() async {
    final result = await Navigator.of(context).push<bool>(
      defaultTargetPlatform == TargetPlatform.iOS
          ? CupertinoPageRoute<bool>(builder: (_) => PactEditScreen(pactId: widget.pactId))
          : MaterialPageRoute<bool>(builder: (_) => PactEditScreen(pactId: widget.pactId)),
    );

    // Reload pact detail if the edit was saved successfully.
    if (result == true && mounted) {
      ref.invalidate(pactDetailNowProvider);
      unawaited(
        ref.read(pactDetailViewModelProvider(widget.pactId).notifier).load(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pactDetailViewModelProvider(widget.pactId));
    final flags = ref.watch(featureFlagsProvider);

    Future<void> onStopPact(String? reason) async {
      // Invalidate so stopPact() samples the real current time even if the
      // screen has been open for an extended period.
      ref.invalidate(pactDetailNowProvider);
      await ref.read(pactDetailViewModelProvider(widget.pactId).notifier).stopPact(reason);
    }

    Future<void> onSaveNote(String note) async {
      await ref.read(pactDetailViewModelProvider(widget.pactId).notifier).saveNote(note);
    }

    Future<void> onArchivePact(bool archive) async {
      await ref.read(pactDetailViewModelProvider(widget.pactId).notifier).archivePact(archive, source: 'detail_screen');
    }

    Future<void> onStopBreak() async {
      ref.invalidate(pactDetailNowProvider);
      await ref.read(pactDetailViewModelProvider(widget.pactId).notifier).stopBreak();
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
    );
  }
}
