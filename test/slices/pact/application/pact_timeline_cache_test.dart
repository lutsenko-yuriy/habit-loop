import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_cache.dart';

Showup _showup(String id, String pactId) => Showup(
      id: id,
      pactId: pactId,
      scheduledAt: DateTime(2024, 1, 1, 8),
      duration: const Duration(minutes: 30),
      status: ShowupStatus.done,
    );

void main() {
  group('PactTimelineCache', () {
    group('get', () {
      test('returns null for unknown pactId', () {
        final cache = PactTimelineCache();
        expect(cache.get('p1'), isNull);
      });

      test('returns showups after populate', () {
        final cache = PactTimelineCache();
        final showups = [_showup('s1', 'p1'), _showup('s2', 'p1')];
        cache.populate('p1', showups);
        expect(cache.get('p1'), showups);
      });

      test('returns null after evict', () {
        final cache = PactTimelineCache();
        cache.populate('p1', [_showup('s1', 'p1')]);
        cache.evict('p1');
        expect(cache.get('p1'), isNull);
      });
    });

    group('populate', () {
      test('overwrites previous entry for same pactId', () {
        final cache = PactTimelineCache();
        final v1 = [_showup('s1', 'p1')];
        final v2 = [_showup('s2', 'p1'), _showup('s3', 'p1')];
        cache.populate('p1', v1);
        cache.populate('p1', v2);
        expect(cache.get('p1'), v2);
      });
    });

    group('evict', () {
      test('is a no-op for unknown pactId', () {
        final cache = PactTimelineCache();
        expect(() => cache.evict('unknown'), returnsNormally);
      });

      test('only evicts the targeted pactId', () {
        final cache = PactTimelineCache();
        cache.populate('p1', [_showup('s1', 'p1')]);
        cache.populate('p2', [_showup('s2', 'p2')]);
        cache.evict('p1');
        expect(cache.get('p1'), isNull);
        expect(cache.get('p2'), isNotNull);
      });
    });

    group('per-pactId isolation', () {
      test('separate pactIds do not interfere', () {
        final cache = PactTimelineCache();
        final p1 = [_showup('s1', 'p1')];
        final p2 = [_showup('s2', 'p2'), _showup('s3', 'p2')];
        cache.populate('p1', p1);
        cache.populate('p2', p2);
        expect(cache.get('p1'), p1);
        expect(cache.get('p2'), p2);
      });
    });
  });
}
