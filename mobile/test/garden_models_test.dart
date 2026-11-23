import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gardening_mentor/data/image_quality.dart';
import 'package:ai_gardening_mentor/data/offline_garden_store.dart';
import 'package:ai_gardening_mentor/data/tanzania_crops.dart';
import 'package:ai_gardening_mentor/models/garden_models.dart';
import 'package:ai_gardening_mentor/services/garden_backend_client.dart';

class FakeGardenBackend implements GardenBackendClient {
  final StreamController<GardenSnapshot> snapshotController =
      StreamController<GardenSnapshot>.broadcast();
  final List<Map<String, dynamic>> initPayloads = [];
  final List<TaskCompletionEvent> appendedCompletions = [];
  final List<String> uploadedPaths = [];
  final List<String> recoveryDiagnosisIds = [];
  final List<String> archivedSessionIds = [];

  @override
  bool get isLiveConnected => true;

  @override
  String? get currentUid => 'uid_tz_test';

  @override
  String get connectionLabel => 'Fake Firebase Emulators';

  @override
  Future<void> ensureSignedIn() async {}

  @override
  Stream<GardenSnapshot> watchGarden() => snapshotController.stream;

  @override
  Future<Map<String, dynamic>> initializeGarden(Map<String, dynamic> payload) async {
    initPayloads.add(payload);
    return {'status': 'ok', 'requestId': payload['requestId']};
  }

  @override
  Future<void> appendTaskCompletion(TaskCompletionEvent event) async {
    appendedCompletions.add(event);
  }

  @override
  Future<String> uploadDiagnosticJpeg({
    required String diagnosisId,
    required Uint8List jpegBytes,
    required int widthPx,
    required int heightPx,
  }) async {
    final path = 'users/uid_tz_test/diagnostics/$diagnosisId.jpg';
    uploadedPaths.add(path);
    return path;
  }

  @override
  Future<TriageOutcome> executeMultimodalTriage({
    required String requestId,
    required String diagnosisId,
    required String imageStoragePath,
    String? cropId,
    String? plotId,
    required ImageQualityMetrics metrics,
  }) async {
    return TriageOutcome(
      diagnosisId: diagnosisId,
      assessmentStatus: 'supported',
      detectedAnomalyType: 'normal_growth',
      recoveryTemplateId: 'tpl_lower_leaf_prune',
      whatItIs: 'Healthy lower leaf senescence on Tomato.',
      immediateAction: 'Trim yellowed lower leaves cleanly.',
      whatNotToWorryAbout: 'Upper canopy and flowers are healthy.',
      sourceRefs: const [kGrowHowFixtureCitation],
    );
  }

  @override
  Future<void> addRecoveryTask({
    required String requestId,
    required String diagnosisId,
    required String plotId,
    required String cropId,
  }) async {
    recoveryDiagnosisIds.add(diagnosisId);
  }

  @override
  Stream<MentorSseEvent> streamMentorChat({
    required String requestId,
    required String sessionId,
    required String messageId,
    required String text,
    String? plotId,
    String? diagnosisId,
  }) async* {
    yield const MentorSseEvent(
      event: 'delta',
      data: {'text': 'Water your Dar es Salaam tomatoes '},
    );
    yield const MentorSseEvent(
      event: 'delta',
      data: {'text': 'at the root zone before 09:00.'},
    );
    yield const MentorSseEvent(
      event: 'done',
      data: {
        'messageId': 'asst_1',
        'validationStatus': 'passed',
        'sourceRefs': [
          {
            'sourceId': 'ewskt_growhow_tropical_veg',
            'revision': 'v1-fixture',
            'passageId': 'root_zone_watering_am',
            'publisher': 'East-West Seed Knowledge Transfer (EWS-KT)',
            'title': 'GrowHow Tropical Vegetable Production Guides (Prototype Fixture)',
            'canonicalUrl': 'https://growhow.ews-kt.com/in/en',
          },
        ],
      },
    );
  }

  @override
  Future<void> archiveChatSession({
    required String requestId,
    required String sessionId,
  }) async {
    archivedSessionIds.add(sessionId);
  }

