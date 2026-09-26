import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore knowledge base access for the chatbot.
///
/// Responsibilities:
///  * [retrieveContext] — Phase 1 keyword/tag RAG retrieval (cap ~5 entries)
///  * [ruleFallback] — the original keyword-matcher, used when the AI proxy
///    is unavailable (offline, quota, proxy error)
///  * [ensureSeeded] — one-time seed of placeholder FAQs / crisis hotlines
class ChatbotKnowledgeService {
  ChatbotKnowledgeService._();

  static const int maxContextEntries = 5;

  // ---------------------------------------------------------------------------
  // RAG retrieval (Phase 1: keyword overlap, free, no vector DB)
  // ---------------------------------------------------------------------------
  static Future<List<String>> retrieveContext(String message) async {
    final normalized = message.toLowerCase();
    final tokens = _tokenize(normalized);
    final scored = <_ScoredEntry>[];

    try {
      // (a) Dedicated knowledge base collection.
      final snap = await FirebaseFirestore.instance
          .collection('chatbot_knowledge_base')
          .limit(200)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['active'] == false) continue;

        final content = (data['content'] ?? '').toString();
        if (content.isEmpty) continue;

        final keywords = _stringList(data['keywords']);
        final title = (data['title'] ?? data['category'] ?? '').toString();

        final score = _score(normalized, tokens, keywords, title);
        if (score > 0) scored.add(_ScoredEntry(score, content));
      }
    } catch (e) {
      // Offline — continue with whatever else we can reach.
    }

    try {
      // (b) Admin-managed rule responses also ground the model, so edits in
      //     the existing Chatbot admin page feed straight into the NLP bot.
      final rules =
          await FirebaseFirestore.instance.collection('chatbot_responses').get();

      for (final doc in rules.docs) {
        final content = (doc['response'] ?? '').toString();
        if (content.isEmpty) continue;

        final score = _score(
          normalized,
          tokens,
          _stringList(doc['keywords']),
          (doc['title'] ?? '').toString(),
        );
        if (score > 0) scored.add(_ScoredEntry(score, content));
      }
    } catch (e) {
      // Offline — ignore.
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    // De-duplicate identical entries before capping.
    final seen = <String>{};
    final result = <String>[];
    for (final entry in scored) {
      if (seen.add(entry.content)) result.add(entry.content);
      if (result.length >= maxContextEntries) break;
    }
    return result;
  }

  static int _score(
    String normalized,
    Set<String> tokens,
    List<String> keywords,
    String title,
  ) {
    var score = 0;
    for (final kw in keywords) {
      final k = kw.toLowerCase();
      if (k.isEmpty) continue;
      if (normalized.contains(k)) score += 2;
      if (tokens.contains(k)) score += 1;
    }
    final t = title.toLowerCase();
    if (t.isNotEmpty && normalized.contains(t)) score += 1;
    return score;
  }

  // ---------------------------------------------------------------------------
  // Rule-based fallback (original behaviour) — used when the AI call fails
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> ruleFallback(String message) async {
    final firestore = FirebaseFirestore.instance;
    final responses = await firestore.collection('chatbot_responses').get();

    List<Map<String, dynamic>> matchedResponses = [];
    int maxMatches = 0;

    for (var doc in responses.docs) {
      final keywords = _stringList(doc['keywords']);
      int matches = 0;

      for (var keyword in keywords) {
        if (message.trim().toLowerCase().contains(keyword.toLowerCase())) {
          matches++;
        }
      }

      if (matches > 0 && matches >= maxMatches) {
        if (matches > maxMatches) {
          matchedResponses.clear();
        }
        matchedResponses.add({
          'text': doc['response'] ?? 'No response found',
          'title': doc['title'] ?? 'Suggested Topic',
          'follow_up': doc.data().containsKey('follow_up')
              ? List<String>.from(
                  (doc['follow_up'] as List).whereType<String>(),
                )
              : null,
        });
        maxMatches = matches;
      }
    }

    if (matchedResponses.isEmpty) {
      return {
        'text':
            "I'm sorry, I didn't understand that. Would you like to send this question to your counselor?",
        'escalate': true,
      };
    }

    // Single best match — the student-facing "pick a response" dialog was
    // removed; ties resolve to the first-authored entry with the highest
    // keyword match count.
    return matchedResponses.first;
  }

  // ---------------------------------------------------------------------------
  // One-time seeding of the knowledge base + crisis keywords
  // ---------------------------------------------------------------------------
  static bool _seeded = false;

  static Future<void> ensureSeeded() async {
    if (_seeded) return;
    _seeded = true;

    try {
      final firestore = FirebaseFirestore.instance;
      final kbSnap =
          await firestore.collection('chatbot_knowledge_base').limit(1).get();
      if (kbSnap.docs.isEmpty) {
        final batch = firestore.batch();
        for (final entry in ChatbotSeedData.knowledgeBase) {
          final ref = firestore.collection('chatbot_knowledge_base').doc();
          batch.set(ref, {...entry, 'timestamp': FieldValue.serverTimestamp()});
        }
        await batch.commit();
      }

      final crisisSnap =
          await firestore.collection('chatbot_crisis_keywords').limit(1).get();
      if (crisisSnap.docs.isEmpty) {
        final batch = firestore.batch();
        for (final entry in ChatbotSeedData.crisisKeywords) {
          final ref = firestore.collection('chatbot_crisis_keywords').doc();
          batch.set(ref, entry);
        }
        await batch.commit();
      }
    } catch (e) {
      // Seeding is best-effort; the app still works without it.
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  static Set<String> _tokenize(String text) => text
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.length > 2)
      .toSet();

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.whereType<String>().toList();
    return const [];
  }
}

