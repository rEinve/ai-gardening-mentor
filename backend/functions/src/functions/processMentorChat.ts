/**
 * Phase 3 Grounded Mentor Chat (`processMentorChatMessage`) & `archiveChatSession`.
 *
 * Enforces:
 * - Single authenticated streaming HTTPS endpoint (no duplicate Firestore trigger).
 * - Server-assembled authorized garden context snapshot on every turn.
 * - Verifies ownership of optional `plotId` and `diagnosisId` (rejects forged IDs).
 * - Emits provisional SSE `delta` events; durable request + finalized messages are authoritative.
 * - Retries/disconnects with same `requestId` replay the finalized message without duplicating turns.
 * - Returns `insufficient_evidence` (with zero invented citations) when no approved passages match.
 */

import type {
  ChatMessageRecord,
  ChatSessionRecord,
  CropRecord,
  DurableRequestRecord,
  GardenContextSnapshot,
  KnowledgeSourceRevision,
  PlotRecord,
  SourceRef,
  SseEvent,
  TriageLogRecord,
  UserProfile,
} from '../types/schema.ts';
import { computeInputHash } from '../domain/identity.ts';
import {
  retrieveApprovedPassages,
  validateChatAnswerSafetyAndCitations,
  type RetrievedPassage,
} from '../domain/retrieval.ts';
import { LIMITS, ValidationError } from '../validators/garden.ts';
import { ConflictError } from './initializeGarden.ts';

const ID_REGEX = /^[a-zA-Z0-9_-]{8,64}$/;

export class ForbiddenResourceError extends Error {
  public readonly code = 'PERMISSION_DENIED';
  constructor(message: string) {
    super(message);
    this.name = 'ForbiddenResourceError';
  }
}

export interface ProcessMentorChatInput {
  requestId: string;
  sessionId: string;
  messageId: string;
  text: string;
  plotId: string | null;
  diagnosisId: string | null;
}

export function validateMentorChatInput(raw: unknown): ProcessMentorChatInput {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    throw new ValidationError('Chat payload must be an object.');
  }
  const obj = raw as Record<string, unknown>;
  const allowed = new Set(['requestId', 'sessionId', 'messageId', 'text', 'plotId', 'diagnosisId']);
  for (const key of Object.keys(obj)) {
    if (!allowed.has(key)) {
      throw new ValidationError(`Unexpected field "${key}" in processMentorChatMessage.`);
    }
  }
  for (const idField of ['requestId', 'sessionId', 'messageId'] as const) {
    if (typeof obj[idField] !== 'string' || !ID_REGEX.test(obj[idField] as string)) {
      throw new ValidationError(`Invalid ${idField}.`);
    }
  }
  if (typeof obj.text !== 'string' || obj.text.trim().length === 0 || obj.text.length > LIMITS.CHAT_TEXT_MAX) {
    throw new ValidationError(`text must be 1–${LIMITS.CHAT_TEXT_MAX} characters.`);
  }
  if (obj.plotId !== null && (typeof obj.plotId !== 'string' || !ID_REGEX.test(obj.plotId))) {
    throw new ValidationError('Invalid plotId.');
  }
  if (obj.diagnosisId !== null && (typeof obj.diagnosisId !== 'string' || !ID_REGEX.test(obj.diagnosisId))) {
    throw new ValidationError('Invalid diagnosisId.');
  }
  return {
    requestId: obj.requestId as string,
    sessionId: obj.sessionId as string,
    messageId: obj.messageId as string,
    text: obj.text.trim(),
    plotId: obj.plotId as string | null,
    diagnosisId: obj.diagnosisId as string | null,
  };
}

export interface MentorChatProvider {
  streamGroundedAnswer(params: {
    userText: string;
    context: GardenContextSnapshot;
    passages: readonly RetrievedPassage[];
    onDelta: (chunk: string) => void;
  }): Promise<{ content: string; sourceRefs: SourceRef[] }>;
}

export interface MentorChatRepository {
  getRequest(userId: string, requestId: string): Promise<DurableRequestRecord | null>;
  getMessage(userId: string, sessionId: string, messageId: string): Promise<ChatMessageRecord | null>;
  getSession(userId: string, sessionId: string): Promise<ChatSessionRecord | null>;
  getUserProfile(userId: string): Promise<UserProfile | null>;
  getOwnedPlot(userId: string, plotId: string): Promise<PlotRecord | null>;
  getActiveCrops(userId: string, plotId: string | null): Promise<CropRecord[]>;
  getOwnedDiagnosis(userId: string, diagnosisId: string): Promise<TriageLogRecord | null>;
  getKnowledgeSources(): Promise<KnowledgeSourceRevision[]>;
  commitChatTurn(params: {
    userId: string;
    requestRecord: DurableRequestRecord;
    session: ChatSessionRecord;
    userMessage: ChatMessageRecord;
    assistantMessage: ChatMessageRecord;
  }): Promise<void>;
  archiveSession(userId: string, requestRecord: DurableRequestRecord, sessionId: string, archivedAt: string): Promise<ChatSessionRecord>;
}

