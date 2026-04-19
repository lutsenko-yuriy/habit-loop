import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/remote_config/data/firebase_remote_config_service.dart';
import 'package:habit_loop/remote_config/domain/remote_config_defaults.dart';

// Hand-rolled fake — no firebase_remote_config import needed because the
// interface only exposes plain Dart types.
class FakeFirebaseRemoteConfigClient implements FirebaseRemoteConfigClient {
  final List<Map<String, Duration>> appliedSettings = [];
  final List<Map<String, dynamic>> appliedDefaults = [];
  int fetchAndActivateCallCount = 0;

  final Map<String, dynamic> _values = {};

  void setValue(String key, dynamic value) => _values[key] = value;

  @override
  Future<void> setConfigSettings({
    required Duration fetchTimeout,
    required Duration minimumFetchInterval,
  }) async {
    appliedSettings.add({
      'fetchTimeout': fetchTimeout,
      'minimumFetchInterval': minimumFetchInterval,
    });
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {
    appliedDefaults.add(defaults);
  }

  @override
  Future<bool> fetchAndActivate() async {
    fetchAndActivateCallCount++;
    return true;
  }

  @override
  int getInt(String key) {
    final value = _values[key];
    if (value is int) return value;
    return 0;
  }

  @override
  bool getBool(String key) {
    final value = _values[key];
    if (value is bool) return value;
    return false;
  }

  @override
  String getString(String key) {
    final value = _values[key];
    if (value is String) return value;
    return '';
  }

  @override
  double getDouble(String key) {
    final value = _values[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0.0;
  }
}

class _ThrowingFirebaseRemoteConfigClient
    implements FirebaseRemoteConfigClient {
  @override
  Future<void> setConfigSettings({
    required Duration fetchTimeout,
    required Duration minimumFetchInterval,
  }) async {
    throw Exception('Remote Config error');
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {
    throw Exception('Remote Config error');
  }

  @override
  Future<bool> fetchAndActivate() async {
    throw Exception('Remote Config error');
  }

  @override
  int getInt(String key) => throw Exception('Remote Config error');

  @override
  bool getBool(String key) => throw Exception('Remote Config error');

  @override
  String getString(String key) => throw Exception('Remote Config error');

  @override
  double getDouble(String key) => throw Exception('Remote Config error');
}

class _FetchThrowingClient implements FirebaseRemoteConfigClient {
  final List<Map<String, Duration>> appliedSettings = [];
  final List<Map<String, dynamic>> appliedDefaults = [];

  @override
  Future<void> setConfigSettings({
    required Duration fetchTimeout,
    required Duration minimumFetchInterval,
  }) async {
    appliedSettings.add({
      'fetchTimeout': fetchTimeout,
      'minimumFetchInterval': minimumFetchInterval,
    });
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {
    appliedDefaults.add(defaults);
  }

  @override
  Future<bool> fetchAndActivate() async {
    throw Exception('Network unavailable');
  }

  @override
  int getInt(String key) => 0;

  @override
  bool getBool(String key) => false;

  @override
  String getString(String key) => '';

  @override
  double getDouble(String key) => 0.0;
}

class _TrackingFirebaseRemoteConfigClient
    implements FirebaseRemoteConfigClient {
  _TrackingFirebaseRemoteConfigClient(this._log);
  final List<String> _log;

  @override
  Future<void> setConfigSettings({
    required Duration fetchTimeout,
    required Duration minimumFetchInterval,
  }) async {
    _log.add('setConfigSettings');
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {
    _log.add('setDefaults');
  }

  @override
  Future<bool> fetchAndActivate() async {
    _log.add('fetchAndActivate');
    return true;
  }

  @override
  int getInt(String key) => 0;

  @override
  bool getBool(String key) => false;

  @override
  String getString(String key) => '';

  @override
  double getDouble(String key) => 0.0;
}

void main() {
  late FakeFirebaseRemoteConfigClient fakeClient;
  late FirebaseRemoteConfigService service;

  setUp(() {
    fakeClient = FakeFirebaseRemoteConfigClient();
    service = FirebaseRemoteConfigService(fakeClient);
  });

  group('FirebaseRemoteConfigService.initialize', () {
    test('calls setConfigSettings, setDefaults, and fetchAndActivate in order',
        () async {
      final callOrder = <String>[];
      final trackingClient = _TrackingFirebaseRemoteConfigClient(callOrder);
      final trackingService = FirebaseRemoteConfigService(trackingClient);

      await trackingService.initialize();

      expect(callOrder, [
        'setConfigSettings',
        'setDefaults',
        'fetchAndActivate',
      ]);
    });

    test('calls setDefaults with RemoteConfigDefaults.all', () async {
      await service.initialize();
      expect(fakeClient.appliedDefaults.single, RemoteConfigDefaults.all);
    });

    test('calls fetchAndActivate once', () async {
      await service.initialize();
      expect(fakeClient.fetchAndActivateCallCount, 1);
    });

    test('swallows exception from setConfigSettings', () async {
      final throwingService = FirebaseRemoteConfigService(
        _ThrowingFirebaseRemoteConfigClient(),
      );
      await expectLater(throwingService.initialize(), completes);
    });

    test('swallows exception from fetchAndActivate', () async {
      final fetchThrowingService =
          FirebaseRemoteConfigService(_FetchThrowingClient());
      await expectLater(fetchThrowingService.initialize(), completes);
    });

    test('completes without throwing on success', () async {
      await expectLater(service.initialize(), completes);
    });
  });

  group('FirebaseRemoteConfigService.getInt', () {
    test('returns int value from client', () async {
      fakeClient.setValue('max_active_pacts', 5);

      final result = service.getInt('max_active_pacts');
      expect(result, 5);
    });

    test('returns in-code default when client throws', () {
      // The fallback fires when the client raises an exception during getInt.
      final throwingService = FirebaseRemoteConfigService(
        _ThrowingFirebaseRemoteConfigClient(),
      );
      final result = throwingService.getInt('max_active_pacts');
      expect(result, RemoteConfigDefaults.maxActivePacts);
    });

    test('returns default value when client throws', () {
      final throwingService = FirebaseRemoteConfigService(
        _ThrowingFirebaseRemoteConfigClient(),
      );
      final result = throwingService.getInt('max_active_pacts');
      expect(result, RemoteConfigDefaults.maxActivePacts);
    });

    test('does not throw when client throws', () {
      final throwingService = FirebaseRemoteConfigService(
        _ThrowingFirebaseRemoteConfigClient(),
      );
      expect(() => throwingService.getInt('max_active_pacts'), returnsNormally);
    });
  });

  group('FirebaseRemoteConfigService.getBool', () {
    test('returns true when client returns true', () {
      fakeClient.setValue('feature_flag', true);
      expect(service.getBool('feature_flag'), isTrue);
    });

    test('returns false when client returns false', () {
      fakeClient.setValue('feature_flag', false);
      expect(service.getBool('feature_flag'), isFalse);
    });

    test('returns false when client throws', () {
      final throwingService = FirebaseRemoteConfigService(
        _ThrowingFirebaseRemoteConfigClient(),
      );
      expect(throwingService.getBool('flag'), isFalse);
    });

    test('does not throw when client throws', () {
      final throwingService = FirebaseRemoteConfigService(
        _ThrowingFirebaseRemoteConfigClient(),
      );
      expect(() => throwingService.getBool('flag'), returnsNormally);
    });
  });

  group('FirebaseRemoteConfigService.getString', () {
    test('returns string value from client', () {
      fakeClient.setValue('greeting', 'hello');
      expect(service.getString('greeting'), 'hello');
    });

    test('returns empty string when client throws', () {
      final throwingService = FirebaseRemoteConfigService(
        _ThrowingFirebaseRemoteConfigClient(),
      );
      expect(throwingService.getString('key'), '');
    });

    test('does not throw when client throws', () {
      final throwingService = FirebaseRemoteConfigService(
        _ThrowingFirebaseRemoteConfigClient(),
      );
      expect(() => throwingService.getString('key'), returnsNormally);
    });
  });

  group('FirebaseRemoteConfigService.getDouble', () {
    test('returns double value from client', () {
      fakeClient.setValue('ratio', 3.14);
      expect(service.getDouble('ratio'), closeTo(3.14, 0.001));
    });

    test('returns 0.0 when client throws', () {
      final throwingService = FirebaseRemoteConfigService(
        _ThrowingFirebaseRemoteConfigClient(),
      );
      expect(throwingService.getDouble('key'), 0.0);
    });

    test('does not throw when client throws', () {
      final throwingService = FirebaseRemoteConfigService(
        _ThrowingFirebaseRemoteConfigClient(),
      );
      expect(() => throwingService.getDouble('key'), returnsNormally);
    });
  });
}