class _ScoredEntry {
  final int score;
  final String content;
  _ScoredEntry(this.score, this.content);
}

/// ⚠️ PLACEHOLDER CONTENT — replace with the guidance office's approved
/// FAQs, school-specific policies and crisis hotline details.
class ChatbotSeedData {
  ChatbotSeedData._();

  static final List<Map<String, dynamic>> knowledgeBase = [
    {
      'category': 'hotline',
      'title': 'Crisis hotlines',
      'language': 'any',
      'keywords': [
        'crisis',
        'hotline',
        'emergency',
        'help now',
        'lifeline',
        'ncmh',
      ],
      'active': true,
      'content':
          'If this is an emergency, kindly call the NCMH Hotlines: '
          '09178998727 / (02) 78988727 / 1553. Counseling are scheduled from '
          '9:00am-2:00pm. Pls wait for the counselor to message you. '
          'Thank you very much! '
          'If a student is in immediate danger, always surface these numbers '
          'and offer to connect them with their guidance counselor.',
    },
    {
      'category': 'faq',
      'title': 'How to book an appointment',
      'language': 'any',
      'keywords': [
        'appointment',
        'book',
        'schedule',
        'paano mag book',
        'reservation',
        'sessions',
      ],
      'active': true,
      'content':
          'Students can book a counseling appointment through the app\'s '
          'Appointments page. Choose an available counselor and time slot, '
          'then confirm. The counselor is notified and can approve or '
          'reschedule. Walk-ins at the guidance office are also accommodated '
          'during office hours.',
    },
    {
      'category': 'faq',
      'title': 'Confidentiality policy',
      'language': 'any',
      'keywords': [
        'confidential',
        'privacy',
        'secret',
        'sinong makakakita',
        'public',
      ],
      'active': true,
      'content':
          'Counseling conversations are confidential between the student and '
          'their counselor, except where there is risk of harm to the student '
          'or others, or where the law requires disclosure. Chat logs in this '
          'app are visible to the student, their assigned counselor, and '
          'authorized system admins for support and safety purposes. '
          'Never promise absolute confidentiality.',
    },
    {
      'category': 'faq',
      'title': 'What the guidance office offers',
      'language': 'any',
      'keywords': [
        'guidance',
        'counseling',
        'office',
        'services',
        'tulong',
        'gabay',
      ],
      'active': true,
      'content':
          'The guidance office offers individual counseling sessions, '
          'stress and study-skills support, crisis support, referrals, and '
          'psychoeducational materials available in the app. Counselors help '
          'students work through personal, academic, and social concerns.',
    },
    {
      'category': 'faq',
      'title': 'How to log mood',
      'language': 'any',
      'keywords': [
        'mood',
        'mood log',
        'moodtracker',
        'mag log',
        'feelings',
        'how are you feeling',
      ],
      'active': true,
      'content':
          'Students log their mood from the Mood Tracker page: pick how they '
          'feel, optionally add a note, and save. Entries appear on the mood '
          'calendar and in trends. The bot may discuss mood entries but must '
          'never create, edit, or delete them.',
    },
    {
      'category': 'resource',
      'title': 'General coping strategies',
      'language': 'any',
      'keywords': [
        'stress',
        'anxiety',
        'coping',
        'exam',
        'nervous',
        'relax',
        'calm',
        'takot',
        'kaba',
      ],
      'active': true,
      'content':
          'Gentle, general coping ideas: slow breathing (inhale 4s, hold 4s, '
          'exhale 6s), short movement or stretching breaks, breaking tasks '
          'into small steps, sleeping and eating regularly, and talking to '
          'someone you trust. Offer one suggestion at a time, not a lecture. '
          'These are not substitutes for professional help.',
    },
    {
      'category': 'policy',
      'title': 'Bot limitations',
      'language': 'any',
      'keywords': ['are you a robot', 'are you human', 'therapist', 'doctor'],
      'active': true,
      'content':
          'The bot is a support companion, not a licensed therapist, '
          'counselor, or doctor. It must say so if asked and encourage '
          'connecting with the real guidance counselor for serious concerns.',
    },
  ];

  static final List<Map<String, dynamic>> crisisKeywords = [
    {'phrase': 'kill myself', 'severity': 'high', 'language': 'en'},
    {'phrase': 'end my life', 'severity': 'high', 'language': 'en'},
    {'phrase': 'suicide', 'severity': 'high', 'language': 'en'},
    {'phrase': 'hurt myself', 'severity': 'high', 'language': 'en'},
    {'phrase': 'self harm', 'severity': 'high', 'language': 'en'},
    {'phrase': 'gusto ko nang mamatay', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'pakamatay', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'ayoko nang mabuhay', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'saktan ang sarili', 'severity': 'high', 'language': 'tl'},
    {'phrase': 'hindi ko na kaya', 'severity': 'medium', 'language': 'tl'},
    {'phrase': 'wala nang pag-asa', 'severity': 'medium', 'language': 'tl'},
  ];
}
