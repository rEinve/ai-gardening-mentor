import 'dart:async';

enum HybridCapabilityStatus {
  checking,
  unsupported,
  downloadAvailable,
  downloading,
  ready,
  error,
}

enum HybridInferenceMode {
  preferOnDevice,
  onlyOnDevice,
  onlyInCloud,
}

enum HybridInferenceSource {
  onDevice,
  inCloud,
  unknown,
}

class HybridCapabilityInfo {
  const HybridCapabilityInfo({
    required this.status,
    this.platformLabel = '',
    this.modelIdentity,
    this.downloadSizeBytes,
    this.downloadProgress,
    this.message,
  });

  final HybridCapabilityStatus status;
  final String platformLabel;
  final String? modelIdentity;
  final int? downloadSizeBytes;
  final double? downloadProgress;
  final String? message;
}

class HybridChecklistResult {
  const HybridChecklistResult({
    required this.requestId,
    required this.inferenceSource,
    required this.elapsedMs,
    this.text,
    this.modelIdentity,
    this.errorCode,
    this.errorMessage,
  });

  final String requestId;
  final HybridInferenceSource inferenceSource;
  final int elapsedMs;
  final String? text;
  final String? modelIdentity;
  final String? errorCode;
  final String? errorMessage;

  bool get isSuccess => text != null && text!.trim().isNotEmpty && errorCode == null;

  String get userFacingSourceLabel {
    switch (inferenceSource) {
      case HybridInferenceSource.onDevice:
        return 'Generated on this device';
      case HybridInferenceSource.inCloud:
        return 'Generated in cloud';
      case HybridInferenceSource.unknown:
        return 'Source unavailable';
    }
  }
}

/// Platform-agnostic contract for Firebase AI Logic hybrid checklist inference.
abstract class HybridChecklistAdapter {
  Future<HybridCapabilityInfo> checkCapability();

  /// Prepares/downloads the on-device model ONLY when explicitly invoked by the user.
  Stream<HybridCapabilityInfo> prepareModel();

  Future<HybridChecklistResult> generateChecklist({
    required String prompt,
    required HybridInferenceMode mode,
    required String requestId,
    String cloudModel = 'gemini-3.8-flash',
  });

  Future<void> cancel(String requestId);

  void dispose();
}

/// Honest fallback adapter for unsupported desktop/iOS/test platforms.
/// Never fabricates AI answers.
class UnsupportedHybridChecklistAdapter implements HybridChecklistAdapter {
  const UnsupportedHybridChecklistAdapter({
    this.platformLabel = 'Unsupported platform',
  });

  final String platformLabel;

  @override
  Future<HybridCapabilityInfo> checkCapability() async {
    return HybridCapabilityInfo(
      status: HybridCapabilityStatus.unsupported,
      platformLabel: platformLabel,
      message: 'On-device Firebase AI Logic is only supported on compatible Android devices and desktop Chrome.',
    );
  }

  @override
  Stream<HybridCapabilityInfo> prepareModel() async* {
    yield await checkCapability();
  }

  @override
  Future<HybridChecklistResult> generateChecklist({
    required String prompt,
    required HybridInferenceMode mode,
    required String requestId,
    String cloudModel = 'gemini-3.8-flash',
  }) async {
    return HybridChecklistResult(
      requestId: requestId,
      inferenceSource: HybridInferenceSource.unknown,
      elapsedMs: 0,
      errorCode: 'UNSUPPORTED_PLATFORM',
      errorMessage: 'Hybrid AI adapter is not supported on $platformLabel.',
    );
  }

  @override
  Future<void> cancel(String requestId) async {}

  @override
  void dispose() {}
}