export interface ProcessMentorChatResult {
  requestId: string;
  sessionId: string;
  assistantMessage: ChatMessageRecord;
  idempotentReplay: boolean;
}

export async function processMentorChatMessage(params: {
  auth: { uid: string };
  rawPayload: unknown;
  repo: MentorChatRepository;
  provider: MentorChatProvider;
  emitSse?: (event: SseEvent) => void;
  now?: Date;
}): Promise<ProcessMentorChatResult> {
  const now = params.now ?? new Date();
  const nowIso = now.toISOString();
  const emit = params.emitSse ?? (() => {});
  const input = validateMentorChatInput(params.rawPayload);

  const inputHash = computeInputHash({
    sessionId: input.sessionId,
    messageId: input.messageId,
    text: input.text,
    plotId: input.plotId,
    diagnosisId: input.diagnosisId,
  });

  // 1. Idempotency & conflict check
  const existingReq = await params.repo.getRequest(params.auth.uid, input.requestId);
  if (existingReq) {
    if (existingReq.inputHash !== inputHash) {
      throw new ConflictError(`Request ID "${input.requestId}" already used with different chat input.`);
    }
    if (existingReq.state === 'succeeded' && existingReq.resultId) {
      const existingAssistant = await params.repo.getMessage(
        params.auth.uid,
        input.sessionId,
        existingReq.resultId,
      );
      if (existingAssistant) {
        emit({
          event: 'done',
          data: {
            messageId: existingAssistant.messageId,
            validationStatus: existingAssistant.validationStatus ?? 'passed',
            sourceRefs: existingAssistant.sourceRefs,
          },
        });
        return {
          requestId: input.requestId,
          sessionId: input.sessionId,
          assistantMessage: existingAssistant,
          idempotentReplay: true,
        };
      }
    }
  }

  // 2. Assemble authorized garden context (verifying plot & diagnosis ownership)
  const profile = await params.repo.getUserProfile(params.auth.uid);
  if (!profile) {
    throw new ForbiddenResourceError('User profile not initialized.');
  }

  let activePlot: PlotRecord | null = null;
  if (input.plotId) {
    activePlot = await params.repo.getOwnedPlot(params.auth.uid, input.plotId);
    if (!activePlot) {
      throw new ForbiddenResourceError('Referenced plot does not belong to the authenticated user.');
    }
  }

  let diagnosis: TriageLogRecord | null = null;
  if (input.diagnosisId) {
    diagnosis = await params.repo.getOwnedDiagnosis(params.auth.uid, input.diagnosisId);
    if (!diagnosis) {
      throw new ForbiddenResourceError('Referenced diagnosis does not belong to the authenticated user.');
    }
  }

  const crops = await params.repo.getActiveCrops(params.auth.uid, activePlot?.plotId ?? null);
  const contextSnapshot: GardenContextSnapshot = {
    asOf: nowIso,
    regionCode: profile.geographicLocation.countryCode,
    regionName: profile.geographicLocation.regionName,
    activePlotId: activePlot?.plotId ?? null,
    activePlotName: activePlot?.name ?? null,
    crops: crops
      .filter((c) => c.lifecycleStatus === 'active')
      .map((c) => ({
        cropId: c.cropId,
        cropProfileId: c.cropProfileId,
        commonName: c.commonName,
        currentGrowthStage: c.currentGrowthStage,
        healthStatus: c.healthStatus,
      })),
    diagnosisSummary: diagnosis
      ? {
          diagnosisId: diagnosis.diagnosisId,
          assessmentStatus: diagnosis.assessmentStatus,
          whatItIs: diagnosis.triageCard.whatItIs,
        }
      : null,
  };

  // 3. Retrieve applicable approved passages
  const sources = await params.repo.getKnowledgeSources();
  const retrieved = retrieveApprovedPassages({
    regionCode: contextSnapshot.regionCode,
    cropProfileIds: contextSnapshot.crops.map((c) => c.cropProfileId),
    queryText: input.text,
    sources,
  });

  const assistantMessageId = `asst_${input.messageId}`;
  let finalContent: string;
  let finalSourceRefs: SourceRef[];
  let validationStatus: 'passed' | 'insufficient_evidence';

  if (retrieved.length === 0) {
    // Explicit insufficient-evidence path — never invent a citation
    finalContent =
      `I do not have reviewed horticultural evidence for this specific question in ${contextSnapshot.regionName} (${contextSnapshot.regionCode}). ` +
      'Please share which crop and visible symptoms you are seeing, or consult your local agricultural extension officer before applying any treatment.';
    finalSourceRefs = [];
    validationStatus = 'insufficient_evidence';
    emit({ event: 'delta', data: { text: finalContent } });
  } else {
    const candidate = await params.provider.streamGroundedAnswer({
      userText: input.text,
      context: contextSnapshot,
      passages: retrieved,
      onDelta: (chunk) => emit({ event: 'delta', data: { text: chunk } }),
    });

    const safetyCheck = validateChatAnswerSafetyAndCitations({
      content: candidate.content,
      sourceRefs: candidate.sourceRefs,
      retrievedPassages: retrieved,
    });

    if (!safetyCheck.valid) {
      emit({
        event: 'error',
        data: { code: 'UNSAFE_OR_UNGROUNDED_OUTPUT', message: safetyCheck.reason ?? 'Invalid output', retryable: true },
      });
      throw new ValidationError(`Assistant output rejected: ${safetyCheck.reason}`);
    }

    finalContent = candidate.content;
    finalSourceRefs = [...candidate.sourceRefs];
    validationStatus = 'passed';
  }

  const existingSession = await params.repo.getSession(params.auth.uid, input.sessionId);
  const session: ChatSessionRecord = existingSession
    ? { ...existingSession, lastMessageAt: nowIso }
    : {
        sessionId: input.sessionId,
        title: input.text.slice(0, 50),
        activePlotId: contextSnapshot.activePlotId,
        diagnosisId: input.diagnosisId,
        archivedAt: null,
        createdAt: nowIso,
        lastMessageAt: nowIso,
      };

  const userMessage: ChatMessageRecord = {
    messageId: input.messageId,
    requestId: input.requestId,
    senderRole: 'user',
    content: input.text,
    sourceRefs: [],
    contextSnapshot: null,
    validationStatus: null,
    createdAt: nowIso,
  };

  const assistantMessage: ChatMessageRecord = {
    messageId: assistantMessageId,
    requestId: input.requestId,
    senderRole: 'assistant',
    content: finalContent,
    sourceRefs: finalSourceRefs,
    contextSnapshot,
    validationStatus,
    createdAt: nowIso,
  };

  const requestRecord: DurableRequestRecord = {
    requestId: input.requestId,
    kind: 'processMentorChatMessage',
    inputHash,
    state: 'succeeded',
    attemptCount: (existingReq?.attemptCount ?? 0) + 1,
    leaseExpiresAt: null,
    resultId: assistantMessage.messageId,
    errorCode: null,
    retryable: false,
    createdAt: existingReq?.createdAt ?? nowIso,
    updatedAt: nowIso,
  };

  await params.repo.commitChatTurn({
    userId: params.auth.uid,
    requestRecord,
    session,
    userMessage,
    assistantMessage,
  });

  emit({
    event: 'done',
    data: {
      messageId: assistantMessage.messageId,
      validationStatus,
      sourceRefs: finalSourceRefs,
    },
  });

  return {
    requestId: input.requestId,
    sessionId: input.sessionId,
    assistantMessage,
    idempotentReplay: false,
  };
}

