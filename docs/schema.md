# Data Schema: Firebase Logic Garden App MVP

Aligned application baseline — 2026-11-21. This is the canonical planned data contract. [Technical requirements](tech-requirement-document.md) define processing; this is not deployed database configuration.

## Conventions

All private records live below `/users/{uid}`. IDs are opaque stable strings; user-generated request/event IDs use UUIDs. Task IDs are deterministic as defined in the technical requirements. Timestamps use UTC; local calendar dates use `YYYY-MM-DD`. Nullable fields explicitly accept null. Reject undeclared client fields and validate all references belong to the same user.

The lists below define required fields unless marked optional. Server timestamps record receipt; device timestamps record reported physical actions and are not trusted for authorization. Strings and arrays require bounded lengths in implementation validators. Baseline limits: names 50 characters, task titles 60, instructions 250, chat text 2,000, triage fields 200, steps 1–10, citations at most 10. URL fields resolve only to approved source records.

## Private collections

| Path below `/users/{uid}` | Required fields and meaning |
| --- | --- |
| Root profile | `userId`, `displayName` nullable, `email` nullable, `isAnonymous`, `geographicLocation` (latitude, longitude, nullable postalCode and usdaHardinessZone), `timeZone` (valid IANA ID), `unitPreference` (`metric`/`imperial`), `gardenExperienceLevel`, `fcmDeviceTokens`, `createdAt`, `updatedAt`. Auth-derived fields are server-managed. |
| `plots/{plotId}` | `plotId`, `name`, `plotType` (`in_ground`, `raised_bed`, `container`, `indoor_window`), `rainExposure` (`exposed`, `sheltered`, `indoor`), nullable `dimensions` (lengthMetres, widthMetres; positive), `sunlightExposure` (`full_sun`, `partial_shade`, `deep_shade`), `createdAt`, `updatedAt`. |
| `plots/{plotId}/crops/{cropId}` | `cropId`, `cropProfileId`, `commonName`, nullable `variety`, `plantingDate` (local date, not future), `plantingMethod` (`direct_seed`, `transplant`), `currentGrowthStage` (`germination`, `vegetative`, `flowering`, `fruiting`, `harvest`), `lifecycleStatus` (`active`, `retired`), `healthStatus` (`healthy`, `stressed`, `recovering`), nullable `retiredAt`, `createdAt`, `updatedAt`. Growth-stage estimates and profile-derived values are server-managed. |
| `tasks/{taskId}` | `taskId`, `cropId`, `plotId`, `ruleId`, `ruleVersion`, `taskCategory` (`watering`, `soil_check`, `pruning`, `pest_scout`, `frost_defense`, `heat_protection`, `harvesting`, `recovery`), `title`, `instructions`, `steps` (ordered strings), `rationale`, positive `estimatedDurationMinutes`, `scheduledDate`, `timeZone`, nullable `dueAt` (UTC deadline), `scheduleStatus` (`pending`, `deferred_weather`, `cancelled`), `weatherOverrideApplied`, nullable `weatherOverrideReason`, nullable `forecastFetchedAt`, `sourceRefs`, nullable `diagnosisId`, `createdAt`, `updatedAt`. |
| `taskCompletions/{eventId}` | `eventId`, `taskId`, `completedAt` (device-reported UTC timestamp), `receivedAt` (server timestamp). Append-only; no mutable task `status` or `isCompleted` field. |
| `requests/{requestId}` | `requestId`, `kind`, `inputHash`, `state` (`queued`, `processing`, `succeeded`, `failed`), `attemptCount`, nullable `leaseExpiresAt`, nullable `resultId`, nullable `errorCode`, `retryable`, `createdAt`, `updatedAt`. Server-owned; never include credentials. |
| `triageLogs/{diagnosisId}` | `diagnosisId`, `requestId`, nullable `cropId` and `plotId`, `imageStoragePath`, `imageExpiresAt`, `preFlightMetrics` (policyVersion, laplacianVariance, meanLuminance, saturatedFraction, subjectCheckPassed), `triageCard` (whatItIs, immediateAction, whatNotToWorryAbout), `assessmentStatus` (`supported`, `uncertain`), nullable `detectedAnomalyType`, nullable `modelConfidence`, `sourceRefs`, nullable `recoveryTemplateId`, `createdAt`. |
| `chatSessions/{sessionId}` | `sessionId`, `title`, nullable `activePlotId`, nullable `diagnosisId`, nullable `archivedAt`, `createdAt`, `lastMessageAt`. |
| `chatSessions/{sessionId}/messages/{messageId}` | `messageId`, `requestId`, `senderRole` (`user`, `assistant`), `content`, `sourceRefs`, nullable `contextSnapshot`, nullable `validationStatus`, `createdAt`. Server persists both roles through the chat endpoint. |
| `jobRuns/{jobKey}` | `kind`, `localDate`, `timeZone`, `state`, `attemptCount`, nullable `leaseExpiresAt`, nullable `completedAt`. Server-only scheduling/idempotency records. |

