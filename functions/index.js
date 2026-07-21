const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {defineSecret} = require('firebase-functions/params');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {getAuth} = require('firebase-admin/auth');
const {getMessaging} = require('firebase-admin/messaging');
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

const SCORING_VERSION = 'v4-analytical-harsh-scoring';
const MAX_PHOTO_BYTES = 10 * 1024 * 1024;

// Rekognition validation thresholds — all tunable. Deliberately not using
// Rekognition's Gender or AgeRange attributes anywhere in this file: only
// structural/quality attributes (pose, sharpness, brightness, occlusion)
// feed into validation, and none of them feed into the score at all.
// Rekognition's Sharpness score is a blur-detection heuristic, not a true
// focus check — it's known to under-score genuinely in-focus photos that
// have smooth, low-texture skin or flat lighting, since it likely reads
// local contrast/edges as its blur signal. 40 was rejecting real, clearly
// sharp phone photos as "blurry"; keep this loose enough to only catch
// actual motion blur, not just low local-contrast lighting.
const MIN_SHARPNESS = 15;
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
You are a clinical facial-aesthetics analyst scoring a single standardized
photo submitted to a dating app's photo-compatibility feature. This photo
has already been validated as a clear, unobstructed, forward-facing single
face — do not re-validate it.

Be rigorous and critical, not encouraging. This is a structural analysis,
not a compliment. Most faces are ordinary and should score in the ordinary
range — do not inflate scores out of generosity or to soften the result.
Real flaws (asymmetry, disproportion, weak structure) must pull the score
down accordingly, and no single strong feature should mask weaknesses
elsewhere.

Analyze the face across these dimensions, weighted roughly equally, then
integrate them into one overall judgment of facial harmony:

- Symmetry: compare left and right sides — alignment of eyes, eyebrows,
  ears, and mouth corners; any visible tilt or asymmetry in the jaw or
  nose.
- Proportion and balance: vertical thirds (hairline-to-brow,
  brow-to-nose-base, nose-base-to-chin should read as roughly even) and
  horizontal fifths (eye spacing relative to face width).
- Jawline: definition and angularity of the mandible, sharpness of the
  gonial angle, and how distinctly the jaw separates from the neck.
- Nose: size and width relative to eye spacing and overall face width,
  straightness of the bridge, and refinement of the tip — judged as a
  proportion problem, not against any single ideal nose shape.
- Cheekbones: prominence, height, and how much structure they give the
  midface.
- Eyes: shape, spacing, and left-right symmetry.
- Skin: clarity, evenness, and texture as visible in the photo only.

Facial structure (symmetry, proportion, jawline, nose, cheekbones, eyes)
should dominate the score. Photo clarity, lighting, composition, and
expression are secondary modifiers only — a great photo of an ordinary
face should not outscore a strong face in a mediocre photo.

Symmetry and proportion are geometric properties of an individual's own
face, evaluated relative to that face — not against a single ethnic or
cultural beauty ideal. Apply the exact same standard to every photo
regardless of the person's race, ethnicity, skin tone, gender, or age;
none of those attributes should raise or lower the score, and structural
variation that's typical across different ancestries is not itself a
flaw.

