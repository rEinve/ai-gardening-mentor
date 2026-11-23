/**
 * Canonical TypeScript Data Schema for AI Gardening Mentor (Tanzania MVP)
 * Strictly aligned with docs/schema.md and docs/phase-0-decisions.md.
 */

export type UnitPreference = 'metric' | 'imperial';
export type GardenExperienceLevel = 'novice' | 'beginner' | 'intermediate';
export type PlotType = 'in_ground' | 'raised_bed' | 'container' | 'indoor_window';
export type RainExposure = 'exposed' | 'sheltered' | 'indoor';
export type SunlightExposure = 'full_sun' | 'partial_shade' | 'deep_shade';
export type PlantingMethod = 'direct_seed' | 'transplant';
export type GrowthStage = 'germination' | 'vegetative' | 'flowering' | 'fruiting' | 'harvest';
export type LifecycleStatus = 'active' | 'retired';
export type HealthStatus = 'healthy' | 'stressed' | 'recovering';

export type TaskCategory =
  | 'watering'
  | 'soil_check'
  | 'pruning'
  | 'pest_scout'
  | 'frost_defense'
  | 'heat_protection'
  | 'harvesting'
  | 'recovery';

export type ScheduleStatus = 'pending' | 'deferred_weather' | 'cancelled';
export type EffectiveTaskStatus = 'completed' | 'cancelled' | 'deferred_weather' | 'pending';
export type RequestState = 'queued' | 'processing' | 'succeeded' | 'failed';
export type ReviewStatus = 'prototype_fixture' | 'approved' | 'deprecated';

export interface GeographicLocation {
  latitude: number;
  longitude: number;
  regionName: string; // e.g., "Dar es Salaam", "Arusha", "Morogoro"
  countryCode: string; // "TZ"
  postalCode: string | null;
  usdaHardinessZone: string | null; // null for Tanzania
}

export interface UserProfile {
  userId: string;
  displayName: string | null;
  email: string | null;
  isAnonymous: boolean;
  geographicLocation: GeographicLocation;
  timeZone: string; // IANA ID, default "Africa/Dar_es_Salaam"
  unitPreference: UnitPreference;
  gardenExperienceLevel: GardenExperienceLevel;
  fcmDeviceTokens: string[];
  createdAt: string; // ISO UTC timestamp
  updatedAt: string;
}

export interface PlotDimensions {
  lengthMetres: number;
  widthMetres: number;
}

export interface PlotRecord {
  plotId: string;
  name: string;
  plotType: PlotType;
  rainExposure: RainExposure;
  dimensions: PlotDimensions | null;
  sunlightExposure: SunlightExposure;
  createdAt: string;
  updatedAt: string;
}

