import '../models/crop_planner_models.dart';

/// Deterministic, rule-based offline field guidance.
///
/// IMPORTANT: This is saved/rule-based guidance—NOT on-device AI inference.
/// Genuine on-device and cloud hybrid generation lives in `HybridChecklistAdapter`.
class SavedOfflineGuidance {
  const SavedOfflineGuidance({
    required this.badgeLabel,
    required this.content,
    required this.needsConnectionForNewAiAnswer,
  });

  final String badgeLabel;
  final String content;
  final bool needsConnectionForNewAiAnswer;
}

class HybridMentorResponder {
  /// Returns a deterministic Saved Field Guide when the farmer is offline or
  /// cloud mentor is unreachable, clearly stating it is saved guidance and that
  /// a new cloud AI answer requires an internet connection.
  static SavedOfflineGuidance buildOfflineSafeGuide({
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

    return SavedOfflineGuidance(
      badgeLabel: 'Saved Field Guide (Offline)',
      needsConnectionForNewAiAnswer: true,
      content:
          'Saved Field Guide ($regionName — Not AI Generated):\n'
          '1. Immediate Safe Step: ${guidance.safeStep}\n'
          '2. What to Check: ${guidance.checkStep}\n'
          '3. What NOT to Do: ${guidance.avoidStep}$prepNote\n\n'
          'Note: You are viewing saved rule-based guidance. A new cloud mentor answer needs an internet connection, '
          'or open "Offline Care Checklist" to run on-device Firebase AI Logic if supported on this device.',
    );
  }

  static _TopicGuidance _matchTopicGuidance(
    String question,
    String regionName,
    String cropsSummary,
  ) {
    final q = question.toLowerCase();

    if (RegExp(r'yellow|spot|blight|mildew|curl|leaf|leaves').hasMatch(q)) {
      return const _TopicGuidance(
        safeStep: 'Remove only the worst bottom yellowed leaves at the stem collar and keep foliage dry.',
        checkStep: 'Inspect the underside of upper young leaves for insects or spreading dark rings.',
        avoidStep: 'Do not panic-spray strong chemicals during midday sun—it can scorch healthy leaves.',
      );
    }

    if (RegExp(r'pest|aphid|worm|bug|insect|whitefly|hole').hasMatch(q)) {
      return const _TopicGuidance(
        safeStep: 'Hand-remove visible caterpillars/beetles and spray leaf undersides with clean water in the morning.',
        checkStep: 'Check young shoots and flower buds across 5 plants to see if damage is spreading.',
        avoidStep: 'Avoid broad-spectrum spraying at noon when bees are active and heat is high.',
      );
    }

    if (RegExp(r'water|wilt|dry|rain|heat|droop').hasMatch(q)) {
      return const _TopicGuidance(
        safeStep: 'Push your finger 5 cm into the root zone—water deeply at the soil base only if dry.',
        checkStep: 'Check whether plants recover in the cool evening (normal midday heat droop vs. true drought).',
        avoidStep: 'Avoid overhead watering late in the evening, which encourages fungal spots.',
      );
    }

    if (RegExp(r'fertilizer|dap|can|urea|npk|foliar|manure|feed|nutrient').hasMatch(q)) {
      return const _TopicGuidance(
        safeStep: 'Check your Crop Planner stage before applying—keep granules 5 cm away from the stem.',
        checkStep: 'Confirm soil is moist before side-dressing DAP, CAN/Urea, or NPK 17:17:17.',
        avoidStep: 'Never drop concentrated fertilizer directly against wet stems or dry midday soil.',
      );
    }

    return const _TopicGuidance(
      safeStep: 'Do a 5-minute morning check: feel soil moisture 5 cm deep and water at the root zone if dry.',
      checkStep: 'Look under lower leaves and review your next Crop Planner milestone.',
      avoidStep: 'Avoid changing watering and fertilizer routines all at once without checking the root zone first.',
    );
  }
}

class _TopicGuidance {
  const _TopicGuidance({
    required this.safeStep,
    required this.checkStep,
    required this.avoidStep,
  });

  final String safeStep;
  final String checkStep;
  final String avoidStep;
}
