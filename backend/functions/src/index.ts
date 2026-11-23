/**
 * Firebase Cloud Functions v2 Entry Point (`europe-west1`).
 *
 * Exports all Tanzania MVP endpoints across Phases 1–4:
 * - `initializeGarden` (callable)
 * - `executeMultimodalTriage` (callable, GEMINI_API_KEY secret)
 * - `addRecoveryTask` (callable)
 * - `processMentorChatMessage` (authenticated HTTPS SSE streaming, GEMINI_API_KEY secret)
 * - `archiveChatSession` (callable)
 * - `retireCrop` (callable)
 * - `deleteAccount` (callable)
 * - `dispatchScheduledJobs` (15-min UTC scheduler, OPENWEATHER_API_KEY secret)
 */

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import {
  ConflictError,
  executeInitializeGarden,
  type GardenInitRepository,
} from './functions/initializeGarden.ts';
import {
  executeMultimodalTriage as runMultimodalTriage,
  InvalidModelOutputError,
  QuotaExceededError,
  type TriageRepository,
} from './functions/executeMultimodalTriage.ts';
import {
  executeAddRecoveryTask,
  UnsupportedActionError,
  type RecoveryTaskRepository,
} from './functions/addRecoveryTask.ts';
import {
  archiveChatSession as runArchiveChatSession,
  ForbiddenResourceError,
  processMentorChatMessage as runMentorChatMessage,
  type MentorChatRepository,
} from './functions/processMentorChat.ts';
import {
  executeDeleteAccount,
  executeRetireCrop,
  type RetireCropRepository,
} from './functions/lifecycle.ts';
import { generateSevenDayCadence } from './domain/cadence.ts';
import { evaluateDueJobsForUser } from './domain/scheduler.ts';
import { evaluateWeatherOverrides } from './domain/weatherOverrides.ts';
import { ValidationError } from './validators/garden.ts';
import {
  createGeminiMentorChatProvider,
  createGeminiTriageProvider,
} from './providers/geminiProvider.ts';
import { fetchOpenWeatherForecast } from './providers/openWeatherProvider.ts';
import {
  TANZANIA_CARE_RULES,
  TANZANIA_CROP_PROFILES,
  TANZANIA_KNOWLEDGE_SOURCES,
  TANZANIA_TASK_TEMPLATES,
} from './seeds/tanzaniaFixtures.ts';
import type {
  ChatMessageRecord,
  ChatSessionRecord,
  CropRecord,
  DurableRequestRecord,
  PlotRecord,
  TaskRecord,
  TriageLogRecord,
  UserProfile,
} from './types/schema.ts';

initializeApp();
const db = getFirestore();
const authAdmin = getAuth();
const storage = getStorage();

const REGION = 'europe-west1';
const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
const OPENWEATHER_API_KEY = defineSecret('OPENWEATHER_API_KEY');

function mapDomainError(err: unknown): HttpsError {
  if (err instanceof ValidationError) return new HttpsError('invalid-argument', err.message);
  if (err instanceof ConflictError) return new HttpsError('already-exists', err.message);
  if (err instanceof QuotaExceededError) return new HttpsError('resource-exhausted', err.message);
  if (err instanceof ForbiddenResourceError) return new HttpsError('permission-denied', err.message);
  if (err instanceof UnsupportedActionError || err instanceof InvalidModelOutputError) {
    return new HttpsError('failed-precondition', err.message);
  }
  return new HttpsError('internal', 'Internal server error.');
}

