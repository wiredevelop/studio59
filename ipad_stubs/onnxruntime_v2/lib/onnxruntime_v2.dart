// Versão iPad iOS 12: sem reconhecimento facial local (é feito no PC/servidor).
import 'dart:typed_data';

Never _off() =>
    throw UnsupportedError('Reconhecimento facial local indisponível no iPad');

class OrtEnv {
  OrtEnv._();
  static final OrtEnv instance = OrtEnv._();
  void init() => _off();
}

class OrtSessionOptions {
  OrtSessionOptions setIntraOpNumThreads(int n) => this;
}

class OrtRunOptions {
  void release() {}
}

class OrtValue {
  Object? get value => null;
  void release() {}
}

class OrtValueTensor extends OrtValue {
  static OrtValueTensor createTensorWithDataList(
          Float32List data, List<int> shape) =>
      _off();
}

class OrtSession {
  static OrtSession fromBuffer(Uint8List bytes, OrtSessionOptions options) =>
      _off();
  List<String> get inputNames => const <String>[];
  Future<List<OrtValue?>?> runAsyncWithTimeout(OrtRunOptions runOptions,
          Map<String, OrtValue> inputs, Duration timeout) async =>
      _off();
  Future<void> release() async {}
}
