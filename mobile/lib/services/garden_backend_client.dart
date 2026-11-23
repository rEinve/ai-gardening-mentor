import 'dart:typed_data';

import '../data/image_quality.dart';
import '../models/garden_models.dart';

/// Snapshot of user-owned Firestore garden collections (with offline cache support).
class GardenSnapshot {
  const GardenSnapshot({
    required this.activePlot,
    required this.crops,
    required this.tasks,
    required this.completionsByTaskId,
  });

  final PlotModel? activePlot;
  final List<CropModel> crops;
  final List<TaskModel> tasks;
  final Map<String, List<TaskCompletionEvent>> completionsByTaskId;
}

/// Structured 3-step Calm Triage result returned by `executeMultimodalTriage`.
class TriageOutcome {
  const TriageOutcome({
    required this.diagnosisId,
    required this.assessmentStatus,
    required this.whatItIs,
    required this.immediateAction,
    required this.whatNotToWorryAbout,
    this.detectedAnomalyType,
    this.recoveryTemplateId,
    this.sourceRefs = const [],
  });

  final String diagnosisId;
  final String assessmentStatus; // 'supported' | 'uncertain'
  final String whatItIs;
  final String immediateAction;
  final String whatNotToWorryAbout;
  final String? detectedAnomalyType;
  final String? recoveryTemplateId;
  final List<SourceCitation> sourceRefs;

  bool get isUncertain => assessmentStatus != 'supported';
}

/// Parsed SSE event emitted by `processMentorChatMessage`.
class MentorSseEvent {
  const MentorSseEvent({
    required this.event,
    required this.data,
  });

  final String event; // 'delta' | 'done' | 'error'
  final Map<String, dynamic> data;
}

/// Abstract backend client decoupling Flutter stores & screens from Firebase SDK globals.
/// Implemented by [FirebaseGardenBackend] for live/emulator execution and faked in unit tests.
abstract class GardenBackendClient {
  bool get isLiveConnected;
  String? get currentUid;
  String get connectionLabel;

  Future<void> ensureSignedIn();

  Stream<GardenSnapshot> watchGarden();

  Future<Map<String, dynamic>> initializeGarden(Map<String, dynamic> payload);

  Future<void> appendTaskCompletion(TaskCompletionEvent event);

  Future<String> uploadDiagnosticJpeg({
    required String diagnosisId,
    required Uint8List jpegBytes,
    required int widthPx,
    required int heightPx,
  });

  Future<TriageOutcome> executeMultimodalTriage({
    required String requestId,
    required String diagnosisId,
    required String imageStoragePath,
    String? cropId,
    String? plotId,
    required ImageQualityMetrics metrics,
  });

  Future<void> addRecoveryTask({
    required String requestId,
    required String diagnosisId,
    required String plotId,
    required String cropId,
  });

  Stream<MentorSseEvent> streamMentorChat({
    required String requestId,
    required String sessionId,
    required String messageId,
    required String text,
    String? plotId,
    String? diagnosisId,
  });

  Future<void> archiveChatSession({
    required String requestId,
    required String sessionId,
  });
}