// ---------------------------------------------------------------------------
// 1. initializeGarden (Callable)
// ---------------------------------------------------------------------------
const gardenInitRepo: GardenInitRepository = {
  async getRequest(userId, requestId) {
    const snap = await db.doc(`users/${userId}/requests/${requestId}`).get();
    return snap.exists ? (snap.data() as DurableRequestRecord) : null;
  },
  async getExistingCounts(userId) {
    const [plotsSnap, tasksSnap] = await Promise.all([
      db.collection(`users/${userId}/plots`).get(),
      db.collection(`users/${userId}/tasks`).get(),
    ]);
    let cropCount = 0;
    for (const plotDoc of plotsSnap.docs) {
      const cropsSnap = await plotDoc.ref.collection('crops').get();
      cropCount += cropsSnap.size;
    }
    return { plotCount: plotsSnap.size, cropCount, taskCount: tasksSnap.size };
  },
  async getReferenceData() {
    return {
      cropProfiles: new Map(TANZANIA_CROP_PROFILES.map((c) => [c.id, c])),
      careRules: TANZANIA_CARE_RULES,
      taskTemplates: new Map(TANZANIA_TASK_TEMPLATES.map((t) => [t.id, t])),
    };
  },
  async commitInitialization({ userId, requestRecord, profile, plots, cropsByPlotId, tasks }) {
    const batch = db.batch();
    batch.set(db.doc(`users/${userId}`), profile, { merge: true });
    batch.set(db.doc(`users/${userId}/requests/${requestRecord.requestId}`), requestRecord);
    for (const plot of plots) {
      batch.set(db.doc(`users/${userId}/plots/${plot.plotId}`), plot);
      for (const crop of cropsByPlotId.get(plot.plotId) ?? []) {
        batch.set(db.doc(`users/${userId}/plots/${plot.plotId}/crops/${crop.cropId}`), crop);
      }
    }
    for (const task of tasks) {
      batch.set(db.doc(`users/${userId}/tasks/${task.taskId}`), task);
    }
    await batch.commit();
  },
};

export const initializeGarden = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication required.');
  try {
    return await executeInitializeGarden({
      auth: {
        uid: request.auth.uid,
        email: request.auth.token.email ?? null,
        isAnonymous: request.auth.token.firebase?.sign_in_provider === 'anonymous',
      },
      rawPayload: request.data,
      repo: gardenInitRepo,
    });
  } catch (err) {
    throw mapDomainError(err);
  }
});

// ---------------------------------------------------------------------------
// 2. executeMultimodalTriage (Callable + GEMINI_API_KEY)
// ---------------------------------------------------------------------------
const triageRepo: TriageRepository = {
  async getRequest(userId, requestId) {
    const snap = await db.doc(`users/${userId}/requests/${requestId}`).get();
    return snap.exists ? (snap.data() as DurableRequestRecord) : null;
  },
  async getTriageLog(userId, diagnosisId) {
    const snap = await db.doc(`users/${userId}/triageLogs/${diagnosisId}`).get();
    return snap.exists ? (snap.data() as TriageLogRecord) : null;
  },
  async countDailyTriages(userId, utcDatePrefix) {
    const snap = await db
      .collection(`users/${userId}/triageLogs`)
      .where('createdAt', '>=', `${utcDatePrefix}T00:00:00.000Z`)
      .get();
    return snap.size;
  },
  async getStoredImageMetadata(imageStoragePath) {
    const file = storage.bucket().file(imageStoragePath);
    const [exists] = await file.exists();
    if (!exists) return null;
    const [meta] = await file.getMetadata();
    const [headBuf] = await file.download({ start: 0, end: 2 });
    const hasJpegMagicBytes = headBuf.length >= 2 && headBuf[0] === 0xff && headBuf[1] === 0xd8;
    return {
      contentType: meta.contentType ?? '',
      sizeBytes: Number(meta.size ?? 0),
      widthPx: Number(meta.metadata?.widthPx ?? 1024),
      heightPx: Number(meta.metadata?.heightPx ?? 768),
      hasJpegMagicBytes,
    };
  },
  async getValidPassageKeys() {
    const keys = new Set<string>();
    for (const src of TANZANIA_KNOWLEDGE_SOURCES) {
      for (const p of src.passages) keys.add(`${src.sourceId}|${src.revision}|${p.passageId}`);
    }
    return keys;
  },
  async getValidTemplateIds() {
    return new Set(TANZANIA_TASK_TEMPLATES.map((t) => t.id));
  },
  async saveRequest(userId, req) {
    await db.doc(`users/${userId}/requests/${req.requestId}`).set(req);
  },
  async commitTriageResult(userId, req, log) {
    const batch = db.batch();
    batch.set(db.doc(`users/${userId}/requests/${req.requestId}`), req);
    batch.set(db.doc(`users/${userId}/triageLogs/${log.diagnosisId}`), log);
    await batch.commit();
  },
};

