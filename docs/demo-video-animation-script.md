# AI Gardening Mentor — Three-Minute Hackathon & Homepage Demo Script

Version: 25 November 2026.  
Format: Founder voiceover with real screen captures from Desktop Chrome (`https://ai-gardening-mentor-dev.web.app`) and Android (`emulator-5554` / Android device) inside clean animated device frames.  
Audience: **#BuildHybridAI 2026** judges & marketing homepage visitors.

**Creative core:** *“Peer-to-peer homestead mentorship — the practical guidance farmers already ask me for, growing into their own offline farm library.”*  
Follow one grower in **Dodoma, Tanzania** managing raised beds (Tomatoes, Cucumbers, Peppers, Amaranth, African Eggplant) — from planning the month ahead, to building a personal living crop library, to generating a fresh care checklist **on-device with Chrome Built-in Gemini Nano via Firebase AI Logic**.

**Status: Ready for recording.** Web app is deployed at `https://ai-gardening-mentor-dev.web.app` with `Chrome Built-in Gemini Nano (LanguageModel)` verified `ready` in Desktop Chrome 158 + Firebase JS AI Logic (`PREFER_ON_DEVICE` + App Check + `agm-app-shell-v5` offline cache). Android APK (`google_sign_in` + `GardenHybridAiBridge.kt`) is verified on Android API 37 emulator.

---

## Format & Production Checklist

- **Target runtime:** **2:55 – 2:58** (strictly under the 3:00 limit).
- **Spoken script length:** ~375 words (natural, warm, practical founder pace with pauses to read real UI responses).
- **Authenticity rule:** Every app tap, generated checklist, `SDK Inference Source` badge, and saved note is captured from the real working build — never faked or simulated.
- **Audio & Captions:** Record founder voiceover first, lock scene timings to the voice track, include crisp English captions (readable on mobile), and keep background music quiet underneath.

---

## Timed Storyboard & Voiceover Script

*(Only the blockquotes are spoken.)*

### Scene 1 — The Grower's Reality (0:00 – 0:18 | 18s)
**Visual:** Dawn over a homestead plot in Dodoma. A farmer checking tomato leaves with a handwritten planting date and weak mobile signal. Smooth transition into the **AI Gardening Mentor** brand logo (`BrandLogo`) and app frame.  
**On-screen callout:** *“What should I do next?” → AI Gardening Mentor*

> I am a farmer. Friends already call me for peer-to-peer advice: how to prepare their beds, when to plant, what inputs to buy early, and what to do when a leaf looks wrong. I built AI Gardening Mentor to put that practical homestead guidance right in their hands — online and offline.

---

### Scene 2 — Personalized Homestead Setup (0:18 – 0:34 | 16s)
**Visual:** Show the real app signed in (Dodoma • Raised Bed • Exposed) with active crops (`Tomato`, `Cucumber`, `Pepper`, `Amaranth`, `African Eggplant`).  
**On-screen callout:** *Dodoma • Raised Bed • Your Crops, Your Conditions*

> Start by setting your region, your plot type, and the crops you are growing. Here in Dodoma, we are following a homestead grower with raised beds — turning one planting date into a clear plan and a personal farm library.

---

### Scene 3 — Calendar-First Crop Planner (0:34 – 1:02 | 28s)
**Visual:** Open **Planner**. Show the **Month** calendar switcher (`This Month` → tap `>` for `Next Month`), toggle to **Week**, then **Batches**. Tap a **Prepare Ahead (Next 14 Days)** alert to show upcoming input preparation and staggered succession batches.  
**On-screen callout:** *Month & Week Calendar • 14-Day Prepare Ahead • Staggered Harvests*

> In Crop Planner, you can switch between Month, Week, and Batch views to see what is coming this month and next month. Prepare Ahead highlights inputs two weeks before they are due, so you never miss feeding or transplanting windows. Staggered batches help you plan continuous harvests.

---

### Scene 4 — My Garden: Your Living Crop Library (1:02 – 1:34 | 32s)
**Visual:** Open **My Garden**. Briefly tap **Compost & Bed Health** (off-season June–July manure collection & pit/heap composting) and **Trellis & Support Prep** (stakes & Florida Weave). Then tap **Tomato (Nyanya)** to open its **Living Crop Library**: show the **Tailored for Your Homestead** card (cm + adult foot-length / cut-stick spacing), harvest countdown, **Add Note**, and peer-to-peer field notes.  
**On-screen callout:** *Bed Health & Compost • Practical cm & Foot-Length Spacing • Grows Every Season*

> My Garden is not a static textbook — it is your living farm library. It starts with bed health: how to compost dry off-season manure instead of using raw manure, and how to prepare trellises before flowering. Tap any crop for spacing tailored to your raised bed — in centimeters and simple foot-lengths — plus your harvest countdown and personal season notes.

---

