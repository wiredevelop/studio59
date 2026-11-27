// Versão iPad iOS 12: sem biometria.
enum BiometricType { face, fingerprint, iris, strong, weak }

class AuthenticationOptions {
  const AuthenticationOptions({
    this.stickyAuth = false,
    this.biometricOnly = false,
    this.useErrorDialogs = true,
    this.sensitiveTransaction = true,
  });
  final bool stickyAuth;
  final bool biometricOnly;
  final bool useErrorDialogs;
  final bool sensitiveTransaction;
}

class LocalAuthentication {
  Future<bool> isDeviceSupported() async => false;
  Future<bool> get canCheckBiometrics async => false;
  Future<List<BiometricType>> getAvailableBiometrics() async =>
      <BiometricType>[];
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object> authMessages = const <Object>[],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async =>
      false;
}
