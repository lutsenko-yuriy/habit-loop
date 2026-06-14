import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/debug/ui/generic/rc_entry_edit_state.dart';
import 'package:habit_loop/slices/debug/ui/generic/remote_config_overrides_view_model.dart';

RemoteConfigEntry _entry({
  String key = 'k',
  String defaultValue = '5',
  String? overrideValue,
  String effectiveValue = '5',
  List<String>? allowedValues,
  ({int min, int max})? intRange,
}) =>
    RemoteConfigEntry(
      key: key,
      defaultValue: defaultValue,
      overrideValue: overrideValue,
      effectiveValue: effectiveValue,
      isFeatureToggle: false,
      allowedValues: allowedValues,
      intRange: intRange,
    );

void main() {
  group('RcEntryEditState.fromEntry — type selection', () {
    test('creates AllowedValues state when entry has allowedValues', () {
      final state = RcEntryEditState.fromEntry(
        _entry(allowedValues: ['real', 'local'], effectiveValue: 'real'),
      );
      expect(state, isA<RcEntryEditAllowedValues>());
    });

    test('AllowedValues — selects effectiveValue when it is in allowedValues', () {
      final state = RcEntryEditState.fromEntry(
        _entry(allowedValues: ['real', 'local'], effectiveValue: 'local'),
      ) as RcEntryEditAllowedValues;
      expect(state.selected, 'local');
    });

    test('AllowedValues — selects overrideValue when present and valid', () {
      final state = RcEntryEditState.fromEntry(
        _entry(allowedValues: ['real', 'local'], overrideValue: 'local', effectiveValue: 'local'),
      ) as RcEntryEditAllowedValues;
      expect(state.selected, 'local');
    });

    test('AllowedValues — falls back to first allowed value when override is stale', () {
      final state = RcEntryEditState.fromEntry(
        _entry(allowedValues: ['real', 'local'], overrideValue: 'stale', effectiveValue: 'real'),
      ) as RcEntryEditAllowedValues;
      expect(state.selected, 'real');
    });

    test('creates IntRange state when entry has intRange (and no allowedValues)', () {
      final state = RcEntryEditState.fromEntry(
        _entry(intRange: (min: 0, max: 100), effectiveValue: '50'),
      );
      expect(state, isA<RcEntryEditIntRange>());
    });

    test('IntRange — initialises sliderValue from overrideValue', () {
      final state = RcEntryEditState.fromEntry(
        _entry(intRange: (min: 0, max: 100), overrideValue: '72', effectiveValue: '50'),
      ) as RcEntryEditIntRange;
      expect(state.sliderValue, 72.0);
    });

    test('IntRange — clamps overrideValue to range max', () {
      final state = RcEntryEditState.fromEntry(
        _entry(intRange: (min: 0, max: 100), overrideValue: '200', effectiveValue: '50'),
      ) as RcEntryEditIntRange;
      expect(state.sliderValue, 100.0);
    });

    test('IntRange — clamps overrideValue to range min', () {
      final state = RcEntryEditState.fromEntry(
        _entry(intRange: (min: 10, max: 100), overrideValue: '0', effectiveValue: '10'),
      ) as RcEntryEditIntRange;
      expect(state.sliderValue, 10.0);
    });

    test('IntRange — falls back to range min when override is non-numeric', () {
      final state = RcEntryEditState.fromEntry(
        _entry(intRange: (min: 5, max: 100), overrideValue: 'bad', effectiveValue: '50'),
      ) as RcEntryEditIntRange;
      expect(state.sliderValue, 5.0);
    });

    test('creates FreeText state for plain entry', () {
      final state = RcEntryEditState.fromEntry(_entry());
      expect(state, isA<RcEntryEditFreeText>());
      (state as RcEntryEditFreeText).dispose();
    });

    test('FreeText — controller text is overrideValue when present', () {
      final state = RcEntryEditState.fromEntry(
        _entry(overrideValue: '9', effectiveValue: '9'),
      ) as RcEntryEditFreeText;
      expect(state.controller.text, '9');
      state.dispose();
    });

    test('FreeText — controller text is empty when no override', () {
      final state = RcEntryEditState.fromEntry(_entry()) as RcEntryEditFreeText;
      expect(state.controller.text, '');
      state.dispose();
    });
  });

  group('computeSaveValue', () {
    test('AllowedValues — returns selected string', () {
      expect(const RcEntryEditAllowedValues(selected: 'local').computeSaveValue(), 'local');
    });

    test('AllowedValues — returns null when nothing is selected', () {
      expect(const RcEntryEditAllowedValues(selected: null).computeSaveValue(), isNull);
    });

    test('IntRange — rounds and stringifies slider value', () {
      expect(const RcEntryEditIntRange(sliderValue: 72.7).computeSaveValue(), '73');
    });

    test('IntRange — handles exact integer value', () {
      expect(const RcEntryEditIntRange(sliderValue: 50.0).computeSaveValue(), '50');
    });

    test('FreeText — returns trimmed non-empty text', () {
      final state = RcEntryEditFreeText(controller: TextEditingController(text: '  9  '));
      expect(state.computeSaveValue(), '9');
      state.dispose();
    });

    test('FreeText — returns null for whitespace-only input', () {
      final state = RcEntryEditFreeText(controller: TextEditingController(text: '   '));
      expect(state.computeSaveValue(), isNull);
      state.dispose();
    });

    test('FreeText — returns null for empty input', () {
      final state = RcEntryEditFreeText(controller: TextEditingController());
      expect(state.computeSaveValue(), isNull);
      state.dispose();
    });
  });

  group('copy helpers', () {
    test('AllowedValues.withSelected produces updated copy', () {
      const original = RcEntryEditAllowedValues(selected: 'real');
      final updated = original.withSelected('local');
      expect(updated.selected, 'local');
    });

    test('IntRange.withSliderValue produces updated copy', () {
      const original = RcEntryEditIntRange(sliderValue: 50.0);
      final updated = original.withSliderValue(80.0);
      expect(updated.sliderValue, 80.0);
    });
  });
}