export async function archiveChatSession(params: {
  auth: { uid: string };
  requestId: string;
  sessionId: string;
  repo: MentorChatRepository;
  now?: Date;
}): Promise<{ session: ChatSessionRecord; archivedNote: string }> {
  if (!ID_REGEX.test(params.requestId) || !ID_REGEX.test(params.sessionId)) {
    throw new ValidationError('Invalid requestId or sessionId.');
  }

  const session = await params.repo.getSession(params.auth.uid, params.sessionId);
  if (!session) {
    throw new ForbiddenResourceError('Chat session not found for authenticated user.');
  }

  const nowIso = (params.now ?? new Date()).toISOString();
  const archivedAt = session.archivedAt ?? nowIso;
  const req: DurableRequestRecord = {
    requestId: params.requestId,
    kind: 'archiveChatSession',
    inputHash: computeInputHash({ sessionId: params.sessionId }),
    state: 'succeeded',
    attemptCount: 1,
    leaseExpiresAt: null,
    resultId: params.sessionId,
    errorCode: null,
    retryable: false,
    createdAt: nowIso,
    updatedAt: nowIso,
  };

  const updated = await params.repo.archiveSession(params.auth.uid, req, params.sessionId, archivedAt);
  return {
    session: updated,
    archivedNote: 'Session hidden from active history. Messages are retained until account deletion.',
  };
}
