# Returning to Rumini — full checklist

> Repo state (as of 2026-09-27): history was **rewritten to a single clean commit `5eb1efa`**
> on `main` + `NLPDeployment`. No secrets in git. Firebase client config is **not** in git
> (see Setup below). Old history exists only on the local branch `backup/pre-clean` — **never push it**.

---

## 0. PENDING security catch-up (do this first, before anything else)

The Gmail app password was once public on GitHub. Until these steps are done, password-reset
emails will break as soon as you rotate.

1. **Rotate the app password**
   Google Account → Security → 2-Step Verification → **App passwords** → delete the old one →
   create a new 16-character password → save it somewhere safe (password manager).
2. **Store it as a Firebase secret** (from the project root):
   ```sh
   firebase functions:secrets:set GMAIL_APP_PASSWORD
   # paste the NEW password when prompted
   ```
3. **Redeploy the functions** (the live function still embeds the old password):
   ```sh
   cd functions
   npm install
   firebase deploy --only functions
   ```
4. **Test**: trigger "Forgot password" OTP email in the app → email arrives.
5. **Optional hardening**
   - Firebase console → project rumini-5f6ff → Settings → API keys → add restrictions
     (Android: package `...` + SHA-1; Web: HTTP referrers).
   - Review Firestore security rules.
   - Close the 2 stale pull requests on GitHub if still open.
6. **Only after rotation worked**, delete the local refs that contain the old password:
   ```sh
   git branch -D backup/pre-clean
   git stash drop        # optional, old WIP backup
   ```

---

## 1. Fresh clone / new machine setup

**Prerequisites**: Git, Flutter SDK (project built with 3.44.x), Node.js + npm,
Firebase CLI (`npm i -g firebase-tools`), FlutterFire CLI
(`dart pub global activate flutterfire_cli`).

```sh
git clone https://github.com/aaronCustodio11/Rumini.git
cd Rumini
```

**Restore the 2 credential files that are intentionally NOT in git:**

1. `lib/firebase_options.dart` — run `flutterfire configure` (pick project `rumini-5f6ff`),
   or copy the file from another machine that has it.
2. `android/app/google-services.json` — download from
   Firebase Console → Project settings → Your apps → **Android app** → download
   `google-services.json` → put it in `android/app/`.

Then:
```sh
flutter pub get
flutter run            # or: flutter build web --release / flutter build apk --release
```

---

## 2. Day-to-day work (existing checkout)

```sh
git status                 # should be clean; on branch NLPDeployment
git pull
flutter pub get            # after any pubspec change
```

