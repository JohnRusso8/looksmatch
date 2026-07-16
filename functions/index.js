const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {GoogleGenerativeAI} = require('@google/generative-ai');

initializeApp();

const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');

// Verify this against Google's current model list before deploying —
// Gemini model names change over time.
const MODEL_NAME = 'gemini-flash-lite-latest';

// Bump this and re-run the demographic bias audit before trusting a higher
// value in production. More samples = steadier scores, at proportional
// Gemini cost.
const SAMPLES_PER_PHOTO = 1;

const SCORING_VERSION = 'v1-gemini-flash-lite';
const MAX_PHOTO_BYTES = 10 * 1024 * 1024;

const REJECTION_REASONS = [
  'none',
  'no_face_detected',
  'multiple_faces',
  'face_obscured',
  'low_quality',
  'inappropriate_content',
];

const SCORE_SCHEMA = {
  type: 'object',
  properties: {
    valid: {type: 'boolean'},
    rejectionReason: {type: 'string', enum: REJECTION_REASONS},
    score: {type: 'integer'},
    confidence: {type: 'number'},
  },
  required: ['valid', 'rejectionReason', 'score', 'confidence'],
};

const RUBRIC_PROMPT = `
You are scoring a single standardized photo submitted to a dating app's
photo-compatibility feature. Follow these steps exactly.

STEP 1 — VALIDATE
Reject the photo (valid=false) if any of these are true:
- No clear human face is visible.
- More than one face is in the frame.
- The face is substantially obscured (sunglasses, mask, heavy filter, a hat
  shadowing the eyes).
- The image is too dark, blurry, or low-resolution to assess clearly.
- The image contains nudity or otherwise violates a general content policy.
If rejecting, set rejectionReason to the single best-matching reason, set
score to 0, and set confidence to 0.

STEP 2 — SCORE (only if valid)
Score the photo from 1 to 100 based only on: facial symmetry and
proportion, photo clarity, lighting and composition, and expression. Apply
the exact same standard to every photo regardless of the person's race,
ethnicity, skin tone, gender, or age — none of those attributes should
raise or lower the score. Set rejectionReason to "none".

STEP 3 — CONFIDENCE
Set confidence (0 to 1) to how certain you are in the score itself, not in
whether a face was detected.

Return only the structured JSON described by the response schema.
`.trim();

function median(numbers) {
  const sorted = [...numbers].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[mid - 1] + sorted[mid]) / 2
    : sorted[mid];
}

function scoreToBand(score) {
  if (score >= 90) return 5;
  if (score >= 75) return 4;
  if (score >= 60) return 3;
  if (score >= 40) return 2;
  return 1;
}

async function scoreOnce(model, imagePart) {
  const result = await model.generateContent([RUBRIC_PROMPT, imagePart]);
  const parsed = JSON.parse(result.response.text());

  if (
    typeof parsed.valid !== 'boolean' ||
    !REJECTION_REASONS.includes(parsed.rejectionReason) ||
    typeof parsed.score !== 'number' ||
    typeof parsed.confidence !== 'number'
  ) {
    throw new Error('Gemini returned a malformed scoring response.');
  }

  return parsed;
}

exports.scorePhoto = onCall(
  {secrets: [GEMINI_API_KEY], region: 'us-central1'},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }

    const storagePath = request.data?.storagePath;
    if (
      typeof storagePath !== 'string' ||
      !storagePath.startsWith(`scoring_photos/${uid}/`)
    ) {
      throw new HttpsError('invalid-argument', 'Invalid storage path.');
    }

    const bucket = getStorage().bucket();
    const file = bucket.file(storagePath);
    const [exists] = await file.exists();
    if (!exists) {
      throw new HttpsError('not-found', 'Photo not found in storage.');
    }

    const [metadata] = await file.getMetadata();
    if (Number(metadata.size) > MAX_PHOTO_BYTES) {
      throw new HttpsError('invalid-argument', 'Photo is too large.');
    }

    const [buffer] = await file.download();
    const imagePart = {
      inlineData: {
        data: buffer.toString('base64'),
        mimeType: metadata.contentType || 'image/jpeg',
      },
    };

    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
    const model = genAI.getGenerativeModel({
      model: MODEL_NAME,
      generationConfig: {
        temperature: 0,
        responseMimeType: 'application/json',
        responseSchema: SCORE_SCHEMA,
      },
    });

    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);
    const scoreRef = db.collection('scores').doc(uid);

    try {
      const attempts = [];
      for (let i = 0; i < SAMPLES_PER_PHOTO; i++) {
        attempts.push(await scoreOnce(model, imagePart));
      }

      const validAttempts = attempts.filter((a) => a.valid);
      const isValid = validAttempts.length > attempts.length / 2;

      if (!isValid) {
        const reasonCounts = {};
        for (const attempt of attempts) {
          reasonCounts[attempt.rejectionReason] =
            (reasonCounts[attempt.rejectionReason] || 0) + 1;
        }
        const topReason = Object.entries(reasonCounts).sort(
          (a, b) => b[1] - a[1],
        )[0][0];

        await userRef.set(
          {
            scoringStatus: 'rejected',
            scoreRejectionReason: topReason,
            scoreBand: null,
            scoredAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );

        return {status: 'rejected', reason: topReason};
      }

      const finalScore = median(validAttempts.map((a) => a.score));
      const finalConfidence =
        validAttempts.reduce((sum, a) => sum + a.confidence, 0) /
        validAttempts.length;
      const band = scoreToBand(finalScore);

      await scoreRef.set({
        rawScore: finalScore,
        confidence: finalConfidence,
        scoringVersion: SCORING_VERSION,
        model: MODEL_NAME,
        sampleCount: attempts.length,
        scoredAt: FieldValue.serverTimestamp(),
      });

      await userRef.set(
        {
          scoringStatus: 'scored',
          scoreRejectionReason: null,
          scoreBand: band,
          scoredAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      return {status: 'scored', band};
    } finally {
      // The standardized scoring photo isn't a profile photo — don't keep
      // it around once we've extracted a score from it.
      file.delete().catch((error) => {
        console.error('Could not delete scoring photo:', error);
      });
    }
  },
);
