# NLP Chatbot Implementation Plan
### Guidance Counseling & Mood Tracking App — Rule-Based to NLP Migration

---

## 1. Overview & Goals

**Current state:** Rule-based chatbot in a Flutter app with Firebase (Spark plan, no billing account).

**Target state:** A generative, NLP-powered chatbot that:
- Understands and responds naturally in **English, Tagalog, and Taglish** (code-switching), mirroring whatever the student uses.
- Is **specialized for guidance counseling and mood tracking** — not a generic chatbot — through prompt engineering and grounding, not fine-tuning.
- Stays **free**, meaning it must run entirely on the **Spark plan** (no Blaze/billing account, no paid API tiers).
- Includes a **safety layer** for crisis/self-harm disclosures that does not rely solely on the generative model's judgment.

**Key constraint driving the architecture:** Cloud Functions cannot make outbound calls to external APIs (like the Gemini API) on the Spark plan — that requires Blaze. Since the project must stay on Spark, **all AI logic runs client-side in Flutter**, using the Firebase AI Logic SDK to call the Gemini Developer API directly and safely (API key never exposed, protected by Firebase App Check).

---

## 2. Chosen Stack

| Component | Choice | Why |
|---|---|---|
| LLM | Gemini Developer API (via Firebase AI Logic) | Free tier, no payment method required, strong Tagalog/Taglish support, official Flutter/Dart SDK |
| Integration | Firebase AI Logic SDK (`firebase_ai` Flutter package) | Client-to-Gemini calls without exposing API key, works on Spark plan |
| Security | Firebase App Check | Prevents abuse of the Gemini API key/quota from unauthorized clients |
| Grounding (RAG) | Firestore (existing) | Store counseling resources, FAQs, crisis protocol text, few-shot examples; retrieved at query time |
| Crisis detection | Local Dart logic (on-device, pre- and post-check) | No backend needed; runs before/after the Gemini call |
| Chat history / mood data | Firestore (existing) | Keep current schema/flow, extend as needed for conversation logs |

**Not used for this migration:** Cloud Functions (Blaze-only for external API calls), Vertex AI/Agent Platform Gemini API (requires Blaze), any paid API tier.

---

## 3. High-Level Architecture

```
Student types message in Flutter chat UI
        │
        ▼
[1] Local crisis-keyword pre-check (Dart, on-device)
        │
        ├── If crisis indicators found ──► Show fixed safety response
        │                                   (hotline numbers, human counselor
        │                                    escalation option). Skip Gemini call.
        │                                   Log flagged event to Firestore.
        │
        └── If no crisis indicators ──► continue
                        │
                        ▼
        [2] Retrieve relevant context from Firestore (RAG)
            (matching FAQs, resources, few-shot examples
             based on message content/keywords)
                        │
                        ▼
        [3] Build final prompt:
            system instruction + retrieved context +
            recent conversation history + user message
                        │
                        ▼
        [4] Call Gemini via Firebase AI Logic SDK
                        │
                        ▼
        [5] Local post-check on Gemini's response
            (in case the model surfaces crisis content
             the pre-check missed)
                        │
                        ▼
        [6] Display response in chat UI
                        │
                        ▼
        [7] Save exchange to Firestore (chat history,
            and mood-tracking data if applicable)
```

**Why two crisis checks (pre and post):** The pre-check catches obvious cases before wasting a call. The post-check catches cases where the student's message was ambiguous but Gemini's own response reveals a concern (e.g., the model itself flags distress in its reasoning/response).

---

## 4. System Prompt Design

The system instruction sent with every Gemini call should define, at minimum:

### 4.1 Persona
- A warm, non-judgmental guidance companion for students.
- Explicitly **not** a licensed therapist or counselor — must say so if asked, and should encourage connecting with a real counselor for serious concerns.
- Age-appropriate, supportive, and culturally attuned to Filipino students (values around family, "hiya," indirect communication styles, etc.).

