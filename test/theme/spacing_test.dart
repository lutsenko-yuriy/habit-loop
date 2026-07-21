import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/theme/spacing.dart';

void main() {
  test('AppSpacing exposes an ascending, distinct scale', () {
    const scale = [AppSpacing.xs, AppSpacing.sm, AppSpacing.md, AppSpacing.lg, AppSpacing.xl];

    expect(scale.toSet().length, scale.length, reason: 'every step of the scale must be distinct');
    for (var i = 1; i < scale.length; i++) {
      expect(scale[i], greaterThan(scale[i - 1]), reason: 'scale must be strictly ascending');
    }
  });

  test('AppSpacing values match the documented scale', () {
    expect(AppSpacing.xs, 4);
    expect(AppSpacing.sm, 8);
    expect(AppSpacing.md, 12);
    expect(AppSpacing.lg, 16);
    expect(AppSpacing.xl, 24);
  });
}
