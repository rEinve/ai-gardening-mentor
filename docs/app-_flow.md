# Application Flow: Firebase Logic Garden App MVP

Aligned application baseline — 2026-11-21. Routes are logical screen identifiers, independent of the eventual native routing library. [Schema](schema.md) owns stored fields; [technical requirements](tech-requirement-document.md) own endpoints and retry behavior.

## Navigation

Home (`/home`), Garden (`/garden`), and Mentor (`/mentor`) are the three root tabs. A camera action opens `/camera/capture` from each tab. Detail screens return to their originating tab without clearing pending work. Support screen readers, visible focus where applicable, scalable text, reduced motion, and accessible status announcements.

## Onboarding

| Screen/action | State and operation | Next state |
| --- | --- | --- |
| `/onboarding/welcome`: start | Create/recover anonymous identity online; preserve draft if offline | Crop selection or connection-required state |
| `/onboarding/select-crops`: select | Choose from reviewed, region-supported crop catalogue; at least one required | Plot details |
| `/onboarding/plot-details`: submit | Collect crop dates/methods, plot type, rain exposure, sunlight, manual/GPS location, timezone and units; call `initializeGarden` with stable request ID | Home with schedule pending until acknowledged |
| Submission/network failure | Keep entered values; explain missing/unsupported inputs | Retry same logical submission |

Location denial offers manual entry. Crop choices without reviewed regional coverage are unavailable with an explanation. Account linking is optional in account settings; a credential collision offers sign-in/recovery without silently replacing the garden.

## Home and task detail

| Action | Data contract and behavior |
| --- | --- |
| Open `/home` or select calendar date | Read cached tasks and completion events for that date. Future dates are read-only. Show empty, loading, or stale states explicitly. |
| Open `/tasks/:taskId` | Render instructions, ordered steps, rationale, duration, source references, and deadline if supplied. |
| Mark completed | Persist append-only completion event; immediately derive completed UI state. Show pending sync until acknowledged. Repeated taps reuse the event. |
| Read weather banner | Show reason, forecast age, and deferred tasks. Physical completion can still be recorded after a weather deferral. |
| Reconnect | Sync events; completed state remains even if weather fields changed. Failed writes remain visibly recoverable. |

No completion undo in MVP. If necessary tasks exceed the daily routine target, explain the additional work instead of hiding it.

## Camera and triage

1. `/camera/capture`: request permission; denied permission offers gallery selection or device settings. Capture and gallery selection both open review.
2. `/camera/review`: run image-quality-v1. Failed checks disable analysis and offer retake/another image. No bypass. A valid offline image can be saved to the persistent upload queue and removed before upload.
3. Analyze: allocate stable request/diagnosis IDs, upload the owned JPEG, then call `executeMultimodalTriage`. `/camera/analyzing` reads the durable request state.
4. After eight seconds, offer return to Home while the request continues. Pending requests survive navigation/restart. Home shows completion or failure; optional notifications are supplementary.
5. `/diagnostic/:diagnosisId`: show the three-part card, supported/uncertain assessment, source references, and image or an expired-image placeholder. Uncertainty offers retake/additional observations instead of definitive reassurance.
6. Add recovery chore: select an owned active crop if diagnosis was unlinked; call `addRecoveryTask`. Show success once, or explain why no reviewed task is available. Offline actions remain visibly pending.
7. Ask Mentor: open/create a session carrying the diagnosis ID; the server verifies ownership and loads the diagnostic context.

Upload/analysis errors show retry or cancel where applicable. Quota failures show the limit and reset information. Never present a queued image as already diagnosed.

## Mentor

- `/mentor` opens cached sessions and recent messages. The context chip opens `/mentor/context`, showing the garden snapshot used for the displayed answer and its timestamp.
- Suggested prompts populate/send through the same `processMentorChatMessage` endpoint as typed messages. Persist a local pending bubble; do not separately trigger generation through a database write.
- Offline input remains a draft until the user sends it online. Online sending uses a stable request/message ID and displays provisional stream fragments.
- SSE disconnect: show reconnecting state and inspect the durable request/final message before retrying. Do not duplicate the user turn or answer.
- Source link: show approved title, publisher, URL, passage reference, region and review date. An insufficient-evidence answer explains the missing basis.
- Archive conversation: confirm, call `archiveChatSession`, hide from active list, and explain that history is retained. Do not label archive as permanent deletion.

## Garden and account

- `/garden`: show active plots and crops, with pending initialization states when applicable.
- `/garden/crop/:cropId`: display planting information, estimated stage, care history, and triage history. Harvest-ready is still active.
- Retire crop: confirm, call `retireCrop`, show pending until acknowledged, and retain history after future tasks are cancelled.
- Account settings: link identity, change units/timezone, manage notification permission, sign out, or explicitly request account deletion. Offline deletion remains a request awaiting connection; do not show it as complete.
- Sign-out clears local private data after resolving or explicitly warning about unsynced operations. Account deletion displays progress until the backend confirms removal.