### 4.2 Language behavior
- Detect and mirror the student's language choice per message: respond in Tagalog if they wrote Tagalog, English if English, Taglish if Taglish.
- Code-switching should feel natural, not forced or overly formal — match how Filipino students actually text.
- Default to Taglish if the input is ambiguous or mixed.

### 4.3 Scope boundaries
- Can: listen, validate feelings, offer general coping strategies, help log/reflect on mood, explain what the counseling office offers, answer FAQs about the app/school counseling process.
- Cannot: diagnose conditions, give medical/psychiatric advice, give legal advice, make promises about confidentiality it can't keep, replace a real counselor.
- Off-topic requests (schoolwork help, unrelated chit-chat) should be gently redirected, not fully refused — keep it friendly.

### 4.4 Response style
- Short, conversational turns (2–4 sentences typically) — not essay-length responses.
- Ask one gentle follow-up question at a time rather than interrogating.
- Avoid clinical jargon unless the student uses it first.

### 4.5 Few-shot examples
Include 4–6 example exchanges in the system prompt covering:
- A student expressing exam stress (English).
- A student venting about family issues (Tagalog).
- A student using Taglish casually to ask about their mood log.
- A student asking an FAQ about the counseling office (e.g., "Paano mag-book ng appointment?").
- A borderline emotional disclosure that should prompt gentle check-in questions, not alarm.
- **One example of a crisis-adjacent phrase that should NOT be auto-handled by the model** — used to reinforce that this category should defer to the safety layer, not be a lesson in phrasing crisis language.

*(Exact example wording is best written once real Firestore resource content and school-specific policies are available — placeholder examples should be drafted collaboratively, not invented generically.)*

---

## 5. Firestore Knowledge Base (RAG) Structure

**Goal:** Give Gemini grounded, school-specific context instead of relying purely on general knowledge.

### 5.1 Suggested collections

**`chatbot_knowledge_base`**
- `id`
- `category` (e.g., `faq`, `resource`, `policy`, `hotline`, `example_response`)
- `language` (`en`, `tl`, `taglish`, or `any`)
- `keywords` (array, for simple keyword-matching retrieval)
- `content` (the actual text to inject into context)
- `active` (boolean, so entries can be toggled without deleting)

**`chatbot_crisis_keywords`**
- `id`
- `phrase` or `pattern`
- `severity` (e.g., `high`, `medium`) — allows tiered responses (immediate hotline display vs. gentle check-in)
- `language`

**`chatbot_flagged_events`** (for crisis pre/post-check hits)
- `studentId` (respecting existing privacy/consent model)
- `timestamp`
- `triggerType` (`pre-check` / `post-check`)
- `messageSnippet` (only as much as needed for follow-up, minimize retained sensitive data)
- `reviewedByCounselor` (boolean)

### 5.2 Retrieval approach (kept simple, no paid vector DB needed)
- **Phase 1 (simplest, free):** Keyword/tag matching — pull `chatbot_knowledge_base` entries whose `keywords` overlap with the user's message, cap at ~3–5 entries to keep the prompt small.
- **Phase 2 (optional upgrade, still free):** Use Gemini's embedding model (also on the free tier) to do semantic similarity matching instead of keyword overlap, if keyword matching proves too rigid. This can be added later without changing the overall architecture.

---

## 6. Crisis-Safety Protocol (Critical — Do Not Skip)

This is the most important part of the migration given the app's context.

### 6.1 Principle
The generative model must **never be the sole handler** of a self-harm, suicide, or acute distress disclosure. Detection and response for these cases should be deterministic, not left to the LLM's judgment.

### 6.2 Pre-check (before calling Gemini)
- Run the student's message against `chatbot_crisis_keywords` (and common misspellings/Taglish variants) locally in Dart.
- On a match:
  - Do **not** send the message to Gemini.
  - Display a fixed, pre-written, pre-approved response with crisis hotline numbers and an option to immediately request a human counselor.
  - Log the event to `chatbot_flagged_events`.

