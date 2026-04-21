import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/features/showup/analytics/showup_analytics_events.dart';
import 'package:habit_loop/features/showup/ui/android/showup_detail_page_android.dart';
import 'package:habit_loop/features/showup/ui/generic/showup_detail_view_model.dart';
import 'package:habit_loop/features/showup/ui/ios/showup_detail_page_ios.dart';

/// Platform-adaptive showup detail screen.
///
/// Delegates to [ShowupDetailPageIos] on iOS and [ShowupDetailPageAndroid]
/// on other platforms. Triggers [ShowupDetailViewModel.load] on first build.
class ShowupDetailScreen extends ConsumerStatefulWidget {
  /// The ID of the showup to display.
  final String showupId;

  const ShowupDetailScreen({super.key, required this.showupId});

  @override
  ConsumerState<ShowupDetailScreen> createState() => _ShowupDetailScreenState();
}

class _ShowupDetailScreenState extends ConsumerState<ShowupDetailScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(() {
        unawaited(
          ref
              .read(analyticsServiceProvider)
              .logScreenView(const ShowupDetailAnalyticsScreen()),
        );
        // Invalidate the now provider so load() always samples the real current
        // time, not a cached value from a previous navigation or app start.
        ref.invalidate(showupDetailNowProvider);
        unawaited(
          ref
              .read(showupDetailViewModelProvider(widget.showupId).notifier)
              .load(),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(showupDetailViewModelProvider(widget.showupId));

    Future<void> onMarkDone() async {
      await ref
          .read(showupDetailViewModelProvider(widget.showupId).notifier)
          .markDone();
    }

    Future<void> onMarkFailed() async {
      await ref
          .read(showupDetailViewModelProvider(widget.showupId).notifier)
          .markFailed();
    }

    Future<void> onSaveNote(String note) async {
      await ref
          .read(showupDetailViewModelProvider(widget.showupId).notifier)
          .saveNote(note);
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ShowupDetailPageIos(
        state: state,
        onMarkDone: onMarkDone,
        onMarkFailed: onMarkFailed,
        onSaveNote: onSaveNote,
      );
    }
    return ShowupDetailPageAndroid(
      state: state,
      onMarkDone: onMarkDone,
      onMarkFailed: onMarkFailed,
      onSaveNote: onSaveNote,
    );
  }
}
