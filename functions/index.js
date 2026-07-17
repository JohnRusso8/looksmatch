const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {defineSecret} = require('firebase-functions/params');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {GoogleGenerativeAI} = require('@google/generative-ai');
const {
  RekognitionClient,
  DetectFacesCommand,
  DetectModerationLabelsCommand,
} = require('@aws-sdk/client-rekognition');

initializeApp();

const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
const AWS_ACCESS_KEY_ID = defineSecret('AWS_ACCESS_KEY_ID');
const AWS_SECRET_ACCESS_KEY = defineSecret('AWS_SECRET_ACCESS_KEY');

const AWS_REGION = 'us-east-1';

// Verify this against Google's current model list before deploying —
// Gemini model names change over time.
const MODEL_NAME = 'gemini-flash-lite-latest';

// Bump this and re-run the demographic bias audit before trusting a higher
// value in production. More samples = steadier scores, at proportional
// Gemini cost.
const SAMPLES_PER_PHOTO = 1;

const SCORING_VERSION = 'v3-profile-photo-scoring';
const MAX_PHOTO_BYTES = 10 * 1024 * 1024;

// Rekognition validation thresholds — all tunable. Deliberately not using
// Rekognition's Gender or AgeRange attributes anywhere in this file: only
// structural/quality attributes (pose, sharpness, brightness, occlusion)
// feed into validation, and none of them feed into the score at all.
const MIN_SHARPNESS = 40;
const MIN_BRIGHTNESS = 30;
const MAX_BRIGHTNESS = 90;
const MAX_POSE_DEGREES = 30;
const SUNGLASSES_CONFIDENCE_THRESHOLD = 70;
const EYES_CLOSED_CONFIDENCE_THRESHOLD = 70;
const MODERATION_CONFIDENCE_THRESHOLD = 80;

// Rekognition's moderation taxonomy has severity tiers — "Explicit Nudity"
// and "Revealing Clothes"/"Swimwear" are entirely different categories.
// Only reject on the tiers that are actually inappropriate for a dating
// app; swimwear, revealing clothes, kissing, alcohol, etc. are completely
// normal profile-photo content and must not trip this.
const BLOCKED_MODERATION_CATEGORIES = new Set([
  'Explicit Nudity',
  'Violence',
  'Visually Disturbing',
  'Drugs & Tobacco',
  'Hate Symbols',
]);

const SCORE_SCHEMA = {
  type: 'object',
  properties: {
    score: {type: 'integer'},
    confidence: {type: 'number'},
  },
  required: ['score', 'confidence'],
};

