# AI Gardening Mentor — Three-minute hackathon demo

Version: 23 November 2026. Format: animated presentation with founder voiceover and authentic app footage inside animated device frames. Audience: #BuildHybridAI 2026 judges; reusable on the marketing homepage.

**Creative idea: “From planting day to the next right action.”** Follow one grower in Dodoma and one tomato crop. Show a complete journey rather than a catalogue of features.

**Status: production script draft.** Product scenes need a recorded walkthrough check. Scene 5 is a conditional target sequence: local inference and cloud fallback must be implemented and verified before recording its target narration. This document does not establish submission readiness.

## Format and editorial direction

- Timeline: exactly 3:00, including opening and closing. Aim for a 2:58 export to leave encoding margin by shortening the closing hold.
- Voice: founder speaking naturally in English, warm and practical. Approximately 360–390 words; allow pauses for results and transitions. Rehearse against the timed scenes before animation lock.
- Animation: illustrated garden, growing timeline, moving device frames, tap highlights, and short text callouts. No presenter footage required.
- Product proof: use real captures for taps, generated answers, and state changes. Animation can frame and explain these captures; do not animate invented responses as if they were observed app behavior.
- Art direction: use the existing Gardening Mentor logo and botanical brand palette. Reuse approved app screens and brand assets. Keep captions clear at mobile playback size.
- Sound: quiet instrumental bed, subtle taps, no sound effect over key voiceover. Deliver captions and a clean voice track as well as the mixed master.

## Timed storyboard and recording script

Only the blockquotes are spoken. Overlays are editorial callouts, not claims that the app already has these UI labels.

### 1. The grower's problem — 0:00–0:18 (18 seconds)

**Animation:** Dawn over a small tomato plot in Dodoma. A grower checks a leaf, a handwritten planting date, and a phone with a weak connection. Transform the paper date into the app's Planner. Keep the tone resourceful rather than helpless.

**On-screen:** “What should I do next?” → “AI Gardening Mentor”.

> Growing tomatoes means making decisions every day. When should I transplant? What should I prepare next? And what does this leaf need? For growers in Tanzania, those questions do not wait for a reliable internet connection.

### 2. One grower, one crop — 0:18–0:35 (17 seconds)

**Animation:** Phone enters frame. Briefly show account entry, then actual region and crop setup. Choose Dodoma and tomato. Zoom into the saved garden context; skip typing passwords and lengthy forms.

**On-screen:** “Dodoma • Tomatoes • Your growing conditions”.

> Meet AI Gardening Mentor. Start with your region, your crops, and your growing conditions. We are following a tomato grower in Dodoma, turning one planting date into a practical plan for the weeks ahead.

### 3. Make the season visible — 0:35–1:02 (27 seconds)

**Animation:** Open Planner. Select bought seedlings and a planting date. Expand the real waterfall timeline. Trace planting, vegetative growth, flowering, and estimated harvest. Open Prepare Ahead, then show three succession batches offset by 21 days. Use dates computed by the app rather than manually designed dates.

**On-screen:** “Planting → Care milestones → Expected harvest” / “Prepare ahead” / “Stagger your batches”.

> Choose whether you are starting from seed, buying seedlings, or sowing directly. The planner lays out your crop milestones and expected harvest date. Prepare Ahead brings upcoming needs into view, so you can organize supplies before they are due. Staggered planting batches help you spread the work and plan for successive harvests.

### 4. Turn a photo into a next step — 1:02–1:27 (25 seconds)

**Animation:** A farm colleague sends a leaf photo. Show it being saved from WhatsApp, then the actual Garden Mentor plus menu and photo upload. Hold on a real response long enough to read its core advice. Magnify the uncertainty or follow-up question if the response includes one.

**On-screen:** “Upload a photo” / “Understand the concern” / “Choose a next step”.

> When a leaf looks unusual, open Garden Mentor and add a photo, including one saved from WhatsApp. The mentor helps you understand the concern and choose a next step. If the image is unclear, it can ask for a better view. The aim is calmer decisions, with uncertainty made visible.

**Capture note:** This is a manual photo import, not an automated WhatsApp bot. Do not promise a definitive diagnosis or a fixed response time.

