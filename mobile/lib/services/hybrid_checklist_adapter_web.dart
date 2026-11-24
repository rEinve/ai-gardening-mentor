import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'firebase_garden_backend.dart';
import 'hybrid_checklist_contract.dart';

@JS('gardenHybridAi')
external _JsGardenHybridAi? get _jsBridge;

extension type _JsGardenHybridAi(JSObject _) implements JSObject {
  external JSPromise<JSString> checkCapability(JSString configJson);
  external JSPromise<JSString> prepareModel(
    JSString configJson,
    JSFunction onProgress,
  );
  external JSPromise<JSString> generateChecklist(JSString paramsJson);
  external void cancel(JSString requestId);
}

HybridChecklistAdapter createPlatformHybridAdapter() {
  return WebHybridChecklistAdapter();
}

/// Web adapter backed by locally bundled Firebase JS SDK (`firebase/ai` hybrid API).
class WebHybridChecklistAdapter implements HybridChecklistAdapter {
  static const String _recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

  Map<String, dynamic> _firebaseConfig() => {
        'apiKey': FirebaseRuntimeConfig.apiKey,
        'appId': FirebaseRuntimeConfig.appId,
        'messagingSenderId': FirebaseRuntimeConfig.messagingSenderId,
        'projectId': FirebaseRuntimeConfig.projectId,
        'authDomain': FirebaseRuntimeConfig.authDomain.isNotEmpty
            ? FirebaseRuntimeConfig.authDomain
            : '${FirebaseRuntimeConfig.projectId}.firebaseapp.com',
        'storageBucket': FirebaseRuntimeConfig.storageBucket.isNotEmpty
            ? FirebaseRuntimeConfig.storageBucket
            : '${FirebaseRuntimeConfig.projectId}.firebasestorage.app',
        if (_recaptchaSiteKey.isNotEmpty) 'recaptchaSiteKey': _recaptchaSiteKey,
      };

  static HybridCapabilityStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'ready':
        return HybridCapabilityStatus.ready;
      case 'downloadAvailable':
        return HybridCapabilityStatus.downloadAvailable;
      case 'downloading':
        return HybridCapabilityStatus.downloading;
      case 'error':
        return HybridCapabilityStatus.error;
      case 'unsupported':
      default:
        return HybridCapabilityStatus.unsupported;
    }
  }

  static HybridInferenceSource _parseSource(String? raw) {
    switch (raw) {
      case 'onDevice':
        return HybridInferenceSource.onDevice;
      case 'inCloud':
        return HybridInferenceSource.inCloud;
      default:
        return HybridInferenceSource.unknown;
    }
  }

  @override
  Future<HybridCapabilityInfo> checkCapability() async {
    final bridge = _jsBridge;
    if (bridge == null) {
      return const HybridCapabilityInfo(
        status: HybridCapabilityStatus.error,
        platformLabel: 'Web',
        message: 'Local hybrid_ai.bundle.js bridge is not loaded.',
      );
    }
    try {
      final jsRes = await bridge.checkCapability(jsonEncode(_firebaseConfig()).toJS).toDart;
      final map = jsonDecode(jsRes.toDart) as Map<String, dynamic>;
      return HybridCapabilityInfo(
        status: _parseStatus(map['status'] as String?),
        platformLabel: (map['platformLabel'] as String?) ?? 'Web',
        modelIdentity: map['modelIdentity'] as String?,
        downloadProgress: (map['downloadProgress'] as num?)?.toDouble(),
        message: map['message'] as String?,
      );
    } catch (err) {
      return HybridCapabilityInfo(
        status: HybridCapabilityStatus.error,
        platformLabel: 'Web',
        message: 'Capability check failed: $err',
      );
    }
  }

  @override
  Stream<HybridCapabilityInfo> prepareModel() {
    final controller = StreamController<HybridCapabilityInfo>();
    final bridge = _jsBridge;
    if (bridge == null) {
      controller.add(
        const HybridCapabilityInfo(
          status: HybridCapabilityStatus.error,
          platformLabel: 'Web',
          message: 'Local hybrid_ai.bundle.js bridge is not loaded.',
        ),
      );
      controller.close();
      return controller.stream;
    }

    controller.add(
      const HybridCapabilityInfo(
        status: HybridCapabilityStatus.downloading,
        platformLabel: 'Web (Desktop Chrome + Firebase JS AI Logic)',
        downloadProgress: 0.0,
        message: 'Preparing on-device model...',
      ),
    );

    final progressCb = ((JSNumber p) {
      if (!controller.isClosed) {
        controller.add(
          HybridCapabilityInfo(
            status: HybridCapabilityStatus.downloading,
            platformLabel: 'Web (Desktop Chrome + Firebase JS AI Logic)',
            downloadProgress: p.toDartDouble.clamp(0.0, 1.0),
            message: 'Downloading on-device model...',
          ),
        );
      }
    }).toJS;

    () async {
      try {
        final jsRes = await bridge
            .prepareModel(jsonEncode(_firebaseConfig()).toJS, progressCb)
            .toDart;
        final map = jsonDecode(jsRes.toDart) as Map<String, dynamic>;
        if (!controller.isClosed) {
          controller.add(
            HybridCapabilityInfo(
              status: _parseStatus(map['status'] as String?),
              platformLabel: (map['platformLabel'] as String?) ?? 'Web',
              modelIdentity: map['modelIdentity'] as String?,
              downloadProgress: (map['downloadProgress'] as num?)?.toDouble(),
              message: map['message'] as String?,
            ),
          );
        }
      } catch (err) {
        if (!controller.isClosed) {
          controller.add(
            HybridCapabilityInfo(
              status: HybridCapabilityStatus.error,
              platformLabel: 'Web',
              message: 'Preparation error: $err',
            ),
          );
        }
      } finally {
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }();

    return controller.stream;
  }

  @override
  Future<HybridChecklistResult> generateChecklist({
    required String prompt,
    required HybridInferenceMode mode,
    required String requestId,
    String cloudModel = 'gemini-3.8-flash',
  }) async {
    final bridge = _jsBridge;
    if (bridge == null) {
      return HybridChecklistResult(
        requestId: requestId,
        inferenceSource: HybridInferenceSource.unknown,
        elapsedMs: 0,
        errorCode: 'BRIDGE_MISSING',
        errorMessage: 'Local hybrid_ai.bundle.js bridge is not loaded.',
      );
    }

    try {
      final payload = jsonEncode({
        'requestId': requestId,
        'prompt': prompt,
        'mode': mode.name,
        'cloudModel': cloudModel,
        'config': _firebaseConfig(),
      });
      final jsRes = await bridge.generateChecklist(payload.toJS).toDart;
      final map = jsonDecode(jsRes.toDart) as Map<String, dynamic>;
      return HybridChecklistResult(
        requestId: (map['requestId'] as String?) ?? requestId,
        text: map['text'] as String?,
        inferenceSource: _parseSource(map['inferenceSource'] as String?),
        elapsedMs: (map['elapsedMs'] as num?)?.toInt() ?? 0,
        modelIdentity: map['modelIdentity'] as String?,
        errorCode: map['errorCode'] as String?,
        errorMessage: map['errorMessage'] as String?,
      );
    } catch (err) {
      return HybridChecklistResult(
        requestId: requestId,
        inferenceSource: HybridInferenceSource.unknown,
        elapsedMs: 0,
        errorCode: 'JS_INTEROP_ERROR',
        errorMessage: err.toString(),
      );
    }
  }

  @override
  Future<void> cancel(String requestId) async {
    _jsBridge?.cancel(requestId.toJS);
  }

  @override
  void dispose() {}
}
