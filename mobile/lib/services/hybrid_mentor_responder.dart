import '../models/crop_planner_models.dart';

/// The 3 farmer-facing AI execution modes for Tanzania hybrid offline/online resilience.
enum HybridAiRoute {
  /// Supported phone with local model downloaded and no internet:
  /// generates a short, concise answer locally on-device.
  onDeviceLocalOffline,

  /// Phone without local model support when internet is available:
  /// generates the full answer in the cloud (Firebase AI Logic / Cloud Functions).
  cloudOnline,

  /// Phone without local model support and no internet:
  /// shows a deterministic Safe Guiding Plan and explains that a new AI answer
  /// needs an internet connection.
  offlineSafeGuide,
}

class HybridMentorResolution {
  const HybridMentorResolution({
    required this.route,
    required this.badgeLabel,
    required this.content,
    required this.needsConnectionForNewAiAnswer,
  });

  final HybridAiRoute route;
  final String badgeLabel;
  final String content;
  final bool needsConnectionForNewAiAnswer;
}

/// Deterministic routing & offline safe-guidance engine for Garden Mentor.
class HybridMentorResponder {
  /// Decides which of the 3 hybrid AI routes applies given device & network state.
  static HybridAiRoute selectRoute({
    required bool isOnline,
    required bool hasLocalModelDownloaded,
    bool preferOnDeviceWhenOffline = true,
  }) {
    if (!isOnline && hasLocalModelDownloaded && preferOnDeviceWhenOffline) {
      return HybridAiRoute.onDeviceLocalOffline;
    }
    if (isOnline) {
      return HybridAiRoute.cloudOnline;
    }
    return HybridAiRoute.offlineSafeGuide;
  }

  /// Generates a short on-device local answer when a supported device has a local
  /// model downloaded and no internet connection.
  static HybridMentorResolution buildOnDeviceShortAnswer({
    required String regionName,
    required String cropsSummary,
    required String userQuestion,
    ScheduledMilestone? nextPrepAlert,
  }) {
    final guidance = _matchTopicGuidance(userQuestion, regionName, cropsSummary);
    final prepNote = nextPrepAlert != null
        ? '\nNext prep (${nextPrepAlert.daysFromToday}d): ${nextPrepAlert.cropLabel} — ${nextPrepAlert.title}.'
        : '';

    return HybridMentorResolution(
      route: HybridAiRoute.onDeviceLocalOffline,
      badgeLabel: 'On-Device AI (Offline)',
      needsConnectionForNewAiAnswer: false,
      content:
          'Short On-Device Answer ($regionName):\n'
          '${guidance.shortAnswer}$prepNote',
    );
  }

  /// Generates a Safe Guiding Plan for phones without local model support when
  /// offline, clearly explaining that a new AI answer requires an internet connection.
  static HybridMentorResolution buildOfflineSafeGuide({
    required String regionName,
    required String cropsSummary,
    required String userQuestion,
    ScheduledMilestone? nextPrepAlert,
  }) {
    final guidance = _matchTopicGuidance(userQuestion, regionName, cropsSummary);
    final prepNote = nextPrepAlert != null
        ? '\n• Upcoming Planner Milestone: In ${nextPrepAlert.daysFromToday} days (${nextPrepAlert.scheduledDate}), '
            '${nextPrepAlert.cropLabel} is due for "${nextPrepAlert.title}".'
        : '';

    return HybridMentorResolution(
      route: HybridAiRoute.offlineSafeGuide,
      badgeLabel: 'Safe Offline Guide',
      needsConnectionForNewAiAnswer: true,
      content:
          'Safe Guiding Plan ($regionName — Offline):\n'
          '1. Immediate Safe Step: ${guidance.safeStep}\n'
          '2. What to Check: ${guidance.checkStep}\n'
          '3. What NOT to Do: ${guidance.avoidStep}$prepNote\n\n'
          'Note: This phone does not have a local AI model downloaded and is currently offline. '
          'A new AI answer needs an internet connection—reconnect when available to ask for a fresh AI response.',
    );
  }