### 5. Show why hybrid matters — 1:27–2:02 (35 seconds)

**CONDITIONAL: target narration below is only recordable after verified local generation and cloud fallback.**

**Animation:** Keep the same garden context. Use a supported device with its local model already available. Disable the network and submit a fresh, previously unused short care question. Show actual generated text. Then use a supported test configuration where local inference is unavailable, restore connectivity, and show a real cloud response. Animate a small phone → Firebase AI Logic → cloud diagram around the evidence.

**On-screen:** “On-device generation • Network off” → “Cloud fallback • Network available”. Add these labels only when supported by captured runtime evidence. Show “Time compressed” if any wait is shortened.

> Here is why hybrid AI matters in the garden. On a supported device, a short care question can run locally, even without a connection. This is a newly generated answer, not a saved reply. When local inference is unavailable, Firebase AI Logic provides the cloud path when connectivity is available. The grower keeps one familiar conversation, while the app handles where the answer comes from.

**Honest interim narration if the implementation remains unchanged:**

> The current prototype uses Firebase AI Logic for cloud conversations and photo analysis. Our next step is local generation on supported devices, with cloud fallback when needed. That distinction matters: opening a saved plan offline is useful, but it does not demonstrate on-device AI. Before submission, we need to prove both inference paths using a fresh question and visible runtime evidence.

The interim version makes this an accurate progress demo; it does not resolve the hackathon's hybrid implementation requirement. For the interim visuals, show the cloud capture and a diagram clearly marked “Planned local inference”; omit the simulated offline answer.

### 6. Make the technology legible — 2:02–2:20 (18 seconds)

**Animation:** Four restrained labels appear around a real app capture: Firebase AI Logic, Authentication, App Check, Remote Config. Briefly show the relevant runtime call or sanitized trace in a magnified inset. Keep explanations readable, not a wall of code.

**On-screen:** “Firebase AI Logic at runtime”.

> Firebase AI Logic powers the mentor's responses. The app also connects account access, App Check, and Remote Config, bringing identity, request protection, and configurable model settings into the experience. The code shows where the AI calls actually run.

**Capture note:** Verify the configured build and active App Check before using this wording. Do not imply that merely reading a preference enables hybrid routing.

### 7. Keep daily work together — 2:20–2:40 (20 seconds)

**Animation:** Return to Home and complete one task. Open chat history, then Account → Farm Contact Book. Show Suppliers and Buyers / Clients with clearly fictional demonstration contacts and no usable personal phone numbers.

**On-screen:** “Today's work • Previous advice • Farm contacts”.

> Back in the garden, today's checklist keeps the next job clear. Previous conversations help the grower revisit advice, while the farm contact book keeps suppliers and buyers together. Planning, asking, and following through become parts of the same daily routine.

### 8. Close with the outcome — 2:40–3:00 (20 seconds)

**Animation:** Pull back from the phone to the original garden. The planting timeline resolves into upcoming milestones; avoid inventing a measured yield improvement. Finish on the logo and verified project URL, with a final silent hold.

**On-screen:** “Plan ahead. Grow with confidence.” / “AI Gardening Mentor by IntelliWebLab” / “[verified project URL]”.

> AI Gardening Mentor helps growers move from uncertainty to a practical next step: plan the crop, prepare for what is coming, and get guidance when questions arise. Built for the realities of growing in Tanzania. Plan ahead. Grow with confidence.

## What must be verified before production lock

Repository review is source inspection, not a live end-to-end acceptance test.

