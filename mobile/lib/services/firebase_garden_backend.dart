import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/image_quality.dart';
import '../data/tanzania_crops.dart';
import '../models/garden_models.dart';
import 'garden_backend_client.dart';

/// Build-time Firebase runtime configuration via `--dart-define`.
///
/// Local Emulator example:
/// ```
/// flutter run -d chrome \
///   --dart-define=USE_FIREBASE_EMULATORS=true \
///   --dart-define=FIREBASE_PROJECT_ID=ai-gardening-mentor-tz
/// ```
class FirebaseRuntimeConfig {
  static const bool useEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );
  static const String emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'ai-gardening-mentor-tz',
  );
  static const String region = String.fromEnvironment(
    'FIREBASE_REGION',
    defaultValue: 'europe-west1',
  );
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '000000000000',
  );
  static const String storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

  static bool get hasExplicitOptions => apiKey.isNotEmpty && appId.isNotEmpty;

  static FirebaseOptions? resolveOptions() {
    if (hasExplicitOptions) {
      return FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain.isNotEmpty ? authDomain : '$projectId.firebaseapp.com',
        storageBucket:
            storageBucket.isNotEmpty ? storageBucket : '$projectId.firebasestorage.app',
      );
    }
    if (useEmulators) {
      // Synthetic options are sufficient for local Firebase Emulators (Web/Desktop/Mobile).
      return const FirebaseOptions(
        apiKey: 'demo-emulator-api-key',
        appId: '1:000000000000:web:ai-gardening-mentor-tz',
        messagingSenderId: '000000000000',
        projectId: projectId,
        storageBucket: '$projectId.appspot.com',
      );
    }
    return null;
  }

  static Uri chatStreamEndpoint() {
    if (useEmulators) {
      return Uri.parse(
        'http://$emulatorHost:5001/$projectId/$region/processMentorChatMessage',
      );
    }
    return Uri.parse(
      'https://$region-$projectId.cloudfunctions.net/processMentorChatMessage',
    );
  }
}

/// Live Firebase implementation connecting Flutter to:
/// - Firebase Auth (anonymous sign-in)
/// - Cloud Firestore (with offline persistence enabled)
/// - Private Cloud Storage (`users/{uid}/diagnostics/{diagnosisId}.jpg`)
/// - Cloud Functions v2 in `europe-west1` (callables + authenticated HTTPS SSE)
class FirebaseGardenBackend implements GardenBackendClient {
  FirebaseGardenBackend._({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required FirebaseStorage storage,
    required bool usingEmulators,
    http.Client? httpClient,
  })  : _auth = auth,
        _firestore = firestore,
        _functions = functions,
        _storage = storage,
        _usingEmulators = usingEmulators,
        _httpClient = httpClient ?? http.Client();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final bool _usingEmulators;
  final http.Client _httpClient;