const RUBRIC_PROMPT = `
You are scoring a single standardized photo submitted to a dating app's
photo-compatibility feature. This photo has already been validated as a
clear, unobstructed, forward-facing single face — do not re-validate it.

Score the photo from 1 to 100 based only on: facial symmetry and
proportion, photo clarity, lighting and composition, and expression. Apply
the exact same standard to every photo regardless of the person's race,
ethnicity, skin tone, gender, or age — none of those attributes should
raise or lower the score.

Set confidence (0 to 1) to how certain you are in the score itself.

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
  return Math.min(10, Math.max(1, Math.ceil(score / 10)));
}

async function validateWithRekognition(rekognitionClient, buffer) {
  const facesResult = await rekognitionClient.send(
    new DetectFacesCommand({
      Image: {Bytes: buffer},
      Attributes: ['ALL'],
    }),
  );

  const faces = facesResult.FaceDetails || [];
  if (faces.length === 0) return {valid: false, reason: 'no_face_detected'};
  if (faces.length > 1) return {valid: false, reason: 'multiple_faces'};

  const face = faces[0];

  if (
    face.Sunglasses?.Value &&
    face.Sunglasses.Confidence > SUNGLASSES_CONFIDENCE_THRESHOLD
  ) {
    return {valid: false, reason: 'face_obscured'};
  }

  if (
    face.EyesOpen?.Value === false &&
    face.EyesOpen.Confidence > EYES_CLOSED_CONFIDENCE_THRESHOLD
  ) {
    return {valid: false, reason: 'eyes_closed'};
  }

  if ((face.Quality?.Sharpness ?? 0) < MIN_SHARPNESS) {
    return {valid: false, reason: 'low_quality'};
  }

  const brightness = face.Quality?.Brightness ?? 0;
  if (brightness < MIN_BRIGHTNESS || brightness > MAX_BRIGHTNESS) {
    return {valid: false, reason: 'low_quality'};
  }

  const pose = face.Pose || {};
  if (
    Math.abs(pose.Yaw ?? 0) > MAX_POSE_DEGREES ||
    Math.abs(pose.Pitch ?? 0) > MAX_POSE_DEGREES
  ) {
    return {valid: false, reason: 'extreme_pose'};
  }

  const moderationResult = await rekognitionClient.send(
    new DetectModerationLabelsCommand({
      Image: {Bytes: buffer},
      MinConfidence: MODERATION_CONFIDENCE_THRESHOLD,
    }),
  );

  const hasBlockedContent = (moderationResult.ModerationLabels || []).some(
    (label) =>
      BLOCKED_MODERATION_CATEGORIES.has(label.ParentName || label.Name),
  );

  if (hasBlockedContent) {
    return {valid: false, reason: 'inappropriate_content'};
  }

  return {valid: true, reason: 'none'};
}

async function scoreOnce(model, imagePart) {
  const result = await model.generateContent([RUBRIC_PROMPT, imagePart]);
  const parsed = JSON.parse(result.response.text());

  if (
    typeof parsed.score !== 'number' ||
    typeof parsed.confidence !== 'number'
  ) {
    throw new Error('Gemini returned a malformed scoring response.');
  }

  return parsed;
}

exports.scorePhoto = onCall(
  {
    secrets: [GEMINI_API_KEY, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY],
    region: 'us-central1',
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }

    // The scored photo must be one of the user's actual profile photos —
    // not an arbitrary upload — so the score always reflects what matches
    // actually see. This also means we never delete it after scoring.
    const storagePath = request.data?.storagePath;
    if (
      typeof storagePath !== 'string' ||
      !storagePath.startsWith(`profile_photos/${uid}/`)
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

    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);
    const scoreRef = db.collection('scores').doc(uid);

    const rekognitionClient = new RekognitionClient({
      region: AWS_REGION,
      credentials: {
        accessKeyId: AWS_ACCESS_KEY_ID.value(),
        secretAccessKey: AWS_SECRET_ACCESS_KEY.value(),
      },
    });

    const validation = await validateWithRekognition(rekognitionClient, buffer);

    if (!validation.valid) {
      console.log(`scorePhoto rejected uid=${uid} reason=${validation.reason}`);

      await userRef.set(
        {
          scoringStatus: 'rejected',
          scoreRejectionReason: validation.reason,
          scoredAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      return {status: 'rejected', reason: validation.reason};
    }

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

    const attempts = [];
    for (let i = 0; i < SAMPLES_PER_PHOTO; i++) {
      attempts.push(await scoreOnce(model, imagePart));
    }

    const finalScore = median(attempts.map((a) => a.score));
    const finalConfidence =
      attempts.reduce((sum, a) => sum + a.confidence, 0) / attempts.length;
    const band = scoreToBand(finalScore);

    // band lives ONLY here — scores/{uid} is never client-readable (see
    // firestore.rules). users/{uid} only gets a status flag, never the
    // score itself, so no client (including the profile's own owner) can
    // ever read it, by design.
    await scoreRef.set({
      rawScore: finalScore,
      confidence: finalConfidence,
      band,
      scoringVersion: SCORING_VERSION,
      model: MODEL_NAME,
      sampleCount: attempts.length,
      scoredAt: FieldValue.serverTimestamp(),
    });

    await userRef.set(
      {
        scoringStatus: 'scored',
        scoreRejectionReason: null,
        scoredAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    return {status: 'scored'};
  },
);

// Bump this for a paid tier later — everything downstream already reads
// from this constant, nothing else needs to change.
const DAILY_MATCH_LIMIT = 3;

// Cap how many candidate profiles we scan per allocation. Keeps cost and
// latency bounded; revisit with a proper matching index once the user base
// is large enough that this stops finding good candidates.
const CANDIDATE_SCAN_LIMIT = 500;

function todayDateString() {
  return new Date().toISOString().slice(0, 10);
}

function calculateAge(birthDateValue) {
  if (!birthDateValue || typeof birthDateValue.toDate !== 'function') {
    return null;
  }

  const birthDate = birthDateValue.toDate();
  const now = new Date();
  let age = now.getFullYear() - birthDate.getFullYear();

  const hadBirthdayThisYear =
    now.getMonth() > birthDate.getMonth() ||
    (now.getMonth() === birthDate.getMonth() &&
      now.getDate() >= birthDate.getDate());

  if (!hadBirthdayThisYear) age--;
  return age;
}

// `gender` is stored singular ("Man" / "Woman" / "Nonbinary") but
// `interestedIn` is stored plural ("Men" / "Women" / "Everyone") — they're
// different vocabularies, so this maps interest -> the gender value it
// corresponds to before comparing. Comparing the raw strings directly
// (as this used to) meant "Women" never equaled "Woman", so no two users
// could ever be mutually interested unless both had picked "Everyone".
const GENDER_FOR_INTEREST = {Men: 'Man', Women: 'Woman'};

function interestMatchesGender(interestedIn, gender) {
  if (interestedIn === 'Everyone') return true;
  return GENDER_FOR_INTEREST[interestedIn] === gender;
}

function isMutuallyInterested(myGender, myInterestedIn, theirGender, theirInterestedIn) {
  return (
    interestMatchesGender(myInterestedIn, theirGender) &&
    interestMatchesGender(theirInterestedIn, myGender)
  );
}

// Matching tolerance is on raw score (1-100), not band. Bands are coarse
// 10-point buckets purely for privacy — using them for the actual matching
// math would call a 61 and an 80 "one band apart", which isn't remotely
// similar. Starts tight and widens only if there aren't enough compatible
// people yet to fill today's allocation, so early on (small user base) you
// still get 3 matches instead of an empty deck, just less tightly matched.
// Capped well below a 30-point gap — never worth showing fewer than the
// daily limit over matching someone that far off on looks.
const INITIAL_SCORE_TOLERANCE = 10;
const SCORE_TOLERANCE_STEP = 10;
const MAX_SCORE_TOLERANCE = 20;

// `rankedByProximity` must already be sorted closest-first — filtering
// preserves that order, so no need to re-sort as the tolerance widens.
function selectWithinTolerance(rankedByProximity, myRawScore, limit) {
  if (myRawScore === null) return rankedByProximity.slice(0, limit);

  let tolerance = INITIAL_SCORE_TOLERANCE;
  let withinRange = rankedByProximity.filter(
    (c) => Math.abs(c.rawScore - myRawScore) <= tolerance,
  );

  while (withinRange.length < limit && tolerance < MAX_SCORE_TOLERANCE) {
    tolerance += SCORE_TOLERANCE_STEP;
    withinRange = rankedByProximity.filter(
      (c) => Math.abs(c.rawScore - myRawScore) <= tolerance,
    );
  }

  return withinRange.slice(0, limit);
}

function summarizeUserDoc(doc) {
  const data = doc.data();
  const photos = Array.isArray(data.photos) ? data.photos : [];
  const photoUrls = photos.map((photo) => (photo.url || '').toString()).filter(Boolean);

  return {
    uid: doc.id,
    name: (data.name || '').toString(),
    age: calculateAge(data.birthDate),
    primaryPhotoUrl: photoUrls.length > 0 ? photoUrls[0] : '',
    photoUrls,
  };
}

// Keys in profileDetails/{uid} that are ever shown to other users, and
// therefore the only ones fieldVisibility/enrichSummaries needs to know
// about. ageRangeMin/Max and maxDistanceMiles are matching preferences —
// private, used only server-side, never displayed on anyone's profile.
const DISPLAYABLE_PROFILE_FIELDS = [
  'bio',
  'prompts',
  'interests',
  'ethnicity',
  'relationshipType',
  'datingIntention',
  'height',
  'drinking',
  'smoking',
  'educationLevel',
  'college',
];

// Simple exact-match weights for the compatibility score — deliberately
// excludes ethnicity (same anti-bias reasoning as keeping race out of the
// looks score entirely) and anything that isn't really a "compatibility"
// signal (height, college, bio). Interests are scored separately below
// since they're a set, not a single value.
const COMPATIBILITY_MATCH_WEIGHTS = {
  datingIntention: 20,
  relationshipType: 15,
  drinking: 10,
  smoking: 10,
  educationLevel: 5,
};
const COMPATIBILITY_INTERESTS_MAX_POINTS = 40;
const COMPATIBILITY_INTERESTS_CAP = 5;

function fieldMutuallyVisible(a, b, field) {
  return (a?.fieldVisibility || {})[field] !== false && (b?.fieldVisibility || {})[field] !== false;
}

// A field only counts toward compatibility if BOTH people have it visible —
// hiding a field removes it from the score entirely rather than letting it
// silently influence a number the other person sees, which would otherwise
// leak information about something they chose to keep private.
function computeCompatibility(myDetails, theirDetails) {
  if (!myDetails || !theirDetails) return null;

  let points = 0;
  let consideredAny = false;

  for (const [field, weight] of Object.entries(COMPATIBILITY_MATCH_WEIGHTS)) {
    if (!fieldMutuallyVisible(myDetails, theirDetails, field)) continue;
    const mine = myDetails[field];
    const theirs = theirDetails[field];
    if (!hasValue(mine) || !hasValue(theirs)) continue;
    consideredAny = true;
    if (mine === theirs) points += weight;
  }

  if (fieldMutuallyVisible(myDetails, theirDetails, 'interests')) {
    const mine = Array.isArray(myDetails.interests) ? myDetails.interests : [];
    const theirs = Array.isArray(theirDetails.interests) ? theirDetails.interests : [];
    if (mine.length > 0 && theirs.length > 0) {
      consideredAny = true;
      const theirSet = new Set(theirs);
      const shared = mine.filter((interest) => theirSet.has(interest)).length;
      points +=
        Math.min(shared, COMPATIBILITY_INTERESTS_CAP) *
        (COMPATIBILITY_INTERESTS_MAX_POINTS / COMPATIBILITY_INTERESTS_CAP);
    }
  }

  // Nothing comparable was set/visible on either side — show no score
  // rather than a misleading 0%.
  if (!consideredAny) return null;
  return Math.round(points);
}

function toRadians(degrees) {
  return (degrees * Math.PI) / 180;
}

function haversineMiles(lat1, lng1, lat2, lng2) {
  const earthRadiusMiles = 3958.8;
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLng / 2) ** 2;
  return earthRadiusMiles * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function hasValue(value) {
  if (value === undefined || value === null) return false;
  if (Array.isArray(value)) return value.length > 0;
  if (typeof value === 'string') return value.trim().length > 0;
  return true;
}

// Adds each person's own bio/prompts/traits (respecting their individual
// fieldVisibility choices) and their distance from the viewer onto
// already-built candidate summaries. A "hidden" field is filtered out here,
// server-side, before it ever reaches a client — never relying on the
// client to hide it, same reasoning as the score never leaving the server.
async function enrichSummaries(db, summaries, viewerUid) {
  if (summaries.length === 0) return summaries;

  const uids = summaries.map((s) => s.uid);
  const [detailDocs, locationDocs, viewerLocationDoc, viewerDetailsDoc] = await Promise.all([
    Promise.all(uids.map((uid) => db.collection('profileDetails').doc(uid).get())),
    Promise.all(uids.map((uid) => db.collection('locations').doc(uid).get())),
    db.collection('locations').doc(viewerUid).get(),
    db.collection('profileDetails').doc(viewerUid).get(),
  ]);

  const viewerLocation = viewerLocationDoc.exists ? viewerLocationDoc.data() : null;
  const viewerDetails = viewerDetailsDoc.exists ? viewerDetailsDoc.data() : null;

  return summaries.map((summary, index) => {
    const enriched = {...summary};
    const details = detailDocs[index].exists ? detailDocs[index].data() : null;

    if (details) {
      const visibility = details.fieldVisibility || {};
      for (const field of DISPLAYABLE_PROFILE_FIELDS) {
        if (visibility[field] === false) continue;
        if (!hasValue(details[field])) continue;
        enriched[field] = details[field];
      }
    }

    const compatibilityPercent = computeCompatibility(viewerDetails, details);
    if (compatibilityPercent !== null) {
      enriched.compatibilityPercent = compatibilityPercent;
    }

    const location = locationDocs[index].exists ? locationDocs[index].data() : null;
    if (viewerLocation && location) {
      enriched.distanceMiles = Math.round(
        haversineMiles(viewerLocation.lat, viewerLocation.lng, location.lat, location.lng),
      );
    }

    return enriched;
  });
}

function connectionIdFor(uidA, uidB) {
  return [uidA, uidB].sort().join('_');
}

// Idempotent — safe to call even if a connection already exists (e.g. two
// near-simultaneous likes racing each other).
async function createConnection(db, uidA, uidB) {
  const connectionId = connectionIdFor(uidA, uidB);
  const connectionRef = db.collection('connections').doc(connectionId);
  const existing = await connectionRef.get();

  if (!existing.exists) {
    await connectionRef.set({
      userIds: [uidA, uidB].sort(),
      connectedAt: FieldValue.serverTimestamp(),
      lastMessage: '',
      lastMessageAt: FieldValue.serverTimestamp(),
    });
  }

  // Nothing left to accept/decline/cancel once matched.
  await Promise.all([
    db.collection('users').doc(uidA).collection('receivedLikes').doc(uidB).delete(),
    db.collection('users').doc(uidB).collection('receivedLikes').doc(uidA).delete(),
  ]);

  return connectionId;
}

async function buildDailyMatchesResponse(db, allocation, viewerUid) {
  const candidateUids = allocation.candidateUids || [];

  const candidateDocs = await Promise.all(
    candidateUids.map((candidateUid) =>
      db.collection('users').doc(candidateUid).get(),
    ),
  );

  const summaries = candidateDocs
    .filter((doc) => doc.exists)
    .map(summarizeUserDoc);
  const candidates = await enrichSummaries(db, summaries, viewerUid);

  return {
    candidates,
    decisions: allocation.decisions || {},
    hasMore: allocation.hasMore === true,
  };
}

exports.getDailyMatches = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const db = getFirestore();

  const meSnap = await db.collection('users').doc(uid).get();
  const me = meSnap.data();
  if (!me) {
    throw new HttpsError('failed-precondition', 'Complete your profile first.');
  }

  // No matches — not even a cached allocation from before — until this
  // user has their own LooksMatch score. Without it there's nothing to
  // rank candidates by proximity to, so skip straight to an empty deck
  // rather than falling through to selectWithinTolerance's myRawScore-is-
  // null fallback, which used to hand back an arbitrary slice of everyone.
  if (me.scoringStatus !== 'scored') {
    return {candidates: [], decisions: {}, hasMore: false};
  }

  const today = todayDateString();
  const dailyRef = db
    .collection('users')
    .doc(uid)
    .collection('dailyMatches')
    .doc(today);

  const existing = await dailyRef.get();
  if (existing.exists) {
    const existingData = existing.data();
    const hasDecisions =
      Object.keys(existingData.decisions || {}).length > 0;
    const isFull =
      (existingData.candidateUids || []).length >= DAILY_MATCH_LIMIT;

    // Once the user has acted on today's allocation, or it's full, it's
    // locked in for the day — that's the actual "3 a day" product rule.
    // But if it's still empty/partial and nothing's been decided yet, the
    // candidate pool likely just grew (very common pre-launch, before
    // enough people have signed up and been scored) — regenerate instead
    // of permanently caching an empty deck for the rest of the day.
    if (hasDecisions || isFull) {
      return buildDailyMatchesResponse(db, existingData, uid);
    }
  }

  const myGender = (me.gender || '').toString();
  const myInterestedIn = (me.interestedIn || '').toString();

  const interactionsSnap = await db
    .collection('users')
    .doc(uid)
    .collection('interactions')
    .get();
  const excludedUids = new Set(interactionsSnap.docs.map((doc) => doc.id));
  excludedUids.add(uid);

  const candidatesSnap = await db
    .collection('users')
    .where('profileCompleted', '==', true)
    .limit(CANDIDATE_SCAN_LIMIT)
    .get();

  const eligible = candidatesSnap.docs.filter((doc) => {
    if (excludedUids.has(doc.id)) return false;

    const data = doc.data();
    if (data.scoringStatus !== 'scored') return false;

    return isMutuallyInterested(
      myGender,
      myInterestedIn,
      (data.gender || '').toString(),
      (data.interestedIn || '').toString(),
    );
  });

  // Age range and max distance are hard preference filters — applied
  // before score-proximity ranking, unlike the score tolerance which
  // widens to avoid an empty deck. Missing prefs (no profileDetails/
  // location doc yet) mean "no preference", so early users who haven't
  // set these up aren't over-filtered.
  const myDetailsSnap = await db.collection('profileDetails').doc(uid).get();
  const myDetails = myDetailsSnap.exists ? myDetailsSnap.data() : null;

  let ageFiltered = eligible;
  if (myDetails?.ageRangeMin != null || myDetails?.ageRangeMax != null) {
    const minAge = myDetails.ageRangeMin ?? 18;
    const maxAge = myDetails.ageRangeMax ?? 120;
    ageFiltered = eligible.filter((doc) => {
      const age = calculateAge(doc.data().birthDate);
      return age === null || (age >= minAge && age <= maxAge);
    });
  }

  let distanceFiltered = ageFiltered;
  if (myDetails?.maxDistanceMiles != null) {
    const myLocationSnap = await db.collection('locations').doc(uid).get();
    const myLocation = myLocationSnap.exists ? myLocationSnap.data() : null;

    if (myLocation) {
      const candidateLocationDocs = await Promise.all(
        ageFiltered.map((doc) => db.collection('locations').doc(doc.id).get()),
      );
      distanceFiltered = ageFiltered.filter((doc, index) => {
        const locationSnap = candidateLocationDocs[index];
        if (!locationSnap.exists) return true;
        const location = locationSnap.data();
        const miles = haversineMiles(
          myLocation.lat,
          myLocation.lng,
          location.lat,
          location.lng,
        );
        return miles <= myDetails.maxDistanceMiles;
      });
    }
  }

  const myScoreSnap = await db.collection('scores').doc(uid).get();
  const myRawScore = myScoreSnap.data()?.rawScore ?? null;

  const scoreDocs = await Promise.all(
    distanceFiltered.map((doc) => db.collection('scores').doc(doc.id).get()),
  );

  const ranked = distanceFiltered
    .map((doc, index) => ({
      uid: doc.id,
      rawScore: scoreDocs[index].data()?.rawScore ?? null,
    }))
    .filter((c) => c.rawScore !== null)
    .sort((a, b) => {
      if (myRawScore === null) return 0;
      return (
        Math.abs(a.rawScore - myRawScore) - Math.abs(b.rawScore - myRawScore)
      );
    });

  const selected = selectWithinTolerance(ranked, myRawScore, DAILY_MATCH_LIMIT);

  const allocation = {
    candidateUids: selected.map((c) => c.uid),
    decisions: {},
    hasMore: ranked.length > selected.length,
    generatedAt: FieldValue.serverTimestamp(),
  };

  await dailyRef.set(allocation);

  return buildDailyMatchesResponse(db, allocation, uid);
});

exports.recordMatchDecision = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const candidateUid = request.data?.candidateUid;
  const decision = request.data?.decision;

  if (typeof candidateUid !== 'string' || candidateUid.length === 0) {
    throw new HttpsError('invalid-argument', 'Missing candidateUid.');
  }
  if (decision !== 'liked' && decision !== 'passed') {
    throw new HttpsError('invalid-argument', 'Invalid decision.');
  }

  const db = getFirestore();
  const today = todayDateString();
  const dailyRef = db
    .collection('users')
    .doc(uid)
    .collection('dailyMatches')
    .doc(today);

  const dailySnap = await dailyRef.get();
  const candidateUids = dailySnap.data()?.candidateUids || [];

  if (!dailySnap.exists || !candidateUids.includes(candidateUid)) {
    throw new HttpsError(
      'failed-precondition',
      'That person is not part of today\'s matches.',
    );
  }

  // Dotted field path, not a nested object literal — merge:true replaces
  // whole nested maps given as object literals, which would wipe out any
  // decisions already recorded earlier today.
  await dailyRef.set(
    {[`decisions.${candidateUid}`]: decision},
    {merge: true},
  );

  await db
    .collection('users')
    .doc(uid)
    .collection('interactions')
    .doc(candidateUid)
    .set({
      decision,
      decidedAt: FieldValue.serverTimestamp(),
    });

  if (decision === 'liked') {
    const theirInteractionSnap = await db
      .collection('users')
      .doc(candidateUid)
      .collection('interactions')
      .doc(uid)
      .get();

    if (theirInteractionSnap.data()?.decision === 'liked') {
      // They already liked us first — it's a match, not a pending like.
      const connectionId = await createConnection(db, uid, candidateUid);
      return {status: 'matched', connectionId};
    }

    await db
      .collection('users')
      .doc(candidateUid)
      .collection('receivedLikes')
      .doc(uid)
      .set({likedAt: FieldValue.serverTimestamp()});
  }

  return {status: 'ok'};
});

exports.getLikes = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const db = getFirestore();

  const [receivedSnap, sentInteractionsSnap] = await Promise.all([
    db.collection('users').doc(uid).collection('receivedLikes').get(),
    db
      .collection('users')
      .doc(uid)
      .collection('interactions')
      .where('decision', '==', 'liked')
      .get(),
  ]);

  const sentCandidateUids = sentInteractionsSnap.docs.map((doc) => doc.id);

  // interactions docs are permanent decision records — they don't get
  // cleaned up once a like is resolved, unlike receivedLikes. So a "sent"
  // like is only still pending if it hasn't already turned into a match
  // (connection exists) and the other person hasn't already declined it;
  // otherwise it'd sit in Sent forever regardless of outcome.
  const [connectionDocs, theirInteractionDocs, receivedDocs] = await Promise.all([
    Promise.all(
      sentCandidateUids.map((candidateUid) =>
        db.collection('connections').doc(connectionIdFor(uid, candidateUid)).get(),
      ),
    ),
    Promise.all(
      sentCandidateUids.map((candidateUid) =>
        db
          .collection('users')
          .doc(candidateUid)
          .collection('interactions')
          .doc(uid)
          .get(),
      ),
    ),
    Promise.all(
      receivedSnap.docs.map((doc) => db.collection('users').doc(doc.id).get()),
    ),
  ]);

  const pendingSentUids = sentCandidateUids.filter((candidateUid, index) => {
    if (connectionDocs[index].exists) return false;
    if (theirInteractionDocs[index].data()?.decision === 'passed') return false;
    return true;
  });

  const sentDocs = await Promise.all(
    pendingSentUids.map((candidateUid) => db.collection('users').doc(candidateUid).get()),
  );

  const received = receivedDocs
    .map((doc, index) => ({doc, likedAt: receivedSnap.docs[index].data().likedAt}))
    .filter((entry) => entry.doc.exists)
    .map((entry) => ({
      ...summarizeUserDoc(entry.doc),
      likedAt: entry.likedAt?.toDate?.().toISOString() ?? null,
    }));

  const sent = sentDocs.filter((doc) => doc.exists).map(summarizeUserDoc);

  const [enrichedReceived, enrichedSent] = await Promise.all([
    enrichSummaries(db, received, uid),
    enrichSummaries(db, sent, uid),
  ]);

  return {received: enrichedReceived, sent: enrichedSent};
});

exports.respondToLike = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const likerUid = request.data?.likerUid;
  const accept = request.data?.accept;

  if (typeof likerUid !== 'string' || likerUid.length === 0) {
    throw new HttpsError('invalid-argument', 'Missing likerUid.');
  }
  if (typeof accept !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Missing accept.');
  }

  const db = getFirestore();
  const receivedLikeRef = db
    .collection('users')
    .doc(uid)
    .collection('receivedLikes')
    .doc(likerUid);

  const receivedLikeSnap = await receivedLikeRef.get();
  if (!receivedLikeSnap.exists) {
    throw new HttpsError(
      'failed-precondition',
      'No pending like from that person.',
    );
  }

  await db
    .collection('users')
    .doc(uid)
    .collection('interactions')
    .doc(likerUid)
    .set({
      decision: accept ? 'liked' : 'passed',
      decidedAt: FieldValue.serverTimestamp(),
    });

  if (accept) {
    const connectionId = await createConnection(db, uid, likerUid);
    return {status: 'matched', connectionId};
  }

  await receivedLikeRef.delete();
  return {status: 'declined'};
});

exports.cancelSentLike = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const candidateUid = request.data?.candidateUid;
  if (typeof candidateUid !== 'string' || candidateUid.length === 0) {
    throw new HttpsError('invalid-argument', 'Missing candidateUid.');
  }

  const db = getFirestore();

  await db
    .collection('users')
    .doc(uid)
    .collection('interactions')
    .doc(candidateUid)
    .set({
      decision: 'passed',
      decidedAt: FieldValue.serverTimestamp(),
    });

  await db
    .collection('users')
    .doc(candidateUid)
    .collection('receivedLikes')
    .doc(uid)
    .delete();

  return {status: 'ok'};
});

exports.getMatches = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const db = getFirestore();
  const connectionsSnap = await db
    .collection('connections')
    .where('userIds', 'array-contains', uid)
    .get();

  const matches = await Promise.all(
    connectionsSnap.docs.map(async (doc) => {
      const data = doc.data();
      const otherUid = (data.userIds || []).find((id) => id !== uid);
      if (!otherUid) return null;

      const otherDoc = await db.collection('users').doc(otherUid).get();
      if (!otherDoc.exists) return null;

      return {
        connectionId: doc.id,
        ...summarizeUserDoc(otherDoc),
        lastMessage: (data.lastMessage || '').toString(),
        lastMessageAt: data.lastMessageAt?.toDate?.().toISOString() ?? null,
        connectedAt: data.connectedAt?.toDate?.().toISOString() ?? null,
      };
    }),
  );

  const enrichedMatches = await enrichSummaries(
    db,
    matches.filter((m) => m !== null),
    uid,
  );

  return {matches: enrichedMatches};
});

// Stores the caller's current coordinates for distance-based matching and
// the "N miles away" shown on their profile to others. Written to a
// fully locked-down collection (see firestore.rules) — no client, not even
// the owner, ever reads raw coordinates back; only rounded distances
// computed server-side (enrichSummaries) reach a client.
exports.updateLocation = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const lat = request.data?.lat;
  const lng = request.data?.lng;

  if (
    typeof lat !== 'number' || typeof lng !== 'number' ||
    lat < -90 || lat > 90 || lng < -180 || lng > 180
  ) {
    throw new HttpsError('invalid-argument', 'Invalid coordinates.');
  }

  await getFirestore().collection('locations').doc(uid).set({
    lat,
    lng,
    updatedAt: FieldValue.serverTimestamp(),
  });

  return {status: 'ok'};
});

// Keeps connections/{id}.lastMessage in sync server-side so clients never
// need write access to the connection doc itself — just send a message and
// this trigger updates the preview shown on the Matches list.
exports.onMessageCreated = onDocumentCreated(
  {
    document: 'connections/{connectionId}/messages/{messageId}',
    region: 'us-central1',
  },
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const db = getFirestore();
    await db
      .collection('connections')
      .doc(event.params.connectionId)
      .set(
        {
          lastMessage: (message.text || '').toString(),
          lastMessageAt: message.sentAt || FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
  },
);
