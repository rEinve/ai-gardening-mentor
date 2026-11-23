/**
 * Deterministic curated passage retrieval & safety validation for Grounded Mentor Chat (Phase 3).
 * - Matches approved/fixture knowledgeSources by region, crop, and topic keywords.
 * - Never invents citations; resolves every returned SourceRef against retrieved passages.
 * - Blocks synthetic pesticide / unsafe chemical advice even under prompt injection.
 */

import type { KnowledgeSourceRevision, SourceRef } from '../types/schema.ts';

export interface RetrievedPassage {
  sourceRef: SourceRef;
  publisher: string;
  title: string;
  canonicalUrl: string;
  topic: string;
  summary: string;
}

const TOPIC_KEYWORDS: ReadonlyArray<{ topic: string; pattern: RegExp }> = [
  { topic: 'watering', pattern: /\b(water|watering|wilt|wilting|droop|dry|irrigation|soak)\b/i },
  { topic: 'soil_moisture', pattern: /\b(soil|container|pot|sheltered|drainage|moisture|soggy|wet)\b/i },
  { topic: 'pest_scouting', pattern: /\b(pest|bug|aphid|whitefly|mite|insect|hole|chew|spray|spot)\b/i },
  { topic: 'pruning', pattern: /\b(yellow|yellowing|prune|pruning|lower leaf|leaves|blight|airflow)\b/i },
  { topic: 'harvesting', pattern: /\b(harvest|pick|picking|ripe|pod|ready|cut)\b/i },
];

const UNSAFE_CHAT_PATTERNS: readonly RegExp[] = [
  /\borganophosphate/i,
  /\bcarbofuran\b/i,
  /\bchlorpyrifos\b/i,
  /\bimidacloprid\b/i,
  /\bglyphosate\b/i,
  /\bparaquat\b/i,
  /\bmalathion\b/i,
  /\bddt\b/i,
  /\bbleach\b/i,
  /\bkerosene\b/i,
  /\bgasoline\b/i,
];

export function retrieveApprovedPassages(params: {
  regionCode: string;
  cropProfileIds: readonly string[];
  queryText: string;
  sources: readonly KnowledgeSourceRevision[];
}): RetrievedPassage[] {
  const matchedTopics = new Set<string>();
  for (const { topic, pattern } of TOPIC_KEYWORDS) {
    if (pattern.test(params.queryText)) {
      matchedTopics.add(topic);
    }
  }

  if (matchedTopics.size === 0) {
    return [];
  }

  const results: RetrievedPassage[] = [];
  for (const src of params.sources) {
    if (src.reviewStatus === 'deprecated') continue;
    if (src.region !== params.regionCode) continue;

    const cropMatches =
      params.cropProfileIds.length === 0 ||
      params.cropProfileIds.some((id) => src.crops.includes(id));
    if (!cropMatches) continue;

    for (const passage of src.passages) {
      if (!matchedTopics.has(passage.topic)) continue;
      results.push({
        sourceRef: {
          sourceId: src.sourceId,
          revision: src.revision,
          passageId: passage.passageId,
        },
        publisher: src.publisher,
        title: src.title,
        canonicalUrl: src.canonicalUrl,
        topic: passage.topic,
        summary: passage.summary,
      });
    }
  }

  return results;
}

export function validateChatAnswerSafetyAndCitations(params: {
  content: string;
  sourceRefs: readonly SourceRef[];
  retrievedPassages: readonly RetrievedPassage[];
}): { valid: boolean; reason?: string } {
  if (params.content.trim().length === 0 || params.content.length > 2000) {
    return { valid: false, reason: 'Assistant response length out of bounds (1–2000 chars).' };
  }

  for (const pattern of UNSAFE_CHAT_PATTERNS) {
    if (pattern.test(params.content)) {
      return { valid: false, reason: 'Assistant response contained prohibited chemical/pesticide advice.' };
    }
  }

  const allowedKeys = new Set(
    params.retrievedPassages.map(
      (p) => `${p.sourceRef.sourceId}|${p.sourceRef.revision}|${p.sourceRef.passageId}`,
    ),
  );

  for (const ref of params.sourceRefs) {
    const key = `${ref.sourceId}|${ref.revision}|${ref.passageId}`;
    if (!allowedKeys.has(key)) {
      return { valid: false, reason: `Assistant cited unretrieved or unapproved source: ${key}` };
    }
  }

  return { valid: true };
}
