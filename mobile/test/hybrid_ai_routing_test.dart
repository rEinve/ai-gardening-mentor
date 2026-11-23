import 'package:flutter_test/flutter_test.dart';

import 'package:ai_gardening_mentor/services/hybrid_mentor_responder.dart';

void main() {
  test('Tier 1: Supported phone with local model downloaded + offline generates short local answer', () {
    final route = HybridMentorResponder.selectRoute(
      isOnline: false,
      hasLocalModelDownloaded: true,
    );
    expect(route, HybridAiRoute.onDeviceLocalOffline);

    final res = HybridMentorResponder.buildOnDeviceShortAnswer(
      regionName: 'Dodoma',
      cropsSummary: 'Tomato',
      userQuestion: 'My tomato lower leaves are turning yellow',
    );
    expect(res.route, HybridAiRoute.onDeviceLocalOffline);
    expect(res.needsConnectionForNewAiAnswer, isFalse);
    expect(res.badgeLabel, contains('On-Device'));
    expect(res.content, contains('Dodoma'));
  });

  test('Tier 2: Phone without local model + online routes to Cloud AI', () {
    final route = HybridMentorResponder.selectRoute(
      isOnline: true,
      hasLocalModelDownloaded: false,
    );
    expect(route, HybridAiRoute.cloudOnline);
  });

  test('Tier 3: Phone without local model + offline shows Safe Guiding Plan and explains internet is needed', () {
    final route = HybridMentorResponder.selectRoute(
      isOnline: false,
      hasLocalModelDownloaded: false,
    );
    expect(route, HybridAiRoute.offlineSafeGuide);

    final res = HybridMentorResponder.buildOfflineSafeGuide(
      regionName: 'Arusha',
      cropsSummary: 'Bell Pepper',
      userQuestion: 'How do I fertilize my peppers?',
    );
    expect(res.route, HybridAiRoute.offlineSafeGuide);
    expect(res.needsConnectionForNewAiAnswer, isTrue);
    expect(res.content, contains('Safe Guiding Plan'));
    expect(res.content, contains('needs an internet connection'));
  });
}
