import 'package:flutter/widgets.dart';
import 'package:habit_loop/slices/debug/ui/generic/remote_config_overrides_view_model.dart';

sealed class RcEntryEditState {
  const RcEntryEditState();

  factory RcEntryEditState.fromEntry(RemoteConfigEntry entry) {
    if (entry.hasAllowedValues) {
      final effective = entry.overrideValue ?? entry.effectiveValue;
      final initial = entry.allowedValues!.contains(effective) ? effective : entry.allowedValues!.first;
      return RcEntryEditAllowedValues(selected: initial);
    } else if (entry.hasIntRange) {
      final range = entry.intRange!;
      final raw = int.tryParse(entry.overrideValue ?? entry.effectiveValue) ?? range.min;
      return RcEntryEditIntRange(sliderValue: raw.clamp(range.min, range.max).toDouble());
    } else {
      return RcEntryEditFreeText(controller: TextEditingController(text: entry.overrideValue ?? ''));
    }
  }

  String? computeSaveValue();
}

final class RcEntryEditAllowedValues extends RcEntryEditState {
  const RcEntryEditAllowedValues({required this.selected});
  final String? selected;

  @override
  String? computeSaveValue() => selected;

  RcEntryEditAllowedValues withSelected(String? v) => RcEntryEditAllowedValues(selected: v);
}

final class RcEntryEditIntRange extends RcEntryEditState {
  const RcEntryEditIntRange({required this.sliderValue});
  final double sliderValue;

  @override
  String? computeSaveValue() => sliderValue.round().toString();

  RcEntryEditIntRange withSliderValue(double v) => RcEntryEditIntRange(sliderValue: v);
}

final class RcEntryEditFreeText extends RcEntryEditState {
  const RcEntryEditFreeText({required this.controller});
  final TextEditingController controller;

  @override
  String? computeSaveValue() {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  void dispose() => controller.dispose();
}
