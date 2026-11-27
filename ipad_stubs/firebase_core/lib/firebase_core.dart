// Versão iPad iOS 12: sem Firebase.
class FirebaseOptions {
  const FirebaseOptions({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.iosBundleId,
  });
  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String? iosBundleId;
}

class FirebaseApp {}

class Firebase {
  static List<FirebaseApp> get apps => <FirebaseApp>[];
  static Future<FirebaseApp> initializeApp(
          {String? name, FirebaseOptions? options}) async =>
      throw UnsupportedError('Notificações indisponíveis nesta versão iPad');
}
