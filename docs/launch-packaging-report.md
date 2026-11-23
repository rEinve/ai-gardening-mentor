# AI Gardening Mentor (Tanzania MVP) — Packaging & Launch Readiness Report

**Date**: 2026-11-22  
**Status**: Feature-complete MVP ready for Firebase online deployment & pilot testing (Free Trial — no payment gate yet).

---

## 1. Completed App Architecture & Features

| Surface | Path | What Is Included |
| :--- | :--- | :--- |
| **Login / Create Account Gate** | `mobile/lib/screens/auth_gate_screen.dart` | All services sit behind personal authentication (**Create Account**, **Log In**, **Continue with Google**; Log Out in Account). Free Pilot Trial mode (no payment required yet). |
| **3-Screen Tanzania Onboarding** | `mobile/lib/screens/onboarding_flow.dart` | Tanzania region selector (Dodoma, Dar es Salaam, Arusha, Morogoro, Mwanza, Mbeya, Tanga, Zanzibar, Iringa, Kilimanjaro), 9 starter crops, plot type, exposure, and sunlight. |
| **Home (7-Day Care Cadence)** | `mobile/lib/screens/home_cadence_screen.dart` | Rolling 7-day micro-habits with offline-first append-only completions and weather deferral support. |
| **Proactive Crop Planner & Waterfall** | `mobile/lib/screens/crop_planner_screen.dart`, `backend/functions/src/domain/cropPlanner.ts` | Ported from `docs/Crop planting log.xlsx`: **Bought Seedlings / From Seed / Direct Seeding**, interactive **Prepare Ahead (Next 14 Days)** alerts, **Expected Harvest Date** & countdowns, **Succession Planting** with date-shift cascade, and full **Waterfall Timeline** (Nursery → Planting → Vegetative → Flowering → Fruiting → Harvest) with practical Tanzanian inputs (DAP, CAN/Urea, NPK 17:17:17, Calcium-Boron foliar). |
| **Garden Mentor + Search Skill + Logs** | `mobile/lib/screens/mentor_chat_screen.dart`, `backend/functions/src/providers/geminiProvider.ts` | Grounded AI Mentor (`gemini-4-hydrogen`, Interactions API, `store: false`) with **`tools: [{ type: 'google_search' }]`** to look up local agro-dealers & agronomists (information only: Name, Location, Phone Number), **`+`** attachment menu (**Take Photo** / **Upload Photo from Phone or WhatsApp**), and **Saved Chat & Search Logs** history viewer. |
| **Plant Diagnosis (Photo Triage)** | `mobile/lib/screens/triage_flow.dart` | Camera & WhatsApp/Gallery photo upload, `image-quality-v1` check, 3-step Calm Plan, recovery chore button, and agro-dealer lookup. |
| **My Account & Farm Contact Book** | `mobile/lib/screens/account_screen.dart` | Personal account info + Log Out + dedicated **Farm Contact Book** with 2 categories only (**Suppliers** & **Buyers / Clients**), kept separate from the farmer's personal phonebook. |
| **Firebase Backend (`europe-west1`)** | `backend/` | Strict Firestore/Storage security rules, 6 composite indexes, 8 Cloud Functions v2, Gemini + OpenWeather providers, and unit + emulator tests. |
| **Web Landing Prototype & Container** | `src/`, `dist/`, `Containerfile`, `podman-compose.yml` | Static M3 landing site + rootless Podman/Docker deployment config. |

---

## 2. Going Live Online (Firebase Hosting + Cloud Functions)

To publish the live app online so pilot testers (including your mom and friends) can create accounts and test from anywhere:

1. **Create / link your Firebase project** (`backend/.firebaserc`) and enable **Firebase Authentication** (Email/Password + Google provider), **Firestore**, and **Storage** in `europe-west1`.
2. **Set your API secrets securely on Firebase** (end-users never see or supply keys):
   ```bash
   cd backend
   firebase functions:secrets:set GEMINI_API_KEY
   firebase functions:secrets:set OPENWEATHER_API_KEY
   ```
   *(Note: Gemini's built-in `google_search` grounding tool works directly through `GEMINI_API_KEY`—no separate Search API key is needed!)*
3. **Deploy Backend & Web App**:
   ```bash
   cd backend && firebase deploy --only firestore,storage,functions
   cd ../mobile && flutter build web --release
   # Host mobile/build/web on Firebase Hosting (or your domain)
   ```
---

## 3. Locked Platform & Firebase AI Logic Strategy (Cost-Optimized for Tanzania)

- **Target Platforms**: **Web (Chrome)** and **Android** only for MVP (iOS / Apple Foundation Models deferred to avoid unnecessary complexity for the Tanzania market).
- **Hybrid AI via Firebase AI Logic**:
  - **On-device Gemini Nano** (Chrome Web + Android via Firebase AI Logic hybrid mode) to minimize API costs and support fast local responses where hardware supports it.
  - **Cloud Gemini fallback** (via Firebase AI Logic / Cloud Functions) for devices without Gemini Nano and for live `google_search` agro-dealer discovery.
- **Core Firebase Stack**:
  - **Firebase Authentication** (Email/Password + Google Sign-In — all services behind login)
  - **Cloud Firestore** (private user data, crop plans, completions, chat logs, Farm Contact Book)
  - **Firebase Remote Config** (live tuning of hybrid Nano/Cloud mode, pilot quotas, and feature flags without app store resubmission)
  - **Firebase App Check** (debug tokens in development; Play Integrity on Android & reCAPTCHA on Web in production)