**Verification baselines (don't chase legacy lints):**

| Check | Expected |
|---|---|
| `flutter analyze` | **0 errors**; ~547 issues / 21 warnings (pre-existing, leave alone) |
| `flutter test` | `crisis_detector_test` **10/10**; `widget_test` **always fails** (template test — ignore or delete it) |
| `cd functions && npx tsc -p tsconfig.json --noEmit` | exit 0 |

---

## 3. Building & deploying

**Web (Firebase Hosting)**:
```sh
flutter build web --release
firebase deploy --only hosting          # live at https://rumini-5f6ff.web.app
```

**Android APK** (outputs → `build/app/outputs/flutter-apk/`):
```sh
flutter build apk --release             # fat APK
flutter build apk --release --split-per-abi   # smaller per-CPU APKs
```
⚠️ **Signing**: release builds currently sign with this machine's **debug keystore**.
APKs built on this machine update-install over existing installs. Building on a **different**
machine produces a different signature → Android will refuse the update; users must
uninstall first (loses their local data). For real distribution, set up a dedicated
release keystore (`key.properties`, gitignored) + `signingConfig release` — note switching
keystores also requires a one-time uninstall.

**Cloud Functions**: see step 0.3 (`npm install` first — `node_modules` is not in git).

**Supabase Edge Function (`groq-chat`)**:
- Code lives in `supabase/functions/groq-chat/index.ts`.
- Secrets (dashboard → Edge Functions → Secrets, or CLI):
  `GROQ_API_KEY` (required), `GROQ_MODEL` (optional, default `openai/gpt-oss-120b`).
- Deploy via Supabase dashboard or `supabase functions deploy groq-chat --project-ref bllozhiuxtkhgqjvxsph`.
- **Keep-alive**: cron-job.org fires a daily GET at
  `https://bllozhiuxtkhgqjvxsph.supabase.co/functions/v1/groq-chat` (must return `200 {"ok":true,...}`).
  If the pinger stops → project pauses after ~7 days → resume free from the warning email
  (within 90 days). The app degrades gracefully to the rule-based chatbot meanwhile.

---

## 4. Git hygiene (how the repo stays clean)

**Always work on `NLPDeployment`, then merge into `main`:**
```sh
git checkout main && git pull
git merge NLPDeployment
git push
git checkout NLPDeployment
```

**NEVER commit (all are gitignored — verify `git status` never lists them):**
- `lib/firebase_options.dart`, `android/app/google-services.json` (credentials)
- `.idea/`, `*.iml`, `cors.json`, `.firebase/` (junk)
- `.dart_tool/`, `build/`, `functions/node_modules/` (regenerable)

**NEVER put secrets in code** — runtime secrets go in:
- Functions → Firebase **Secret Manager** (`defineSecret`, see `functions/src/index.ts`)
- Supabase → Edge Function **Secrets**
- Flutter app → nothing secret should ever live client-side; the Supabase *publishable*
  key and Firebase client API keys are public by design.

**Pre-push scan (run before every push):**
```sh
git diff origin/main..HEAD -U0 | Select-String -Pattern 'AIza|gsk_|sb_secret|service_role|pass\s*:\s*["'']|BEGIN .*PRIVATE'
```
Must return nothing. Then `flutter analyze` (0 errors) + `flutter test`.

**Push only explicit refs — never `git push --all` / `--mirror`**
(only until `backup/pre-clean` is deleted — it contains the old leaked password).

---

## 5. Service map

| Service | ID / URL | Notes |
|---|---|---|
| GitHub | `aaronCustodio11/Rumini` (public) | branches: `main`, `NLPDeployment` |
| Firebase | `rumini-5f6ff` | Hosting `rumini-5f6ff.web.app`, Auth, Firestore, Functions |
| Supabase | `bllozhiuxtkhgqjvxsph` | Edge fn `groq-chat` → Groq model `openai/gpt-oss-120b` |
| Pinger | cron-job.org | daily health GET, keeps Supabase awake |
| Email | `rumini.site@gmail.com` | Gmail **app password** via Secret Manager (never in code) |

**Key source files**: `lib/services/chatbot_ai_service.dart` (function URL),
`supabase/functions/groq-chat/index.ts` (system prompt, auth, rate limit, health GET),
`lib/services/crisis_detector.dart` (rule fallback + tests),
`lib/pages(admin)/chatbot_ad.dart` (admin KB tab).

---

## 6. Known gotchas

- **OneDrive locks** (this repo lives in OneDrive): builds fail with file-in-use errors →
  `android\gradlew.bat --stop`, kill stray `dart`/`java` processes, then retry;
  worst case: `attrib -r -h -s <dir> /s /d` + `cmd /c rmdir /s /q <dir>`.
- **Kotlin Gradle plugin pinned to 2.4.20** (`android/settings.gradle.kts`) — firebase_auth
  requires Kotlin metadata ≥ 2.3.0; don't downgrade. `jvmTarget` uses the new
  `kotlin { compilerOptions { ... } }` DSL.
- **Web-only Dart** (js_interop etc.) must use conditional imports:
  `import 'x_web.dart' if (dart.library.io) 'x_android.dart';` — see
  `lib/pages(admin)/userdashboard/dashboard_web.dart` / `dashboard_android.dart`,
  `lib/utils(emo)/pdf_downloader_web.dart`.
- **Free tiers**: Firebase Spark plan (no paid background work) + Supabase free (auto-pause).
- **9 orphaned Dart files** were left in place (never approved for deletion):
  `lib/components/consent.dart`, `lib/pages(admin)/monitoring/monitorSt.dart` + its 4 children
  (`analytic_Emotion.dart`, `analytic_Mood.dart`, `calendarEmotion.dart`, `calendarMood.dart`),
  `lib/pages(admin)/templates/announceTemp.dart`, `lib/pages(user)/forms/already.dart`,
  `lib/pages(user)/forms/questionaires.dart`. They're unreachable from `main.dart` —
  delete them whenever you like (that would also clear ~8 analyzer warnings).
- **Chatbot loading-spinner bug** (known, cosmetic): in `chatbot_ad.dart` the dialog declares
  `isLoading` inside the StatefulBuilder so it resets each rebuild — the spinner/`Saving...`
  state never shows. Fix = move the declaration above `showDialog` if you ever care.
- **APK deliverables** live in `build/app/outputs/flutter-apk/` (gitignored — not on GitHub).
