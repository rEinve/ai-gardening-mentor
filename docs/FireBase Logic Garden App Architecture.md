# Firebase Logic Garden App: MVP Architecture

Aligned application baseline — 2026-11-21. This describes planned behavior, not implemented functionality. Website and landing-page specifications are outside this baseline.

## Product purpose

Help novice vegetable gardeners avoid panic-driven interventions, maintain manageable care routines, and get consistent advice suited to their garden.

## Three core loops

| Loop | On device | Backend and cloud AI |
| --- | --- | --- |
| Camera diagnostic and panic triage | Capture or select a photo; validate quality; compress; queue offline uploads; display saved results. | Analyze an authorized image and return What It Is, Immediate Action, and What Not to Worry About, including uncertainty when identification is insufficient. |
| Seven-day care cadence | Cache tasks and instructions; record completion offline; show synchronization state. | Generate tasks from reviewed crop rules, planting information, and weather; reconcile completed actions without losing them to automation. |
| Grounded mentor chat | Display conversation history, garden context, and source references; retain offline drafts. | Retrieve approved horticultural material, inject current garden context, generate and validate a concise response, and store its sources. |

Offline use includes cached tasks, completion recording, image capture, and reviewing saved advice. Fresh diagnosis and fresh chat answers require connectivity. No on-device diagnostic model is included.

## Responsibilities

- Client: presentation, native camera access, local image-quality checks, persistent cache and pending operations.
- Firebase Auth: anonymous identity and optional permanent account linking.
- Firestore: user-owned garden records, task plans and completion events, request states, diagnoses, and conversations.
- Storage: private diagnostic images with a 30-day retention policy.
- Cloud Functions: authorization, validation, idempotent jobs, scheduling, weather integration, source retrieval, and AI calls.
- Gemini through a verified server integration: candidate diagnoses and answers. The backend validates output before delivery.
- Reviewed reference content: supported crops, regional care rules, and citable extension material. These datasets remain to be supplied.

## Document authority

| Document | Owns |
| --- | --- |
| [Product requirements](produc-requirement-document.md) | Scope, user outcomes, and acceptance criteria. |
| [Technical requirements](tech-requirement-document.md) | Processing, endpoints, synchronization, and operational contracts. |
| [Schema](schema.md) | Paths, fields, write ownership, lifecycle, and query contracts. |
| [Application flow](app-_flow.md) | Screens, actions, and visible states. |
| [Implementation plan](implementation-plan.md) | Delivery sequence, verification, and unresolved dependencies. |

Use these owners instead of copying competing contracts into other documents. Changes to an owned contract must update its dependent flows and acceptance checks together.

## Decisions still required

Choose the native client framework, launch region, supported crop list, reviewed content owner, and service deployment region before production scaffolding. Confirm current SDK/runtime/model compatibility through an integration spike. The three-loop scope does not depend on choosing these prematurely.
