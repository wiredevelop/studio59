// Versão iPad iOS 12: sem notificações push.
enum AuthorizationStatus { authorized, denied, notDetermined, provisional }

class NotificationSettings {
  const NotificationSettings(this.authorizationStatus);
  final AuthorizationStatus authorizationStatus;
}

class FirebaseMessaging {
  FirebaseMessaging._();
  static final FirebaseMessaging instance = FirebaseMessaging._();
  Future<String?> getToken() async => null;
  Future<String?> getAPNSToken() async => null;
  Stream<String> get onTokenRefresh => const Stream<String>.empty();
  Future<NotificationSettings> requestPermission(
          {bool alert = true, bool badge = true, bool sound = true}) async =>
      const NotificationSettings(AuthorizationStatus.denied);
  Future<void> setForegroundNotificationPresentationOptions(
          {bool alert = false, bool badge = false, bool sound = false}) async {}
}