Calibrate against the full 1-100 range: 50 is a typical face with no
notable asymmetry or disproportion and no distinguishing structure either
way. Below 40 reflects visible asymmetry, disproportion, or weak
definition. Above 75 requires strong symmetry, balanced proportion, and
clear structural definition across most dimensions above, not just one.
Reserve 90+ for exceptional harmony across nearly every dimension with no
notable flaws — this should be rare.

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

  const sharpness = face.Quality?.Sharpness ?? 0;
  const brightness = face.Quality?.Brightness ?? 0;

  if (sharpness < MIN_SHARPNESS) {
    console.log(
      `validateWithRekognition low_quality: sharpness=${sharpness} ` +
        `(min ${MIN_SHARPNESS}), brightness=${brightness}`,
    );
    return {valid: false, reason: 'low_quality'};
  }

  if (brightness < MIN_BRIGHTNESS || brightness > MAX_BRIGHTNESS) {
    console.log(
      `validateWithRekognition low_quality: brightness=${brightness} ` +
        `(range ${MIN_BRIGHTNESS}-${MAX_BRIGHTNESS}), sharpness=${sharpness}`,
    );
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

  // At most one photo per category — EditProfileScreen enforces this
  // client-side when tagging, so `find` picking the first match is enough.
  const hobbyPhoto = photos.find((photo) => photo.category === 'hobby');
  const foodPhoto = photos.find((photo) => photo.category === 'food');

  return {
    uid: doc.id,
    name: (data.name || '').toString(),
    age: calculateAge(data.birthDate),
    primaryPhotoUrl: photoUrls.length > 0 ? photoUrls[0] : '',
    photoUrls,
    hobbyPhotoUrl: hobbyPhoto ? (hobbyPhoto.url || '').toString() : '',
    foodPhotoUrl: foodPhoto ? (foodPhoto.url || '').toString() : '',
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
  'values',
  'musicGenres',
  'favoriteFoods',
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
// signal (height, college, bio). Multi-select fields (interests, values,
// music, food, dating intentions) are scored separately below since
// they're sets, not single values.
const COMPATIBILITY_MATCH_WEIGHTS = {
  relationshipType: 10,
  drinking: 5,
  smoking: 5,
  educationLevel: 5,
};

// Each multi-select category contributes up to maxPoints, reached once
// `cap` items are shared — further overlap beyond the cap doesn't add more,
// so one person listing 20 interests can't dominate the score. Dating
// intentions gets a lower cap than the others since it only has ~7 options
// total and picking most of them shouldn't be as easy to max out.
const COMPATIBILITY_OVERLAP_CATEGORIES = {
  interests: {maxPoints: 15, cap: 4},
  values: {maxPoints: 15, cap: 4},
  musicGenres: {maxPoints: 15, cap: 4},
  favoriteFoods: {maxPoints: 15, cap: 4},
  datingIntention: {maxPoints: 15, cap: 2},
};

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

  for (const [field, {maxPoints, cap}] of Object.entries(COMPATIBILITY_OVERLAP_CATEGORIES)) {
    if (!fieldMutuallyVisible(myDetails, theirDetails, field)) continue;
    const mine = Array.isArray(myDetails[field]) ? myDetails[field] : [];
    const theirs = Array.isArray(theirDetails[field]) ? theirDetails[field] : [];
    if (mine.length === 0 || theirs.length === 0) continue;
    consideredAny = true;
    const theirSet = new Set(theirs);
    const shared = mine.filter((item) => theirSet.has(item)).length;
    points += Math.min(shared, cap) * (maxPoints / cap);
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

// A field the candidate has hidden is treated as unknown for preference
// filtering too, not just for display — same "hidden means hidden
// everywhere" rule enrichSummaries uses for compatibility, so a hidden
// choice can never be silently used to include or exclude someone.
function candidateFieldIfVisible(details, field) {
  if (!details) return undefined;
  if ((details.fieldVisibility || {})[field] === false) return undefined;
  return details[field];
}

// No preference set, or the candidate's value is unknown (unset/hidden) —
// either way, don't exclude. Only an explicit preference list AND a known,
// non-matching candidate value excludes.
function matchesListPreference(preferred, candidateValue) {
  if (!hasValue(preferred)) return true;
  if (candidateValue === undefined || candidateValue === null) return true;
  return preferred.includes(candidateValue);
}

// Same "no preference / unknown candidate value never excludes" rule as
// matchesListPreference, but for a candidate field that's itself a list
// (ethnicity, now multi-select) — matches if ANY of the candidate's values
// is in the preferred list, rather than comparing a single scalar.
function matchesAnyListPreference(preferred, candidateValues) {
  if (!hasValue(preferred)) return true;
  if (!hasValue(candidateValues)) return true;
  // Tolerates a pre-multi-select single string still sitting on an
  // untouched profile, same as the client's parseMultiOrLegacySingle.
  const values = Array.isArray(candidateValues) ? candidateValues : [candidateValues];
  const preferredSet = new Set(preferred);
  return values.some((value) => preferredSet.has(value));
}

function matchesTraitPreferences(myDetails, candidateDetails) {
  if (
    !matchesAnyListPreference(
      myDetails?.preferredEthnicities,
      candidateFieldIfVisible(candidateDetails, 'ethnicity'),
    )
  ) {
    return false;
  }
  if (
    !matchesListPreference(
      myDetails?.preferredRelationshipTypes,
      candidateFieldIfVisible(candidateDetails, 'relationshipType'),
    )
  ) {
    return false;
  }
  if (
    !matchesListPreference(
      myDetails?.preferredFamilyPlans,
      candidateFieldIfVisible(candidateDetails, 'familyPlans'),
    )
  ) {
    return false;
  }
  if (
    !matchesListPreference(
      myDetails?.preferredEducationLevels,
      candidateFieldIfVisible(candidateDetails, 'educationLevel'),
    )
  ) {
    return false;
  }

  const height = candidateFieldIfVisible(candidateDetails, 'height');
  if (typeof height === 'number') {
    if (myDetails?.minHeightInches != null && height < myDetails.minHeightInches) {
      return false;
    }
    if (myDetails?.maxHeightInches != null && height > myDetails.maxHeightInches) {
      return false;
    }
  }

  return true;
}

// Union of who this user has blocked and who has blocked this user — both
// directions are mutually invisible. blockedBy is maintained by the other
// person's blockUser/unblockUser call specifically so this never needs a
// collection-group query across every user's blocks subcollection.
async function getBlockedUids(db, uid) {
  const [blocksSnap, blockedBySnap] = await Promise.all([
    db.collection('users').doc(uid).collection('blocks').get(),
    db.collection('users').doc(uid).collection('blockedBy').get(),
  ]);

  return new Set([
    ...blocksSnap.docs.map((doc) => doc.id),
    ...blockedBySnap.docs.map((doc) => doc.id),
  ]);
}

// FCM error codes that mean a token is permanently dead (app uninstalled,
// reinstalled with a new token, etc.) — anything else (rate limits,
// transient network errors) is left alone so a blip doesn't wipe out a
// perfectly good token.
const DEAD_TOKEN_ERROR_CODES = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

// category must match a key in notificationPrefs (see the Settings
// screen) — 'like' | 'match' | 'message'. Missing prefs (a user who's
// never touched notification settings) default to enabled, so this only
// ever narrows delivery for someone who explicitly muted that category.
const NOTIFICATION_CATEGORIES = new Set(['like', 'match', 'message']);

// Sends the same notification to every device this user has registered,
// pruning any token FCM reports as dead so the token list self-cleans
// instead of growing forever. Never throws — a failed push shouldn't ever
// fail the like/match/message action that triggered it.
async function sendPushToUser(db, uid, {title, body, data, category}) {
  try {
    if (category && NOTIFICATION_CATEGORIES.has(category)) {
      const userSnap = await db.collection('users').doc(uid).get();
      const prefs = userSnap.data()?.notificationPrefs || {};
      if (prefs[category] === false) return;
    }

    const tokensSnap = await db.collection('users').doc(uid).collection('fcmTokens').get();
    if (tokensSnap.empty) return;

    const tokens = tokensSnap.docs.map((doc) => doc.id);
    const stringData = Object.fromEntries(
      Object.entries(data || {}).map(([key, value]) => [key, String(value)]),
    );

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title, body},
      data: stringData,
      apns: {payload: {aps: {sound: 'default'}}},
      android: {notification: {sound: 'default'}},
    });

    const deadTokens = [];
    response.responses.forEach((result, index) => {
      if (!result.success && DEAD_TOKEN_ERROR_CODES.has(result.error?.code)) {
        deadTokens.push(tokens[index]);
      }
    });

    if (deadTokens.length > 0) {
      await Promise.all(
        deadTokens.map((token) =>
          db.collection('users').doc(uid).collection('fcmTokens').doc(token).delete(),
        ),
      );
    }
  } catch (error) {
    console.log(`Could not send push to ${uid}: ${error.message}`);
  }
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

    const [aDoc, bDoc] = await Promise.all([
      db.collection('users').doc(uidA).get(),
      db.collection('users').doc(uidB).get(),
    ]);
    const aName = (aDoc.data()?.name || 'Someone').toString();
    const bName = (bDoc.data()?.name || 'Someone').toString();

    await Promise.all([
      sendPushToUser(db, uidA, {
        title: 'It\'s a match!',
        body: `You and ${bName} liked each other.`,
        data: {type: 'match', connectionId},
        category: 'match',
      }),
      sendPushToUser(db, uidB, {
        title: 'It\'s a match!',
        body: `You and ${aName} liked each other.`,
        data: {type: 'match', connectionId},
        category: 'match',
      }),
    ]);
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

  const [interactionsSnap, blockedUids] = await Promise.all([
    db.collection('users').doc(uid).collection('interactions').get(),
    getBlockedUids(db, uid),
  ]);
  const excludedUids = new Set(interactionsSnap.docs.map((doc) => doc.id));
  blockedUids.forEach((blockedUid) => excludedUids.add(blockedUid));
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
    // Paused is self-service (Settings screen) and distinct from
    // accountStatus (reviewer-only moderation) — a paused user keeps full
    // access to their existing matches/messages, they just stop being
    // surfaced to new people.
    if (data.paused === true) return false;

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

  // Ethnicity/height/relationship-type/children/education-level preferences
  // (see PreferencesScreen) — same hard-filter, permissive-on-missing-data
  // treatment as age range and distance above. Only fetches profileDetails
  // for whoever's left after the cheaper filters already ran.
  let preferenceFiltered = distanceFiltered;
  const hasTraitPreferences =
    hasValue(myDetails?.preferredEthnicities) ||
    hasValue(myDetails?.preferredRelationshipTypes) ||
    hasValue(myDetails?.preferredFamilyPlans) ||
    hasValue(myDetails?.preferredEducationLevels) ||
    myDetails?.minHeightInches != null ||
    myDetails?.maxHeightInches != null;

  if (hasTraitPreferences) {
    const candidateDetailDocs = await Promise.all(
      distanceFiltered.map((doc) => db.collection('profileDetails').doc(doc.id).get()),
    );
    preferenceFiltered = distanceFiltered.filter((doc, index) => {
      const details = candidateDetailDocs[index].exists
        ? candidateDetailDocs[index].data()
        : null;
      return matchesTraitPreferences(myDetails, details);
    });
  }

  const myScoreSnap = await db.collection('scores').doc(uid).get();
  const myRawScore = myScoreSnap.data()?.rawScore ?? null;

  const scoreDocs = await Promise.all(
    preferenceFiltered.map((doc) => db.collection('scores').doc(doc.id).get()),
  );

  const ranked = preferenceFiltered
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

    const myDoc = await db.collection('users').doc(uid).get();
    const myName = (myDoc.data()?.name || 'Someone').toString();
    await sendPushToUser(db, candidateUid, {
      title: 'New like',
      body: `${myName} likes you!`,
      data: {type: 'like'},
      category: 'like',
    });
  }

  return {status: 'ok'};
});

