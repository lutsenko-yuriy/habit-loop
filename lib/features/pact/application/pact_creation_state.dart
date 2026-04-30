import 'package:habit_loop/domain/pact/schedule_type.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/features/pact/application/pact_builder.dart';

// Re-export ScheduleType so all existing import sites that import
// pact_creation_state.dart continue to resolve ScheduleType without change.
export 'package:habit_loop/domain/pact/schedule_type.dart' show ScheduleType;

enum PactCreationStep {
  pactDuration(0),
  showupDuration(1),
  schedule(2),
  reminder(3),
  commitment(4);

  const PactCreationStep(this.value);
  final int value;

  static int get count => PactCreationStep.values.length;

  bool get isFirst => this == PactCreationStep.values.first;
  bool get isLast => this == PactCreationStep.values.last;

  PactCreationStep? get next {
    final i = index + 1;
    return i < PactCreationStep.values.length ? PactCreationStep.values[i] : null;
  }

  PactCreationStep? get previous {
    final i = index - 1;
    return i >= 0 ? PactCreationStep.values[i] : null;
  }
}

/// Wizard-navigation state for the pact creation flow.
///
/// Pact-data fields (habit name, dates, schedule, etc.) are owned by
/// [PactBuilder], which is held here as [builder]. Proxy getters expose the
/// builder's fields directly so widget code that reads `state.habitName`,
/// `state.startDate`, etc. requires no changes.
class PactCreationState {
  static int get totalSteps => PactCreationStep.count;

  /// The pact-data currently being assembled by the wizard.
  final PactBuilder builder;

  final PactCreationStep currentStep;
  final bool commitmentAccepted;
  final bool isSubmitting;
  final Object? submitError;

  PactCreationState({
    required DateTime today,
    PactBuilder? builder,
    this.currentStep = PactCreationStep.pactDuration,
    this.commitmentAccepted = false,
    this.isSubmitting = false,
    this.submitError,
  }) : builder = builder ?? PactBuilder(today: today);

  PactCreationState._internal({
    required this.builder,
    required this.currentStep,
    required this.commitmentAccepted,
    required this.isSubmitting,
    required this.submitError,
  });

  // ---------------------------------------------------------------------------
  // Proxy getters — delegate to builder so widget code is unchanged.
  // ---------------------------------------------------------------------------

  String get habitName => builder.habitName;
  DateTime get startDate => builder.startDate;
  DateTime get endDate => builder.endDate;
  Duration? get showupDuration => builder.showupDuration;
  ScheduleType? get scheduleType => builder.scheduleType;
  ShowupSchedule? get schedule => builder.schedule;
  Duration? get reminderOffset => builder.reminderOffset;

  // ---------------------------------------------------------------------------
  // Step-validation dispatch table — each step delegates to a builder predicate.
  // ---------------------------------------------------------------------------

  bool get canAdvanceFromStep {
    switch (currentStep) {
      case PactCreationStep.pactDuration:
        return builder.isDateRangeValid;
      case PactCreationStep.showupDuration:
        return builder.isShowupDurationValid;
      case PactCreationStep.schedule:
        return builder.isScheduleSet;
      case PactCreationStep.reminder:
        return true;
      case PactCreationStep.commitment:
        return commitmentAccepted && builder.isHabitNameValid;
    }
  }

  // ---------------------------------------------------------------------------
  // copyWith — wizard concerns only; data-field params removed.
  // ---------------------------------------------------------------------------

  PactCreationState copyWith({
    PactBuilder? builder,
    PactCreationStep? currentStep,
    bool? commitmentAccepted,
    bool? isSubmitting,
    Object? submitError,
    bool clearSubmitError = false,
  }) {
    return PactCreationState._internal(
      builder: builder ?? this.builder,
      currentStep: currentStep ?? this.currentStep,
      commitmentAccepted: commitmentAccepted ?? this.commitmentAccepted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}
