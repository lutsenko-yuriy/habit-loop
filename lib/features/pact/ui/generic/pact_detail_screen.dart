import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/features/analytics/domain/analytics_screen.dart';
import 'package:habit_loop/features/analytics/ui/generic/analytics_providers.dart';
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
      ref.read(analyticsServiceProvider).logScreenView(AnalyticsScreen.pactDetail);
      ref.read(pactDetailViewModelProvider(widget.pactId).notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pactDetailViewModelProvider(widget.pactId));

    Future<void> onStopPact(String? reason) async {
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
