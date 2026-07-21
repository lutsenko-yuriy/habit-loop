import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/theme/spacing.dart';

void main() {
  test('AppSpacing exposes an ascending, distinct scale', () {
    const scale = [
      AppSpacing.s0,
      AppSpacing.s2,
      AppSpacing.s4,
      AppSpacing.s6,
      AppSpacing.s8,
      AppSpacing.s10,
      AppSpacing.s12,
      AppSpacing.s14,
      AppSpacing.s16,
      AppSpacing.s20,
      AppSpacing.s24,
      AppSpacing.s32,
    ];

    expect(scale.toSet().length, scale.length, reason: 'every step of the scale must be distinct');
    for (var i = 1; i < scale.length; i++) {
      expect(scale[i], greaterThan(scale[i - 1]), reason: 'scale must be strictly ascending');
    }
  });

  test('AppSpacing values match the documented scale', () {
    expect(AppSpacing.s0, 0);
    expect(AppSpacing.s2, 2);
    expect(AppSpacing.s4, 4);
    expect(AppSpacing.s6, 6);
    expect(AppSpacing.s8, 8);
    expect(AppSpacing.s10, 10);
    expect(AppSpacing.s12, 12);
    expect(AppSpacing.s14, 14);
    expect(AppSpacing.s16, 16);
    expect(AppSpacing.s20, 20);
    expect(AppSpacing.s24, 24);
    expect(AppSpacing.s32, 32);
  });
}
