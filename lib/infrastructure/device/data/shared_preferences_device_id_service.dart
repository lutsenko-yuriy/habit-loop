import 'package:habit_loop/infrastructure/device/contracts/device_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final class SharedPreferencesDeviceIdService implements DeviceIdService {
  SharedPreferencesDeviceIdService(this._prefs);

  static const prefsKey = 'habit_loop_device_id';

  final SharedPreferences _prefs;

  @override
  Future<String> getOrCreateDeviceId() async {
    final stored = _prefs.getString(prefsKey);
    if (stored != null) return stored;
    final id = const Uuid().v4();
    await _prefs.setString(prefsKey, id);
    return id;
  }
}