exports.getLikes = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const db = getFirestore();

  const [receivedSnap, sentInteractionsSnap, blockedUids] = await Promise.all([
    db.collection('users').doc(uid).collection('receivedLikes').get(),
    db
      .collection('users')
      .doc(uid)
      .collection('interactions')
      .where('decision', '==', 'liked')
      .get(),
    getBlockedUids(db, uid),
  ]);

  const sentCandidateUids = sentInteractionsSnap.docs
    .map((doc) => doc.id)
    .filter((candidateUid) => !blockedUids.has(candidateUid));
  const receivedEntryDocs = receivedSnap.docs.filter((doc) => !blockedUids.has(doc.id));

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
      receivedEntryDocs.map((doc) => db.collection('users').doc(doc.id).get()),
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
    .map((doc, index) => ({doc, likedAt: receivedEntryDocs[index].data().likedAt}))
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
  const [connectionsSnap, blockedUids] = await Promise.all([
    db.collection('connections').where('userIds', 'array-contains', uid).get(),
    getBlockedUids(db, uid),
  ]);

  const matches = await Promise.all(
    connectionsSnap.docs.map(async (doc) => {
      const data = doc.data();
      const otherUid = (data.userIds || []).find((id) => id !== uid);
      if (!otherUid || blockedUids.has(otherUid)) return null;

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

// Keyed by the token itself, so re-registering the same device on every
// app launch is just a harmless overwrite rather than an ever-growing list.
exports.registerFcmToken = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const token = request.data?.token;
  if (typeof token !== 'string' || token.length === 0) {
    throw new HttpsError('invalid-argument', 'Missing token.');
  }

  await getFirestore()
    .collection('users')
    .doc(uid)
    .collection('fcmTokens')
    .doc(token)
    .set({updatedAt: FieldValue.serverTimestamp()});

  return {status: 'ok'};
});

// Called on sign-out so a shared/reused device stops receiving this
// account's pushes once someone else signs in on it.
exports.unregisterFcmToken = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const token = request.data?.token;
  if (typeof token !== 'string' || token.length === 0) {
    throw new HttpsError('invalid-argument', 'Missing token.');
  }

  await getFirestore()
    .collection('users')
    .doc(uid)
    .collection('fcmTokens')
    .doc(token)
    .delete();

  return {status: 'ok'};
});

