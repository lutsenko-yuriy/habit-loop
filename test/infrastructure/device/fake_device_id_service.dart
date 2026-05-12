import 'package:habit_loop/infrastructure/device/contracts/device_id_service.dart';

class FakeDeviceIdService implements DeviceIdService {
  FakeDeviceIdService({this.deviceId = 'test-device-id'});

  final String deviceId;

  @override
  Future<String> getOrCreateDeviceId() async => deviceId;
}
