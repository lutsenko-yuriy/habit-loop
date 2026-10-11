import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/navigation/link_deduper.dart';

void main() {
  final a = Uri.parse('habitloop://checklist/selected?pactId=p1&status=cancelled');
  final b = Uri.parse('habitloop://checklist/selected?pactId=p2&status=cancelled');

  late DateTime now;
  late LinkDeduper deduper;

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    deduper = LinkDeduper(window: const Duration(seconds: 2), now: () => now);
  });

  test('first delivery is not a duplicate', () {
    expect(deduper.isDuplicate(a), isFalse);
  });

  test('same uri inside the window is a duplicate', () {
    deduper.isDuplicate(a);
    now = now.add(const Duration(milliseconds: 500));
    expect(deduper.isDuplicate(a), isTrue);
  });

  test('same uri after the window is accepted again', () {
    deduper.isDuplicate(a);
    now = now.add(const Duration(seconds: 3));
    expect(deduper.isDuplicate(a), isFalse);
  });

  test('a different uri is never a duplicate', () {
    deduper.isDuplicate(a);
    expect(deduper.isDuplicate(b), isFalse);
  });

  test('an interleaved different uri resets the comparison', () {
    deduper.isDuplicate(a);
    deduper.isDuplicate(b);
    expect(deduper.isDuplicate(a), isFalse);
  });
}
