# Technical Requirements: Firebase Logic Garden App MVP

Aligned application baseline — 2026-11-21. [Schema](schema.md) owns field definitions; [product requirements](produc-requirement-document.md) own acceptance behavior.

## Stack and integration boundary

Use a native mobile client, Firebase Auth, Firestore, private Cloud Storage, Cloud Functions, and a Gemini server integration. Backend code uses strict TypeScript. React Native versus Flutter remains a decision gate; do not assume shared client/backend types before that choice.

Select supported runtime, SDK, model, and camera-library versions in a compatibility spike and record tested versions before implementation. Earlier version pins and SDK snippets are superseded; this document makes no claim that they compile. Confirm provider support for structured output and streaming. OpenWeather is the proposed weather provider; verify regional coverage, units, quotas, and cost before enabling it.

## Canonical image contract: image-quality-v1

These are provisional engineering defaults requiring representative device/lighting calibration, not validated diagnostic thresholds.

- Capture or choose an image, then validate it on the review screen. Live preview feedback is advisory; 30-fps image analysis is not an MVP release requirement.
- Preserve aspect ratio, normalize orientation, and analyze a grayscale image fitted within 640 by 480 pixels without stretching.
- Reject Laplacian variance below 100, mean luminance below 40 or above 220, or saturated pixels exceeding 15 percent. Equality at the stated bounds passes.
- Retain the color image for a plant/soil relevance check. The classifier/heuristic and its validation dataset remain a spike deliverable; do not claim grayscale sharpness proves plant presence.
- No failed-check override. Offer retake, better-light guidance, or another gallery image.
- Compress to JPEG at initial quality 80, longest edge at most 1024 pixels, maximum 350,000 bytes. Reduce quality/size within validated bounds or request another image if oversized.
- Upload privately to `users/{uid}/diagnostics/{diagnosisId}.jpg`. Validate ownership, actual decoded format, size, dimensions, and request association on the server. Client metrics are advisory, not an authorization boundary.
- Remove unnecessary image metadata before upload. Retain uploaded originals for 30 days; historical results must handle expired images.

## Request and endpoint contract

All user-facing endpoints require authenticated ownership checks, validated input, rate limits, and App Check where supported by the selected integration. Derive the user ID from authentication, never from a trusted payload field.

| Operation | Input | Result and execution |
| --- | --- | --- |
| `initializeGarden` | `requestId`, validated profile, plots and crops | Idempotently commits setup and schedules the first cadence. |
| `generateDailyCadence` | Internal user/date job | Upserts deterministic task IDs for seven local dates; never directly callable without authorization. |
| `evaluateWeatherOverrides` | Internal user/date job | Updates weather fields and inserts deterministic protection tasks. |
| `executeMultimodalTriage` | `requestId`, `diagnosisId`, owned image path, optional crop/plot IDs, metrics | Creates or returns a durable request; a worker writes one result. |
| `processMentorChatMessage` | `requestId`, `sessionId`, `messageId`, text, optional plot/diagnosis IDs | Authenticated streaming HTTPS endpoint; saves user input and final assistant message once. |
| `addRecoveryTask` | `requestId`, `diagnosisId`, selected owned crop | Creates one task from a reviewed template authorized by that result, or returns an unsupported-action error. |
| `retireCrop` | `requestId`, owned plot/crop IDs | Sets lifecycle to retired and cancels future pending tasks transactionally in bounded batches. |
| `archiveChatSession` | `requestId`, owned session ID | Hides the session from active history; does not claim permanent deletion. |
| `deleteAccount` | Authenticated explicit deletion request | Starts an idempotent deletion job covering records, subcollections, images, and Auth identity. |

Use callable endpoints except the streaming chat endpoint and internal jobs. Do not also trigger a second chat generation from a message-created event.

Persist request states `queued`, `processing`, `succeeded`, `failed` under the user. Bind request IDs to an input hash; conflicting reuse is rejected. Workers use leases and bounded retries; expired processing leases can be reclaimed. Provider calls may repeat after a crash, but committed results and user-visible messages must not duplicate. Record retryable errors and explicit attempts; retrying a failed operation uses the same logical request ID.

