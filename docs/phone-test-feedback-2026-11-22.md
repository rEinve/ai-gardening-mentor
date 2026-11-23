# Live Phone Testing Feedback & Action Plan (2026-11-22)

Captured during live Android Wi-Fi testing (Dodoma, raised bed, exposed, full sun).

## Fixed Immediately in This Pass
1. **Removed global floating "Triage" button**: No longer stuck across Home, Planner, and Garden. Plant Diagnosis (camera) is now placed directly inside the **Garden Mentor** chat composer and top bar where it belongs.
2. **Fixed "Prepare Ahead (Next 14 Days)" click bug**: Every upcoming alert row is now tappable and opens an interactive **Preparation Action Sheet** showing exact date, crop, recommended input/dosage per plant, and a **"Mark Prepared / Completed"** button.
3. **Removed "Organic" positioning & toggle**: Tanzania smallholder/home farming uses standard practical inputs (DAP, CAN/Urea, NPK 17:17:17, foliar spray, plus normal manure soil prep). Renamed "Organic Mentor" → **"Garden Mentor"** and removed the Organic/Conventional toggle.
4. **Removed Harvest Quantity Estimation (`Est. kg`) from MVP**: Open-field/exposed beds have too many variables to promise kg yield numbers. Kept **Expected Harvest Date** and **Days Remaining to Harvest** (yield estimation deferred to future Pro/Custom Greenhouse/Drip tier).
5. **Improved Flowering, Fruiting & Harvest Waterfall Interactivity**: Split Flowering and Fruiting steps clearly, made every waterfall milestone tappable for full details, and added a clear **"Set Planting Date"** button on every batch card.

## Next Sprint Backlog (Prioritized)
1. **Google Sign-In & Personal Account Authentication (High Priority)**:
   - Add Google Sign-In + Email/Password account creation at onboarding (replacing anonymous-only flow) so each grower's plots, crop plans, and diagnoses stay private and synced across devices.
2. **Native Android USB Debugging**:
   - Once Android Studio finishes installing, verify `flutter devices` and run native Android debug builds (with live native camera capture for Triage).
3. **Pro / Custom Farm Tier (Future)**:
   - Yield quantity estimation only when full controlled-environment inputs (drip irrigation, spacing, greenhouse/shade-net, soil test) are configured.
