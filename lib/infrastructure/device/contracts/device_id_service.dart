abstract interface class DeviceIdService {
  /// Returns the stable device UUID, generating and persisting it on first call.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<String> getOrCreateDeviceId();
}