  /// Initializes Firebase once across backend and AI Logic services.
  /// Returns `false` if this platform has no Firebase options configured.
  static Future<bool> ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) return true;
    final options = FirebaseRuntimeConfig.resolveOptions();
    try {
      if (options != null) {
        await Firebase.initializeApp(options: options);
        return true;
      }
      if (!kIsWeb) {
        await Firebase.initializeApp();
        return true;
      }
      return false;
    } on FirebaseException catch (err) {
      if (err.code == 'duplicate-app') return true;
      rethrow;
    }
  }

  /// Attempts to initialize Firebase (live or local emulators).
  /// Returns `null` cleanly if no Firebase options are configured on this host,
  /// allowing the app to run in pure local offline preview mode.
  static Future<FirebaseGardenBackend?> tryInitialize() async {
    try {
      if (!await ensureFirebaseInitialized()) {
        return null;
      }

      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final functions = FirebaseFunctions.instanceFor(region: FirebaseRuntimeConfig.region);
      final storage = FirebaseStorage.instance;

      if (FirebaseRuntimeConfig.useEmulators) {
        final host = FirebaseRuntimeConfig.emulatorHost;
        await auth.useAuthEmulator(host, 9099);
        firestore.useFirestoreEmulator(host, 8088); // Matches backend/firebase.json
        functions.useFunctionsEmulator(host, 5001);
        await storage.useStorageEmulator(host, 9199);
      }

      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      final backend = FirebaseGardenBackend._(
        auth: auth,
        firestore: firestore,
        functions: functions,
        storage: storage,
        usingEmulators: FirebaseRuntimeConfig.useEmulators,
      );
      return backend;
    } catch (err) {
      debugPrint('Firebase unavailable — running in local offline preview mode: $err');
      return null;
    }
  }

  @override
  bool get isLiveConnected => _auth.currentUser != null;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  String get connectionLabel =>
      _usingEmulators ? 'Firebase Emulators' : 'Firebase (${FirebaseRuntimeConfig.region})';

  @override
  Future<void> ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Authenticated Firebase user required.');
    }
    return uid;
  }

  @override
  Stream<GardenSnapshot> watchGarden() {
    final uid = _requireUid();
    final controller = StreamController<GardenSnapshot>.broadcast();

    String regionName = 'Tanzania';
    PlotModel? activePlot;
    List<CropModel> crops = const [];
    List<TaskModel> tasks = const [];
    Map<String, List<TaskCompletionEvent>> completions = const {};

    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? profileSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? plotsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? cropsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? tasksSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? completionsSub;

    void emit() {
      if (!controller.isClosed) {
        controller.add(
          GardenSnapshot(
            activePlot: activePlot,
            crops: crops,
            tasks: tasks,
            completionsByTaskId: completions,
          ),
        );
      }
    }

    profileSub = _firestore.doc('users/$uid').snapshots().listen((snap) {
      final data = snap.data();
      final loc = data?['geographicLocation'] as Map<String, dynamic>?;
      final name = loc?['regionName'] as String?;
      if (name != null && name.isNotEmpty) {
        regionName = name;
        if (activePlot != null) {
          activePlot = PlotModel(
            plotId: activePlot!.plotId,
            name: activePlot!.name,
            plotType: activePlot!.plotType,
            rainExposure: activePlot!.rainExposure,
            sunlightExposure: activePlot!.sunlightExposure,
            regionName: regionName,
          );
          emit();
        }
      }
    });

    plotsSub = _firestore.collection('users/$uid/plots').snapshots().listen((snap) {
      if (snap.docs.isEmpty) {
        activePlot = null;
        crops = const [];
        cropsSub?.cancel();
        emit();
        return;
      }
      final doc = snap.docs.first;
      final d = doc.data();
      final plotId = (d['plotId'] as String?) ?? doc.id;
      activePlot = PlotModel(
        plotId: plotId,
        name: (d['name'] as String?) ?? 'Home Garden Bed',
        plotType: _parsePlotType(d['plotType'] as String?),
        rainExposure: _parseRainExposure(d['rainExposure'] as String?),
        sunlightExposure: _parseSunlight(d['sunlightExposure'] as String?),
        regionName: regionName,
      );

      cropsSub?.cancel();
      cropsSub = _firestore
          .collection('users/$uid/plots/$plotId/crops')
          .snapshots()
          .listen((cropSnap) {
        crops = cropSnap.docs.map((cDoc) {
          final c = cDoc.data();
          final profileId = (c['cropProfileId'] as String?) ?? '';
          final matched = kTanzaniaCrops.where((o) => o.profileId == profileId).firstOrNull;
          return CropModel(
            cropId: (c['cropId'] as String?) ?? cDoc.id,
            plotId: plotId,
            cropProfileId: profileId,
            commonName: (c['commonName'] as String?) ?? matched?.commonName ?? profileId,
            localNameSw: matched?.localNameSw ?? '',
            plantingDate: (c['plantingDate'] as String?) ?? '',
            plantingMethod: (c['plantingMethod'] as String?) == 'direct_seed'
                ? PlantingMethod.directSeed
                : PlantingMethod.transplant,
            growthStage: (c['currentGrowthStage'] as String?) ?? 'vegetative',
            isRetired: (c['lifecycleStatus'] as String?) == 'retired',
          );
        }).toList();
        emit();
      });
      emit();
    });

    tasksSub = _firestore.collection('users/$uid/tasks').snapshots().listen((snap) {
      tasks = snap.docs.map((doc) {
        final t = doc.data();
        final rawSteps = (t['steps'] as List<dynamic>?) ?? const [];
        final rawRefs = (t['sourceRefs'] as List<dynamic>?) ?? const [];
        return TaskModel(
          taskId: (t['taskId'] as String?) ?? doc.id,
          cropId: (t['cropId'] as String?) ?? '',
          plotId: (t['plotId'] as String?) ?? '',
          cropName: (t['cropName'] as String?) ?? (t['cropId'] as String?) ?? 'Crop',
          category: (t['category'] as String?) ?? 'watering',
          title: (t['title'] as String?) ?? 'Garden Care',
          instructions: (t['instructions'] as String?) ?? '',
          steps: rawSteps.map((s) => s.toString()).toList(),
          rationale: (t['rationale'] as String?) ?? '',
          estimatedDurationMinutes: (t['estimatedDurationMinutes'] as num?)?.toInt() ?? 3,
          scheduledDate: (t['scheduledDate'] as String?) ?? '',
          scheduleStatus: _parseScheduleStatus(t['scheduleStatus'] as String?),
          weatherOverrideReason: t['weatherOverrideReason'] as String?,
          sources: rawRefs.isEmpty ? const [kGrowHowFixtureCitation] : _parseCitations(rawRefs),
        );
      }).toList()
        ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
      emit();
    });

    completionsSub = _firestore.collection('users/$uid/taskCompletions').snapshots().listen((snap) {
      final grouped = <String, List<TaskCompletionEvent>>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        final taskId = (d['taskId'] as String?) ?? '';
        if (taskId.isEmpty) continue;
        final ts = d['completedAt'];
        final completedAtUtc = ts is Timestamp ? ts.toDate().toUtc() : DateTime.now().toUtc();
        grouped.putIfAbsent(taskId, () => []).add(
              TaskCompletionEvent(
                eventId: (d['eventId'] as String?) ?? doc.id,
                taskId: taskId,
                completedAtUtc: completedAtUtc,
                pendingSync: doc.metadata.hasPendingWrites,
              ),
            );
      }
      completions = grouped;
      emit();
    });

    controller.onCancel = () {
      profileSub?.cancel();
      plotsSub?.cancel();
      cropsSub?.cancel();
      tasksSub?.cancel();
      completionsSub?.cancel();
    };

    return controller.stream;
  }

  @override
  Future<Map<String, dynamic>> initializeGarden(Map<String, dynamic> payload) async {
    await ensureSignedIn();
    final callable = _functions.httpsCallable('initializeGarden');
    final result = await callable.call<dynamic>(payload);
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<void> appendTaskCompletion(TaskCompletionEvent event) async {
    await ensureSignedIn();
    final uid = _requireUid();
    // Strictly matches backend/firestore.rules allowlist:
    // ['eventId', 'taskId', 'completedAt', 'receivedAt']
    await _firestore.doc('users/$uid/taskCompletions/${event.eventId}').set({
      'eventId': event.eventId,
      'taskId': event.taskId,
      'completedAt': Timestamp.fromDate(event.completedAtUtc),
      'receivedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<String> uploadDiagnosticJpeg({
    required String diagnosisId,
    required Uint8List jpegBytes,
    required int widthPx,
    required int heightPx,
  }) async {
    await ensureSignedIn();
    final uid = _requireUid();
    final storagePath = 'users/$uid/diagnostics/$diagnosisId.jpg';
    final ref = _storage.ref(storagePath);
    await ref.putData(
      jpegBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'widthPx': widthPx.toString(),
          'heightPx': heightPx.toString(),
        },
      ),
    );
    return storagePath;
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
    await ensureSignedIn();
    final callable = _functions.httpsCallable('executeMultimodalTriage');
    final response = await callable.call<dynamic>({
      'requestId': requestId,
      'diagnosisId': diagnosisId,
      'imageStoragePath': imageStoragePath,
      'cropId': cropId,
      'plotId': plotId,
      'preFlightMetrics': {
        'policyVersion': 'image-quality-v1',
        'laplacianVariance': metrics.laplacianVariance,
        'meanLuminance': metrics.meanLuminance,
        'saturatedFraction': metrics.saturatedFraction,
        'subjectCheckPassed': metrics.subjectCheckPassed,
      },
    });

    final data = Map<String, dynamic>.from(response.data as Map);
    final log = Map<String, dynamic>.from((data['triageLog'] ?? data) as Map);
    final card = Map<String, dynamic>.from(log['triageCard'] as Map);

    return TriageOutcome(
      diagnosisId: (log['diagnosisId'] as String?) ?? diagnosisId,
      assessmentStatus: (log['assessmentStatus'] as String?) ?? 'uncertain',
      whatItIs: (card['whatItIs'] as String?) ?? '',
      immediateAction: (card['immediateAction'] as String?) ?? '',
      whatNotToWorryAbout: (card['whatNotToWorryAbout'] as String?) ?? '',
      detectedAnomalyType: log['detectedAnomalyType'] as String?,
      recoveryTemplateId: log['recoveryTemplateId'] as String?,
      sourceRefs: _parseCitations((log['sourceRefs'] as List<dynamic>?) ?? const []),
    );
  }

  @override
  Future<void> addRecoveryTask({
    required String requestId,
    required String diagnosisId,
    required String plotId,
    required String cropId,
  }) async {
    await ensureSignedIn();
    final callable = _functions.httpsCallable('addRecoveryTask');
    await callable.call<dynamic>({
      'requestId': requestId,
      'diagnosisId': diagnosisId,
      'plotId': plotId,
      'cropId': cropId,
    });
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
    await ensureSignedIn();
    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Unable to obtain Firebase ID token for Mentor stream.');
    }

    final req = http.Request('POST', FirebaseRuntimeConfig.chatStreamEndpoint());
    req.headers['Authorization'] = 'Bearer $idToken';
    req.headers['Content-Type'] = 'application/json';
    req.headers['Accept'] = 'text/event-stream';
    req.body = jsonEncode({
      'requestId': requestId,
      'sessionId': sessionId,
      'messageId': messageId,
      'text': text,
      'plotId': plotId,
      'diagnosisId': diagnosisId,
    });

    final streamed = await _httpClient.send(req);
    if (streamed.statusCode >= 400) {
      final body = await streamed.stream.bytesToString();
      throw StateError('Mentor chat HTTP ${streamed.statusCode}: $body');
    }

    String currentEvent = 'message';
    final dataBuffer = StringBuffer();

    await for (final line in streamed.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataBuffer.isNotEmpty) {
          final rawJson = dataBuffer.toString().trim();
          dataBuffer.clear();
          try {
            final parsed = jsonDecode(rawJson) as Map<String, dynamic>;
            yield MentorSseEvent(event: currentEvent, data: parsed);
          } catch (_) {
            yield MentorSseEvent(event: currentEvent, data: {'raw': rawJson});
          }
        }
        currentEvent = 'message';
      } else if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataBuffer.writeln(line.substring(5).trim());
      }
    }
  }

  @override
  Future<void> archiveChatSession({
    required String requestId,
    required String sessionId,
  }) async {
    await ensureSignedIn();
    final callable = _functions.httpsCallable('archiveChatSession');
    await callable.call<dynamic>({
      'requestId': requestId,
      'sessionId': sessionId,
    });
  }

  static PlotType _parsePlotType(String? raw) => switch (raw) {
        'in_ground' => PlotType.inGround,
        'raised_bed' => PlotType.raisedBed,
        'container' => PlotType.container,
        'indoor_window' => PlotType.indoorWindow,
        _ => PlotType.raisedBed,
      };

  static RainExposure _parseRainExposure(String? raw) => switch (raw) {
        'exposed' => RainExposure.exposed,
        'sheltered' => RainExposure.sheltered,
        'indoor' => RainExposure.indoor,
        _ => RainExposure.exposed,
      };

  static SunlightExposure _parseSunlight(String? raw) => switch (raw) {
        'full_sun' => SunlightExposure.fullSun,
        'partial_shade' => SunlightExposure.partialShade,
        'deep_shade' => SunlightExposure.deepShade,
        _ => SunlightExposure.fullSun,
      };

  static ScheduleStatus _parseScheduleStatus(String? raw) => switch (raw) {
        'deferred_weather' => ScheduleStatus.deferredWeather,
        'cancelled' => ScheduleStatus.cancelled,
        _ => ScheduleStatus.pending,
      };

  static List<SourceCitation> _parseCitations(List<dynamic> rawRefs) {
    return rawRefs.map((entry) {
      final map = Map<String, dynamic>.from(entry as Map);
      return SourceCitation(
        sourceId: (map['sourceId'] as String?) ?? kGrowHowFixtureCitation.sourceId,
        revision: (map['revision'] as String?) ?? kGrowHowFixtureCitation.revision,
        passageId: (map['passageId'] as String?) ?? kGrowHowFixtureCitation.passageId,
        publisher: (map['publisher'] as String?) ?? kGrowHowFixtureCitation.publisher,
        title: (map['title'] as String?) ?? kGrowHowFixtureCitation.title,
        canonicalUrl: (map['canonicalUrl'] as String?) ?? kGrowHowFixtureCitation.canonicalUrl,
      );
    }).toList();
  }
}
