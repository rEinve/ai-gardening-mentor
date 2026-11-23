import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/agro_supplier_models.dart';
import '../models/crop_planner_models.dart';
import '../models/garden_models.dart';
import '../services/firebase_ai_logic_service.dart';
import '../services/garden_backend_client.dart';
import 'tanzania_crops.dart';

/// Offline-first Phase 1–3 store.
/// Holds cached plots, crops, 7-day tasks, waterfall plans, farm contacts, and chat logs.
/// Connects to Firebase AI Logic (`firebase_ai`) and Firebase Backend when configured.
class OfflineGardenStore extends ChangeNotifier {
  OfflineGardenStore({
    GardenBackendClient? backend,
    FirebaseAiLogicService? aiLogic,
  })  : _backend = backend,
        _aiLogic = aiLogic {
    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        _isAuthenticated = true;
        _userEmail = user.email;
        _userDisplayName =
            user.displayName ?? user.email?.split('@').first;
        _userPhotoUrl = user.photoURL;
      }
    }
    if (_backend != null) {
      unawaited(_startBackendSync());
    }
  }

  final GardenBackendClient? _backend;
  final FirebaseAiLogicService? _aiLogic;
  StreamSubscription<GardenSnapshot>? _gardenSub;

  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userDisplayName;
  String? _userPhotoUrl;
  Uint8List? _userPhotoBytes;
  bool _initialized = false;
  PlotModel? _activePlot;
  final List<CropModel> _crops = [];
  final List<TaskModel> _tasks = [];
  final Map<String, List<TaskCompletionEvent>> _completionsByTaskId = {};
  final List<CropBatchPlan> _batchPlans = [];
  final List<AgroSupplier> _customSuppliers = [];
  final List<MentorChatLogEntry> _chatLogs = [];
  InputPreference _inputPreference = InputPreference.both;
  String? _lastSyncError;

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userDisplayName => _userDisplayName;
  String? get userPhotoUrl => _userPhotoUrl;
  Uint8List? get userPhotoBytes => _userPhotoBytes;

  Future<void> signInWithEmail({
    required String email,
    required String password,
    String? displayName,
    required bool createAccount,
  }) async {
    if (Firebase.apps.isNotEmpty) {
      final auth = FirebaseAuth.instance;
      final UserCredential cred;
      if (createAccount) {
        cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (displayName != null && displayName.isNotEmpty) {
          await cred.user?.updateDisplayName(displayName);
        }
      } else {
        cred = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      _userEmail = cred.user?.email ?? email;
      _userDisplayName =
          cred.user?.displayName ?? displayName ?? email.split('@').first;
      _userPhotoUrl = cred.user?.photoURL;
    } else {
      _userEmail = email;
      _userDisplayName = displayName ?? email.split('@').first;
    }
    _isAuthenticated = true;
    notifyListeners();
    if (_backend != null) {
      unawaited(_startBackendSync());
    }
  }

  Future<void> signInWithGoogle() async {
    if (Firebase.apps.isNotEmpty) {
      final auth = FirebaseAuth.instance;
      final provider = GoogleAuthProvider();
      final UserCredential cred = kIsWeb
          ? await auth.signInWithPopup(provider)
          : await auth.signInWithProvider(provider);
      _userEmail = cred.user?.email;
      _userDisplayName =
          cred.user?.displayName ??
          cred.user?.email?.split('@').first ??
          'Google User';
      _userPhotoUrl = cred.user?.photoURL;
    } else {
      _userEmail = 'farmer@gmail.com';
      _userDisplayName = 'Google Account';
    }
    _isAuthenticated = true;
    notifyListeners();
    if (_backend != null) {
      unawaited(_startBackendSync());
    }
  }

  Future<void> updateProfilePhoto(Uint8List bytes) async {
    _userPhotoBytes = bytes;
    notifyListeners();
    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('users/${user.uid}/profile.jpg');
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
          final url = await ref.getDownloadURL();
          await user.updatePhotoURL(url);
          _userPhotoUrl = url;
          notifyListeners();
        } catch (_) {
          // Keep local photo bytes if offline or storage permission differs.
        }
      }
    }
  }

  Future<void> signOut() async {
    if (Firebase.apps.isNotEmpty) {
      await FirebaseAuth.instance.signOut();
    }
    _isAuthenticated = false;
    _userEmail = null;
    _userDisplayName = null;
    _userPhotoUrl = null;
    _userPhotoBytes = null;
    notifyListeners();
  }

  List<MentorChatLogEntry> get chatLogs => List.unmodifiable(_chatLogs);

  void recordChatLog({
    required String sessionId,
    required String question,
    required String answer,
    required String dateIso,
  }) {
    _chatLogs.insert(
      0,
      MentorChatLogEntry(
        id: 'log_${DateTime.now().microsecondsSinceEpoch}',
        sessionId: sessionId,
        question: question,
        answer: answer,
        dateIso: dateIso,
      ),
    );
    notifyListeners();
  }

  void deleteChatLog(String logId) {
    _chatLogs.removeWhere((l) => l.id == logId);
    notifyListeners();
  }

  List<AgroSupplier> contactsByCategory(FarmContactCategory category) {
    return _customSuppliers.where((s) => s.category == category).toList();
  }

  List<AgroSupplier> get suppliersForActiveRegion =>
      contactsByCategory(FarmContactCategory.supplier);

  List<AgroSupplier> get buyerContacts =>
      contactsByCategory(FarmContactCategory.buyer);

  void addCustomSupplier({
    required String name,
    required String regionName,
    required String townOrArea,
    required String phoneNumber,
    required List<String> inputsStocked,
    FarmContactCategory category = FarmContactCategory.supplier,
  }) {
    _customSuppliers.insert(
      0,
      AgroSupplier(
        id: 'sup_user_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        regionName: regionName,
        townOrArea: townOrArea,
        phoneNumber: phoneNumber,
        inputsStocked: inputsStocked,
        category: category,
        isUserAdded: true,
      ),
    );
    notifyListeners();
  }

  GardenBackendClient? get backend => _backend;
  FirebaseAiLogicService? get aiLogic => _aiLogic;
  bool get isLiveBackend => _backend != null || _aiLogic != null;
  String get connectionLabel {
    if (_backend != null) return _backend.connectionLabel;
    if (_aiLogic != null) return 'Firebase AI Logic (${_aiLogic.activeModelName})';
    return 'Local Offline Mode';
  }
  String? get lastSyncError => _lastSyncError;

  bool get isInitialized => _initialized;
  PlotModel? get activePlot => _activePlot;
  List<CropModel> get crops => List.unmodifiable(_crops);
  List<TaskModel> get tasks => List.unmodifiable(_tasks);
  InputPreference get inputPreference => _inputPreference;

  List<ComputedBatchSchedule> get computedBatchSchedules {
    final todayIso = _formatLocalDate(DateTime.now());
    return _batchPlans.map((p) => computeBatchSchedule(p, todayIso)).toList();
  }

  List<ScheduledMilestone> get upcomingPrepAlerts {
    final alerts = computedBatchSchedules.expand((s) => s.upcomingPrepAlerts).toList();
    alerts.sort((a, b) => a.daysFromToday.compareTo(b.daysFromToday));
    return alerts;
  }

  void setInputPreference(InputPreference pref) {
    _inputPreference = pref;
    notifyListeners();
  }

  void addCropBatch({
    required String cropProfileId,
    required BatchStartMode startMode,
    required String anchorDate,
    required int plantCount,
    int? traysCount,
  }) {
    final id = 'batch_${cropProfileId}_${DateTime.now().microsecondsSinceEpoch}';
    _batchPlans.add(
      CropBatchPlan(
        batchId: id,
        cropProfileId: cropProfileId,
        startMode: startMode,
        anchorDate: anchorDate,
        plantCount: plantCount,
        traysCount: traysCount,
      ),
    );
    notifyListeners();
  }

  void addSuccessionPlan({
    required String cropProfileId,
    required BatchStartMode startMode,
    required String firstAnchorDate,
    required int intervalDays,
    required int batchCount,
    required int plantCountPerBatch,
  }) {
    final groupId = 'succ_${cropProfileId}_${DateTime.now().microsecondsSinceEpoch}';
    var currentDate = firstAnchorDate;
    for (var i = 0; i < batchCount; i++) {
      if (i > 0) {
        currentDate = addDaysIso(currentDate, intervalDays);
      }
      _batchPlans.add(
        CropBatchPlan(
          batchId: '${groupId}_b${i + 1}',
          cropProfileId: cropProfileId,
          startMode: startMode,
          anchorDate: currentDate,
          plantCount: plantCountPerBatch,
          successionGroupId: groupId,
          successionIndex: i + 1,
        ),
      );
    }
    notifyListeners();
  }

  void toggleMilestoneCompleted(String batchId, String milestoneId) {
    final idx = _batchPlans.indexWhere((b) => b.batchId == batchId);
    if (idx == -1) return;
    final current = _batchPlans[idx];
    final nextSet = Set<String>.from(current.completedMilestoneIds);
    if (nextSet.contains(milestoneId)) {
      nextSet.remove(milestoneId);
    } else {
      nextSet.add(milestoneId);
    }
    _batchPlans[idx] = current.copyWith(completedMilestoneIds: nextSet);
    notifyListeners();
  }

  void logActualHarvestDate(String batchId, String actualHarvestIso) {
    final idx = _batchPlans.indexWhere((b) => b.batchId == batchId);
    if (idx == -1) return;
    _batchPlans[idx] = _batchPlans[idx].copyWith(actualHarvestDate: actualHarvestIso);
    notifyListeners();
  }

  void rescheduleBatch(
    String batchId,
    String newAnchorIso, {
    required bool cascadeSuccession,
  }) {
    final idx = _batchPlans.indexWhere((b) => b.batchId == batchId);
    if (idx == -1) return;
    final target = _batchPlans[idx];
    final deltaDays = diffDaysIso(newAnchorIso, target.anchorDate);
    _batchPlans[idx] = target.copyWith(anchorDate: newAnchorIso);

    if (cascadeSuccession && target.successionGroupId != null && deltaDays != 0) {
      final groupId = target.successionGroupId!;
      final targetOrder = target.successionIndex ?? 0;
      for (var i = 0; i < _batchPlans.length; i++) {
        final other = _batchPlans[i];
        if (other.successionGroupId == groupId && (other.successionIndex ?? 0) > targetOrder) {
          _batchPlans[i] = other.copyWith(
            anchorDate: addDaysIso(other.anchorDate, deltaDays),
          );
        }
      }
    }
    notifyListeners();
  }

  int get pendingSyncCount => _completionsByTaskId.values
      .expand((list) => list)
      .where((ev) => ev.pendingSync)
      .length;

  List<TaskCompletionEvent> completionsFor(String taskId) {
    return List.unmodifiable(_completionsByTaskId[taskId] ?? const []);
  }

  EffectiveTaskStatus effectiveStatusFor(TaskModel task) {
    return deriveEffectiveTaskStatus(task, completionsFor(task.taskId));
  }

  List<TaskModel> tasksForDate(String localDate) {
    return _tasks.where((t) => t.scheduledDate == localDate).toList();
  }

  Future<void> _startBackendSync() async {
    final client = _backend;
    if (client == null) return;
    try {
      await client.ensureSignedIn();
      _gardenSub?.cancel();
      _gardenSub = client.watchGarden().listen(
        (snapshot) {
          if (snapshot.activePlot != null) {
            _activePlot = snapshot.activePlot;
            _initialized = true;
          }
          if (snapshot.crops.isNotEmpty) {
            _crops
              ..clear()
              ..addAll(snapshot.crops);
          }
          if (snapshot.tasks.isNotEmpty) {
            _tasks
              ..clear()
              ..addAll(snapshot.tasks);
          }
          if (snapshot.completionsByTaskId.isNotEmpty) {
            for (final entry in snapshot.completionsByTaskId.entries) {
              _completionsByTaskId[entry.key] = List<TaskCompletionEvent>.from(entry.value);
            }
          }
          _lastSyncError = null;
          notifyListeners();
        },
        onError: (Object err) {
          _lastSyncError = err.toString();
          notifyListeners();
        },
      );
    } catch (err) {
      _lastSyncError = err.toString();
      notifyListeners();
    }
  }

  /// Idempotent onboarding commit + initial 7-day Tanzania cadence preview.
  /// Updates local offline state immediately and syncs to `initializeGarden` when connected.
  Future<void> initializeGarden({
    required String plotName,
    required String regionName,
    required PlotType plotType,
    required RainExposure rainExposure,
    required SunlightExposure sunlightExposure,
    required List<TanzaniaCropOption> selectedCrops,
  }) async {
    final now = DateTime.now();
    const plotId = 'plot_tz_primary';
    final resolvedPlotName = plotName.trim().isEmpty ? 'Home Garden Bed' : plotName.trim();

    _activePlot = PlotModel(
      plotId: plotId,
      name: resolvedPlotName,
      plotType: plotType,
      rainExposure: rainExposure,
      sunlightExposure: sunlightExposure,
      regionName: regionName,
    );

    _crops.clear();
    _tasks.clear();
    _completionsByTaskId.clear();
    _batchPlans.clear();

    final todayStr = _formatLocalDate(now);
    final isSheltered = rainExposure != RainExposure.exposed;
    final cropPayloads = <Map<String, dynamic>>[];

    for (var i = 0; i < selectedCrops.length; i++) {
      final option = selectedCrops[i];
      final cropId = 'crop_${option.profileId}_$i';
      _crops.add(
        CropModel(
          cropId: cropId,
          plotId: plotId,
          cropProfileId: option.profileId,
          commonName: option.commonName,
          localNameSw: option.localNameSw,
          plantingDate: todayStr,
          plantingMethod: option.defaultMethod,
          growthStage: option.defaultMethod == PlantingMethod.transplant
              ? 'vegetative'
              : 'germination',
        ),
      );

      // Seed proactive waterfall batch plan for each onboarded crop
      _batchPlans.add(
        CropBatchPlan(
          batchId: 'batch_${option.profileId}_$i',
          cropProfileId: option.profileId,
          startMode: option.defaultMethod == PlantingMethod.transplant
              ? BatchStartMode.boughtSeedlings
              : BatchStartMode.directSeed,
          anchorDate: todayStr,
          plantCount: 20,
        ),
      );

      cropPayloads.add({
        'cropId': cropId,
        'cropProfileId': option.profileId,
        'variety': null,
        'plantingDate': todayStr,
        'plantingMethod': _plantingMethodToWire(option.defaultMethod),
      });

      // Generate deterministic 7-day rolling tasks matching backend rules (instant offline preview)
      for (var day = 0; day < 7; day++) {
        final dateStr = _formatLocalDate(now.add(Duration(days: day)));
        if (day % 2 == 0) {
          _tasks.add(
            TaskModel(
              taskId: 'task_${dateStr}_${cropId}_water',
              cropId: cropId,
              plotId: plotId,
              cropName: '${option.commonName} (${option.localNameSw})',
              category: isSheltered ? 'soil_check' : 'watering',
              title: isSheltered
                  ? '${option.commonName}: Check sheltered soil moisture'
                  : '${option.commonName}: Morning root-zone watering',
              instructions: isSheltered
                  ? 'Test potting mix or sheltered bed moisture 2–3 cm deep before adding water.'
                  : 'Water evenly at the soil base before 09:00 to keep leaves dry.',
              steps: isSheltered
                  ? const [
                      'Press one finger 2–3 cm into the soil near the stem.',
                      'Water gently only if dry at fingertip depth.',
                    ]
                  : const [
                      'Check topsoil moisture 2 cm deep near the stem.',
                      'Pour water slowly at the root zone, avoiding foliage.',
                      'Verify excess water drains cleanly.',
                    ],
              rationale: isSheltered
                  ? 'Sheltered and container beds dry unevenly and do not receive natural rainfall.'
                  : 'Morning root-zone watering prevents heat wilt and reduces fungal leaf spots.',
              estimatedDurationMinutes: isSheltered ? 2 : 3,
              scheduledDate: dateStr,
              scheduleStatus: ScheduleStatus.pending,
              sources: const [kGrowHowFixtureCitation],
            ),
          );
        }

        if (day % 3 == 0) {
          _tasks.add(
            TaskModel(
              taskId: 'task_${dateStr}_${cropId}_scout',
              cropId: cropId,
              plotId: plotId,
              cropName: '${option.commonName} (${option.localNameSw})',
              category: 'pest_scout',
              title: '${option.commonName}: 2-minute leaf underside check',
              instructions:
                  'Lift 3–4 leaves per plant to spot early aphids, whiteflies, or mites.',
              steps: const [
                'Inspect upper young leaves and lower mature undersides.',
                'Rinse small pest clusters gently with clean water.',
                'Capture a triage photo if spots are spreading.',
              ],
              rationale:
                  'Early physical scouting prevents panic spraying and protects pollinators.',
              estimatedDurationMinutes: 2,
              scheduledDate: dateStr,
              scheduleStatus: ScheduleStatus.pending,
              sources: const [kGrowHowFixtureCitation],
            ),
          );
        }
      }
    }

    _initialized = true;
    notifyListeners();

    final client = _backend;
    if (client != null) {
      final coords = kTanzaniaRegionCoords[regionName] ?? (lat: -6.7924, lng: 39.2083);
      final requestId = 'req_init_${now.toUtc().millisecondsSinceEpoch}';
      final payload = <String, dynamic>{
        'requestId': requestId,
        'displayName': null,
        'geographicLocation': {
          'latitude': coords.lat,
          'longitude': coords.lng,
          'regionName': regionName,
          'countryCode': 'TZ',
          'postalCode': null,
          'usdaHardinessZone': null,
        },
        'timeZone': 'Africa/Dar_es_Salaam',
        'unitPreference': 'metric',
        'gardenExperienceLevel': 'beginner',
        'plots': [
          {
            'plotId': plotId,
            'name': resolvedPlotName,
            'plotType': _plotTypeToWire(plotType),
            'rainExposure': _rainExposureToWire(rainExposure),
            'dimensions': null,
            'sunlightExposure': _sunlightToWire(sunlightExposure),
            'crops': cropPayloads,
          },
        ],
      };

      try {
        await client.initializeGarden(payload);
        _lastSyncError = null;
      } catch (err) {
        _lastSyncError = err.toString();
      }
      notifyListeners();
    }
  }

  /// Appends an immutable offline completion event (idempotent on repeated taps).
  /// Syncs to `users/{uid}/taskCompletions/{eventId}` when connected to Firebase.
  Future<void> markTaskCompleted(String taskId) async {
    final existing = _completionsByTaskId[taskId];
    if (existing != null && existing.isNotEmpty) {
      return; // Repeated tap reuses existing event; no undo in MVP.
    }

    final event = TaskCompletionEvent(
      eventId: 'ev_local_$taskId',
      taskId: taskId,
      completedAtUtc: DateTime.now().toUtc(),
      pendingSync: true,
    );
    _completionsByTaskId[taskId] = [event];
    notifyListeners();

    final client = _backend;
    if (client != null) {
      try {
        await client.appendTaskCompletion(event);
        _completionsByTaskId[taskId] = [
          TaskCompletionEvent(
            eventId: event.eventId,
            taskId: event.taskId,
            completedAtUtc: event.completedAtUtc,
            pendingSync: false,
          ),
        ];
        _lastSyncError = null;
      } catch (err) {
        _lastSyncError = err.toString();
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _gardenSub?.cancel();
    super.dispose();
  }

  static String _formatLocalDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _plotTypeToWire(PlotType t) => switch (t) {
        PlotType.inGround => 'in_ground',
        PlotType.raisedBed => 'raised_bed',
        PlotType.container => 'container',
        PlotType.indoorWindow => 'indoor_window',
      };

  static String _rainExposureToWire(RainExposure r) => switch (r) {
        RainExposure.exposed => 'exposed',
        RainExposure.sheltered => 'sheltered',
        RainExposure.indoor => 'indoor',
      };

  static String _sunlightToWire(SunlightExposure s) => switch (s) {
        SunlightExposure.fullSun => 'full_sun',
        SunlightExposure.partialShade => 'partial_shade',
        SunlightExposure.deepShade => 'deep_shade',
      };

  static String _plantingMethodToWire(PlantingMethod m) => switch (m) {
        PlantingMethod.directSeed => 'direct_seed',
        PlantingMethod.transplant => 'transplant',
      };
}