  static _TopicGuidance _matchTopicGuidance(
    String question,
    String regionName,
    String cropsSummary,
  ) {
    final q = question.toLowerCase();
    final crops = cropsSummary.isEmpty ? 'your vegetables' : cropsSummary;

    if (RegExp(r'yellow|spot|blight|mildew|curl|leaf|leaves').hasMatch(q)) {
      return _TopicGuidance(
        shortAnswer:
            'Lower-leaf yellowing on $crops is often normal aging or water stress. Snip only the bottom 1–2 yellowed leaves cleanly, water at the soil base before 09:00 AM, and avoid panic-spraying in midday heat.',
        safeStep: 'Remove only the worst bottom yellowed leaves at the stem collar and keep foliage dry.',
        checkStep: 'Inspect the underside of upper young leaves for insects or spreading dark rings.',
        avoidStep: 'Do not panic-spray strong chemicals during midday sun—it can scorch healthy leaves.',
      );
    }

    if (RegExp(r'pest|aphid|worm|bug|insect|whitefly|hole').hasMatch(q)) {
      return _TopicGuidance(
        shortAnswer:
            'Inspect leaf undersides on $crops early in the morning. Hand-pick caterpillars and rinse soft aphids off with a steady water spray before deciding on any targeted agro-dealer treatment.',
        safeStep: 'Hand-remove visible caterpillars/beetles and spray leaf undersides with clean water in the morning.',
        checkStep: 'Check young shoots and flower buds across 5 plants to see if damage is spreading.',
        avoidStep: 'Avoid broad-spectrum spraying at noon when bees are active and heat is high.',
      );
    }

    if (RegExp(r'water|wilt|dry|rain|heat|droop').hasMatch(q)) {
      return _TopicGuidance(
        shortAnswer:
            'Test soil 5 cm deep near the roots of $crops. Water slowly at the soil base before 09:00 AM if dry; skip watering exposed beds after heavy rain (>12 mm).',
        safeStep: 'Push your finger 5 cm into the root zone—water deeply at the soil base only if dry.',
        checkStep: 'Check whether plants recover in the cool evening (normal midday heat droop vs. true drought).',
        avoidStep: 'Avoid overhead watering late in the evening, which encourages fungal spots.',
      );
    }

    if (RegExp(r'fertilizer|dap|can|urea|npk|foliar|manure|feed|nutrient').hasMatch(q)) {
      return _TopicGuidance(
        shortAnswer:
            'Match fertilizer to crop stage in $regionName: DAP at planting, CAN/Urea during vegetative growth, and NPK 17:17:17 + Calcium-Boron foliar at flowering/fruiting. Always water before side-dressing.',
        safeStep: 'Check your Crop Planner stage before applying—keep granules 5 cm away from the stem.',
        checkStep: 'Confirm soil is moist before side-dressing DAP, CAN/Urea, or NPK 17:17:17.',
        avoidStep: 'Never drop concentrated fertilizer directly against wet stems or dry midday soil.',
      );
    }

    return _TopicGuidance(
      shortAnswer:
          'For $crops in $regionName: water at the root zone before 09:00 AM, inspect leaf undersides twice a week, and review your 14-Day Prepare Ahead milestones in the Crop Planner.',
      safeStep: 'Do a 5-minute morning check: feel soil moisture 5 cm deep and water at the root zone if dry.',
      checkStep: 'Look under lower leaves and review your next Crop Planner milestone.',
      avoidStep: 'Avoid changing watering and fertilizer routines all at once without checking the root zone first.',
    );
  }
}

class _TopicGuidance {
  const _TopicGuidance({
    required this.shortAnswer,
    required this.safeStep,
    required this.checkStep,
    required this.avoidStep,
  });

  final String shortAnswer;
  final String safeStep;
  final String checkStep;
  final String avoidStep;
}
