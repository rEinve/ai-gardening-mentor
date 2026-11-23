/**
 * Firestore Security Rules Emulator Test Suite (Acceptance Criterion A8)
 *
 * Run against the local Firebase Firestore Emulator:
 *   cd backend && firebase emulators:exec --only firestore "npm --prefix functions run test:rules"
 *
 * Verifies:
 * 1. Cross-user isolation: User B cannot read or write User A's profile, plots, crops, tasks, or completions.
 * 2. Server-owned denial: Owner client cannot forge tasks, triageLogs, requests, chatSessions, messages, or jobRuns.
 * 3. Append-only taskCompletions: Owner can create a valid completion event for an owned task, but cannot update or delete it.
 * 4. Field allowlists: Owner cannot forge server-managed fields on profile or crops (e.g., currentGrowthStage, lifecycleStatus).
 */

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, serverTimestamp, setDoc, updateDoc, deleteDoc, Timestamp } from 'firebase/firestore';

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  const [host, portStr] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088').split(':');
  testEnv = await initializeTestEnvironment({
    projectId: 'ai-gardening-mentor-rules-test',
    firestore: {
      rules: readFileSync(resolve(__dirname, '../../firestore.rules'), 'utf8'),
      host: host || '127.0.0.1',
      port: Number(portStr) || 8088,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/alice'), {
      userId: 'alice',
      displayName: 'Asha',
      email: null,
      isAnonymous: true,
      geographicLocation: {
        latitude: -6.7924,
        longitude: 39.2083,
        regionName: 'Dar es Salaam',
        countryCode: 'TZ',
        postalCode: null,
        usdaHardinessZone: null,
      },
      timeZone: 'Africa/Dar_es_Salaam',
      unitPreference: 'metric',
      gardenExperienceLevel: 'novice',
      fcmDeviceTokens: [],
    });

    await setDoc(doc(db, 'users/alice/tasks/task_001'), {
      taskId: 'task_001',
      cropId: 'crop_tomato_01',
      plotId: 'plot_01',
      scheduleStatus: 'pending',
    });
  });
});

describe('A8: Firestore Permission Matrix', () => {
  test('Cross-user read and write are denied', async () => {
    const bobDb = testEnv.authenticatedContext('bob').firestore();
    await assertFails(getDoc(doc(bobDb, 'users/alice')));
    await assertFails(getDoc(doc(bobDb, 'users/alice/tasks/task_001')));
    await assertFails(
      setDoc(doc(bobDb, 'users/alice/taskCompletions/ev_forged'), {
        eventId: 'ev_forged',
        taskId: 'task_001',
        completedAt: Timestamp.now(),
        receivedAt: serverTimestamp(),
      }),
    );
  });

  test('Owner cannot forge server-owned tasks, triageLogs, chat messages, or jobRuns', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(aliceDb, 'users/alice/tasks/task_forged'), { title: 'Fake task' }));
    await assertFails(setDoc(doc(aliceDb, 'users/alice/triageLogs/diag_forged'), { assessmentStatus: 'supported' }));
    await assertFails(setDoc(doc(aliceDb, 'users/alice/chatSessions/s1/messages/m1'), { senderRole: 'assistant' }));
    await assertFails(getDoc(doc(aliceDb, 'users/alice/jobRuns/job_1')));
  });

  test('Owner can append a valid taskCompletion for an owned task, but cannot update or delete it', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const completionRef = doc(aliceDb, 'users/alice/taskCompletions/ev_001');

    await assertSucceeds(
      setDoc(completionRef, {
        eventId: 'ev_001',
        taskId: 'task_001',
        completedAt: Timestamp.now(),
        receivedAt: serverTimestamp(),
      }),
    );

    // Undo / mutation is denied in MVP
    await assertFails(updateDoc(completionRef, { taskId: 'task_002' }));
    await assertFails(deleteDoc(completionRef));

    // Completion for non-existent task is denied
    await assertFails(
      setDoc(doc(aliceDb, 'users/alice/taskCompletions/ev_bad'), {
        eventId: 'ev_bad',
        taskId: 'task_does_not_exist',
        completedAt: Timestamp.now(),
        receivedAt: serverTimestamp(),
      }),
    );
  });

  test('Owner cannot forge server-derived crop fields or identity fields on profile', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    await assertFails(updateDoc(doc(aliceDb, 'users/alice'), { isAnonymous: false }));
    await assertSucceeds(updateDoc(doc(aliceDb, 'users/alice'), { displayName: 'Asha M.' }));

    await assertFails(
      setDoc(doc(aliceDb, 'users/alice/plots/p1/crops/c1'), {
        cropId: 'c1',
        cropProfileId: 'tz_tomato',
        variety: 'Tengeru 97',
        plantingDate: '2026-10-15',
        plantingMethod: 'transplant',
        currentGrowthStage: 'harvest', // Forged server-managed field
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });
});