// Whether uid is allowed into the moderation review queue — checked
// server-side for every review action so a client can never spoof its way
// into reviewer-only capabilities. adminConfig is fully locked down (see
// firestore.rules) — this is the only way to read it.
async function isReviewer(db, uid) {
  const settingsSnap = await db.collection('adminConfig').doc('settings').get();
  const reviewerUids = settingsSnap.data()?.reviewerUids || [];
  return reviewerUids.includes(uid);
}

exports.checkReviewerStatus = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  return {isReviewer: await isReviewer(getFirestore(), uid)};
});

// Every account currently flagged in any way — under_review from
// auto-flagging, or already suspended/banned, included too so a reviewer
// can revisit or undo a past decision — with a summary of the reports
// filed against them. Reporter identity is deliberately left out of what's
// returned; a reason/details/count is enough to judge whether action is
// warranted without exposing who filed a report.
exports.getReviewQueue = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const db = getFirestore();
  if (!(await isReviewer(db, uid))) {
    throw new HttpsError('permission-denied', 'Not authorized.');
  }

  const flaggedSnap = await db
    .collection('users')
    .where('accountStatus', 'in', ['under_review', 'restricted', 'suspended', 'banned'])
    .get();

  const entries = await Promise.all(
    flaggedSnap.docs.map(async (doc) => {
      const data = doc.data();
      const photos = Array.isArray(data.photos) ? data.photos : [];
      const reportsSnap = await db.collection('users').doc(doc.id).collection('reports').get();

      return {
        uid: doc.id,
        name: (data.name || '').toString(),
        age: calculateAge(data.birthDate),
        primaryPhotoUrl: photos.length > 0 ? (photos[0].url || '').toString() : '',
        accountStatus: (data.accountStatus || '').toString(),
        accountStatusMessage: (data.accountStatusMessage || '').toString(),
        accountStatusReason: (data.accountStatusReason || '').toString(),
        suspensionUntil: data.suspensionUntil?.toDate?.().toISOString() ?? null,
        reportCount: reportsSnap.size,
        reports: reportsSnap.docs.map((reportDoc) => ({
          reason: (reportDoc.data().reason || '').toString(),
          details: (reportDoc.data().details || '').toString(),
          createdAt: reportDoc.data().createdAt?.toDate?.().toISOString() ?? null,
        })),
      };
    }),
  );

  return {entries};
});