export const executeMultimodalTriage = onCall(
  { region: REGION, secrets: [GEMINI_API_KEY] },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication required.');
    try {
      const provider = createGeminiTriageProvider({
        apiKey: GEMINI_API_KEY.value(),
        downloadImageBase64: async (path) => {
          const [buf] = await storage.bucket().file(path).download();
          return buf.toString('base64');
        },
        defaultSourceRefs: [
          {
            sourceId: 'ewskt_growhow_tropical_veg',
            revision: 'v1-fixture',
            passageId: 'underside_leaf_scout',
          },
        ],
      });
      return await runMultimodalTriage({
        auth: { uid: request.auth.uid },
        rawPayload: request.data,
        repo: triageRepo,
        provider,
      });
    } catch (err) {
      throw mapDomainError(err);
    }
  },
);

// ---------------------------------------------------------------------------
// 3. addRecoveryTask (Callable)
// ---------------------------------------------------------------------------
const recoveryRepo: RecoveryTaskRepository = {
  async getRequest(userId, id) {
    const s = await db.doc(`users/${userId}/requests/${id}`).get();
    return s.exists ? (s.data() as DurableRequestRecord) : null;
  },
  async getTask(userId, id) {
    const s = await db.doc(`users/${userId}/tasks/${id}`).get();
    return s.exists ? (s.data() as TaskRecord) : null;
  },
  async getTriageLog(userId, id) {
    const s = await db.doc(`users/${userId}/triageLogs/${id}`).get();
    return s.exists ? (s.data() as TriageLogRecord) : null;
  },
  async getOwnedCrop(userId, plotId, cropId) {
    const s = await db.doc(`users/${userId}/plots/${plotId}/crops/${cropId}`).get();
    return s.exists ? (s.data() as CropRecord) : null;
  },
  async getUserTimeZone(userId) {
    const s = await db.doc(`users/${userId}`).get();
    return (s.data() as UserProfile | undefined)?.timeZone ?? 'Africa/Dar_es_Salaam';
  },
  async getTaskTemplate(id) {
    return TANZANIA_TASK_TEMPLATES.find((t) => t.id === id) ?? null;
  },
  async commitRecoveryTask(userId, req, task) {
    const batch = db.batch();
    batch.set(db.doc(`users/${userId}/requests/${req.requestId}`), req);
    batch.set(db.doc(`users/${userId}/tasks/${task.taskId}`), task);
    await batch.commit();
  },
};

export const addRecoveryTask = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication required.');
  try {
    return await executeAddRecoveryTask({
      auth: { uid: request.auth.uid },
      rawPayload: request.data,
      repo: recoveryRepo,
    });
  } catch (err) {
    throw mapDomainError(err);
  }
});