`detectedAnomalyType` is one of pest, fungal_blight, bacterial_blight, watering_symptom, nutrient_deficiency, normal_growth, or null when uncertain. `modelConfidence`, if retained, is an uncalibrated model value in [0,1], never presented as verified accuracy.

`sourceRefs` entries contain `sourceId`, `revision`, and `passageId`. Source title, publisher, URL, region, and review date resolve from approved reference records; retain the cited revision for historical answers. User messages have an empty source list. Assistant `validationStatus` is `passed` or `insufficient_evidence`, assigned only by the backend; context snapshots contain authorized plot/crop values and an `asOf` timestamp. Do not label an unreviewed answer safety-verified.

## Effective task state and lifecycle

Completed state is derived from accepted completion events, not written over the task plan. If any completion exists, display completed. Otherwise use cancelled, deferred_weather, or pending from `scheduleStatus`. Fetch completions alongside visible tasks and retain both in the offline cache.

Clients cannot undo completion in this MVP. Repeated taps reuse the same event ID; events from multiple devices are retained but display one completion. A late completion for a retained cancelled task records physical reality. Do not delete task records while they may receive pending offline events; automatic task-history pruning is deferred until a retention policy is agreed.

Retiring a crop preserves its record and history, and cancels future pending plans. Reaching growth stage harvest does not retire it. Raw images expire after 30 days; triage text and sources remain until account deletion. Archived sessions remain readable in history; deletion is a separate account operation.

## Permission matrix

| Records | Owner client access | Backend authority |
| --- | --- | --- |
| Profile | Read; update allowlisted display, location, timezone, units, experience, own notification tokens | Identity fields, creation/deletion and server metadata |
| Plots | Read; create/update validated garden fields only | Cascade deletion and metadata |
| Crops | Read; create/edit profile selection, variety, planting date/method only | Validate profile, calculate stage, derive health, retire and timestamp |
| Task plans | Read only | Create/update instructions and scheduling fields |
| Completion events | Read; create only with matching ID and existing owned task; valid timestamps; no extra fields | Validate receipt; retain immutable physical-action record |
| Requests, triage, sessions, messages | Read only | All mutations via authorized endpoints/workers |
| Job runs | No direct access | Internal reads/writes only |
| Reviewed reference content | Read approved records only | Publish/revise after review |

Client crop creation must omit server-derived fields until backend initialization completes; show a pending state. Firestore rules and backend validators must implement this distinction explicitly. Never allow an owner client to forge assistant messages, source lists, diagnostic output, or generated task text. Ownership alone is insufficient field validation.

## Reviewed reference datasets

These are required inputs, not supplied horticultural facts. Prototype fixtures must be marked as examples and cannot be promoted as reviewed content.

| Collection | Minimum record |
| --- | --- |
| `cropProfiles/{id}` | Common name, botanical family (not a fixed seven-family enum), varieties, supported regions, planting-method-specific stage estimates, rule IDs, revision, review status and reviewer/date. |
| `careRules/{id}` | Crop/profile applicability, region, stage and planting-method conditions, cadence, plot exposure constraints, weather conditions with explicit units, template ID, source references, revision and review metadata. |
| `taskTemplates/{id}` | Category, title, instructions, ordered steps, rationale, estimated minutes, optional deadline policy, source references, revision and review metadata. |
| `knowledgeSources/{id}/revisions/{revision}` | Publisher, title, canonical URL, region, topics/crops, reviewedAt, reviewer, review status, reuse permission/basis, and identified approved passages. |

Only approved revisions may generate advice. Establish a named content reviewer and the initial region/crop coverage before pilot; missing coverage produces an explicit unsupported state.

## Queries and indexes

| Query | Planned composite index |
| --- | --- |
| Tasks for local date, ordered by creation | tasks: scheduledDate ASC, createdAt ASC |
| Tasks for crop history | tasks: cropId ASC, scheduledDate DESC |
| Active crops by planting date | crops: lifecycleStatus ASC, plantingDate DESC |
| Triage history for crop | triageLogs: cropId ASC, createdAt DESC |
| Unarchived sessions by recent activity | chatSessions: archivedAt ASC, lastMessageAt DESC |
| Completions for task ordered by receipt | taskCompletions: taskId ASC, receivedAt ASC |

Messages use createdAt ordering and a last-50 window; triage history is paginated in groups of 20. Validate actual query/index files in emulators; single-field orderings do not require invented composite indexes. Server dispatch queries and indexes must be finalized with the scheduling spike.
