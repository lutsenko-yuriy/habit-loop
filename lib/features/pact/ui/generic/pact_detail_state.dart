import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';

class PactDetailState {
  final Pact? pact;
  final PactStats? stats;
  final bool isLoading;
  final Object? loadError;
  final bool isStopping;
  final Object? stopError;

  const PactDetailState({
    this.pact,
    this.stats,
    this.isLoading = true,
    this.loadError,
    this.isStopping = false,
    this.stopError,
  });

  PactDetailState copyWith({
    Pact? pact,
    PactStats? stats,
    bool? isLoading,
    Object? loadError,
    bool clearLoadError = false,
    bool? isStopping,
    Object? stopError,
    bool clearStopError = false,
  }) {
    return PactDetailState(
      pact: pact ?? this.pact,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      isStopping: isStopping ?? this.isStopping,
      stopError: clearStopError ? null : (stopError ?? this.stopError),
    );
  }
}