const BAN_ACTIONS = new Set(['permanent', 'temporary', 'clear']);

// permanent -> banned for good. temporary -> suspended until now+durationDays.
// clear -> restores access, e.g. when a report turns out to be unfounded.
exports.banUser = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const db = getFirestore();
  if (!(await isReviewer(db, uid))) {
    throw new HttpsError('permission-denied', 'Not authorized.');
  }

  const targetUid = request.data?.targetUid;
  const action = request.data?.action;
  const durationDays = request.data?.durationDays;

  if (typeof targetUid !== 'string' || targetUid.length === 0) {
    throw new HttpsError('invalid-argument', 'Missing targetUid.');
  }
  if (!BAN_ACTIONS.has(action)) {
    throw new HttpsError('invalid-argument', 'Invalid action.');
  }

  const targetRef = db.collection('users').doc(targetUid);

  if (action === 'clear') {
    await targetRef.update({
      accountStatus: FieldValue.delete(),
      accountStatusMessage: FieldValue.delete(),
      accountStatusReason: FieldValue.delete(),
      suspensionUntil: FieldValue.delete(),
      restrictionUntil: FieldValue.delete(),
    });
    return {status: 'ok'};
  }

  if (action === 'permanent') {
    await targetRef.update({
      accountStatus: 'banned',
      accountStatusMessage: 'Your account has been permanently banned from LooksMatch.',
      accountStatusReason: 'Violation of community guidelines',
      suspensionUntil: FieldValue.delete(),
      restrictionUntil: FieldValue.delete(),
    });
    return {status: 'ok'};
  }

  if (typeof durationDays !== 'number' || durationDays <= 0) {
    throw new HttpsError('invalid-argument', 'Missing or invalid durationDays.');
  }

  const suspensionUntil = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000);
  await targetRef.update({
    accountStatus: 'suspended',
    accountStatusMessage: `Your account is suspended until ${suspensionUntil.toDateString()}.`,
    accountStatusReason: 'Violation of community guidelines',
    suspensionUntil,
    restrictionUntil: FieldValue.delete(),
  });

  return {status: 'ok'};
});

