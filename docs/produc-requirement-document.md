# Product Requirements: Firebase Logic Garden App MVP

Aligned application baseline — 2026-11-21. See the [architecture](<FireBase Logic Garden App Architecture.md>) for responsibilities and document ownership.

## Audience and outcomes

The MVP serves novice household vegetable gardeners. It should reduce panic-driven over-correction, make daily care manageable, and provide consistent garden-specific advice. These are product hypotheses to validate with users, not proven outcomes.

## Scope

1. Camera diagnostic and panic triage.
2. A rolling seven-day care cadence with offline completion and weather adjustments.
3. Grounded mentor chat with garden context and cached history.

Anonymous onboarding, plot/crop management, optional account linking, and history support these loops. Commercial farm tooling, hardware automation, sensor networks, social/community features, and offline AI inference are excluded.

## Onboarding and garden context

- Collect at least one supported crop, planting date and method, plot type, sunlight, location, and confirmed IANA timezone. Provide manual location entry if permission is denied.
- Let users choose metric or imperial display units. Do not require a USDA zone outside supported regions where it applies.
- Keep setup to three screens and target completion within two minutes in usability testing.
- First authentication and initial schedule generation require connectivity. Preserve incomplete setup locally and explain what is pending.
- Optional permanent account linking must preserve existing garden ownership; credential collisions require an explicit recovery flow.

## Camera triage

- Validate camera and gallery images using the single image contract in the technical requirements. Failed checks offer retake or another image; no bypass in this MVP.
- Valid photos captured offline remain queued until connected. Clearly distinguish queued, processing, failed, and completed requests.
- Return three fields: What It Is, Immediate Action, and What Not to Worry About.
- An uncertain result must say identification is insufficient, request useful additional observations, and avoid unsupported reassurance or treatment claims. A model-generated confidence number is not a validated probability.
- Favor reviewed, beginner-appropriate physical care actions. Organic labeling alone does not establish safety. Reject unsupported treatment instructions.
- Offer an idempotent recovery-task action only when a reviewed, applicable task template is available; permit triage-to-chat handoff.

## Seven-day care cadence

- Use reviewed crop and regional rules to generate a rolling seven-day schedule. Display instructions, steps, rationale, expected duration, and source references.
- Aim for a five-to-ten-minute daily routine across the garden. Do not enforce a minimum duration on every task or hide necessary safety work to meet the target; explain exceptions.
- Cache seven days of tasks and their detail content. Record physical completion offline and preserve it across app restarts and weather updates.
- Weather adjustments must consider plot exposure: rainfall does not justify automatically deferring indoor or sheltered-container watering.
- Separate crop lifecycle from growth stage. Harvest-ready plants can remain active; explicit retirement removes future pending care.

## Grounded mentor chat

- Inject current authorized plot/crop context and relevant diagnostic history on every request.
- Retrieve approved source passages applicable to crop and region. Store and display references used in an answer.
- Without applicable reviewed evidence, acknowledge the gap and ask for clarification or suggest local expert help; do not invent a citation.
- Show cached history offline and retain unsent drafts. Do not imply a new answer can be generated offline.
- Preserve response streaming as an interaction requirement; finalized messages and request state are the durable record.

## Acceptance criteria

| ID | Observable pass condition |
| --- | --- |
| A1 | A new user creates a supported garden and receives seven days of care; repeated setup submission does not duplicate it. |
| A2 | Failed-quality images never upload; valid camera and gallery images follow the same validation policy. |
| A3 | A queued image survives restart; retrying one request creates one diagnostic result. |
| A4 | An uncertain image produces an uncertainty state, not a definitive unsupported diagnosis. |
| A5 | A task completed offline stays complete after reconnect, including when weather automation ran meanwhile. |
| A6 | Repeated schedule jobs do not duplicate tasks; retiring a crop cancels future pending tasks without removing history. |
| A7 | A mentor answer shows the current garden context and resolvable approved sources, or explicitly reports insufficient evidence. |
| A8 | Another user's records and images are inaccessible; clients cannot forge generated answers or task instructions. |
| A9 | Camera denial, network loss, request failure, quota exhaustion, and missing source data each have a recoverable UI state. |
| A10 | Account linking preserves data; account deletion removes cloud records/images and clears local data on the device. |

## Validation and release boundaries

Measure onboarding completion, repeat weekly use, task completion, triage helpfulness, and unsupported-answer rate during a pilot. Set numeric product targets after a baseline study. Technical performance targets and release gates live in the technical requirements and implementation plan.

Launch region, crop catalogue, reviewed care content, and approved reference sources are open dependencies. No accuracy or horticultural outcome claim is approved by this document.
