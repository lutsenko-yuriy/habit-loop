import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/features/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/features/pact/ui/android/pact_detail_page_android.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/features/pact/ui/ios/pact_detail_page_ios.dart';

class PactDetailScreen extends ConsumerStatefulWidget {
  final String pactId;

  const PactDetailScreen({super.key, required this.pactId});

  @override
  ConsumerState<PactDetailScreen> createState() => _PactDetailScreenState();
}

class _PactDetailScreenState extends ConsumerState<PactDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(analyticsServiceProvider).logScreenView(const PactDetailAnalyticsScreen());
      // Invalidate so load() always samples the real current time, not a
      // cached value from a previous navigation or app start. Mirrors the
      // ref.invalidate(showupDetailNowProvider) pattern in ShowupDetailScreen.
      ref.invalidate(pactDetailNowProvider);
      ref.read(pactDetailViewModelProvider(widget.pactId).notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pactDetailViewModelProvider(widget.pactId));

    Future<void> onStopPact(String? reason) async {
      // Invalidate so stopPact() samples the real current time even if the
      // screen has been open for an extended period.
      ref.invalidate(pactDetailNowProvider);
      await ref
          .read(pactDetailViewModelProvider(widget.pactId).notifier)
          .stopPact(reason);
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return PactDetailPageIos(state: state, onStopPact: onStopPact);
    }
    return PactDetailPageAndroid(state: state, onStopPact: onStopPact);
  }
}