SSE events are `delta`, `done`, and `error`. Streaming fragments are provisional. The durable request and finalized message are authoritative; disconnect/restart reads them before retry. Reject unsupported output before finalizing it. After eight seconds, triage offers return to Home while processing continues; this is a UI transition, not job cancellation. Notification permission is optional; Home must expose finished and failed requests without notifications.

## Scheduling and offline reconciliation

Store an IANA timezone for each user. A UTC dispatcher runs every 15 minutes and selects due users for local 03:00 cadence and local 05:00, 11:00, 17:00 weather checks. Store a per-user/date/job execution key to prevent duplicates across retries and daylight-saving changes. On timezone changes, recalculate future run times while preserving completed work. Catch up missed runs and expose forecast age.

Use deterministic task identity from user, crop, rule ID, local date, and occurrence slot; keep rule version as metadata rather than changing identity on retry. Onboarding calls the same generator. Do not regenerate completed tasks or cancel harvest-ready plants merely because they reached the harvest growth stage.

Physical task completion is an append-only `taskCompletions` event, separate from the server-owned task plan. Persist events offline using the selected client's supported persistence layer. A task's displayed status is completed when any accepted completion exists; otherwise cancelled, deferred by weather, or pending, in that priority order. Weather workers never edit completion events. Multiple-device completions collapse to one visible completed state. Undo completion is outside MVP scope.

Keep a persistent local queue for image uploads and callable requests; do not assume Firestore offline writes execute HTTP operations. Retry with bounded exponential backoff. Show pending versus acknowledged operations and retain recoverable failures. Clear device caches on sign-out/account deletion so another account cannot see prior data.

## Reviewed care and knowledge content

- Seed versioned crop profiles, care rules, task templates, and approved source passages as specified in the schema. Missing reviewed data blocks automated advice for that crop/region; it is not silently replaced with invented rules.
- Growth-stage estimates depend on crop profile and planting method; calendar age is an estimate, not an observation. Allow correction through validated garden editing.
- Store weather in millimetres and Celsius. Initial candidate thresholds are rain above 12.7 mm/24h, frost at or below 1.1 C, and heat at or above 35 C. Review them for the supported crops/region before enabling automation.
- Apply rain deferrals only to exposed plots and pending tasks. For sheltered/indoor plots, retain soil-check guidance. Weather outages retain reviewed baseline care and display stale/unavailable forecast state.
- Retrieve approved passages by crop, region, topic, and applicability; a deterministic curated lookup is sufficient for MVP. Assemble current garden context on every turn. Resolve returned citation IDs against retrieved source records before display.
- Validate structured triage output and message content server-side. Do not equate valid JSON or an organic keyword with safe advice. Unsupported diagnoses return `uncertain`; unsupported treatment guidance is withheld. Evaluate against an expert-reviewed test set before release.

## Authorization and lifecycle

The schema permission matrix is normative; deployable security-rule files must be written and tested during implementation. All unspecified paths deny access. Backend Admin operations repeat ownership and schema validation because client rules do not protect privileged writes.

Generated task plans, results, assistant messages, citations, and review flags are server-owned. Clients can only create validated completion events and edit explicitly allowed garden/profile fields. Reject unknown fields and forged server metadata. Storage allows only owned JPEG creation within the image contract; no public download links.

Account deletion cascades through all nested records and Storage. Image expiry does not delete the textual diagnostic. Archive chat preserves history until account deletion; explain this distinction in the interface. Store credentials server-side; never include credentials or private images/chat bodies in routine logs.

## Performance and verification

| Measure | Initial target | Failure behavior |
| --- | --- | --- |
| Local image validation | p95 at most 250 ms on agreed reference devices | Guidance remains responsive; profile/adjust processing before release. |
| Triage end-to-end | p90 at most 3.5 seconds on a defined online test profile | After eight seconds allow background waiting; no offline-model fallback. |
| Task sync acknowledgement | At most one second on stable test connectivity | Preserve local state and pending indicator. |
| Scheduled jobs | 99.9 percent completed within their documented window | Retry and alert; measure window in the implementation spike. |
| Delivered structured output | 100 percent schema-valid | Reject invalid output and return recoverable failure. |

Targets require measurement, not assumption. Set explicit triage and chat cost ceilings, abuse controls, and weather caching before pilot. Initial triage limit is ten requests per user per day; anonymous-account abuse also needs project-level controls. Budget alerts are notifications, not spending caps.
