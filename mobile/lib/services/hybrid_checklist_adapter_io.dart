import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'hybrid_checklist_contract.dart';

HybridChecklistAdapter createPlatformHybridAdapter() {
  if (Platform.isAndroid) {
    return AndroidHybridChecklistAdapter();
  }
  return UnsupportedHybridChecklistAdapter(
    platformLabel: Platform.operatingSystem,
  );
}

/// Android native MethodChannel / EventChannel adapter backed by
/// Kotlin `firebase-ai` + `firebase-ai-ondevice` (`FirebaseAIOnDevice` + `OnDeviceConfig`).
class AndroidHybridChecklistAdapter implements HybridChecklistAdapter {
  static const MethodChannel _channel =
      MethodChannel('com.example.ai_gardening_mentor/hybrid_ai');
  static const EventChannel _progressChannel =
      EventChannel('com.example.ai_gardening_mentor/hybrid_ai_progress');

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
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('checkCapability');
      if (raw == null) {
        return const HybridCapabilityInfo(
          status: HybridCapabilityStatus.unsupported,
          platformLabel: 'Android',
          message: 'Android hybrid AI channel returned no status.',
        );
      }
      return HybridCapabilityInfo(
        status: _parseStatus(raw['status'] as String?),
        platformLabel: (raw['platformLabel'] as String?) ?? 'Android (AICore + Firebase AI Logic)',
        modelIdentity: raw['modelIdentity'] as String?,
        downloadSizeBytes: (raw['downloadSizeBytes'] as num?)?.toInt(),
        downloadProgress: (raw['downloadProgress'] as num?)?.toDouble(),
        message: raw['message'] as String?,
      );
    } on PlatformException catch (err) {
      return HybridCapabilityInfo(
        status: HybridCapabilityStatus.error,
        platformLabel: 'Android',
        message: err.message ?? err.code,
      );
    } catch (err) {
      return HybridCapabilityInfo(
        status: HybridCapabilityStatus.error,
        platformLabel: 'Android',
        message: err.toString(),
      );
    }
  }

  @override
  Stream<HybridCapabilityInfo> prepareModel() {
    final controller = StreamController<HybridCapabilityInfo>();
    StreamSubscription<dynamic>? sub;

    sub = _progressChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map && !controller.isClosed) {
          controller.add(
            HybridCapabilityInfo(
              status: _parseStatus(event['status'] as String?),
              platformLabel: 'Android (AICore + Firebase AI Logic)',
              modelIdentity: event['modelIdentity'] as String?,
              downloadSizeBytes: (event['downloadSizeBytes'] as num?)?.toInt(),
              downloadProgress: (event['downloadProgress'] as num?)?.toDouble(),
              message: event['message'] as String?,
            ),
          );
        }
      },
      onError: (Object err) {
        if (!controller.isClosed) {
          controller.add(
            HybridCapabilityInfo(
              status: HybridCapabilityStatus.error,
              platformLabel: 'Android',
              message: err.toString(),
            ),
          );
        }
      },
    );

    () async {
      try {
        final raw = await _channel.invokeMapMethod<String, dynamic>('prepareModel');
        if (!controller.isClosed && raw != null) {
          controller.add(
            HybridCapabilityInfo(
              status: _parseStatus(raw['status'] as String?),
              platformLabel: 'Android (AICore + Firebase AI Logic)',
              modelIdentity: raw['modelIdentity'] as String?,
              downloadSizeBytes: (raw['downloadSizeBytes'] as num?)?.toInt(),
              downloadProgress: (raw['downloadProgress'] as num?)?.toDouble(),
              message: raw['message'] as String?,
            ),
          );
        }
      } catch (err) {
        if (!controller.isClosed) {
          controller.add(
            HybridCapabilityInfo(
              status: HybridCapabilityStatus.error,
              platformLabel: 'Android',
              message: err.toString(),
            ),
          );
        }
      } finally {
        await sub?.cancel();
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
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'generateChecklist',
        {
          'prompt': prompt,
          'mode': mode.name,
          'requestId': requestId,
          'cloudModel': cloudModel,
        },
      );
      if (raw == null) {
        return HybridChecklistResult(
          requestId: requestId,
          inferenceSource: HybridInferenceSource.unknown,
          elapsedMs: 0,
          errorCode: 'EMPTY_RESPONSE',
          errorMessage: 'Native Android bridge returned null.',
        );
      }
      return HybridChecklistResult(
        requestId: (raw['requestId'] as String?) ?? requestId,
        text: raw['text'] as String?,
        inferenceSource: _parseSource(raw['inferenceSource'] as String?),
        elapsedMs: (raw['elapsedMs'] as num?)?.toInt() ?? 0,
        modelIdentity: raw['modelIdentity'] as String?,
        errorCode: raw['errorCode'] as String?,
        errorMessage: raw['errorMessage'] as String?,
      );
    } on PlatformException catch (err) {
      return HybridChecklistResult(
        requestId: requestId,
        inferenceSource: HybridInferenceSource.unknown,
        elapsedMs: 0,
        errorCode: err.code,
        errorMessage: err.message ?? err.toString(),
      );
    } catch (err) {
      return HybridChecklistResult(
        requestId: requestId,
        inferenceSource: HybridInferenceSource.unknown,
        elapsedMs: 0,
        errorCode: 'ANDROID_BRIDGE_ERROR',
        errorMessage: err.toString(),
      );
    }
  }

  @override
  Future<void> cancel(String requestId) async {
    try {
      await _channel.invokeMethod<void>('cancel', {'requestId': requestId});
    } catch (_) {}
  }

  @override
  void dispose() {}
}