const REPORT_REASONS = new Set([
  'Inappropriate photos',
  'Harassment or abuse',
  'Fake profile',
  'Spam or scam',
  'Underage user',
  'Other',
]);
const REPORT_AUTO_REVIEW_THRESHOLD = 5;
const REPORT_DETAILS_MAX_LENGTH = 500;

// Reports are keyed by reporter uid, not auto-incrementing — repeat reports
// from the same person overwrite their existing report rather than piling
// up, so the threshold below always means reports from 5 distinct people,
// not 5 taps from one person trying to force a ban.
exports.reportUser = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const reportedUid = request.data?.reportedUid;
  const reason = request.data?.reason;
  const details = (request.data?.details || '').toString().trim().slice(0, REPORT_DETAILS_MAX_LENGTH);

  if (typeof reportedUid !== 'string' || reportedUid.length === 0) {
    throw new HttpsError('invalid-argument', 'Missing reportedUid.');
  }
  if (reportedUid === uid) {
    throw new HttpsError('invalid-argument', 'You can\'t report yourself.');
  }
  if (typeof reason !== 'string' || !REPORT_REASONS.has(reason)) {
    throw new HttpsError('invalid-argument', 'Invalid reason.');
  }

  const db = getFirestore();
  const reportsRef = db.collection('users').doc(reportedUid).collection('reports');

  await reportsRef.doc(uid).set({
    reason,
    details,
    createdAt: FieldValue.serverTimestamp(),
  });

  const reportsSnap = await reportsRef.get();

  if (reportsSnap.size >= REPORT_AUTO_REVIEW_THRESHOLD) {
    const targetSnap = await db.collection('users').doc(reportedUid).get();

    // Don't stomp a status an admin may have already set manually (e.g.
    // upgraded straight to 'banned') just because more reports rolled in.
    if (!targetSnap.data()?.accountStatus) {
      await db.collection('users').doc(reportedUid).update({
        accountStatus: 'under_review',
        accountStatusMessage:
          'Your account has been reported multiple times and is under review by our team.',
        accountStatusReason: 'Multiple user reports',
      });
    }
  }

  return {status: 'ok'};
});