export interface CropRecord {
  cropId: string;
  cropProfileId: string;
  commonName: string;
  variety: string | null;
  plantingDate: string; // YYYY-MM-DD local date
  plantingMethod: PlantingMethod;
  currentGrowthStage: GrowthStage;
  lifecycleStatus: LifecycleStatus;
  healthStatus: HealthStatus;
  retiredAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface SourceRef {
  sourceId: string;
  revision: string;
  passageId: string;
}

export interface TaskRecord {
  taskId: string;
  cropId: string;
  plotId: string;
  ruleId: string;
  ruleVersion: string;
  taskCategory: TaskCategory;
  title: string;
  instructions: string;
  steps: string[];
  rationale: string;
  estimatedDurationMinutes: number;
  scheduledDate: string; // YYYY-MM-DD local date
  timeZone: string;
  dueAt: string | null;
  scheduleStatus: ScheduleStatus;
  weatherOverrideApplied: boolean;
  weatherOverrideReason: string | null;
  forecastFetchedAt: string | null;
  sourceRefs: SourceRef[];
  diagnosisId: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface TaskCompletionEvent {
  eventId: string;
  taskId: string;
  completedAt: string; // Device-reported UTC ISO timestamp
  receivedAt: string; // Server receipt UTC ISO timestamp
}

export interface DurableRequestRecord {
  requestId: string;
  kind: 'initializeGarden' | 'executeMultimodalTriage' | 'processMentorChatMessage' | 'addRecoveryTask' | 'retireCrop' | 'archiveChatSession' | 'deleteAccount';
  inputHash: string;
  state: RequestState;
  attemptCount: number;
  leaseExpiresAt: string | null;
  resultId: string | null;
  errorCode: string | null;
  retryable: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface StageDayThreshold {
  stage: GrowthStage;
  minDaysFromPlanting: number;
}

export interface CropProfile {
  id: string;
  commonName: string;
  localNameSw: string;
  botanicalFamily: string;
  varieties: string[];
  supportedRegions: string[]; // e.g., ["TZ"]
  stageEstimatesByMethod: Record<PlantingMethod, StageDayThreshold[]>;
  ruleIds: string[];
  revision: string;
  reviewStatus: ReviewStatus;
  reviewer: string;
  reviewedAt: string;
}

export interface CareRule {
  id: string;
  cropProfileIds: string[];
  region: string;
  applicableStages: GrowthStage[];
  applicableMethods: PlantingMethod[];
  cadenceIntervalDays: number;
  occurrenceSlot: number;
  allowedRainExposures: RainExposure[];
  templateId: string;
  sourceRefs: SourceRef[];
  revision: string;
  reviewStatus: ReviewStatus;
  reviewer: string;
  reviewedAt: string;
}

export interface TaskTemplate {
  id: string;
  category: TaskCategory;
  title: string;
  instructions: string;
  steps: string[];
  rationale: string;
  estimatedDurationMinutes: number;
  sourceRefs: SourceRef[];
  revision: string;
  reviewStatus: ReviewStatus;
  reviewer: string;
  reviewedAt: string;
}

export interface ApprovedPassage {
  passageId: string;
  topic: string;
  summary: string;
}

export interface KnowledgeSourceRevision {
  sourceId: string;
  revision: string;
  publisher: string;
  title: string;
  canonicalUrl: string;
  region: string;
  topics: string[];
  crops: string[];
  reuseBasis: string;
  reviewStatus: ReviewStatus;
  reviewer: string;
  reviewedAt: string;
  passages: ApprovedPassage[];
}

export type AssessmentStatus = 'supported' | 'uncertain';

export type DetectedAnomalyType =
  | 'pest'
  | 'fungal_blight'
  | 'bacterial_blight'
  | 'watering_symptom'
  | 'nutrient_deficiency'
  | 'normal_growth';

export interface PreFlightMetrics {
  policyVersion: 'image-quality-v1';
  laplacianVariance: number;
  meanLuminance: number;
  saturatedFraction: number;
  subjectCheckPassed: boolean;
}

export interface TriageCard {
  whatItIs: string;
  immediateAction: string;
  whatNotToWorryAbout: string;
}

export interface TriageLogRecord {
  diagnosisId: string;
  requestId: string;
  cropId: string | null;
  plotId: string | null;
  imageStoragePath: string;
  imageExpiresAt: string; // ISO UTC timestamp (+30 days)
  preFlightMetrics: PreFlightMetrics;
  triageCard: TriageCard;
  assessmentStatus: AssessmentStatus;
  detectedAnomalyType: DetectedAnomalyType | null;
  modelConfidence: number | null; // Uncalibrated [0,1], never displayed as verified accuracy
  sourceRefs: SourceRef[];
  recoveryTemplateId: string | null;
  createdAt: string;
}

export type ChatSenderRole = 'user' | 'assistant';
export type ChatValidationStatus = 'passed' | 'insufficient_evidence';

export interface GardenContextSnapshot {
  asOf: string; // ISO UTC timestamp
  regionCode: string;
  regionName: string;
  activePlotId: string | null;
  activePlotName: string | null;
  crops: Array<{
    cropId: string;
    cropProfileId: string;
    commonName: string;
    currentGrowthStage: GrowthStage;
    healthStatus: HealthStatus;
  }>;
  diagnosisSummary: {
    diagnosisId: string;
    assessmentStatus: AssessmentStatus;
    whatItIs: string;
  } | null;
}

export interface ChatSessionRecord {
  sessionId: string;
  title: string;
  activePlotId: string | null;
  diagnosisId: string | null;
  archivedAt: string | null;
  createdAt: string;
  lastMessageAt: string;
}

export interface ChatMessageRecord {
  messageId: string;
  requestId: string;
  senderRole: ChatSenderRole;
  content: string;
  sourceRefs: SourceRef[];
  contextSnapshot: GardenContextSnapshot | null;
  validationStatus: ChatValidationStatus | null;
  createdAt: string;
}

export type SseEvent =
  | { event: 'delta'; data: { text: string } }
  | { event: 'done'; data: { messageId: string; validationStatus: ChatValidationStatus; sourceRefs: SourceRef[] } }
  | { event: 'error'; data: { code: string; message: string; retryable: boolean } };
