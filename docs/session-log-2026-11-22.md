# Session Handoff Report — 2026-11-22

**Project**: AI Gardening Mentor (Tanzania MVP)  
**Workspace**: `/Users/mac/Developer/IntelliTheme-Studio/Prototypes/ai-gardening-mentor`

---

## 1. Key Product & Architecture Decisions Locked
Recorded in [docs/phase-0-decisions.md](phase-0-decisions.md):
- **Launch Market**: **Tanzania** nationwide (manual region/city + GPS + OpenWeather metric API; `Africa/Dar_es_Salaam`; `usdaHardinessZone: null`).
- **Language**: **English** for MVP (externalized for Swahili post-MVP).
- **Client Framework**: **Flutter** (hybrid Android, iOS, Web, macOS/Desktop; offline-first).
- **Backend & Region**: **Firebase** (Auth, Firestore, private Storage, strict TypeScript Cloud Functions v2) in **`europe-west1`**.
- **AI Engine & Subscription Model**: Server-side managed **Gemini** (`@google/genai` `^3.2.0`, `gemini-4-hydrogen`, Interactions API, `store: false`). End-users never supply API keys or see the underlying model; server-side quotas (`10 triages/day` baseline) power future Free vs. Monthly/Yearly subscription tiers.
- **9 Starter Tanzania Crops**: Tomato (*Nyanya*), Pepper (*Pilipili*), African Eggplant (*Ngogwe / Bilinganya*), African Nightshade (*Mnavu*), Okra (*Bamia*), Amaranth (*Mchicha*), Sukuma Wiki (*Sukumawiki*), Cucumber (*Tango*), and Squash / Pumpkin (*Boga*).
- **Horticultural Content**: Structured original care rules & templates grounded in **East-West Seed Knowledge Transfer (GrowHow)** (`https://growhow.ews-kt.com/in/en`), explicitly marked `reviewStatus: 'prototype_fixture'` until licensing/agronomic sign-off before public pilot.

---

## 2. Completed Deliverables

### A. Podman Container & M3 Web Prototype
- `Containerfile`, `Dockerfile`, `.containerignore`, `.dockerignore`, `podman-compose.yml`, `compose.yaml`, `nginx/nginx.conf`, `CONTAINER.md`.
- Executable helper scripts: `scripts/podman-build.sh`, `scripts/podman-run.sh`, `scripts/podman-dev.sh`, `scripts/podman-stop.sh`, `scripts/build.mjs`, `scripts/dev-server.mjs`.
- Material Design 3 landing prototype: `src/styles/m3-tokens.css`, `src/styles/main.css`, `src/index.html` → compiled cleanly to `dist/`.

### B. Firebase Backend (`backend/`) — Phases 1–4 + Live Providers
- **Config & Rules**:
  - `backend/firebase.json` (Firestore Emulator moved to `127.0.0.1:8088` to avoid port `8080` conflicts), `backend/.firebaserc`.
  - `backend/firestore.rules` (normative deny-all default, allowlisted fields, append-only `taskCompletions`, server-owned tasks/requests/triage/chat/jobRuns).
  - `backend/storage.rules` (private `users/{uid}/diagnostics/{diagnosisId}.jpg`, JPEG only, ≤ 350,000 bytes).
  - `backend/firestore.indexes.json` (all 6 composite indexes).
- **Cloud Functions (`backend/functions/src/`)**:
  - `types/schema.ts`, `validators/garden.ts`, `validators/triage.ts`.
  - `domain/identity.ts`, `domain/cadence.ts`, `domain/effectiveState.ts`, `domain/retrieval.ts`, `domain/scheduler.ts`, `domain/weatherOverrides.ts`.
  - `functions/initializeGarden.ts`, `functions/executeMultimodalTriage.ts`, `functions/addRecoveryTask.ts`, `functions/processMentorChat.ts`, `functions/lifecycle.ts`.
  - `providers/geminiProvider.ts` (`gemini-4-hydrogen` structured triage + SSE streaming chat) and `providers/openWeatherProvider.ts` (24h metric rain/temp + outage fallback).
  - `seeds/tanzaniaFixtures.ts` (all 9 Tanzania crops, care rules, task templates, GrowHow citations).
  - `index.ts` exporting all 8 functions in `europe-west1` with Firebase Secrets (`GEMINI_API_KEY`, `OPENWEATHER_API_KEY`).

### C. Flutter Hybrid Client (`mobile/`) — Phases 1–3 + Proactive Crop Planner
- `mobile/pubspec.yaml`, `mobile/lib/main.dart`, `mobile/lib/theme/app_theme.dart` (M3 Botanical Emerald light/dark).
- `mobile/lib/models/garden_models.dart`, `mobile/lib/models/crop_planner_models.dart`, `mobile/lib/data/tanzania_crops.dart`, `mobile/lib/data/offline_garden_store.dart`, `mobile/lib/data/image_quality.dart`.
- Screens: `onboarding_flow.dart` (3-screen Tanzania setup), `home_cadence_screen.dart` (7-day offline-first cadence), `crop_planner_screen.dart` (proactive waterfall project manager, 14-day prepare-ahead alerts, succession planting, conventional + organic input schedule, conservative yield estimates), `task_detail_screen.dart`, `garden_and_mentor_screens.dart`, `triage_flow.dart` (`image-quality-v1` + 8s background return + 3-step Calm Plan), `mentor_chat_screen.dart` (context snapshot with planner countdowns + offline drafts + citations + archive).

---

## 3. Verification Status (All Passing)
- **Backend TypeScript Build** (`cd backend/functions && npm run build`): **0 errors** (`@google/genai` installed, `rewriteRelativeImportExtensions: true`).
- **Backend Unit Suite** (`phase1.test.ts` → `phase4.test.ts`): **17/17 passed** (`A1`–`A7`, `A9`, `A10`, + OpenWeather provider).
- **Firestore Security Rules Emulator Suite** (`firestore.rules.test.ts`): **4/4 passed** (`A8` on local emulator `127.0.0.1:8088`).
- **Flutter Platform Runners & Firebase Integration**:
  - Generated `web`, `macos`, `android`, `ios` runners via `flutter create`.
  - Added `GardenBackendClient` + `FirebaseGardenBackend` (`mobile/lib/services/`) wiring `OfflineGardenStore`, `TriageFlowScreen`, and `MentorChatScreen` to Firebase Auth (anonymous sign-in), Firestore offline cache, private Storage (`users/{uid}/diagnostics/{diagnosisId}.jpg`), and `europe-west1` Cloud Functions / local Emulators (`USE_FIREBASE_EMULATORS=true`), with graceful offline preview fallback.
- **Flutter Unit & Widget Suite** (`garden_models_test.dart`, `widget_test.dart`): **5/5 passed** (includes full Onboarding → 7-day cadence → Triage → Recovery Chore → Mentor SSE E2E widget test).
- **Flutter Web Build** (`cd mobile && flutter build web`): **✓ Built `build/web` (0 errors)**.
- **Web Prototype Build** (`npm run build`): **0 errors**.

---

## 4. Pick Up Here Next Session
1. **Run live end-to-end with local Firebase Emulators**:
   - Terminal 1: `cd backend/functions && npm run serve`
   - Terminal 2: `cd mobile && flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true`
2. **Before Public Tanzania Pilot (Phase 5)**:
   - Configure `GEMINI_API_KEY` and `OPENWEATHER_API_KEY` in Firebase Functions Secrets.
   - Add subscription tier entitlements (Free vs. Monthly/Yearly) to daily triage/chat quotas.
   - Verify EWS-KT GrowHow attribution/licensing and promote `prototype_fixture` records to `approved`.
