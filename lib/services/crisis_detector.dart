import 'package:cloud_firestore/cloud_firestore.dart';

/// ⚠️ PLACEHOLDER CONTENT — MUST BE REVIEWED AND APPROVED BY THE
/// GUIDANCE COUNSELING OFFICE BEFORE PRODUCTION USE.
///
/// Deterministic crisis detection. The generative model must NEVER be the
/// sole handler of a self-harm / suicide / acute distress disclosure.
/// Detection runs twice: once on the student's message (pre-check, before
/// any Gemini call) and once on Gemini's output (post-check).
class CrisisDetector {
  CrisisDetector._();

  // ---------------------------------------------------------------------------
  // Built-in baseline phrases (English, Tagalog, Taglish).
  // These are ALWAYS active, even if Firestore is unreachable, so safety
  // never depends on the network.
  // ---------------------------------------------------------------------------
  static const List<Map<String, String>> _baseline = [
    // --- English (high) ---
    {'phrase': 'kill myself', 'severity': 'high', 'language': 'en'},
    {'phrase': 'killing myself', 'severity': 'high', 'language': 'en'},
    {'phrase': 'end my life', 'severity': 'high', 'language': 'en'},
    {'phrase': 'want to die', 'severity': 'high', 'language': 'en'},
    {'phrase': 'wanna die', 'severity': 'high', 'language': 'en'},
    {'phrase': 'suicide', 'severity': 'high', 'language': 'en'},
    {'phrase': 'commit suicide', 'severity': 'high', 'language': 'en'},
    {'phrase': 'take my own life', 'severity': 'high', 'language': 'en'},
    {'phrase': 'hurt myself', 'severity': 'high', 'language': 'en'},
    {'phrase': 'harm myself', 'severity': 'high', 'language': 'en'},
    {'phrase': 'cut myself', 'severity': 'high', 'language': 'en'},
    {'phrase': 'self harm', 'severity': 'high', 'language': 'en'},
    {'phrase': 'self-harm', 'severity': 'high', 'language': 'en'},
    {'phrase': 'overdose', 'severity': 'high', 'language': 'en'},
    {'phrase': 'no reason to live', 'severity': 'high', 'language': 'en'},
    {'phrase': 'better off dead', 'severity': 'high', 'language': 'en'},
    {'phrase': 'everyone would be better', 'severity': 'high', 'language': 'en'},

    // --- Tagalog / Taglish (high) ---
    {'phrase': 'gusto ko nang mamatay', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'gusto kong mamatay', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'pakamatay', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'kitilin ang buhay', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'saktan ang sarili', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'saktan ko ang sarili', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'ayoko nang mabuhay', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'ayaw ko nang mabuhay', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'mamatay na lang ako', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'wala nang dahilan para mabuhay', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'magpapakamatay', 'severity': 'high', 'language': 'tl'},

    // --- Medium severity (gentle check-in, not automatic hotline) ---
    {'phrase': 'i want to die', 'severity': 'medium', 'language': 'en'},
    {'phrase': 'cant go on', 'severity': 'medium', 'language': 'en'},
    {"phrase": "can't go on", 'severity': 'medium', 'language': 'en'},
    {'phrase': 'give up on life', 'severity': 'medium', 'language': 'en'},
    {'phrase': 'wala nang pag-asa', 'severity': 'medium', 'language': 'tl'},
    {'phrase': 'walang pag asa', 'severity': 'medium', 'language': 'tl'},
    {'phrase': 'hindi ko na kaya', 'severity': 'medium', 'language': 'tl'},
    {'phrase': 'di ko na kaya', 'severity': 'medium', 'language': 'tl'},
    {'phrase': 'pagod na ako sa buhay', 'severity': 'medium', 'language': 'tl'},
    {'phrase': 'tanggapin ko na lang', 'severity': 'medium', 'language': 'tl'},
  ];

  /// Extra phrases loaded from Firestore `chatbot_crisis_keywords`.
  static List<Map<String, String>> _remoteKeywords = [];
  static bool _remoteLoaded = false;

