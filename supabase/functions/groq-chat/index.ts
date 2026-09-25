// Supabase Edge Function: groq-chat
//
// Secure Groq proxy for the Rumini chatbot. The Groq API key lives ONLY in
// Supabase Edge Function secrets (never in the Flutter app or web bundle).
//
// Security model:
//   1. Requires a valid Firebase Auth ID token (only signed-in students).
//   2. Per-user in-memory rate limit (best effort, 20 req/min).
//   3. CORS locked to the app's web origins (Android APKs ignore CORS).
//   4. Groq key read from Deno.env at request time.
//
// Deploy: supabase functions deploy groq-chat --no-verify-jwt
// Secret: dashboard > Settings > Edge Functions > Secrets > GROQ_API_KEY

import {
  createRemoteJWKSet,
  jwtVerify,
} from "https://esm.sh/jose@5.6.3";

const FIREBASE_PROJECT_ID = "rumini-5f6ff";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const DEFAULT_MODEL = "openai/gpt-oss-120b";
// gpt-oss spends part of the budget on reasoning tokens — keep the cap high
// so the visible reply is never starved (empty content would fail the call).
const MAX_TOKENS = 1600;
const RATE_LIMIT_PER_MINUTE = 20;

const FIREBASE_JWKS = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

// ---------------------------------------------------------------------------
// CORS
// ---------------------------------------------------------------------------
const ALLOWED_ORIGIN_PATTERNS = [
  /^https:\/\/[\w-]+\.web\.app$/,
  /^https:\/\/[\w-]+\.firebaseapp\.com$/,
  /^http:\/\/localhost(:\d+)?$/,
  /^http:\/\/127\.0\.0\.1(:\d+)?$/,
];

function corsHeaders(origin: string | null): Record<string, string> {
  const allowed =
    origin !== null &&
    ALLOWED_ORIGIN_PATTERNS.some((pattern) => pattern.test(origin));
  return {
    "Access-Control-Allow-Origin": allowed ? origin : "",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
    "Content-Type": "application/json",
  };
}

function jsonResponse(
  body: unknown,
  status: number,
  origin: string | null,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders(origin),
  });
}

// ---------------------------------------------------------------------------
// Simple per-user rate limiting (in-memory, best effort per isolate)
// ---------------------------------------------------------------------------
const requestLog = new Map<string, number[]>();