### Scene 5 — Mentor + Save to Library + Real Hybrid AI Proof (1:34 – 2:18 | 44s)
**Visual (Part A — 14s):** Open **Mentor**. Show the `+` menu (Camera / WhatsApp Photo Triage) and tap **`Save to Crop Library`** on a real Mentor reply to save that advice directly into Tomato's offline library.  
**Visual (Part B — 30s, Desktop Chrome Hybrid Proof):** Open **Offline Care Checklist** in Desktop Chrome (`https://ai-gardening-mentor-dev.web.app`). Expand **Judge & Developer Details** showing:
- `Platform: Web (Desktop Chrome + Firebase JS AI Logic)`
- `Capability Status: ready`
- `Model Identity: Chrome Built-in Gemini Nano (LanguageModel)`
Disconnect Wi-Fi (or show offline state clearly), enter a fresh observation, tap **Make Today's Care Checklist**, and hold on the real result showing **`Generated on this device`** (`SDK Inference Source: onDevice`) + real elapsed milliseconds. Then show online **`Only Cloud`** / fallback producing **`Generated in cloud`** (`inCloud`) with App Check active.  
**On-screen callout:** *Firebase AI Logic Hybrid • On-Device Gemini Nano (Offline) + Cloud Fallback*

> When you need help, ask Garden Mentor or upload a plant photo from your camera or WhatsApp — and save useful replies straight into that crop’s library. And when the network drops, Offline Care Checklist runs real Firebase AI Logic hybrid inference. Here in Desktop Chrome, Chrome’s built-in Gemini Nano generates a fresh checklist directly on-device with no internet, and automatically falls back to the cloud when local inference isn’t available.

---

### Scene 6 — Architecture & Submission Integrity (2:18 – 2:38 | 20s)
**Visual:** Clean architectural overlay around the app frame: **Firebase AI Logic (Hybrid Nano + Cloud)**, **Firebase Auth**, **App Check (reCAPTCHA Enterprise / Play Integrity)**, **Firestore Offline Persistence**, and **Versioned Offline App Shell (`agm-app-shell-v5`)**.  
**On-screen callout:** *Firebase AI Logic • Auth • App Check • Offline App Shell*

> Under the hood, one Flutter codebase connects Firebase AI Logic for hybrid inference, Firebase Auth for account isolation, App Check for request protection, and a local CanvasKit offline shell — keeping every farmer’s plots, notes, and Farm Contact Book private and accessible offline.

---

### Scene 7 — Close & Call to Action (2:38 – 2:58 | 20s)
**Visual:** Return to **Today** checklist, check off one micro-habit, then pull back to the **AI Gardening Mentor** logo, `https://ai-gardening-mentor-dev.web.app`, and `https://github.com/rEinve/ai-gardening-mentor` with a clean 3-second final hold.  
**On-screen callout:** *Plan ahead. Grow with confidence.* / *AI Gardening Mentor — IntelliWebLab* / `ai-gardening-mentor-dev.web.app`

> The more a farmer farms, the richer their personal library grows. Next, we are putting AI Gardening Mentor into the hands of growers I work with every week. AI Gardening Mentor: practical farmer-to-farmer guidance, ready online and offline.

---

## Verification & Capture Checklist Before Final Export

| Sequence | Verified Status | Capture Target |
| --- | --- | --- |
| Sign-in & Dodoma Raised Bed setup | Verified on Web & Android emulator | Desktop Chrome + Android emulator |
| Planner (`Month` / `Week` / `Batches` + 14-day Prepare Ahead) | Verified (`13/13` tests passing) | Desktop Chrome or Android |
| My Garden Living Crop Library + Compost & Trellis Prep + Add Note | Verified (`13/13` tests passing) | Desktop Chrome + Android |
| Mentor `Save to Crop Library` + WhatsApp Photo Import | Verified | Desktop Chrome or Android |
| On-Device Gemini Nano (`Capability Status: ready`, `onDevice`) | **Verified ready on Desktop Chrome 158** | Desktop Chrome (Wi-Fi OFF capture + cold reload) |
| Cloud Fallback (`inCloud` with App Check) | Wired (`ReCaptchaEnterpriseProvider` + `ONLY_IN_CLOUD` diagnostic) | Desktop Chrome (Wi-Fi ON capture) |
| Native Android APK (`google_sign_in` + `GardenHybridAiBridge.kt`) | Installed & verified on Android API 37 emulator (note: emulator has no hardware AICore; claim on-device proof specifically on verified Desktop Chrome unless also captured on supported AICore phone) | Android emulator |

## Landing-Page Reuse Variant
For the marketing homepage hero (`marketing-prototype/`):
- Swap the final spoken sentence to: *“Start your garden plan today with AI Gardening Mentor.”*
- Show the live app URL `https://ai-gardening-mentor-dev.web.app` on the end card with click-to-play poster and captions.
