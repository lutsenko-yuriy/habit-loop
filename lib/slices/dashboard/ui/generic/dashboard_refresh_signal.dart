import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cross-slice signal: any slice may increment this to request a full dashboard
/// reload. Dashboard listens in [DashboardViewModel.build].
final dashboardRefreshSignalProvider = StateProvider<int>((ref) => 0);
