import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/agro_supplier_models.dart';
import '../models/crop_planner_models.dart';
import '../models/garden_models.dart';
import '../services/checklist_storage.dart';
import '../services/firebase_ai_logic_service.dart';
import '../services/firebase_garden_backend.dart';
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

  GardenBackendClient? _backend;
  FirebaseAiLogicService? _aiLogic;
  StreamSubscription<GardenSnapshot>? _gardenSub;

  /// Attaches Firebase backend and AI Logic after non-blocking startup.
  void attachServices({
    GardenBackendClient? backend,
    FirebaseAiLogicService? aiLogic,
  }) {
    var changed = false;
    if (backend != null && _backend == null) {
      _backend = backend;
      changed = true;
      unawaited(_startBackendSync());
    }
    if (aiLogic != null && _aiLogic == null) {
      _aiLogic = aiLogic;
      changed = true;
    }
    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous && !_isAuthenticated) {
        _isAuthenticated = true;
        _userEmail = user.email;
        _userDisplayName =
            user.displayName ?? user.email?.split('@').first;
        _userPhotoUrl = user.photoURL;
        changed = true;
        unawaited(_restoreLocalGardenProfile());
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userDisplayName;
  String? _userPhotoUrl;
  Uint8List? _userPhotoBytes;
  bool _initialized = false;
  PlotModel? _activePlot;
  String? _farmAreaLabel;
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
    unawaited(_restoreLocalGardenProfile());
    if (_backend != null) {
      unawaited(_startBackendSync());
    }
  }

  Future<void> signInWithGoogle() async {
    if (Firebase.apps.isNotEmpty) {
      final auth = FirebaseAuth.instance;
      final UserCredential cred;
      if (kIsWeb) {
        cred = await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn(scopes: const ['email', 'profile']).signIn();
        if (googleUser == null) {
          throw StateError('Google sign-in was cancelled.');
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        cred = await auth.signInWithCredential(credential);
      }
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
    unawaited(_restoreLocalGardenProfile());
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
    await _gardenSub?.cancel();
    _gardenSub = null;
    if (Firebase.apps.isNotEmpty) {
      await FirebaseAuth.instance.signOut();
      if (!kIsWeb) {
        try {
          await GoogleSignIn().signOut();
        } catch (_) {}
      }
    }
    _isAuthenticated = false;
    _userEmail = null;
    _userDisplayName = null;
    _userPhotoUrl = null;
    _userPhotoBytes = null;
    _activePlot = null;
    _farmAreaLabel = null;
    _initialized = false;
    _crops.clear();
    _tasks.clear();
    _batchPlans.clear();
    _customSuppliers.clear();
    _completionsByTaskId.clear();
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
    final contact = AgroSupplier(
      id: 'sup_user_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      regionName: regionName,
      townOrArea: townOrArea,
      phoneNumber: phoneNumber,
      inputsStocked: inputsStocked,
      category: category,
      isUserAdded: true,
    );
    _customSuppliers.insert(0, contact);
    notifyListeners();
    unawaited(_persistLocalGardenProfile());
    unawaited(_syncContactToFirestore(contact));
  }

  GardenBackendClient? get backend => _backend;
  FirebaseAiLogicService? get aiLogic => _aiLogic;
  bool get isLiveBackend => _backend != null || _aiLogic != null;
  String get connectionLabel {
    final backend = _backend;
    final aiLogic = _aiLogic;
    if (backend != null) return backend.connectionLabel;
    if (aiLogic != null) return 'Firebase AI Logic (${aiLogic.activeModelName})';
    return 'Local Offline Mode';
  }
  String? get lastSyncError => _lastSyncError;

  bool get isInitialized => _initialized;
  PlotModel? get activePlot => _activePlot;
  String? get farmAreaLabel => _farmAreaLabel;
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
    final batch = CropBatchPlan(
      batchId: id,
      cropProfileId: cropProfileId,
      startMode: startMode,
      anchorDate: anchorDate,
      plantCount: plantCount,
      traysCount: traysCount,
    );
    _batchPlans.add(batch);
    notifyListeners();
    unawaited(_persistLocalGardenProfile());
    unawaited(_syncBatchToFirestore(batch));
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
    final created = <CropBatchPlan>[];
    for (var i = 0; i < batchCount; i++) {
      if (i > 0) {
        currentDate = addDaysIso(currentDate, intervalDays);
      }
      final batch = CropBatchPlan(
        batchId: '${groupId}_b${i + 1}',
        cropProfileId: cropProfileId,
        startMode: startMode,
        anchorDate: currentDate,
        plantCount: plantCountPerBatch,
        successionGroupId: groupId,
        successionIndex: i + 1,
      );
      _batchPlans.add(batch);
      created.add(batch);
    }
    notifyListeners();
    unawaited(_persistLocalGardenProfile());
    for (final batch in created) {
      unawaited(_syncBatchToFirestore(batch));
    }
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
    final updated = current.copyWith(completedMilestoneIds: nextSet);
    _batchPlans[idx] = updated;
    notifyListeners();
    unawaited(_persistLocalGardenProfile());
    unawaited(_syncBatchToFirestore(updated));
  }

  void logActualHarvestDate(String batchId, String actualHarvestIso) {
    final idx = _batchPlans.indexWhere((b) => b.batchId == batchId);
    if (idx == -1) return;
    final updated = _batchPlans[idx].copyWith(actualHarvestDate: actualHarvestIso);
    _batchPlans[idx] = updated;
    notifyListeners();
    unawaited(_persistLocalGardenProfile());
    unawaited(_syncBatchToFirestore(updated));
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
    final updatedTarget = target.copyWith(anchorDate: newAnchorIso);
    _batchPlans[idx] = updatedTarget;
    final modified = <CropBatchPlan>[updatedTarget];

    if (cascadeSuccession && target.successionGroupId != null && deltaDays != 0) {
      final groupId = target.successionGroupId!;
      final targetOrder = target.successionIndex ?? 0;
      for (var i = 0; i < _batchPlans.length; i++) {
        final other = _batchPlans[i];
        if (other.successionGroupId == groupId && (other.successionIndex ?? 0) > targetOrder) {
          final shifted = other.copyWith(
            anchorDate: addDaysIso(other.anchorDate, deltaDays),
          );
          _batchPlans[i] = shifted;
          modified.add(shifted);
        }
      }
    }
    notifyListeners();
    unawaited(_persistLocalGardenProfile());
    for (final batch in modified) {
      unawaited(_syncBatchToFirestore(batch));
    }
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
    final retiredCropIds =
        _crops.where((c) => c.isRetired).map((c) => c.cropId).toSet();
    return _tasks
        .where(
          (t) =>
              t.scheduledDate == localDate &&
              t.scheduleStatus != ScheduleStatus.cancelled &&
              !retiredCropIds.contains(t.cropId),
        )
        .toList();
  }

  /// Retires an active crop so future uncompleted tasks are cleared from the schedule.
  Future<void> retireCrop(String cropId) async {
    final idx = _crops.indexWhere((c) => c.cropId == cropId);
    if (idx == -1) return;
    final target = _crops[idx];
    if (target.isRetired) return;

    _crops[idx] = CropModel(
      cropId: target.cropId,
      plotId: target.plotId,
      cropProfileId: target.cropProfileId,
      commonName: target.commonName,
      localNameSw: target.localNameSw,
      plantingDate: target.plantingDate,
      plantingMethod: target.plantingMethod,
      growthStage: target.growthStage,
      isRetired: true,
    );
    _tasks.removeWhere(
      (t) => t.cropId == cropId && (_completionsByTaskId[t.taskId]?.isEmpty ?? true),
    );
    notifyListeners();
    unawaited(_persistLocalGardenProfile());

    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final callable = FirebaseFunctions.instanceFor(
            region: FirebaseRuntimeConfig.region,
          ).httpsCallable('retireCrop');
          await callable.call<dynamic>({
            'requestId': 'req_retire_${DateTime.now().toUtc().millisecondsSinceEpoch}',
            'plotId': target.plotId,
            'cropId': target.cropId,
          });
        } catch (_) {
          // Local retirement remains applied if offline.
        }
      }
    }
  }

  /// Removes a planned crop batch from both local storage and Cloud Firestore.
  Future<void> removeCropBatch(String batchId) async {
    final before = _batchPlans.length;
    _batchPlans.removeWhere((b) => b.batchId == batchId);
    if (_batchPlans.length == before) return;
    notifyListeners();
    unawaited(_persistLocalGardenProfile());

    if (Firebase.apps.isNotEmpty) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .doc('users/$uid/cropBatches/$batchId')
              .delete();
        } catch (_) {
          // Local batch removal remains persisted even if offline.
        }
      }
    }
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
            unawaited(_persistLocalGardenProfile());
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
      unawaited(_loadRemoteBatchesAndContacts());
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
    unawaited(_persistLocalGardenProfile());
  }

  String? _currentAccountId() {
    if (Firebase.apps.isNotEmpty) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) return uid;
    }
    return _userEmail;
  }

  Future<void> _restoreLocalGardenProfile() async {
    final accountId = _currentAccountId();
    if (accountId == null || accountId.isEmpty) return;
    final saved = await AccountGardenProfileStorage.load(accountId);
    if (saved == null) return;
    var changed = false;
    if (_activePlot == null) {
      _activePlot = PlotModel(
        plotId: saved.plotId,
        name: saved.plotName,
        plotType: PlotType.values.firstWhere(
          (e) => e.name == saved.plotTypeName,
          orElse: () => PlotType.inGround,
        ),
        rainExposure: RainExposure.values.firstWhere(
          (e) => e.name == saved.rainExposureName,
          orElse: () => RainExposure.exposed,
        ),
        sunlightExposure: SunlightExposure.values.firstWhere(
          (e) => e.name == saved.sunlightExposureName,
          orElse: () => SunlightExposure.fullSun,
        ),
        regionName: saved.regionName,
      );
      _farmAreaLabel = saved.farmAreaLabel;
      _initialized = true;
      changed = true;
    }
    if (_crops.isEmpty && saved.crops.isNotEmpty) {
      for (final c in saved.crops) {
        _crops.add(
          CropModel(
            cropId: (c['cropId'] as String?) ?? 'crop_saved',
            plotId: saved.plotId,
            cropProfileId: (c['cropProfileId'] as String?) ?? 'tomato',
            commonName: (c['commonName'] as String?) ?? 'Tomato',
            localNameSw: (c['localNameSw'] as String?) ?? 'Nyanya',
            plantingDate: (c['plantingDate'] as String?) ?? _formatLocalDate(DateTime.now()),
            plantingMethod: PlantingMethod.values.firstWhere(
              (e) => e.name == (c['plantingMethod'] as String?),
              orElse: () => PlantingMethod.transplant,
            ),
            growthStage: (c['growthStage'] as String?) ?? 'vegetative',
            isRetired: (c['isRetired'] as bool?) ?? false,
          ),
        );
      }
      changed = true;
    }
    if (_batchPlans.isEmpty && saved.batchPlans.isNotEmpty) {
      for (final b in saved.batchPlans) {
        final batch = _batchFromMap(b);
        if (batch != null) _batchPlans.add(batch);
      }
      changed = true;
    }
    if (_customSuppliers.isEmpty && saved.farmContacts.isNotEmpty) {
      for (final s in saved.farmContacts) {
        final contact = _contactFromMap(s);
        if (contact != null) _customSuppliers.add(contact);
      }
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> _persistLocalGardenProfile() async {
    final accountId = _currentAccountId();
    final plot = _activePlot;
    if (accountId == null || accountId.isEmpty || plot == null) return;
    final profile = PersistedGardenProfile(
      accountId: accountId,
      plotId: plot.plotId,
      plotName: plot.name,
      regionName: plot.regionName,
      plotTypeName: plot.plotType.name,
      rainExposureName: plot.rainExposure.name,
      sunlightExposureName: plot.sunlightExposure.name,
      farmAreaLabel: _farmAreaLabel,
      crops: _crops
          .map(
            (c) => {
              'cropId': c.cropId,
              'cropProfileId': c.cropProfileId,
              'commonName': c.commonName,
              'localNameSw': c.localNameSw,
              'plantingDate': c.plantingDate,
              'plantingMethod': c.plantingMethod.name,
              'growthStage': c.growthStage,
              'isRetired': c.isRetired,
            },
          )
          .toList(),
      batchPlans: _batchPlans.map(_batchToMap).toList(),
      farmContacts: _customSuppliers.map(_contactToMap).toList(),
    );
    await AccountGardenProfileStorage.save(profile);
  }

  static Map<String, dynamic> _batchToMap(CropBatchPlan b) => {
        'batchId': b.batchId,
        'cropProfileId': b.cropProfileId,
        'startMode': b.startMode.name,
        'anchorDate': b.anchorDate,
        'plantCount': b.plantCount,
        if (b.traysCount != null) 'traysCount': b.traysCount,
        if (b.actualHarvestDate != null) 'actualHarvestDate': b.actualHarvestDate,
        if (b.successionGroupId != null) 'successionGroupId': b.successionGroupId,
        if (b.successionIndex != null) 'successionIndex': b.successionIndex,
        'completedMilestoneIds': b.completedMilestoneIds.toList(),
      };

  static CropBatchPlan? _batchFromMap(Map<String, dynamic> m) {
    final batchId = m['batchId'] as String?;
    final cropProfileId = m['cropProfileId'] as String?;
    final anchorDate = m['anchorDate'] as String?;
    if (batchId == null || cropProfileId == null || anchorDate == null) return null;
    final completedRaw = m['completedMilestoneIds'];
    final completed = completedRaw is List
        ? completedRaw.map((e) => e.toString()).toSet()
        : <String>{};
    return CropBatchPlan(
      batchId: batchId,
      cropProfileId: cropProfileId,
      startMode: BatchStartMode.values.firstWhere(
        (e) => e.name == (m['startMode'] as String?),
        orElse: () => BatchStartMode.seedNursery,
      ),
      anchorDate: anchorDate,
      plantCount: (m['plantCount'] as num?)?.toInt() ?? 20,
      traysCount: (m['traysCount'] as num?)?.toInt(),
      actualHarvestDate: m['actualHarvestDate'] as String?,
      successionGroupId: m['successionGroupId'] as String?,
      successionIndex: (m['successionIndex'] as num?)?.toInt(),
      completedMilestoneIds: completed,
    );
  }

  static Map<String, dynamic> _contactToMap(AgroSupplier s) => {
        'id': s.id,
        'name': s.name,
        'regionName': s.regionName,
        'townOrArea': s.townOrArea,
        'phoneNumber': s.phoneNumber,
        'inputsStocked': s.inputsStocked,
        'category': s.category.name,
        'isUserAdded': s.isUserAdded,
      };

  static AgroSupplier? _contactFromMap(Map<String, dynamic> m) {
    final id = m['id'] as String?;
    final name = m['name'] as String?;
    final phone = m['phoneNumber'] as String?;
    if (id == null || name == null || phone == null) return null;
    final inputsRaw = m['inputsStocked'];
    return AgroSupplier(
      id: id,
      name: name,
      regionName: (m['regionName'] as String?) ?? 'Tanzania',
      townOrArea: (m['townOrArea'] as String?) ?? 'Local',
      phoneNumber: phone,
      inputsStocked: inputsRaw is List
          ? inputsRaw.map((e) => e.toString()).toList()
          : const <String>[],
      category: FarmContactCategory.values.firstWhere(
        (e) => e.name == (m['category'] as String?),
        orElse: () => FarmContactCategory.supplier,
      ),
      isUserAdded: (m['isUserAdded'] as bool?) ?? true,
    );
  }

  Future<void> _syncBatchToFirestore(CropBatchPlan batch) async {
    if (Firebase.apps.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .doc('users/$uid/cropBatches/${batch.batchId}')
          .set({
        ..._batchToMap(batch),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Local batch plan remains saved even if offline.
    }
  }

  Future<void> _syncContactToFirestore(AgroSupplier contact) async {
    if (Firebase.apps.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .doc('users/$uid/farmContacts/${contact.id}')
          .set({
        ..._contactToMap(contact),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Local farm contact remains saved even if offline.
    }
  }

  Future<void> _loadRemoteBatchesAndContacts() async {
    if (Firebase.apps.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    var changed = false;
    try {
      final batchSnap = await FirebaseFirestore.instance
          .collection('users/$uid/cropBatches')
          .get();
      for (final doc in batchSnap.docs) {
        final batch = _batchFromMap(doc.data());
        if (batch != null && !_batchPlans.any((b) => b.batchId == batch.batchId)) {
          _batchPlans.add(batch);
          changed = true;
        }
      }
    } catch (_) {}
    try {
      final contactSnap = await FirebaseFirestore.instance
          .collection('users/$uid/farmContacts')
          .get();
      for (final doc in contactSnap.docs) {
        final contact = _contactFromMap(doc.data());
        if (contact != null && !_customSuppliers.any((s) => s.id == contact.id)) {
          _customSuppliers.add(contact);
          changed = true;
        }
      }
    } catch (_) {}
    if (changed) {
      notifyListeners();
      unawaited(_persistLocalGardenProfile());
    }
  }

  /// Permanently updates the farmer's garden location, plot name, area, and growing space.
  Future<void> updatePlotSettings({
    required String plotName,
    required String regionName,
    required PlotType plotType,
    required SunlightExposure sunlightExposure,
    String? farmAreaLabel,
  }) async {
    final existing = _activePlot;
    final plotId = existing?.plotId ?? 'plot_main';
    final resolvedRegion = regionName.trim().isEmpty ? 'Tanzania' : regionName.trim();
    final resolvedName = plotName.trim().isEmpty ? '$resolvedRegion Plot' : plotName.trim();
    final rainExposure = switch (plotType) {
      PlotType.indoorWindow => RainExposure.indoor,
      PlotType.container => RainExposure.sheltered,
      _ => RainExposure.exposed,
    };
    _activePlot = PlotModel(
      plotId: plotId,
      name: resolvedName,
      plotType: plotType,
      rainExposure: rainExposure,
      sunlightExposure: sunlightExposure,
      regionName: resolvedRegion,
    );
    _farmAreaLabel = farmAreaLabel?.trim().isEmpty == true ? null : farmAreaLabel?.trim();
    _initialized = true;
    notifyListeners();
    await _persistLocalGardenProfile();

    if (Firebase.apps.isNotEmpty) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        final coords =
            kTanzaniaRegionCoords[resolvedRegion] ?? (lat: -6.7924, lng: 39.2083);
        try {
          await FirebaseFirestore.instance.doc('users/$uid').update({
            'geographicLocation': {
              'lat': coords.lat,
              'lng': coords.lng,
              'regionName': resolvedRegion,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (err) {
          _lastSyncError = err.toString();
        }

        final plotRef = FirebaseFirestore.instance.doc('users/$uid/plots/$plotId');
        try {
          await plotRef.update({
            'name': _activePlot!.name,
            'plotType': _plotTypeToWire(plotType),
            'rainExposure': _rainExposureToWire(rainExposure),
            'sunlightExposure': _sunlightToWire(sunlightExposure),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } on FirebaseException catch (err) {
          if (err.code == 'not-found') {
            try {
              await plotRef.set({
                'plotId': plotId,
                'name': _activePlot!.name,
                'plotType': _plotTypeToWire(plotType),
                'rainExposure': _rainExposureToWire(rainExposure),
                'dimensions': null,
                'sunlightExposure': _sunlightToWire(sunlightExposure),
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } catch (_) {}
          }
        } catch (_) {
          // Local profile remains saved even if offline.
        }
      }
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