// Blocking writes both directions — blocks/{blockedUid} under the blocker
// (their own list, theirs to undo) and blockedBy/{blockerUid} under the
// blocked person (a read-only signal used purely to filter that person's
// own candidate/like/match queries). This keeps both people mutually
// invisible without ever needing a collection-group query across every
// user's blocks subcollection to answer "who has blocked me?".
exports.blockUser = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const blockedUid = request.data?.blockedUid;
  if (typeof blockedUid !== 'string' || blockedUid.length === 0) {
    throw new HttpsError('invalid-argument', 'Missing blockedUid.');
  }
  if (blockedUid === uid) {
    throw new HttpsError('invalid-argument', 'You can\'t block yourself.');
  }

  const db = getFirestore();
  const createdAt = FieldValue.serverTimestamp();

  await Promise.all([
    db.collection('users').doc(uid).collection('blocks').doc(blockedUid).set({createdAt}),
    db.collection('users').doc(blockedUid).collection('blockedBy').doc(uid).set({createdAt}),
  ]);

  return {status: 'ok'};
});

exports.unblockUser = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const blockedUid = request.data?.blockedUid;
  if (typeof blockedUid !== 'string' || blockedUid.length === 0) {
    throw new HttpsError('invalid-argument', 'Missing blockedUid.');
  }

  const db = getFirestore();

  await Promise.all([
    db.collection('users').doc(uid).collection('blocks').doc(blockedUid).delete(),
    db.collection('users').doc(blockedUid).collection('blockedBy').doc(uid).delete(),
  ]);

  return {status: 'ok'};
});

// Permanently deletes everything tied to this account: the users/{uid} doc
// and all of its subcollections (dailyMatches, interactions, receivedLikes,
// reports filed against them, blocks, blockedBy), scores/profileDetails/
// locations, every connection they're part of (and its messages), their
// uploaded photos in Storage, and finally the Firebase Auth user itself.
//
// Deliberately does NOT scrub this uid out of *other* users' interactions/
// receivedLikes/blocks subcollections — every read path that resolves a
// referenced uid back to a users/{uid} doc already filters on doc.exists
// (see buildDailyMatchesResponse, getLikes, getMatches), so once
// users/{uid} is gone a deleted account silently disappears from everyone
// else's results without needing a separate collection-group cleanup pass.
//
// Runs entirely via the Admin SDK, which is why this doesn't need the
// "recent login" re-authentication the client Firebase Auth SDK would
// otherwise require for self-deletion — a valid ID token is enough.
exports.deleteAccount = onCall({region: 'us-central1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const db = getFirestore();

  const connectionsSnap = await db
    .collection('connections')
    .where('userIds', 'array-contains', uid)
    .get();

  await Promise.all(
    connectionsSnap.docs.map((doc) => db.recursiveDelete(doc.ref)),
  );

  await db.recursiveDelete(db.collection('users').doc(uid));

  await Promise.all([
    db.collection('scores').doc(uid).delete(),
    db.collection('profileDetails').doc(uid).delete(),
    db.collection('locations').doc(uid).delete(),
  ]);

  try {
    await getStorage().bucket().deleteFiles({prefix: `profile_photos/${uid}/`});
  } catch (error) {
    // No photos ever uploaded, or already gone — not fatal, keep going so
    // the account still gets deleted.
    console.log(`No profile photos to delete for ${uid}: ${error.message}`);
  }

  // Deleted last — if anything above throws, the user can still sign in
  // and retry rather than being locked out with a half-cleaned-up account
  // nobody (including them) can act on anymore.
  await getAuth().deleteUser(uid);

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
    const connectionRef = db.collection('connections').doc(event.params.connectionId);

    const [connectionSnap] = await Promise.all([
      connectionRef.get(),
      connectionRef.set(
        {
          lastMessage: (message.text || '').toString(),
          lastMessageAt: message.sentAt || FieldValue.serverTimestamp(),
        },
        {merge: true},
      ),
    ]);

    const senderId = (message.senderId || '').toString();
    const recipientId = (connectionSnap.data()?.userIds || []).find((id) => id !== senderId);
    if (!recipientId) return;

    const senderDoc = await db.collection('users').doc(senderId).get();
    const senderName = (senderDoc.data()?.name || 'Someone').toString();

    await sendPushToUser(db, recipientId, {
      title: senderName,
      body: (message.text || '').toString(),
      data: {type: 'message', connectionId: event.params.connectionId},
      category: 'message',
    });
  },
);
