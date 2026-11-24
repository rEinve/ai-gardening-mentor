import 'dart:async';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'firebase_garden_backend.dart';

/// Runtime Firebase AI Logic service (Web Chrome + Android).
///
/// - Protects AI calls with Firebase App Check (debug provider in dev; Play Integrity / reCAPTCHA in prod).
/// - Reads `ai_model_name` and `ai_prefer_on_device` from Firebase Remote Config so pilot quotas and
///   hybrid on-device/cloud settings can be tuned without republishing the app.
/// - Invokes `FirebaseAI.googleAI(appCheck: FirebaseAppCheck.instance)` at runtime for both
///   streaming Garden Mentor chat and multimodal Plant Photo Diagnosis.
class FirebaseAiLogicService {
  FirebaseAiLogicService._({
    required GenerativeModel mentorModel,
    required GenerativeModel triageModel,
    required this.activeModelName,
    required this.preferOnDevice,
  })  : _mentorModel = mentorModel,
        _triageModel = triageModel;

  final GenerativeModel _mentorModel;
  final GenerativeModel _triageModel;
  final String activeModelName;
  final bool preferOnDevice;

  static const String _defaultModel = 'gemini-3.8-flash';
  static const String _recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');
  static const bool _enablePlayIntegrity = bool.fromEnvironment('ENABLE_PLAY_INTEGRITY');
  static String? lastInitError;

  static const String _mentorSystemPrompt =
      'You are a practical vegetable farming and gardening mentor for growers in Tanzania. '
      'Keep answers concise, metric (°C, mm, cm, g/plant), and proactive. '
      'When recommending fertilizers (DAP, CAN, Urea, NPK 17:17:17, Calcium-Boron foliar) or treatments, '
      'provide clear per-plant rates and advise checking local agro-dealers (Name, Location, Phone) before travelling. '
      'Provide information only—never claim to call or place orders on the farmer\'s behalf.';

  static const String _triageSystemPrompt =
      'You are a calm plant triage assistant for vegetable growers in Tanzania. '
      'Analyze the plant photo and return three concise sections: '
      '1) What It Is, 2) Immediate Action, and 3) What NOT to Worry About. '
      'If the photo is unclear, state that identification is uncertain and ask for a clearer daylight close-up.';

  /// Attempts to initialize Firebase App Check, Remote Config, and Firebase AI Logic.
  /// Returns `null` cleanly when running in local offline/preview mode without Firebase config.
  static Future<FirebaseAiLogicService?> tryInitialize() async {
    try {
      if (!await FirebaseGardenBackend.ensureFirebaseInitialized()) {
        return null;
      }

      // Activate Firebase App Check:
      // - Web: requires RECAPTCHA_SITE_KEY (reCAPTCHA Enterprise)
      // - Android: Play Integrity when ENABLE_PLAY_INTEGRITY=true, otherwise Debug provider
      var appCheckActive = false;
      final shouldActivateAppCheck = !kIsWeb || _recaptchaSiteKey.isNotEmpty;
      if (shouldActivateAppCheck) {
        try {
          await FirebaseAppCheck.instance.activate(
            androidProvider:
                _enablePlayIntegrity ? AndroidProvider.playIntegrity : AndroidProvider.debug,
            webProvider: _recaptchaSiteKey.isNotEmpty
                ? ReCaptchaEnterpriseProvider(_recaptchaSiteKey)
                : null,
          );
          appCheckActive = true;
        } catch (err) {
          debugPrint('App Check activation note: $err');
        }
      }

      // Read cached Remote Config immediately and refresh in background so AI init never stalls.
      var modelName = _defaultModel;
      var preferOnDevice = true;
      try {
        final remoteConfig = FirebaseRemoteConfig.instance;
        await remoteConfig.setDefaults(const {
          'ai_model_name': _defaultModel,
          'ai_prefer_on_device': true,
        });
        await remoteConfig.setConfigSettings(
          RemoteConfigSettings(
            fetchTimeout: const Duration(seconds: 3),
            minimumFetchInterval: const Duration(hours: 1),
          ),
        );
        final configured = remoteConfig.getString('ai_model_name').trim();
        if (configured.isNotEmpty) {
          modelName = configured;
        }
        preferOnDevice = remoteConfig.getBool('ai_prefer_on_device');
        unawaited(remoteConfig.fetchAndActivate().catchError((_) => false));
      } catch (err) {
        debugPrint('Remote Config fallback to defaults: $err');
      }

      // Initialize Firebase AI Logic client backed by Gemini Developer API
      final ai = appCheckActive
          ? FirebaseAI.googleAI(appCheck: FirebaseAppCheck.instance)
          : FirebaseAI.googleAI();

      final mentorModel = ai.generativeModel(
        model: modelName,
        systemInstruction: Content.system(_mentorSystemPrompt),
      );

      final triageModel = ai.generativeModel(
        model: modelName,
        systemInstruction: Content.system(_triageSystemPrompt),
      );

      lastInitError = null;
      return FirebaseAiLogicService._(
        mentorModel: mentorModel,
        triageModel: triageModel,
        activeModelName: modelName,
        preferOnDevice: preferOnDevice,
      );
    } catch (err) {
      lastInitError = err.toString();
      debugPrint('Firebase AI Logic unavailable in local preview mode: $err');
      return null;
    }
  }

  /// Streams a grounded Garden Mentor response directly via Firebase AI Logic.
  Stream<String> streamMentorReply({
    required String regionName,
    required String cropsSummary,
    required String plannerSummary,
    required String userQuestion,
  }) async* {
    final prompt = [
      'Tanzania Grower Context:',
      '- Region: $regionName',
      '- Active Crops: $cropsSummary',
      if (plannerSummary.isNotEmpty) '- Upcoming Planner Milestone: $plannerSummary',
      '',
      'Question: $userQuestion',
    ].join('\n');

    final stream = _mentorModel.generateContentStream([Content.text(prompt)]);
    await for (final chunk in stream) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) {
        yield text;
      }
    }
  }

  /// Analyzes a captured or WhatsApp-uploaded plant photo via Firebase AI Logic multimodal API.
  Future<String> analyzePlantPhoto({
    required Uint8List imageBytes,
    required String regionName,
    required String cropName,
  }) async {
    final response = await _triageModel.generateContent([
      Content.multi([
        TextPart(
          'Analyze this plant photo from $regionName, Tanzania (crop: $cropName). '
          'Provide 1) What It Is, 2) Immediate Action, 3) What NOT to Worry About.',
        ),
        InlineDataPart('image/jpeg', imageBytes),
      ]),
    ]);
    return response.text?.trim() ??
        'Symptoms are not clear enough for identification. Please retake a clear daylight close-up.';
  }
}
