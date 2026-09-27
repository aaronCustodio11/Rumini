import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Groq-backed reply generation via the Supabase Edge Function `groq-chat`.
///
/// The Groq API key lives only in Supabase Edge Function secrets — it is
/// never shipped to the app or web bundle. The function verifies the caller's
/// Firebase ID token (signed-in students only), rate-limits per user, and
/// holds the system prompt server-side.
class ChatbotAiService {
  ChatbotAiService._();

  // Supabase Edge Function proxy (groq-chat) — holds the Groq API key.
  static const String endpoint =
      'https://bllozhiuxtkhgqjvxsph.supabase.co/functions/v1/groq-chat';

  static const Duration _timeout = Duration(seconds: 45);

  /// Generates the bot reply.
  ///
  /// [history] entries are shaped `{'sender': ..., 'text': ...}` (user, bot
  /// and counselor/staff turns are all forwarded; the proxy maps roles).
  /// Returns `{'text': String, 'follow_up': List<String>?}` or `null` when
  /// the call fails (offline, unauthenticated, quota, proxy error, etc.) so
  /// the caller can fall back to the rule-based matcher.
  static Future<Map<String, dynamic>?> generateReply({
    required String userMessage,
    required List<Map<String, dynamic>> history,
    required List<String> context,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return null;

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'userMessage': userMessage,
              'history': history
                  .map((m) => {
                        'sender': m['sender'],
                        'text': m['text'],
                      })
                  .toList(),
              'context': context,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map) return null;
      final text = (data['text'] ?? '').toString().trim();
      if (text.isEmpty) return null;

      // Suggestion chips the model produced (0-3 short follow-ups).
      final followUp = <String>[];
      if (data['follow_up'] is List) {
        for (final item in (data['follow_up'] as List)) {
          if (item is String &&
              item.trim().isNotEmpty &&
              followUp.length < 3) {
            followUp.add(item.trim());
          }
        }
      }

      return {
        'text': text,
        if (followUp.isNotEmpty) 'follow_up': followUp,
      };
    } catch (_) {
      // Timeout, network error, malformed body, token refresh failure, etc.
      return null;
    }
  }
}