  Future<void> dispose() async {
    await snapshotController.close();
  }
}

void main() {
  test('Tanzania starter catalogue includes all 9 locked Phase 0 crops', () {
    expect(kTanzaniaCrops.length, 9);
    expect(kTanzaniaCrops.map((c) => c.profileId), containsAll([
      'tz_tomato',
      'tz_pepper',
      'tz_african_eggplant',
      'tz_african_nightshade',
      'tz_okra',
      'tz_amaranth',
      'tz_sukuma_wiki',
      'tz_cucumber',
      'tz_squash',
    ]));
  });

  test('A5: Offline completion overrides deferredWeather scheduleStatus', () {
    const task = TaskModel(
      taskId: 'task_1',
      cropId: 'crop_1',
      plotId: 'plot_1',
      cropName: 'Tomato (Nyanya)',
      category: 'watering',
      title: 'Morning root-zone watering',
      instructions: 'Water at base.',
      steps: ['Water base'],
      rationale: 'Steady moisture',
      estimatedDurationMinutes: 3,
      scheduledDate: '2026-11-22',
      scheduleStatus: ScheduleStatus.deferredWeather,
    );

    final completion = TaskCompletionEvent(
      eventId: 'ev_1',
      taskId: 'task_1',
      completedAtUtc: DateTime.utc(2026, 11, 22, 6, 0),
    );

    expect(deriveEffectiveTaskStatus(task, [completion]), EffectiveTaskStatus.completed);
    expect(deriveEffectiveTaskStatus(task, const []), EffectiveTaskStatus.deferredWeather);
  });

  test('OfflineGardenStore initializes Tanzania garden and appends idempotent completions', () async {
    final store = OfflineGardenStore();
    await store.initializeGarden(
      plotName: 'Dar Raised Bed',
      regionName: 'Dar es Salaam',
      plotType: PlotType.raisedBed,
      rainExposure: RainExposure.exposed,
      sunlightExposure: SunlightExposure.fullSun,
      selectedCrops: [kTanzaniaCrops.first],
    );

    expect(store.isInitialized, isTrue);
    expect(store.tasks, isNotEmpty);

    final firstTask = store.tasks.first;
    await store.markTaskCompleted(firstTask.taskId);
    await store.markTaskCompleted(firstTask.taskId); // Repeated tap does not duplicate

    expect(store.completionsFor(firstTask.taskId).length, 1);
    expect(store.effectiveStatusFor(firstTask), EffectiveTaskStatus.completed);
    store.dispose();
  });

  test('OfflineGardenStore dispatches schema-valid Tanzania payload and syncs completions to backend', () async {
    final fake = FakeGardenBackend();
    final store = OfflineGardenStore(backend: fake);

    await store.initializeGarden(
      plotName: 'Arusha Kitchen Plot',
      regionName: 'Arusha',
      plotType: PlotType.raisedBed,
      rainExposure: RainExposure.sheltered,
      sunlightExposure: SunlightExposure.partialShade,
      selectedCrops: [kTanzaniaCrops.first],
    );

    expect(fake.initPayloads.length, 1);
    final payload = fake.initPayloads.first;
    final loc = payload['geographicLocation'] as Map<String, dynamic>;
    expect(loc['countryCode'], 'TZ');
    expect(loc['regionName'], 'Arusha');
    expect(loc['usdaHardinessZone'], isNull);
    expect(payload['timeZone'], 'Africa/Dar_es_Salaam');
    expect(payload['unitPreference'], 'metric');

    final plots = payload['plots'] as List<dynamic>;
    final firstPlot = plots.first as Map<String, dynamic>;
    expect(firstPlot['plotType'], 'raised_bed');
    expect(firstPlot['rainExposure'], 'sheltered');
    expect(firstPlot['sunlightExposure'], 'partial_shade');

    final firstTask = store.tasks.first;
    await store.markTaskCompleted(firstTask.taskId);
    expect(fake.appendedCompletions.length, 1);
    expect(store.pendingSyncCount, 0); // Cleared after backend ack

    store.dispose();
    await fake.dispose();
  });
}