// ---------------------------------------------------------------------------
// 4. processMentorChatMessage (Authenticated HTTPS SSE) & archiveChatSession
// ---------------------------------------------------------------------------
const chatRepo: MentorChatRepository = {
  async getRequest(userId, id) {
    const s = await db.doc(`users/${userId}/requests/${id}`).get();
    return s.exists ? (s.data() as DurableRequestRecord) : null;
  },
  async getMessage(userId, sessionId, messageId) {
    const s = await db.doc(`users/${userId}/chatSessions/${sessionId}/messages/${messageId}`).get();
    return s.exists ? (s.data() as ChatMessageRecord) : null;
  },
  async getSession(userId, sessionId) {
    const s = await db.doc(`users/${userId}/chatSessions/${sessionId}`).get();
    return s.exists ? (s.data() as ChatSessionRecord) : null;
  },
  async getUserProfile(userId) {
    const s = await db.doc(`users/${userId}`).get();
    return s.exists ? (s.data() as UserProfile) : null;
  },
  async getOwnedPlot(userId, plotId) {
    const s = await db.doc(`users/${userId}/plots/${plotId}`).get();
    return s.exists ? (s.data() as PlotRecord) : null;
  },
  async getActiveCrops(userId, plotId) {
    if (plotId) {
      const snap = await db
        .collection(`users/${userId}/plots/${plotId}/crops`)
        .where('lifecycleStatus', '==', 'active')
        .get();
      return snap.docs.map((d) => d.data() as CropRecord);
    }
    const plotsSnap = await db.collection(`users/${userId}/plots`).get();
    const crops: CropRecord[] = [];
    for (const p of plotsSnap.docs) {
      const cSnap = await p.ref.collection('crops').where('lifecycleStatus', '==', 'active').get();
      crops.push(...cSnap.docs.map((d) => d.data() as CropRecord));
    }
    return crops;
  },
  async getOwnedDiagnosis(userId, diagnosisId) {
    const s = await db.doc(`users/${userId}/triageLogs/${diagnosisId}`).get();
    return s.exists ? (s.data() as TriageLogRecord) : null;
  },
  async getKnowledgeSources() {
    return TANZANIA_KNOWLEDGE_SOURCES;
  },
  async commitChatTurn({ userId, requestRecord, session, userMessage, assistantMessage }) {
    const batch = db.batch();
    batch.set(db.doc(`users/${userId}/requests/${requestRecord.requestId}`), requestRecord);
    batch.set(db.doc(`users/${userId}/chatSessions/${session.sessionId}`), session, { merge: true });
    batch.set(
      db.doc(`users/${userId}/chatSessions/${session.sessionId}/messages/${userMessage.messageId}`),
      userMessage,
    );
    batch.set(
      db.doc(`users/${userId}/chatSessions/${session.sessionId}/messages/${assistantMessage.messageId}`),
      assistantMessage,
    );
    await batch.commit();
  },
  async archiveSession(userId, req, sessionId, archivedAt) {
    const ref = db.doc(`users/${userId}/chatSessions/${sessionId}`);
    const batch = db.batch();
    batch.set(db.doc(`users/${userId}/requests/${req.requestId}`), req);
    batch.set(ref, { archivedAt }, { merge: true });
    await batch.commit();
    const snap = await ref.get();
    return snap.data() as ChatSessionRecord;
  },
};

export const processMentorChatMessage = onRequest(
  { region: REGION, secrets: [GEMINI_API_KEY], cors: true },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }

    const authHeader = req.headers.authorization ?? '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
    if (!token) {
      res.status(401).json({ error: 'Missing Bearer ID token.' });
      return;
    }

    let uid: string;
    try {
      const decoded = await authAdmin.verifyIdToken(token);
      uid = decoded.uid;
    } catch {
      res.status(401).json({ error: 'Invalid authentication token.' });
      return;
    }

    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const provider = createGeminiMentorChatProvider({ apiKey: GEMINI_API_KEY.value() });
    try {
      await runMentorChatMessage({
        auth: { uid },
        rawPayload: req.body,
        repo: chatRepo,
        provider,
        emitSse: (ev) => {
          res.write(`event: ${ev.event}\ndata: ${JSON.stringify(ev.data)}\n\n`);
        },
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Chat processing error.';
      res.write(`event: error\ndata: ${JSON.stringify({ code: 'CHAT_ERROR', message, retryable: true })}\n\n`);
    } finally {
      res.end();
    }
  },
);

