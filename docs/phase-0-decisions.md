# Phase 0 Decision Record: AI Gardening Mentor (Tanzania MVP)

Recorded — 2026-11-22. This document records the locked Phase 0 product and engineering decisions that unblock Phase 1 scaffolding in [implementation-plan.md](implementation-plan.md).

## 1. Locked Decisions

| Decision Area | Locked Choice | Notes |
| :--- | :--- | :--- |
| **Launch Market & Geography** | **Tanzania** (nationwide) | Manual region/city entry or GPS + live weather API. Do **not** require USDA Hardiness Zones (`usdaHardinessZone` remains `null` for Tanzania). |
| **Units & Default Timezone** | **Metric** (°C, mm, metres), `Africa/Dar_es_Salaam` (UTC+3) | Users may still switch display units in profile preferences per [schema.md](schema.md). |
| **Language** | **English** for MVP | Swahili (`sw`) localization is planned post-MVP; keep UI strings externalized from Phase 1 so localization is straightforward. |
| **Client Framework** | **Flutter** | Hybrid deployment (Android, iOS, Web, Desktop) with local offline-first persistence. |
| **Backend & AI Platform** | **Firebase** (Auth, Firestore, private Cloud Storage, strict TypeScript Cloud Functions) + **Gemini** server integration | Follows [tech-requirement-document.md](tech-requirement-document.md) and [schema.md](schema.md). |
| **Cloud / AI Service Region** | **`europe-west1`** | Broadest Firebase Functions + Firestore + Gemini/Vertex AI availability with reliable latency to East Africa. |
| **Phase 1 Build Sequence** | **Firebase Backend first**, then Flutter Client | Start with TypeScript Functions, Firestore schema validators, security rules, composite indexes, and emulator tests proving A1/A5/A8 before client integration. |

## 2. Initial Tanzania Crop Catalogue (Phase 1)

Selected for daily household consumption and high value among Tanzanian home gardeners:

| Botanical Family | Crop ID (slug) | Common Name (EN) | Local Name (SW) | Planting Methods |
| :--- | :--- | :--- | :--- | :--- |
| Solanaceae | `tz_tomato` | Tomato | Nyanya | `transplant`, `direct_seed` |
| Solanaceae | `tz_pepper` | Pepper (Sweet & Hot) | Pilipili hoho / Pilipili | `transplant` |
| Solanaceae | `tz_african_eggplant` | African Eggplant / Eggplant | Ngogwe / Bilinganya | `transplant` |
| Solanaceae | `tz_african_nightshade` | African Nightshade | Mnavu | `direct_seed`, `transplant` |
| Malvaceae | `tz_okra` | Okra | Bamia | `direct_seed` |
| Amaranthaceae | `tz_amaranth` | Amaranth | Mchicha | `direct_seed` |
| Brassicaceae | `tz_sukuma_wiki` | Collard Greens / Kale | Sukumawiki | `transplant`, `direct_seed` |
| Cucurbitaceae | `tz_cucumber` | Cucumber | Tango | `direct_seed` |
| Cucurbitaceae | `tz_squash` | Squash / Pumpkin | Boga | `direct_seed` |

## 3. Horticultural Content & Attribution Strategy

- **Primary Public Reference**: East-West Seed Knowledge Transfer — **GrowHow** (`https://growhow.ews-kt.com/`), supplemented by public Tanzanian/East African agricultural extension materials (e.g., TARI, FAO).
- **Licensing & Provenance Safeguard**:
  - Do **not** copy-paste verbatim third-party articles into `knowledgeSources`.
  - Author original, concise care rules, growth-stage windows, and task templates grounded in the referenced guides.
  - Record `publisher`, `title`, `canonicalUrl`, `region: "TZ"`, `reviewedAt`, `reviewer`, and `reuseBasis` on every `knowledgeSources/{id}/revisions/{revision}` document.
- **Fixture Boundary**:
  - Phase 1 uses clearly labeled `reviewStatus: "prototype_fixture"` seed data so end-to-end onboarding, scheduling, and offline sync can be built and tested immediately.
  - Before public pilot launch, the product owner (farmer/domain reviewer) and/or local extension partner must verify licensing terms and promote records to `reviewStatus: "approved"`.

## 4. Remaining Phase 0 Spike Deliverables (Parallel with Early Phase 1)

1. **SDK & Model Compatibility Spike**: Pin verified Node.js, Firebase Admin/Functions SDK, Flutter/Firebase plugin, and Gemini model versions.
2. **Weather Provider Check**: Verify OpenWeather (or alternative) coverage, accuracy, and quota limits across Tanzanian regions (Coastal, Highlands, Central, Lake Zone) and calibrate tropical rain/heat thresholds.
3. **Image Contract Calibration**: Calibrate `image-quality-v1` thresholds and plant/soil relevance checks against real photos taken on target Android devices in Tanzanian outdoor daylight.
4. **Pilot Cost Ceiling**: Set daily triage/chat rate limits and GCP budget alerts before external pilot testers are onboarded.