  /// Load additional crisis keywords from Firestore. Failure is non-fatal:
  /// the built-in baseline still applies.
  static Future<void> loadRemoteKeywords() async {
    if (_remoteLoaded) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('chatbot_crisis_keywords')
          .limit(300)
          .get();
      _remoteKeywords = snap.docs.map((d) {
        final data = d.data();
        return {
          'phrase': (data['phrase'] ?? data['pattern'] ?? '').toString().toLowerCase(),
          'severity': (data['severity'] ?? 'high').toString(),
          'language': (data['language'] ?? 'any').toString(),
        };
      }).where((m) => m['phrase']!.isNotEmpty).toList();
      _remoteLoaded = true;
    } catch (e) {
      // Offline / rules denial — keep baseline only.
    }
  }

  static List<Map<String, String>> get _allKeywords =>
      [..._baseline, ..._remoteKeywords];

  /// Pre-check: run the student's message BEFORE calling Gemini.
  /// Returns null when no crisis indicator is found.
  static CrisisMatch? preCheck(String message) =>
      _scan(message, isModelOutput: false);

  /// Post-check: scan Gemini's own output for distress content the
  /// pre-check may have missed.
  static CrisisMatch? postCheck(String response) =>
      _scan(response, isModelOutput: true);

  static CrisisMatch? _scan(String text, {required bool isModelOutput}) {
    final normalized = text.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}\s-]', unicode: true), ' ');
    final collapsed = normalized.replaceAll(RegExp(r'\s+'), ' ');

    CrisisMatch? best;
    for (final entry in _allKeywords) {
      final phrase = entry['phrase']!.toLowerCase();
      if (phrase.isEmpty) continue;
      if (!collapsed.contains(phrase)) continue;

      final severity = entry['severity'] ?? 'high';
      // Post-check only escalates on high-severity hits: model output
      // often contains educational mentions of distress words.
      if (isModelOutput && severity != 'high') continue;

      if (best == null || _rank(severity) > _rank(best.severity)) {
        best = CrisisMatch(
          phrase: phrase,
          severity: severity,
          language: entry['language'] ?? 'any',
        );
      }
    }
    return best;
  }

  static int _rank(String severity) => severity == 'high' ? 2 : 1;

  /// Fixed, pre-approved safety response shown INSTEAD of any AI reply.
  // ⚠️ PLACEHOLDER — replace with the guidance office's approved wording.
  static String fixedSafetyResponse(CrisisMatch match) {
    final urgent = match.severity == 'high';
    if (urgent) {
      return "I'm really glad you told me, and I'm taking this seriously. "
          "You don't have to go through this alone.\n\n"
          "If you are in immediate danger, please reach out now:\n"
          "• NCMH Crisis Hotline — 1553 (toll-free, 24/7)\n"
          "• Emergency — 911\n\n"
          "I've also notified your counselor so a real person can follow up "
          "with you. Would you like to connect with your counselor right now?";
    }
    return "Thank you for sharing that — it takes courage, and I hear you. "
        "Things can feel lighter when you talk to someone.\n\n"
        "If you'd like, I can connect you with your guidance counselor, or "
        "you can call the NCMH Crisis Hotline at 1553 (toll-free) anytime. "
        "Would you like me to reach out to your counselor?";
  }

  /// Log the flagged event so authorized staff can review it.
  /// Only a short snippet is retained, to minimize sensitive data.
  static Future<void> logFlaggedEvent({
    required String studentId,
    required String triggerType,
    required String message,
    required String severity,
  }) async {
    try {
      final snippet = message.length > 140
          ? '${message.substring(0, 140)}…'
          : message;
      await FirebaseFirestore.instance.collection('chatbot_flagged_events').add({
        'studentId': studentId,
        'timestamp': FieldValue.serverTimestamp(),
        'triggerType': triggerType, // 'pre-check' | 'post-check'
        'messageSnippet': snippet,
        'severity': severity,
        'reviewedByCounselor': false,
      });
    } catch (e) {
      // Logging must never block the safety response itself.
    }
  }
}

class CrisisMatch {
  final String phrase;
  final String severity; // 'high' | 'medium'
  final String language;

  const CrisisMatch({
    required this.phrase,
    required this.severity,
    required this.language,
  });

  bool get isHigh => severity == 'high';
}