export const archiveChatSession = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication required.');
  const { requestId, sessionId } = (request.data ?? {}) as { requestId?: string; sessionId?: string };
  try {
    return await runArchiveChatSession({
      auth: { uid: request.auth.uid },
      requestId: requestId ?? '',
      sessionId: sessionId ?? '',
      repo: chatRepo,
    });
  } catch (err) {
    throw mapDomainError(err);
  }
});

// ---------------------------------------------------------------------------
// 5. retireCrop & deleteAccount (Callables)
// ---------------------------------------------------------------------------
const retireRepo: RetireCropRepository = {
  async getRequest(userId, id) {
    const s = await db.doc(`users/${userId}/requests/${id}`).get();
    return s.exists ? (s.data() as DurableRequestRecord) : null;
  },
  async getOwnedCrop(userId, plotId, cropId) {
    const s = await db.doc(`users/${userId}/plots/${plotId}/crops/${cropId}`).get();
    return s.exists ? (s.data() as CropRecord) : null;
  },
  async getUserTimeZone(userId) {
    const s = await db.doc(`users/${userId}`).get();
    return (s.data() as UserProfile | undefined)?.timeZone ?? 'Africa/Dar_es_Salaam';
  },
  async getFuturePendingTasksForCrop(userId, cropId, fromLocalDate) {
    const snap = await db
      .collection(`users/${userId}/tasks`)
      .where('cropId', '==', cropId)
      .where('scheduledDate', '>=', fromLocalDate)
      .get();
    return snap.docs.map((d) => d.data() as TaskRecord).filter((t) => t.scheduleStatus === 'pending');
  },
  async commitRetirement({ userId, requestRecord, plotId, retiredCrop, cancelledTasks }) {
    const batch = db.batch();
    batch.set(db.doc(`users/${userId}/requests/${requestRecord.requestId}`), requestRecord);
    batch.set(db.doc(`users/${userId}/plots/${plotId}/crops/${retiredCrop.cropId}`), retiredCrop);
    for (const task of cancelledTasks) {
      batch.set(db.doc(`users/${userId}/tasks/${task.taskId}`), task);
    }
    await batch.commit();
  },
};

export const retireCrop = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication required.');
  const { requestId, plotId, cropId } = (request.data ?? {}) as {
    requestId?: string;
    plotId?: string;
    cropId?: string;
  };
  try {
    return await executeRetireCrop({
      auth: { uid: request.auth.uid },
      requestId: requestId ?? '',
      plotId: plotId ?? '',
      cropId: cropId ?? '',
      repo: retireRepo,
    });
  } catch (err) {
    throw mapDomainError(err);
  }
});

export const deleteAccount = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication required.');
  const { explicitConfirmation } = (request.data ?? {}) as { explicitConfirmation?: boolean };
  try {
    return await executeDeleteAccount({
      auth: { uid: request.auth.uid },
      explicitConfirmation: Boolean(explicitConfirmation),
      adapter: {
        async deleteUserDiagnosticImages(uid) {
          const [files] = await storage.bucket().getFiles({ prefix: `users/${uid}/diagnostics/` });
          await Promise.all(files.map((f) => f.delete({ ignoreNotFound: true })));
          return { deletedFiles: files.length };
        },
        async deleteUserFirestoreTree(uid) {
          await db.recursiveDelete(db.doc(`users/${uid}`));
          return { deletedDocuments: 1 };
        },
        async deleteAuthIdentity(uid) {
          await authAdmin.deleteUser(uid);
        },
      },
    });
  } catch (err) {
    throw mapDomainError(err);
  }
});