| Claim or sequence | Evidence found | Production decision |
| --- | --- | --- |
| Crop waterfall and succession planning | `mobile/lib/screens/crop_planner_screen.dart`; `backend/functions/src/domain/cropPlanner.ts` | Capture actual dates and interactions from the chosen demo account. Harvest dates are estimates, not promises. |
| Firebase AI Logic cloud calls | `mobile/lib/services/firebase_ai_logic_service.dart` calls `generateContentStream` and `generateContent` | Capture a successfully configured runtime. Preview fallback must not stand in for live AI. |
| On-device AI and automatic fallback | `ai_prefer_on_device` is read and stored, but no routing use was found in `mobile/lib` | Scene 5 target wording is blocked until implemented and observed. Offline storage is not local inference. |
| Server AI route | `backend/functions/src/providers/geminiProvider.ts` uses `@google/genai` directly | Review against the event's Firebase AI Logic requirement before presenting the submission architecture. Do not depict this direct route as Firebase AI Logic. |
| App Check | Activation is attempted; activation errors are caught | Confirm protection is active in the captured build; configuration code alone is insufficient proof. |
| Photo import and mentor | `mobile/lib/screens/mentor_chat_screen.dart`; `triage_flow.dart` | Record the real upload and reply. Preserve qualifications in the answer. |
| Accounts, history, contacts | Corresponding app screens and session notes | Verify persistence and account behavior in the demo build before capture. |
| Chrome and Android | Both are project targets | Only label a platform as demonstrated after running that build; do not imply native Android proof from a browser capture. |

Avoid the previous draft's unverified two-minute setup claim, guaranteed instant diagnosis, guaranteed harvest timing, and universal fertilizer dosages. Local agro-dealer search is deliberately omitted from the main film until its inference route and returned information are validated.

## Landing-page reuse

Use the same main film in the marketing homepage's existing hero/media area, with a clear “Watch the 3-minute demo” poster and click-to-play controls. Preserve the primary signup action. Do not autoplay audio. Provide captions and an adjacent transcript link; lazy-load the player on interaction where possible.

For a marketing cut, replace the last sentence with: “Start your garden plan with AI Gardening Mentor.” Change the end card to “Start your garden plan” and the verified signup URL. Keep any feature limitations accurate. Embedding and video production are separate follow-up work; this task changes the script only.

## Other useful demo placements

| Priority | Placement | Length | Single action to demonstrate |
| --- | --- | --- | --- |
| 1 | Planner empty state and Planner app-guide article | 30–45 seconds | Add a planting date and understand the first milestone and estimated harvest. |
| 1 | Garden Mentor plus menu help and photo-triage article | 20–30 seconds | Save a WhatsApp image, upload it, and read qualified advice. |
| 1 | Offline/help panel, after hybrid verification | 20–30 seconds | Distinguish saved content, new local AI, and cloud access. Explain what happens when neither inference path is available. |
| 2 | First-run setup help | 15–20 seconds | Choose region, crop, and growing conditions. |
| 2 | Succession planting help beside its controls | 20–30 seconds | Create three staggered batches and inspect their dates. |
| 2 | Home checklist first-use tip | 10–15 seconds | Complete a care task and find the next one. |
| 3 | Farm Contact Book empty state | 15–20 seconds | Add one supplier and one buyer. |
| 3 | Homepage feature sections | 6–10 seconds each | Silent clips extracted from planner and photo sequences, each with a static fallback. |

Prefer contextual, dismissible help. Users should not have to watch a video to complete a task.

## Video-studio handoff

Prepare one scene per timed section with separate layers for background, device frame, authentic app footage, callouts, captions, and audio. Keep proof footage readable during transitions. No specific studio project format is assumed because the video studio has not yet been identified.

Inputs needed for rendering: approved logo, garden illustration assets, captures from a configured demo account, a suitable plant photo with permission to use it, verified inference traces, founder voice recording, and final project/signup URLs. Use licensed music and illustrations.

Outputs: 16:9 1080p master, caption file, transcript, poster image, and separate landing-page end-card variant. Record voiceover first, test pacing, then lock animation timing. Keep the last few seconds for a readable end card. Do not speed up speech to fit an overlong take.

## Hackathon reference

Checked 23 November 2026 against the [official event page](https://firebasehybridaihackathon.devpost.com/) and [official rules](https://firebasehybridaihackathon.devpost.com/rules).

The event asks for a video no longer than three minutes, publicly viewable on YouTube, in English or with English subtitles, with footage showing the working project. Judging includes implementation, design, impact, and originality. The submission should demonstrate actual Firebase AI Logic use and hybrid behavior; animation should support that evidence. The rules also say the submitted project must function as depicted.

This is why the script gives hybrid behavior its own proof sequence while retaining the grower's story. A fully animated exterior with real application captures inside it meets the creative direction without substituting a concept animation for a working demo.
