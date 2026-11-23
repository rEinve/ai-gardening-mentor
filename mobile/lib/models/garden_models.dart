// Canonical Flutter data models matching docs/schema.md (Tanzania MVP).

enum PlotType { inGround, raisedBed, container, indoorWindow }

enum RainExposure { exposed, sheltered, indoor }

enum SunlightExposure { fullSun, partialShade, deepShade }

enum PlantingMethod { directSeed, transplant }

enum ScheduleStatus { pending, deferredWeather, cancelled }

enum EffectiveTaskStatus { completed, cancelled, deferredWeather, pending }

class TanzaniaCropOption {
  const TanzaniaCropOption({
    required this.profileId,
    required this.commonName,
    required this.localNameSw,
    required this.family,
    required this.defaultMethod,
  });

  final String profileId;
  final String commonName;
  final String localNameSw;
  final String family;
  final PlantingMethod defaultMethod;
}

class SourceCitation {
  const SourceCitation({
    required this.sourceId,
    required this.revision,
    required this.passageId,
    required this.publisher,
    required this.title,
    required this.canonicalUrl,
  });

  final String sourceId;
  final String revision;
  final String passageId;
  final String publisher;
  final String title;
  final String canonicalUrl;
}

class PlotModel {
  const PlotModel({
    required this.plotId,
    required this.name,
    required this.plotType,
    required this.rainExposure,
    required this.sunlightExposure,
    required this.regionName,
  });

  final String plotId;
  final String name;
  final PlotType plotType;
  final RainExposure rainExposure;
  final SunlightExposure sunlightExposure;
  final String regionName;
}

class CropModel {
  const CropModel({
    required this.cropId,
    required this.plotId,
    required this.cropProfileId,
    required this.commonName,
    required this.localNameSw,
    required this.plantingDate,
    required this.plantingMethod,
    required this.growthStage,
    this.isRetired = false,
  });

  final String cropId;
  final String plotId;
  final String cropProfileId;
  final String commonName;
  final String localNameSw;
  final String plantingDate; // YYYY-MM-DD
  final PlantingMethod plantingMethod;
  final String growthStage;
  final bool isRetired;
}

class TaskModel {
  const TaskModel({
    required this.taskId,
    required this.cropId,
    required this.plotId,
    required this.cropName,
    required this.category,
    required this.title,
    required this.instructions,
    required this.steps,
    required this.rationale,
    required this.estimatedDurationMinutes,
    required this.scheduledDate,
    required this.scheduleStatus,
    this.weatherOverrideReason,
    this.sources = const [],
  });

  final String taskId;
  final String cropId;
  final String plotId;
  final String cropName;
  final String category;
  final String title;
  final String instructions;
  final List<String> steps;
  final String rationale;
  final int estimatedDurationMinutes;
  final String scheduledDate; // YYYY-MM-DD
  final ScheduleStatus scheduleStatus;
  final String? weatherOverrideReason;
  final List<SourceCitation> sources;
}

/// Append-only physical completion record (never mutated or deleted in MVP).
class TaskCompletionEvent {
  const TaskCompletionEvent({
    required this.eventId,
    required this.taskId,
    required this.completedAtUtc,
    this.pendingSync = true,
  });

  final String eventId;
  final String taskId;
  final DateTime completedAtUtc;
  final bool pendingSync;
}

/// Derives effective UI state per docs/schema.md & Acceptance Criterion A5:
/// completed (any completion event) > cancelled > deferredWeather > pending.
EffectiveTaskStatus deriveEffectiveTaskStatus(
  TaskModel task,
  List<TaskCompletionEvent> completionsForTask,
) {
  if (completionsForTask.isNotEmpty) {
    return EffectiveTaskStatus.completed;
  }
  switch (task.scheduleStatus) {
    case ScheduleStatus.cancelled:
      return EffectiveTaskStatus.cancelled;
    case ScheduleStatus.deferredWeather:
      return EffectiveTaskStatus.deferredWeather;
    case ScheduleStatus.pending:
      return EffectiveTaskStatus.pending;
  }
}
