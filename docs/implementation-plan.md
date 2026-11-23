# Implementation Plan: Firebase Logic Garden App MVP

Aligned application baseline — 2026-11-21. This is a planned delivery sequence, not evidence of completed implementation. The previous ten-week estimate is provisional until staffing and dependency spikes are resolved.

## Alignment decisions

The three loops in the [base architecture](<FireBase Logic Garden App Architecture.md>) are unchanged. This pass reconciles application documents only.

| Previous disagreement | Aligned baseline |
| --- | --- |
| Multiple blur/exposure/image limits | image-quality-v1 in technical requirements; provisional until calibrated. |
| Mandatory live shutter gating versus review checks and bypass | Review-screen validation for camera and gallery; no failed-check bypass. |
| Different triage names and competing chat triggers | One endpoint registry; triage durable jobs, chat one authenticated streaming endpoint. |
| Completion and weather overwrite one status | Immutable completion events separate from server task plans. |
| Harvest stage removes plants from care | Explicit lifecycle retirement; harvest stage can remain active. |
| Source links without citation fields | Versioned approved passages and source references in schema. |
| Per-task minimum versus short daily routine | Positive per-task estimate; aim for five-to-ten minutes across daily routine and explain exceptions. |
| Assumed current SDK pins and executable samples | Verify versions in an integration spike; no unverified sample code is normative. |

## Phase 0: decisions and feasibility

- Select React Native or Flutter, target devices, service region, launch geography, initial crops, content reviewer, and pilot cost ceiling.
- Confirm compatible SDK/runtime/model versions, native offline persistence, image processing and authenticated streaming using small integration probes.
- Calibrate image-quality-v1 and subject relevance checks against representative camera/gallery images, devices, lighting, and healthy/damaged plants. Record false-reject and false-accept results; update the single technical contract if thresholds change.
- Supply reviewed crop profiles, care rules, task templates, and source passages with provenance. Select expert-reviewed triage/chat evaluation cases including ambiguous images and unsupported regional advice.
- Agree performance test devices/network profiles and scheduling completion window. Finalize dispatcher query/index strategy and retry/lease limits.

Exit: decisions recorded and enough reviewed content for one supported crop/region. Prototype fixtures remain explicitly marked until reviewed. No production readiness claim before this gate.

## Phase 1: one complete garden and care journey

- Scaffold client and TypeScript backend in the consumer location determined by Studio architecture; keep visual exploration in Studio.
- Configure isolated development/staging/production projects, secret handling, Auth, Storage, Firestore and emulators.
- Implement schema validators, permission matrix and indexes. Test cross-user denial and server-field forgery before connecting AI.
- Deliver onboarding, idempotent initial cadence, seven-day task view, detail steps/sources, and append-only offline completion events.
- Prove completion survives app restart, reconnection, two devices, weather changes, and duplicate event submission.

Exit: A1, A5 and A8 pass for the supported fixture/approved dataset; actual data status is documented.

## Phase 2: camera and durable triage

- Deliver capture/gallery/review with the canonical image policy and explicit permission failures.
- Persist upload queue and request IDs. Implement private storage validation, triage worker leases, bounded retries, output validation and one finalized result per request.
- Include uncertain/no-evidence outcomes, eight-second background transition, expired-image display, and reviewed recovery-task creation.
- Enforce initial ten-triage-per-user/day limit plus project-level abuse and cost controls. Keep quotas authoritative on the server.

Exit: A2–A4 and camera/request portions of A9 pass, including retry after upload success but lost acknowledgement, process restart, provider failure and invalid output.

## Phase 3: grounded mentor

- Retrieve applicable approved passages and current authorized garden context for each request.
- Implement one streaming chat endpoint, durable final messages, citation resolution and insufficient-evidence response.
- Deliver cached history, offline drafts, diagnosis handoff, context inspection and archive behavior.
- Test disconnection mid-stream, duplicate sends, forged context IDs, unsupported sources, and instruction-like text inside user/content inputs.

Exit: A7 passes against reviewed evaluation cases; request retries do not duplicate messages. Source coverage and failure cases are recorded.

## Phase 4: scheduling, weather and lifecycle

- Implement local-time dispatch with execution keys, retry leases, catch-up, DST and timezone-change tests.
- Generate deterministic seven-day task identities from reviewed rules. Update future tasks without overwriting completion events.
- Integrate cached forecasts with region-reviewed thresholds and plot exposure. Handle missing/stale forecasts explicitly.
- Implement crop retirement, account linking/recovery, account deletion cascade, and 30-day image expiry.

Exit: A6 and A10 pass; sheltered plots, overlapping jobs and late offline completions behave as specified.

## Phase 5: field verification and pilot

- Test airplane mode, app termination, intermittent connectivity, low bandwidth, denied permissions, large queues, and expired credentials on target devices.
- Validate accessibility, outdoor readability, error recovery and reduced-motion behavior.
- Evaluate triage uncertainty, advice applicability, source validity and unsafe/unsupported output with the content reviewer. Agree pass thresholds before running the release evaluation; do not substitute JSON validity for answer quality.
- Measure technical targets on agreed profiles. Collect onboarding and weekly-use baselines without claiming unproven gardening outcomes.
- Run complete A1–A10 acceptance journey, production configuration checks, deletion tests, and internal store-distribution validation before public release.

## Quality gates

- Strict TypeScript, ESLint and Prettier for backend; select client equivalents after framework choice. Configure scripts in the actual application repository.
- Target at least 85 percent coverage for core business logic; use Jest for TypeScript logic and the selected client platform's native test tools where needed.
- Emulator tests must verify field allowlists, user isolation, completion-event constraints, job idempotency, and generated-content write denial.
- Require documented review of security, offline reconciliation and content provenance; assign actual reviewers rather than assuming a team size.
- Each phase reports acceptance evidence, known limitations and unresolved dependencies. Runtime budgets, source approval and SDK support cannot be inferred from documentation.

## Open inputs and ownership

See [Phase 0 Decision Record](phase-0-decisions.md) for locked baseline choices.

| Input | Status / Owner | Needed by |
| :--- | :--- | :--- |
| Launch region, crop list, client framework, language | **Locked**: Tanzania (nationwide, metric, EN MVP), 9 starter crops, Flutter | Phase 0 exit (done) |
| Service deployment region & build order | **Locked**: `europe-west1`; Firebase backend first, then Flutter client | Phase 0 exit (done) |
| Reviewed crop rules and reference passages | Phase 1 uses `prototype_fixture` grounded in EWS-KT GrowHow (`growhow.ews-kt.com`); owner/extension sign-off before pilot | Before pilot |
| Verified SDK/model/runtime versions and `image-quality-v1` thresholds | Open — Engineering integration spike | Phase 0/2 gate |
| Spending ceiling, chat quotas, and retention beyond image expiry | Open — Product owner with engineering | Before pilot |
| Numeric advice-quality and usability release thresholds | Open — Product owner with content reviewer | Before release evaluation |

## Current repository verification

- The static landing-page prototype (`src/`, `dist/`, `Containerfile`, `podman-compose.yml`) builds cleanly via `npm run build`.
- The Firebase Logic Garden App MVP (TypeScript Firebase backend + Flutter client) has Phase 0 decisions locked and is ready for Phase 1 backend scaffolding.