function rateLimited(userId: string): boolean {
  const now = Date.now();
  const windowStart = now - 60_000;
  const hits = (requestLog.get(userId) ?? []).filter((t) => t > windowStart);
  if (hits.length >= RATE_LIMIT_PER_MINUTE) {
    requestLog.set(userId, hits);
    return true;
  }
  hits.push(now);
  requestLog.set(userId, hits);
  if (requestLog.size > 5_000) {
    // crude bound so the map cannot grow forever
    const cutoff = now - 120_000;
    for (const [key, times] of requestLog) {
      if (times.every((t) => t < cutoff)) requestLog.delete(key);
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// System prompt (moved server-side from the Flutter app)
// ---------------------------------------------------------------------------
const SYSTEM_PROMPT = `You are "Kuya/Ate Gabay", the guidance-companion chatbot of Rumini, a campus
mental-health and mood-tracking app for Filipino students. You work inside the
app's chat window.

## Persona
- Warm, non-judgmental, and genuinely supportive — like an older sibling who
  listens well, not a clinician.
- You are NOT a licensed therapist, counselor, or doctor. If asked, say so
  plainly and encourage the student to connect with the school's real guidance
  counselor for serious concerns.
- Culturally attuned to Filipino students: family pressure, "hiya" (shame),
  indirect communication, academic pressure, and financial worries are common
  context. Never dismiss "utang na loob" or family obligations lightly.
- Conversations are monitored by the school's counselors and admins for safety.
  If asked about privacy, be honest about this and about the app's
  confidentiality policy in the reference material.

## Language behavior
- Detect the student's language choice PER MESSAGE and mirror it: reply in
  Tagalog if they wrote Tagalog, English if English, Taglish if Taglish.
- Code-switching must feel natural and casual — match how Filipino students
  actually text. Do not force formal or "translated" phrasing.
- If the input is ambiguous or mixed, default to Taglish.

## Scope
You CAN:
- Listen and validate feelings.
- Offer general, practical coping strategies (one suggestion at a time).
- Help the student reflect on their mood log and how they've been feeling.
- Explain what the guidance office offers and how appointments work.
- Answer FAQs using ONLY the reference material provided in the prompt.
- Gently redirect off-topic requests (schoolwork help, random chit-chat)
  back to wellbeing in a friendly way — never a hard refusal.

You CANNOT:
- Diagnose any condition, or give medical/psychiatric/legal advice.
- Prescribe, recommend, or adjust medication.
- Promise absolute confidentiality.
- Claim to replace a real counselor.
- Create, edit, or delete the student's mood logs.

## Safety (critical)
- If a student expresses self-harm, suicide, or acute distress, do NOT handle
  it yourself. The app has a dedicated safety layer that intercepts those
  messages before you see them. If such a topic reaches you anyway, respond
  with a short, calm, validating line and direct them to the NCMH Crisis
  Hotline (1553) and their guidance counselor. Do not improvise safety plans,
  do not assess lethality, and do not ask for details.

## Response style
- Short, conversational turns: typically 2-4 sentences. No essays.
- Ask ONE gentle follow-up question at a time. Never interrogate.
- Avoid clinical jargon unless the student uses it first.
- Never use markdown formatting, bullet lists, or headers — this renders in a
  simple chat bubble.
- Do not include hotline numbers unless the topic is distress or the student
  asks.

## Output format (strict)
Respond with ONLY a JSON object — no text, no markdown fences, nothing else:
{"text":"<your 2-4 sentence reply>","follow_up":["<suggested reply 1>","<suggested reply 2>"]}
- "text" is your full reply to the student.
- "follow_up" holds 1-3 very short (2-6 word) tap-able suggestions for what
  the student might say next, in the same language as your reply. Make them
  feel like natural next steps in a counseling conversation (e.g. a question
  they'd ask, or a feeling they'd share). Never include the safety/hotline
  advice here.

## Few-shot examples (draft — refine with guidance office)
Each example shows only the content of the "text" field — your actual reply
must still be wrapped in the JSON object from Output format.
1) Student (English): "I have finals next week and I can't sleep at all."
   You: "Finals season is rough, and not sleeping makes everything feel
   heavier. What's keeping your mind up at night — the amount of material,
   or the fear of failing?"

2) Student (Tagalog): "Away kami ng mama ko lagi. Parang wala akong value sa
   bahay."
   You: "Masakit 'yan, lalo na kapag sarili mong nanay ang parang hindi
   nakakakita ng effort mo. Ano madalas pinag-aawayan nyo — studies, chores,
   or something else?"

3) Student (Taglish): "ok lang naman ako pero tbh parang pagod na ko sa lahat
   haha"
   You: "Yung 'ok lang' pero pagod na sa lahat — madalas 'yan hindi na
   ok lang talaga. Anong pinaka-napapagod ka these days, acads or personal?"

4) Student: "Paano mag-book ng appointment?"
   You: "Punta ka lang sa Appointments page, piliin ang counselor at oras na
   available, tapos i-confirm. Notified agad ang counselor, at pwede ka rin
   mag-walk-in sa guidance office during office hours."

5) Student: "Naiisip ko minsan na wala nang kwenta lahat."
   You: "Salamat sa paglapit — hindi biro 'yang nararamdaman mo. Gusto mo
   bang ikwento kung kailan mo 'to nararamdaman most? Pwede rin kitang i-connect
   sa guidance counselor natin kung gusto mo."

6) A phrase that signals crisis (e.g. wanting to end one's life) will be
   intercepted by the app's safety layer BEFORE reaching you. If you ever see
   it, do not give advice — acknowledge briefly and point to 1553 and the
   guidance counselor.`;

// ---------------------------------------------------------------------------
// Request handling
// ---------------------------------------------------------------------------
interface HistoryEntry {
  sender?: unknown;
  text?: unknown;
}

function sanitizeHistory(raw: unknown): { role: string; content: string }[] {
  if (!Array.isArray(raw)) return [];
  const entries = raw
    .slice(-12)
    .filter((item): item is HistoryEntry => typeof item === "object" && item !== null)
    .map((item) => ({
      sender: typeof item.sender === "string" ? item.sender : "",
      text: typeof item.text === "string" ? item.text.slice(0, 2000) : "",
    }))
    .filter((item) => item.text.trim().length > 0);

  const messages: { role: string; content: string }[] = [];
  for (const entry of entries) {
    if (entry.sender === "User") {
      messages.push({ role: "user", content: entry.text });
    } else {
      // Bot AND counselor/staff replies both ground the model — the bot must
      // know when a real counselor already intervened in the conversation.
      messages.push({ role: "assistant", content: entry.text });
    }
  }
  return messages;
}

// ---------------------------------------------------------------------------
// Model output parsing — the model is asked for {"text","follow_up"} JSON;
// if it disobeys (or wraps the JSON in fences), degrade gracefully to plain
// text with no chips rather than failing the turn.
// ---------------------------------------------------------------------------
function parseModelOutput(raw: string): { text: string; followUp: string[] } {
  const cleaned = raw
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "");
  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");
  if (start !== -1 && end > start) {
    try {
      const obj = JSON.parse(cleaned.slice(start, end + 1));
      if (typeof obj?.text === "string" && obj.text.trim()) {
        const followUp = Array.isArray(obj.follow_up)
          ? obj.follow_up
              .filter(
                (f: unknown): f is string =>
                  typeof f === "string" && f.trim().length > 0,
              )
              .slice(0, 3)
              .map((f: string) => f.trim().slice(0, 80))
          : [];
        return { text: obj.text.trim(), followUp };
      }
    } catch {
      // Not valid JSON after all — fall through to plain text.
    }
  }
  return { text: cleaned, followUp: [] };
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405, origin);
  }

  // --- 1. Verify the Firebase ID token (signed-in students only) ----------
  const authHeader = req.headers.get("authorization") ?? "";
  const idToken = authHeader.startsWith("Bearer ")
    ? authHeader.slice("Bearer ".length)
    : "";
  if (!idToken) {
    return jsonResponse({ error: "Missing Firebase ID token" }, 401, origin);
  }

  let userId: string;
  try {
    const { payload } = await jwtVerify(idToken, FIREBASE_JWKS, {
      issuer: `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`,
      audience: FIREBASE_PROJECT_ID,
    });
    userId = payload.sub;
    if (!userId) throw new Error("missing sub");
  } catch {
    return jsonResponse({ error: "Invalid Firebase ID token" }, 401, origin);
  }

  // --- 2. Rate limit -------------------------------------------------------
  if (rateLimited(userId)) {
    return jsonResponse({ error: "Too many requests" }, 429, origin);
  }

  // --- 3. Validate body ----------------------------------------------------
  let userMessage = "";
  let history: { role: string; content: string }[] = [];
  let context: string[] = [];
  try {
    const body = await req.json();
    userMessage =
      typeof body.userMessage === "string" ? body.userMessage.slice(0, 4000) : "";
    history = sanitizeHistory(body.history);
    context = Array.isArray(body.context)
      ? body.context
          .filter((item): item is string => typeof item === "string")
          .slice(0, 5)
          .map((item) => item.slice(0, 3000))
      : [];
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400, origin);
  }

  if (userMessage.trim().length === 0) {
    return jsonResponse({ error: "Empty message" }, 400, origin);
  }

  const lastMessage = history[history.length - 1];
  const alreadyPresent =
    lastMessage?.role === "user" && lastMessage.content === userMessage;
  if (!alreadyPresent) history.push({ role: "user", content: userMessage });

  const messages: { role: string; content: string }[] = [];
  if (context.length > 0) {
    messages.push({
      role: "system",
      content:
        "Reference material from the school knowledge base (use only if " +
        "relevant, do not quote verbatim unless asked):\n" +
        context.map((item) => `- ${item}`).join("\n"),
    });
  }
  messages.push({ role: "system", content: SYSTEM_PROMPT });
  messages.push(...history);

  // --- 4. Call Groq --------------------------------------------------------
  const groqKey = Deno.env.get("GROQ_API_KEY");
  if (!groqKey) {
    return jsonResponse(
      { error: "Server configuration error: GROQ_API_KEY not set" },
      500,
      origin,
    );
  }

  let groqResponse: Response;
  try {
    groqResponse = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${groqKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("GROQ_MODEL") ?? DEFAULT_MODEL,
        messages,
        max_tokens: MAX_TOKENS,
        temperature: 0.7,
      }),
      signal: AbortSignal.timeout(30_000),
    });
  } catch (error) {
    console.error("Groq request failed:", error);
    return jsonResponse({ error: "Upstream AI request failed" }, 502, origin);
  }

  if (!groqResponse.ok) {
    const detail = await groqResponse.text().catch(() => "");
    console.error(`Groq error ${groqResponse.status}: ${detail}`);
    if (groqResponse.status === 429) {
      return jsonResponse({ error: "AI rate limit reached" }, 429, origin);
    }
    return jsonResponse({ error: "Upstream AI error" }, 502, origin);
  }

  try {
    const data = await groqResponse.json();
    const raw: string = data?.choices?.[0]?.message?.content ?? "";
    const parsed = parseModelOutput(raw);
    if (!parsed.text.trim()) {
      return jsonResponse({ error: "Empty model response" }, 502, origin);
    }
    return jsonResponse(
      {
        text: parsed.text.trim(),
        ...(parsed.followUp.length > 0 ? { follow_up: parsed.followUp } : {}),
      },
      200,
      origin,
    );
  } catch (error) {
    console.error("Failed to parse Groq response:", error);
    return jsonResponse({ error: "Malformed upstream response" }, 502, origin);
  }
});
