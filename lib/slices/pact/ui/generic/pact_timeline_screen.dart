import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_timeline_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_view_model.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_timeline_page_ios.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_screen.dart';

class PactTimelineScreen extends ConsumerStatefulWidget {
  final String pactId;

  const PactTimelineScreen({super.key, required this.pactId});

  @override
  ConsumerState<PactTimelineScreen> createState() => _PactTimelineScreenState();
}

class _PactTimelineScreenState extends ConsumerState<PactTimelineScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(() {
        unawaited(
          ref.read(analyticsServiceProvider).logScreenView(
                PactTimelineAnalyticsScreen(
                  pactId: widget.pactId,
                  pactStatus: '',
                  totalShowupCount: 0,
                ),
              ),
        );
        ref.invalidate(pactTimelineNowProvider);
        unawaited(
          ref.read(pactTimelineViewModelProvider(widget.pactId).notifier).load(),
        );
      }),
    );
  }

  Future<void> _onMilestoneTapped(PactTimelineMilestone milestone) async {
    ref.read(pactTimelineViewModelProvider(widget.pactId).notifier).onMilestoneTapped(milestone);

    final showupId = switch (milestone) {
      NotedShowupMilestone m => m.showupId,
      SingleShowupMilestone m => m.showupId,
      _ => null,
    };
    if (showupId == null || !mounted) return;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(builder: (_) => ShowupDetailScreen(showupId: showupId)),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ShowupDetailScreen(showupId: showupId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pactTimelineViewModelProvider(widget.pactId));

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return PactTimelinePageIos(
        state: state,
        onMilestoneTapped: _onMilestoneTapped,
      );
    }
    // Android page implemented in WU7.
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
