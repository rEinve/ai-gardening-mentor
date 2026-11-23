# AI Gardening Mentor — Proactive Crop Planner & AI Assistant (Tanzania MVP)

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

**AI Gardening Mentor** is an offline-first, proactive farming and vegetable gardening assistant built for **Web (Chrome)** and **Android** growers in **Tanzania** (part of the **IntelliWebLab** product family).

Instead of waiting until pests, nutrient deficiency, or missed market windows ruin a harvest, AI Gardening Mentor turns every planting date into an actionable **waterfall crop plan** paired with **Firebase AI Logic** (Gemini Nano hybrid on-device + cloud fallback), **WhatsApp/camera plant diagnosis**, and **local agro-dealer discovery**.

---

## Value Proposition

1. **Proactive Crop Planner & Waterfall Management** (`mobile/lib/screens/crop_planner_screen.dart`, `backend/functions/src/domain/cropPlanner.ts`)
   - Supports **Bought Seedlings**, **From Seed (Nursery → Transplant)**, and **Direct Seeding**.
   - Auto-calculates **Expected Transplant Date**, **Expected Harvest Date**, and **Days Remaining** so growers can check market prices and line up buyers *before* crops mature.
   - **14-Day Prepare-Ahead Alerts**: Notifies growers ahead of time to organize basal **DAP**, vegetative **CAN/Urea**, flowering **NPK 17:17:17**, and **Calcium-Boron foliar** inputs.
   - **Succession Planting**: Schedules sequential batches (default every 21 days) with single-batch date overrides and automatic cascade.
2. **Garden Mentor & Multimodal Plant Diagnosis** (`mobile/lib/screens/mentor_chat_screen.dart`, `mobile/lib/screens/triage_flow.dart`)
   - **WhatsApp & Camera Photo Upload**: Farm workers on-site can send leaf photos via WhatsApp; managers in town tap `+` → **Upload Photo from Phone / WhatsApp** for an instant 3-step Calm Diagnosis (*What It Is*, *Immediate Action*, *What NOT to Worry About*).
   - **Agro-Dealer Search Skill (Information Only)**: Returns local service provider **Name**, **Location/Area**, and **Phone Number** so the farmer can call ahead for stock and price before travelling.
   - **Saved Chat & Search Logs**: Browse previous weeks' conversations and search results anytime.
3. **Private Account & Dedicated Farm Contact Book** (`mobile/lib/screens/auth_gate_screen.dart`, `mobile/lib/screens/account_screen.dart`)
   - All services sit behind **Create Account / Log In** (Email/Password & Google Sign-In).
   - Dedicated **Farm Contact Book** with 2 clean categories (**Suppliers** and **Buyers / Clients**) kept separate from personal phonebook contacts.

---

## Runtime Firebase AI Logic Integration

This project imports and invokes **Firebase AI Logic** (`firebase_ai`), **Firebase App Check** (`firebase_app_check`), **Firebase Remote Config** (`firebase_remote_config`), and **Firebase Auth** (`firebase_auth`) directly at runtime:

- **Client Runtime Entry Point**: [`mobile/lib/services/firebase_ai_logic_service.dart`](mobile/lib/services/firebase_ai_logic_service.dart)
  - Imports `package:firebase_ai/firebase_ai.dart`, `package:firebase_app_check/firebase_app_check.dart`, and `package:firebase_remote_config/firebase_remote_config.dart`.
  - Initializes **App Check** (debug provider in dev; Play Integrity / reCAPTCHA in production), fetches **Remote Config** parameters (`ai_model_name`, `ai_prefer_on_device`), and creates a runtime `GenerativeModel` via `FirebaseAI.googleAI(appCheck: FirebaseAppCheck.instance).generativeModel(...)`.
  - Invoked at runtime from [`mobile/lib/main.dart`](mobile/lib/main.dart), [`mobile/lib/screens/mentor_chat_screen.dart`](mobile/lib/screens/mentor_chat_screen.dart) (`streamMentorReply`), and [`mobile/lib/screens/triage_flow.dart`](mobile/lib/screens/triage_flow.dart) (`analyzePlantPhoto`).
- **Server-Side Grounded Agent & Search Skill**: [`backend/functions/src/providers/geminiProvider.ts`](backend/functions/src/providers/geminiProvider.ts)
  - Uses `@google/genai` Interactions API (`gemini-4-hydrogen`, `store: false`) with `tools: [{ type: 'google_search' }]` for grounded local agro-dealer lookup.

---

## Repository Structure

```text
├── LICENSE                        # Apache License 2.0
├── README.md                      # Project overview, value proposition & setup
├── mobile/                        # Flutter hybrid client (Web Chrome + Android)
│   ├── lib/main.dart              # App entry point (Auth Gate + Firebase AI Logic)
│   ├── lib/services/
│   │   ├── firebase_ai_logic_service.dart  # Runtime Firebase AI Logic + App Check + Remote Config
│   │   ├── firebase_garden_backend.dart    # Firestore offline persistence & Callables
│   │   └── photo_picker*.dart              # Camera + WhatsApp/Gallery photo upload
│   ├── lib/screens/               # Auth, Onboarding, Home, Planner, Garden, Mentor, Triage, Account
│   └── test/                      # Unit & end-to-end widget tests
├── backend/                       # Firebase Cloud Functions v2 (TypeScript, europe-west1)
│   ├── firestore.rules            # Strict user isolation & append-only taskCompletions
│   ├── storage.rules              # Private JPEG diagnostic uploads (<= 350 KB)
│   └── functions/src/             # Planner engine, cadence scheduler, Gemini & OpenWeather providers
├── src/                           # Marketing prototype (being aligned to IntelliWebLab Starter Kit)
├── docs/                          # Specs, Excel crop log, architecture & 3-min demo video script
└── Containerfile / compose.yaml   # Rootless Podman & Docker container definitions
```

---

## Quick Start (Build, Test & Run)

### 1. Prerequisites
- **Flutter SDK** 3.24+ (Web & Android targets)
- **Node.js** 20+ / 22+
- **Firebase CLI** (for emulators or cloud deployment)

### 2. Run the Flutter Client (Web / Android)
```bash
cd mobile
flutter pub get
flutter test
flutter run -d chrome
# Or build for Web:
flutter build web --release
# Or run on a USB-connected Android device:
flutter run
```

### 3. Build & Test the Firebase Backend
```bash
cd backend/functions
npm install
npm run build
node --test test/cropPlanner.test.ts
```

### 4. Deploy Live with Firebase AI Logic & Secrets
```bash
cd backend
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set OPENWEATHER_API_KEY
firebase deploy --only firestore,storage,functions
```

---

## License

Licensed under the **Apache License, Version 2.0**. See [LICENSE](LICENSE) for full terms.
