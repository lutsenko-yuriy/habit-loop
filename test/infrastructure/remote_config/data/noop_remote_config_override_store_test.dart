import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/remote_config/data/noop_remote_config_override_store.dart';

void main() {
  late NoopRemoteConfigOverrideStore store;

  setUp(() {
    store = const NoopRemoteConfigOverrideStore();
  });

  group('NoopRemoteConfigOverrideStore', () {
    test('getOverride returns null for any key', () {
      expect(store.getOverride('max_active_pacts'), isNull);
      expect(store.getOverride('unknown_key'), isNull);
    });

    test('setOverride completes without throwing', () async {
      await expectLater(store.setOverride('max_active_pacts', '5'), completes);
    });

    test('clearOverride completes without throwing', () async {
      await expectLater(store.clearOverride('max_active_pacts'), completes);
    });

    test('getAllOverrides returns an empty map', () {
      expect(store.getAllOverrides(), isEmpty);
    });

    test('getOverride is unaffected by setOverride calls (no state)', () async {
      await store.setOverride('max_active_pacts', '10');
      expect(store.getOverride('max_active_pacts'), isNull);
    });
  });
}
