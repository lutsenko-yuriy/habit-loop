import 'package:habit_loop/infrastructure/device/contracts/device_id_service.dart';

final class NoopDeviceIdService implements DeviceIdService {
  static const sentinelId = '00000000-0000-0000-0000-000000000000';

  @override
  Future<String> getOrCreateDeviceId() async => sentinelId;
}