### 6.3 Post-check (after receiving Gemini's response)
- Scan Gemini's own output for distress-related language it may have surfaced even if the pre-check didn't catch the original phrasing.
- If flagged, override the display with the same fixed safety response rather than showing Gemini's generated text.

### 6.4 Content of the fixed safety response
To be finalized with your school's actual guidance office — should include:
- A calm, validating opening line.
- National/local crisis hotline numbers (Philippines-specific, e.g., NCMH Crisis Hotline).
- A direct path to flag the school's real counselor (button/action, not just text).
- Reassurance that reaching out is okay and taken seriously.

### 6.5 Data handling
- Flagged events should be visible to authorized school staff only, per your existing privacy/consent framework — this plan does not define your consent policy, only where the technical hook for it belongs.

---

## 7. Firebase App Check Setup

Since API calls now happen directly from the client, App Check is essential to prevent quota abuse:
- Enable App Check in the Firebase console for the project.
- Configure Play Integrity (Android) / App Attest or DeviceCheck (iOS) / reCAPTCHA (Web, if applicable).
- Firebase AI Logic integrates with App Check natively — calls from unverified clients are blocked before reaching the Gemini API.

---

## 8. Migration Steps (Implementation Checklist)

1. **Add dependencies:** `firebase_ai` (or current Firebase AI Logic Flutter package name) to `pubspec.yaml`.
2. **Enable Gemini Developer API** as the provider in Firebase AI Logic setup (Firebase console).
3. **Enable & configure Firebase App Check** for the project.
4. **Populate `chatbot_knowledge_base`** in Firestore with initial FAQs, resources, and crisis hotline info.
5. **Populate `chatbot_crisis_keywords`** with an initial keyword/phrase list (English, Tagalog, Taglish variants) — ideally reviewed with the guidance office.
6. **Write the local crisis pre-check function** (Dart) — simple string/pattern matching against `chatbot_crisis_keywords`.
7. **Write the Firestore retrieval function** for RAG context (keyword-matching first).
8. **Draft and finalize the system prompt** (persona, language behavior, scope, few-shot examples) — collaboratively, using real examples once available.
9. **Implement the Gemini call** via Firebase AI Logic SDK, assembling: system prompt + retrieved context + recent conversation history + user message.
10. **Write the local post-check function** on Gemini's response.
11. **Replace the rule-based chatbot logic** in the existing chat screen/widget with the new pipeline, preserving existing UI and Firestore chat-history writes.
12. **Test systematically:**
    - Pure English input
    - Pure Tagalog input
    - Taglish input
    - FAQ-style questions (should hit RAG correctly)
    - Off-topic questions (should redirect gracefully)
    - Crisis-trigger phrases in all three languages (should never reach Gemini)
    - Ambiguous distress phrasing (tests the post-check)
13. **Review with guidance counseling staff** before rollout — especially the crisis response content and escalation flow.
14. **Monitor usage** against the Gemini Developer API free tier limits (rate limits, daily quota) to catch any need to throttle or queue requests as usage grows.

---

## 9. Open Items / To Be Finalized Together

These are intentionally left as placeholders since they depend on your actual project files, school policies, and content — not something to invent generically:

- [ ] Exact wording of the crisis-safety fixed response (needs guidance office sign-off).
- [ ] Final crisis keyword/phrase list in English, Tagalog, and Taglish.
- [ ] Initial FAQ/resource content for the Firestore knowledge base.
- [ ] Few-shot example conversations for the system prompt.
- [ ] Existing Firestore chat history schema (to confirm how new fields integrate without breaking current mood-tracking features).
- [ ] Consent/privacy policy language covering AI-generated responses and flagged-event logging.
- [ ] Gemini Developer API free-tier rate limits at time of implementation (subject to change — verify current limits before launch).

---

## 10. Next Step

Once you share the current chatbot screen/widget code, `pubspec.yaml`, and Firestore chat/mood schema, the next deliverable will be the actual Dart implementation (crisis-check function, Firestore retrieval function, Gemini call integration, and system prompt) fitted into your existing project structure.
