# Hybrid implementation review — 23 November 2026

The implementation now includes real Firebase AI Logic calls on Android and Web. This is a material change from the previous keyword-answer placeholder. It is not yet verified end-to-end offline.

## Verified

- `flutter test`: all 12 tests passed.
- Web hybrid JavaScript bundle: `npm run build` passed in `mobile/web_hybrid_src`.
- Root `npm run build`: passed (static prototype build only).
- Android bridge invokes `FirebaseAIOnDevice` status/download and `generateContent` with inference mode configuration.
- Web bridge invokes Firebase AI Logic generation and reads response inference-source metadata.

## Required corrections

1. **Web cloud fallback lacks App Check integration in its independent bundle.** `mobile/web_hybrid_src/src/hybrid_ai.js:20` initializes its own bundled Firebase app and AI service but imports/initializes neither App Check nor Auth. FlutterFire initialization does not automatically initialize the separate bundled SDK instance. Wire attestation and required auth state into the instance making these AI calls, then verify a cloud response with enforcement enabled. Do not solve this by disabling enforcement.
2. **Web renderer remains a network dependency.** The inspected `mobile/build/web/flutter_bootstrap.js` uses the default CDN renderer location; `mobile/web/offline_sw.js:48` excludes cross-origin resources. Configure bundled local renderer assets and cache all required startup resources. Verify cold start with network disconnected and HTTP cache cleared while preserving the installed app-shell cache. Also require successful caching of critical assets rather than silently accepting every failed precache via `Promise.allSettled`.
3. **Android checklist storage is temporary.** `mobile/lib/services/checklist_storage_io.dart:4` writes beneath `Directory.systemTemp`. Use durable app-private support/documents storage and verify saved checklist retention after process restart and cache eviction.

## Still needs runtime evidence

- SDK capability/model version on the Pixel 8 Pro and the desktop Chrome machine.
- A fresh, changed prompt generating locally with all network connectivity disabled.
- Offline app reopening and access to the checklist after authentication/context restoration.
- Genuine prefer-local cloud fallback when local inference is unavailable.
- Actual SDK source metadata and a reproducible judge setup.

Tests use adapter doubles and cannot establish these device-level outcomes. Do not record the final offline AI demo until these checks pass. No application source fixes were made during this review.

Android APK build: attempted with SDK/cache access; Gradle remained at `assembleDebug` without a completion result during the review. No Android build pass is claimed.

## Follow-up review after fixes

Confirmed in source: Android checklist storage now uses `context.filesDir`; Web passes `RECAPTCHA_SITE_KEY` to its bundled SDK and initializes App Check/Auth; the inspected Web build has `useLocalCanvasKit: true`. Critical precaching now uses `cache.addAll`. Flutter tests again passed 12/12, the Web hybrid bundle rebuilt successfully, and the root build passed.

Remaining findings:

- **P1 — precache the renderer Chrome actually selects.** `mobile/web/offline_sw.js:16` precaches only the standard CanvasKit JS/WASM. The current Flutter bootstrap automatically chooses `canvaskit/chromium/` when Chrome capabilities permit, and no `canvasKitVariant: 'full'` override is configured. On an initial visit those renderer requests can occur before service-worker control, leaving them absent from Cache Storage. Precache the Chromium pair too, or explicitly select the standard variant; bump the cache version. Validate a cold offline reopen without relying on HTTP cache.
- **P2 — do not mark every App Check initialization error as success.** `mobile/web_hybrid_src/src/hybrid_ai.js:56` catches all errors and sets `_appCheckInitialized = true`. This conceals configuration/initialization failures and prevents retry. Recognize only a genuinely already-initialized instance; otherwise retain failure state and surface a useful diagnostic. Verify a cloud response with App Check enforced.

These findings do not negate the implemented corrections. They mean source review and passing mocked tests still cannot establish full offline readiness. Device-level local inference and cloud fallback evidence remain outstanding.

Follow-up APK attempt: Gradle again did not complete during the review window; the attempt was interrupted. This is an incomplete build check, not evidence of an Android compilation failure. No new device-runtime pass is claimed.
