import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_gardening_mentor/data/offline_garden_store.dart';
import 'package:ai_gardening_mentor/data/reviewed_tomato_guide.dart';
import 'package:ai_gardening_mentor/screens/offline_checklist_screen.dart';
import 'package:ai_gardening_mentor/services/checklist_storage.dart';
import 'package:ai_gardening_mentor/services/hybrid_checklist_contract.dart';
import 'package:ai_gardening_mentor/services/hybrid_mentor_responder.dart';

class _FakeHybridAdapter implements HybridChecklistAdapter {
  _FakeHybridAdapter({
    required this.initialCapability,
    required this.generateResult,
  });

  HybridCapabilityInfo initialCapability;
  HybridChecklistResult generateResult;
  bool cancelled = false;
  bool prepareCalled = false;

  @override
  Future<HybridCapabilityInfo> checkCapability() async => initialCapability;

  @override
  Stream<HybridCapabilityInfo> prepareModel() async* {
    prepareCalled = true;
    yield const HybridCapabilityInfo(
      status: HybridCapabilityStatus.downloading,
      downloadProgress: 0.5,
      message: 'Downloading...',
    );
    initialCapability = const HybridCapabilityInfo(
      status: HybridCapabilityStatus.ready,
      modelIdentity: 'Gemini Nano Test',
      downloadProgress: 1.0,
      message: 'Ready',
    );
    yield initialCapability;
  }

  @override
  Future<HybridChecklistResult> generateChecklist({
    required String prompt,
    required HybridInferenceMode mode,
    required String requestId,
    String cloudModel = 'gemini-3.8-flash',
  }) async {
    return generateResult;
  }

  @override
  Future<void> cancel(String requestId) async {
    cancelled = true;
  }

  @override
  void dispose() {}
}

void main() {
  test('Saved Field Guide is clearly labelled as non-AI saved guidance', () {
    final res = HybridMentorResponder.buildOfflineSafeGuide(
      regionName: 'Arusha',
      cropsSummary: 'Tomato',
      userQuestion: 'Lower leaves turning yellow',
    );
    expect(res.badgeLabel, contains('Saved Field Guide'));
    expect(res.badgeLabel, isNot(contains('On-Device AI')));
    expect(res.needsConnectionForNewAiAnswer, isTrue);
  });

  test('Shared tomato prompt includes bundled guide, stage, observation, and anti-injection framing', () {
    final prompt = buildCareChecklistPrompt(
      guideText: kReviewedTomatoGuideText,
      cropStage: 'Flowering',
      observation: 'Bottom two leaves yellowed after rain',
      regionName: 'Dodoma',
    );
    expect(prompt, contains('<<<GUIDE DATA>>>'));
    expect(prompt, contains('<<<FARMER OBSERVATION>>>'));
    expect(prompt, contains('Flowering'));
    expect(prompt, contains('Bottom two leaves yellowed after rain'));
    expect(prompt, contains('Dodoma'));
  });

  test('Account-scoped persistence isolates saved checklists between users', () async {
    const userA = 'user_a_test@example.com';
    const userB = 'user_b_test@example.com';
    await AccountChecklistStorage.clear(userA);
    await AccountChecklistStorage.clear(userB);

    await AccountChecklistStorage.save(
      const PersistedChecklistRecord(
        accountId: userA,
        cropStage: 'Flowering',
        observation: 'Check stakes',
        checklistText: '1. Inspect tomato stakes before wind.',
        savedAtIso: '2026-11-23T12:00:00Z',
        originalSource: 'onDevice',
      ),
    );

    final loadedA = await AccountChecklistStorage.load(userA);
    final loadedB = await AccountChecklistStorage.load(userB);
    expect(loadedA, isNotNull);
    expect(loadedA!.checklistText, contains('Inspect tomato stakes'));
    expect(loadedB, isNull);

    await AccountChecklistStorage.clear(userA);
  });

  testWidgets('OfflineChecklistScreen prepares explicitly and displays real SDK inference source', (tester) async {
    AccountChecklistStorage.debugMemoryStore = {};
    addTearDown(() => AccountChecklistStorage.debugMemoryStore = null);

    final store = OfflineGardenStore();
    await store.signInWithEmail(
      email: 'checklist_test@example.com',
      password: 'password123',
      displayName: 'Test Farmer',
      createAccount: true,
    );

    final adapter = _FakeHybridAdapter(
      initialCapability: const HybridCapabilityInfo(
        status: HybridCapabilityStatus.downloadAvailable,
        platformLabel: 'Test Device',
        message: 'Ready to prepare',
      ),
      generateResult: const HybridChecklistResult(
        requestId: 'req_1',
        text: '1. Check soil 5 cm deep before watering.\n2. Snip bottom 2 yellow leaves.',
        inferenceSource: HybridInferenceSource.onDevice,
        elapsedMs: 420,
        modelIdentity: 'Gemini Nano Test',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OfflineChecklistScreen(store: store, adapterOverride: adapter),
      ),
    );
    await tester.pumpAndSettle();

    // Download does not occur until user explicitly taps "Prepare offline AI"
    expect(adapter.prepareCalled, isFalse);
    expect(find.text('Prepare offline AI'), findsOneWidget);

    await tester.tap(find.text('Prepare offline AI'));
    await tester.pumpAndSettle();
    expect(adapter.prepareCalled, isTrue);
    expect(find.text('On-device AI ready (offline checklist supported)'), findsOneWidget);

    await tester.tap(find.text("Make Today's Care Checklist"));
    await tester.pumpAndSettle();

    expect(find.text('Generated on this device'), findsOneWidget);
    expect(find.text('420 ms'), findsOneWidget);
    expect(find.textContaining('Check soil 5 cm deep'), findsOneWidget);

    await AccountChecklistStorage.clear('checklist_test@example.com');
  });
}
