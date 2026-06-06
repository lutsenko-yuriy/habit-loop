import 'package:habit_loop/domain/pact/schedule_type.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';

// Re-export ScheduleType so all existing import sites that import
// pact_creation_state.dart continue to resolve ScheduleType without change.
export 'package:habit_loop/domain/pact/schedule_type.dart' show ScheduleType;

// Each value maps to its PageView page index — matches [goToPage] and int conversion.
enum PactWizardStep {
  habitName(0),
  duration(1),
  showupDuration(2),
  schedule(3),
  reminder(4),
  summary(5);

  const PactWizardStep(this.value);
  final int value;

  static int get count => PactWizardStep.values.length;

  bool get isFirst => this == PactWizardStep.values.first;
  bool get isLast => this == PactWizardStep.values.last;

  // Camel→snake for analytics events, e.g. habitName → 'habit_name'.
  String get analyticsName => name.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (m) => '_${m[0]!.toLowerCase()}',
      );
}

// Wizard-navigation state; pact-data fields are owned by [PactBuilder] (accessed via proxy getters).
class PactCreationState {
  static int get totalSteps => PactWizardStep.count;

  /// The pact-data currently being assembled by the wizard.
  final PactBuilder builder;

  final PactWizardStep currentStep;
  final bool commitmentAccepted;

  // true if user jumped back from the summary screen; false if they swiped linearly.
  final bool usedSummaryJump;

  final bool isSubmitting;
  final Object? submitError;

  PactCreationState({
    required DateTime today,
    PactBuilder? builder,
    this.currentStep = PactWizardStep.habitName,
    this.commitmentAccepted = false,
    this.usedSummaryJump = false,
    this.isSubmitting = false,
    this.submitError,
  }) : builder = builder ?? PactBuilder(today: today);

  PactCreationState._internal({
    required this.builder,
    required this.currentStep,
    required this.commitmentAccepted,
    required this.usedSummaryJump,
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
  // copyWith — wizard concerns only; data-field params removed.
  // ---------------------------------------------------------------------------

  PactCreationState copyWith({
    PactBuilder? builder,
    PactWizardStep? currentStep,
    bool? commitmentAccepted,
    bool? usedSummaryJump,
    bool? isSubmitting,
    Object? submitError,
    bool clearSubmitError = false,
  }) {
    return PactCreationState._internal(
      builder: builder ?? this.builder,
      currentStep: currentStep ?? this.currentStep,
      commitmentAccepted: commitmentAccepted ?? this.commitmentAccepted,
      usedSummaryJump: usedSummaryJump ?? this.usedSummaryJump,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}