// ---------------------------------------------------------------------------
// 6. 15-minute UTC Scheduled Dispatcher (daily_cadence + weather_override)
// ---------------------------------------------------------------------------
export const dispatchScheduledJobs = onSchedule(
  { schedule: 'every 15 minutes', region: REGION, secrets: [OPENWEATHER_API_KEY] },
  async () => {
    const now = new Date();
    const nowIso = now.toISOString();
    const usersSnap = await db.collection('users').get();
    const cropProfileMap = new Map(TANZANIA_CROP_PROFILES.map((c) => [c.id, c]));
    const templateMap = new Map(TANZANIA_TASK_TEMPLATES.map((t) => [t.id, t]));

    for (const userDoc of usersSnap.docs) {
      const profile = userDoc.data() as UserProfile;
      const uid = userDoc.id;

      const jobsSnap = await db.collection(`users/${uid}/jobRuns`).where('state', '==', 'succeeded').get();
      const completedKeys = new Set(jobsSnap.docs.map((d) => d.id));

      const dueJobs = evaluateDueJobsForUser({
        timeZone: profile.timeZone || 'Africa/Dar_es_Salaam',
        now,
        completedJobKeys: completedKeys,
      });
      if (dueJobs.length === 0) continue;

      const [plotsSnap, completionsSnap] = await Promise.all([
        db.collection(`users/${uid}/plots`).get(),
        db.collection(`users/${uid}/taskCompletions`).get(),
      ]);
      const plots = plotsSnap.docs.map((d) => d.data() as PlotRecord);
      const plotsById = new Map(plots.map((p) => [p.plotId, p]));
      const completedTaskIds = new Set(completionsSnap.docs.map((d) => String(d.data().taskId)));

      const cropsByPlotId = new Map<string, CropRecord[]>();
      const activeCrops: CropRecord[] = [];
      const cropPlotMap = new Map<string, string>();
      for (const plot of plots) {
        const cSnap = await db.collection(`users/${uid}/plots/${plot.plotId}/crops`).get();
        const crops = cSnap.docs.map((d) => d.data() as CropRecord);
        cropsByPlotId.set(plot.plotId, crops);
        for (const c of crops) {
          if (c.lifecycleStatus === 'active') {
            activeCrops.push(c);
            cropPlotMap.set(c.cropId, plot.plotId);
          }
        }
      }

      for (const job of dueJobs) {
        const batch = db.batch();
        if (job.kind === 'daily_cadence') {
          const tasks = generateSevenDayCadence({
            userId: uid,
            regionCode: profile.geographicLocation.countryCode,
            timeZone: job.timeZone,
            startLocalDate: job.localDate,
            nowIso,
            plots,
            cropsByPlotId,
            cropProfiles: cropProfileMap,
            careRules: TANZANIA_CARE_RULES,
            taskTemplates: templateMap,
            completedTaskIds,
          });
          for (const task of tasks) {
            batch.set(db.doc(`users/${uid}/tasks/${task.taskId}`), task, { merge: true });
          }
        } else {
          const existingSnap = await db
            .collection(`users/${uid}/tasks`)
            .where('scheduledDate', '==', job.localDate)
            .get();
          const forecast = await fetchOpenWeatherForecast({
            apiKey: OPENWEATHER_API_KEY.value(),
            latitude: profile.geographicLocation.latitude,
            longitude: profile.geographicLocation.longitude,
            now,
          });
          const override = evaluateWeatherOverrides({
            userId: uid,
            localDate: job.localDate,
            timeZone: job.timeZone,
            nowIso,
            forecast,
            plotsById,
            activeCrops,
            cropPlotMap,
            existingTasksForDate: existingSnap.docs.map((d) => d.data() as TaskRecord),
            completedTaskIds,
          });
          for (const t of [...override.updatedTasks, ...override.insertedProtectionTasks]) {
            batch.set(db.doc(`users/${uid}/tasks/${t.taskId}`), t, { merge: true });
          }
        }

        batch.set(db.doc(`users/${uid}/jobRuns/${job.jobKey}`), {
          kind: job.kind,
          localDate: job.localDate,
          timeZone: job.timeZone,
          state: 'succeeded',
          attemptCount: 1,
          leaseExpiresAt: null,
          completedAt: nowIso,
        });
        await batch.commit();
      }
    }
  },
);
