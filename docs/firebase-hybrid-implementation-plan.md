# Firebase hybrid AI — focused implementation plan

Date: 23 November 2026. Status: ready for implementation; no hybrid implementation or device verification performed by this planning task.

## Agreed scope

Priority: submit a working hackathon project tomorrow, 24 November 2026 (the owner’s submission target). Add genuine on-device inference to the existing Gardening Mentor app, preserving its business features. Commercial release configuration and packaging are deferred. Keep the submitted build available and reproducible throughout judging.

Use one Flutter application with two platform adapters, not two independent products. Android and Web can be registered in the same Firebase project; two Firebase backend projects are not required. Reuse the current configured Firebase environment if suitable; creating a separate commercial/demo environment is not a prerequisite for tomorrow’s submission.

**One feature:** “Make today's care checklist” from a bundled, reviewed tomato guide plus user-entered context. Generate up to three concise tasks. Demonstrate new local generation and cloud fallback using this same action. Leave photo diagnosis, supplier search, and full conversational AI outside the local feature.

User implements; Codex reviews and tests afterward; then revise the demo video script to reflect observed behavior.

## Gate 0 — prove the environment before integration

User's available phone: **Google Pixel 8 Pro**. It is absent from the current ML Kit custom-generation support list. Do not equate built-in Gemini features with access to this particular developer API. Treat Android local execution as unconfirmed until a runtime check passes. The event names Gemini Nano 4, so record the actual available model/version as well as availability. An older model's successful execution does not itself settle event compliance. [Device/model support](https://developers.google.com/ml-kit/genai)

Web target: supported desktop Chrome; Mac hardware and Chrome version remain to be checked. Mobile Chrome and an embedded Android WebView are not the local Web target. [Web setup](https://firebase.google.com/docs/ai-logic/hybrid/web/get-started)

First deliverable: a short environment report recording phone/OS/AICore, computer/OS/Chrome, SDK versions, capability status, actual model identity where exposed, and one fresh response from each usable local environment.

If the Pixel is unavailable: retain it for cloud and offline-content tests. Continue both adapters, but obtain compatible Android hardware before claiming Android local generation. Use eligible desktop Chrome for Web proof if available. Do not silently replace the requested two-platform plan with a Web-only submission; report which platform is proven and which remains blocked. Judge-side testing is useful, but is not a substitute for our own successful run.

## Current code findings

- `mobile/lib/services/firebase_ai_logic_service.dart` creates cloud models. `preferOnDevice` is stored but never used to select inference.
- `mobile/lib/main.dart` awaits backend and AI initialization before displaying the app; offline startup must not depend on successful network initialization.
- Latest inspection: `mobile/lib/services/hybrid_mentor_responder.dart` now provides routing scaffolding, but `buildOnDeviceShortAnswer()` calls `_matchTopicGuidance()` and formats preset strings. It does not invoke a model.
- `mobile/lib/screens/mentor_chat_screen.dart` toggles `_hasLocalModelDownloaded` from an ActionChip; this is not an SDK availability check or download. Replace both the flag source and the preset-answer path. Its other preview answers must not supply purported AI results.
- `mobile/test/hybrid_ai_routing_test.dart` exists; routing tests alone cannot prove local generation.
- `mobile/lib/data/offline_garden_store.dart` maintains in-memory state and backend synchronization. Verify durable state after process restart; its name does not prove persistence.
- `mobile/pubspec.yaml` declares `firebase_ai: ^2.0.0`. Verify the resolved package and its actual hybrid API surface; Flutter's cross-platform UI support does not establish hybrid SDK parity.
- `mobile/android/app/src/main/kotlin/com/example/ai_gardening_mentor/MainActivity.kt` is a minimal Flutter activity, so there is no existing native hybrid bridge.
- `backend/functions/src/providers/geminiProvider.ts` calls `@google/genai` directly. Review and migrate or disable that path in the submitted edition so AI presented as Firebase AI Logic actually runs through it.

## Architecture decision

Keep a small Dart contract for the checklist feature, separate from the existing cloud mentor/photo service. Proposed contract: inspect capability, prepare/download with progress, generate checklist, cancel/dispose. Result fields: text, request ID, actual inference source, elapsed time, model identity when available, and a structured error on failure.

First check the resolved Flutter SDK. If it supports the required operations and source metadata on both platforms, use it. Otherwise implement a local Flutter plugin with:

| Platform | Adapter design |
| --- | --- |
| Android | Dart MethodChannel to Kotlin Firebase AI Logic; EventChannel for download progress. Keep native work off the UI thread and cancel work on disposal. |
| Web | Dart JS interop to a bundled module using Firebase's JavaScript hybrid SDK. Reuse the configured Firebase app and coordinate Auth/App Check initialization with FlutterFire. |
| Other platforms | Return unsupported; do not provide fabricated answers. |

Use non-streaming generation first; it is sufficient for three short tasks and makes cancellation/results easier to verify. Keep SDK details out of the farmer-facing interface.

## Ordered implementation tasks

### 1. Replace the inference placeholders and add a shared prompt

Do not spend the submission window building commercial flavors. Replace the existing preset-answer path labelled on-device with real Firebase hybrid generation. Replace the user-toggleable downloaded flag with SDK capability/readiness state. Keep deterministic guides available, clearly labelled as saved/rule-based guidance. Only offer model preparation after an explicit action; never claim a download occurred because a toggle changed.

Bundle a short reviewed guide with the app. Prompt inputs: guide text, crop stage, and one current observation. Ask for up to three tasks grounded in that guide; ask for clarification when facts are missing. Avoid invented fertilizer doses, disease certainty, weather, or live supplier data. Treat guide/user text as input, not executable instructions.

### 2. Implement Android adapter

Use `firebase-ai` plus `firebase-ai-ondevice`, checking compatibility with FlutterFire's resolved native dependencies. The documented on-device dependency requires minimum API 26. Check status with `FirebaseAIOnDevice.checkStatus()` and download through `FirebaseAIOnDevice.download()` after an explicit action. AICore manages the model. Configure `OnDeviceConfig` with `PREFER_ON_DEVICE`; reserve `ONLY_ON_DEVICE` and `ONLY_IN_CLOUD` for diagnostic checks. Return SDK-reported inference source. [Android setup](https://firebase.google.com/docs/ai-logic/hybrid/android/get-started)

Proposed locations: a local plugin under `mobile/packages/garden_hybrid_ai/`; thin Dart facade under `mobile/lib/services/`; Android Gradle updates as needed. Prefer the plugin over putting all logic into MainActivity. Initialize Firebase/App Check once and verify native/Flutter instances agree. Lock working versions after dependency resolution rather than upgrading unrelated packages.

### 3. Implement Web adapter

Use the documented Firebase JavaScript hybrid entry point and inference modes. Prepare the device model with `initializeDeviceModel()` and surface progress. The guide specifies desktop Chrome 139+ and Firebase JS 12.5.0+; verify current requirements and actual capability on the chosen machine. Bundle dependencies locally rather than relying on runtime CDN fetches. [Web setup](https://firebase.google.com/docs/ai-logic/hybrid/web/get-started)

Add offline app-shell caching: Flutter bootstrap/application bundle, renderer/WASM dependencies actually used by this build, fonts, icons, hybrid JS, and bundled guide. Use a versioned cache and an explicit update policy. Do not assume a manifest or generated build automatically supplies offline reopening. Do not cache authenticated API responses in the service-worker asset cache. Test the hosted HTTPS origin, not only a development server.

### 4. Make offline startup and state real

Render the app before optional cloud initialization completes. Bound network attempts; load bundled content and persisted configuration first. Remote Config failure must leave usable local defaults. Cloud service failure must not discard a usable local adapter.

Persist the selected guide, relevant crop context, and generated checklist with account ownership. Restore a previously authenticated session according to Firebase Auth state; do not fabricate authentication or promise first-time offline login. Verify sign-out/account changes cannot expose another user's saved garden. Mark saved outputs as saved; they are not fresh inference.

### 5. Add the smallest usable demo flow

In the existing app, add “Offline care checklist” in an appropriate existing garden/mentor area. Show capability checking, unsupported, download available, downloading, ready, generating, success, and retryable failure. Download happens only after “Prepare offline AI”; show size when provided, otherwise do not invent it. Failed preparation must leave saved guides accessible.

After generation, show “Generated on this device” or “Generated in cloud” from actual response metadata. Display elapsed time only if measured. Keep modes, SDK diagnostics, and request IDs in a judge/developer details panel. No simulated source badges.

### 6. Establish cloud fallback and submission integrity

Use the SDK's real prefer-local routing. Do not infer source from Wi-Fi status: connected Wi-Fi can have no internet. If local is unavailable and the cloud fails, show an actionable error and retain the guide. Bound retries; do not replay cancelled requests or silently duplicate outputs after a partial result.

Verify a supported cloud model in the project's region/provider and configure it explicitly. The existing service defaults to `gemini-2.5-flash`; recheck its lifecycle before locking the demo. Configure App Check for both platform adapters and verify authenticated behavior. Keep debug tokens private; judge instructions must explain any required registration rather than embed shared bypass secrets.

Audit every AI path included in the demo for Firebase AI Logic usage. The existing direct server Gemini route must be migrated or excluded from the submitted feature set, with UI and README reflecting that choice.

## Acceptance tests — run separately on Android and desktop Web

| Test | Procedure | Pass condition |
| --- | --- | --- |
| First-run preparation | Fresh install/profile, online, prepare model | Honest availability and progress; success only after readiness is confirmed. |
| Fresh offline generation | Prepare, disable network, change observation to something not previously submitted, generate | New relevant tasks; SDK source is local; no successful cloud request. |
| Offline cold start | Force-stop Android or close/reopen the cached Web app with network still disabled | Guide/context load and a new local request succeeds on capable hardware. |
| Genuine cloud fallback | Prefer-local mode on an actually unavailable local environment, online | Request succeeds with SDK source cloud. A cloud-only diagnostic alone does not prove fallback. |
| Cloud-only diagnostic | Online, force cloud in developer controls | Cloud path works independently. |
| Neither path available | Unsupported/unprepared device, offline | Saved guide works; new generation is unavailable with a clear explanation. |
| Interrupted download | Disconnect during preparation, reopen, retry online | No false ready state; recover using SDK-supported retry/resume behavior. |
| Errors and cancellation | Cancel generation; test timeout, model busy, cloud/App Check denial | No fake answer, stale success badge, indefinite spinner, or unbounded retries. |
| Auth isolation | Save output, sign out, use another account | Previous private context is inaccessible. |
| Existing feature regression | Exercise planner, account, saved guidance, and cloud mentor | Existing business features remain usable after hybrid integration. |

Use physical device airplane mode with Wi-Fi also off for Android. For Web, disconnect the machine and collect browser network evidence; a developer-tools toggle alone is secondary evidence. Repeat with a changed input and record source metadata. Do not assert exact model wording in tests; assess that tasks respond to the supplied guide/context.

Automated checks: adapter contract/error mapping, UI state transitions, request cancellation, and account-scoped persistence. Run `flutter analyze`, `flutter test`, Android and Web builds for the submission configuration, and the required root `npm run build`. Build success does not replace physical offline inference tests.

## Handoff and completion gate

Implement in this order: short capability probes on Android and desktop Chrome → shared contract/prompt → first adapter on hardware that can actually generate locally → second adapter → startup/cache/persistence → fallback/UI → evidence. Preserve the Android + Web target, but do not let an unsupported phone block progress on a compatible desktop. Record unverified platform claims as blocked, not passed. Hardware availability and SDK compatibility are the first dependencies; do not spend time on animation before these are settled.

Provide Codex with the commit/build identifier, exact SDK lockfiles, phone and browser versions, actual model identity, local/cloud traces without secrets, judge setup instructions, and a completed acceptance table. Include an APK and hosted Web build with clear preparation instructions. Public setup must work from a clean install, not only an already-prepared developer account.

The feature is complete only when both claimed platform paths have been exercised, fresh offline generation is demonstrated, fallback is verified, and saved content survives restart. Report unavailable hardware honestly rather than marking its tests passed.

Only then revise Scene 5 of `docs/demo-video-animation-script.md`: show actual preparation, a fresh offline checklist, and real cloud fallback. Mention only the platforms and capabilities verified. Defer commercial packaging decisions until after the hackathon; the submission video describes the working submitted build.


## Submission-first work split

**Required before recording:** real model execution, genuine readiness/download state, SDK source metadata, a fresh offline result, cloud fallback, and a reproducible judge setup. Remove misleading placeholder labels even if a platform remains unsupported.

**Keep existing:** planner, account, crop context, cloud mentor, and saved guidance. Avoid unrelated rewrites.

**Defer:** commercial flavors, separate commercial deployment, expanded local features, broad visual polish, and additional tutorial videos.

**Hardware decision:** test the Pixel 8 Pro first, but do not promise support. If unavailable, use it for Android cloud/fallback testing and obtain eligible hardware for local proof. Desktop Chrome capability is the next immediate probe. If only one platform can be verified by the owner’s deadline, report that limitation and have the owner choose submission scope; do not fabricate a second-platform demonstration.
