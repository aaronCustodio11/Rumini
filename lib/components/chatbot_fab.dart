import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rumini/services/crisis_detector.dart';
import 'package:rumini/services/chatbot_ai_service.dart';
import 'package:rumini/services/chatbot_knowledge_service.dart';

class ChatbotFAB extends StatefulWidget {
  const ChatbotFAB({super.key, required Map<String, dynamic> userData});

  @override
  _ChatbotFABState createState() => _ChatbotFABState();
}

String assignedCounselorId = '';

class _ChatbotFABState extends State<ChatbotFAB> {
  bool _isHidden = false;
  final ValueNotifier<List<Map<String, dynamic>>> _messageNotifier =
      ValueNotifier([]);
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;
  StreamSubscription? _messageSubscription; // NEW: Add this line
  String studId = '';
  String userName = 'User';

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  // NEW: Add dispose method to clean up the subscription
  @override
  void dispose() {
    _messageSubscription?.cancel();
    _controller.dispose();
    _messageNotifier.dispose();
    super.dispose();
  }

  void _getCurrentUser() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        studId = user.uid;
      });

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(studId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          final firstName = userData?['firstName'] ?? '';
          final lastName = userData?['lastName'] ?? '';
          assignedCounselorId = userData?['assignedCounselor'] ?? '';

          setState(() {
            userName = '$firstName $lastName'.trim();
            if (userName.isEmpty) userName = 'User';
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }

      await _loadMessages();
      await _checkWelcomeMessageStatus();
      _startMessageListener(); // NEW: Start listening for real-time updates

      // NLP chatbot: load remote crisis keywords + seed knowledge base
      // (both are best-effort and never block the chat UI).
      CrisisDetector.loadRemoteKeywords();
      ChatbotKnowledgeService.ensureSeeded();
    }
  }

  // NEW: Add this method for real-time message updates
  void _startMessageListener() {
    _messageSubscription = FirebaseFirestore.instance
        .collection('Users')
        .doc(studId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
          List<Map<String, dynamic>> loadedMessages = [];
          for (var doc in snapshot.docs) {
            loadedMessages.add(doc.data());
          }
          _messageNotifier.value = loadedMessages;
        });
  }

  Future<void> _checkWelcomeMessageStatus() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(studId)
        .get();

    bool hasSeenWelcome = userDoc.data()?['hasSeenWelcome'] == true;

    if (!hasSeenWelcome) {
      final welcomeMessageText =
          "Hi! I'm your guidance companion chatbot. I can listen, help you "
          "reflect on how you're feeling, and answer questions about the "
          "guidance office. Please note that our conversations are monitored "
          "by System Admins and Counselors to help ensure your safety — and "
          "I'm not a licensed therapist, so for serious concerns I'll always "
          "help you connect with a real counselor. What's on your mind today?";

      _messageNotifier.value = List.from(_messageNotifier.value)
        ..add({'sender': 'Bot', 'typing': true});
      setState(() {
        _isTyping = true;
      });

      await Future.delayed(Duration(seconds: 2));

      _messageNotifier.value = List.from(_messageNotifier.value)
        ..removeWhere((msg) => msg.containsKey('typing'))
        ..add({'sender': 'Bot', 'text': welcomeMessageText});

      _isTyping = false;

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(studId)
          .collection('messages')
          .add({
            'sender': 'Bot',
            'text': welcomeMessageText,
            'timestamp': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance.collection('Users').doc(studId).set({
        'hasSeenWelcome': true,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _loadMessages() async {
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .doc(studId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .get();

    List<Map<String, dynamic>> loadedMessages = [];
    for (var doc in messagesSnapshot.docs) {
      loadedMessages.add(doc.data());
    }

    setState(() {
      _messageNotifier.value = loadedMessages.reversed.toList();
    });
  }

  Future sendMessage({String? prefilled}) async {
    String userMessage = prefilled ?? _controller.text.trim();
    if (userMessage.isEmpty) return;

    _controller.clear();

    // Snapshot the conversation BEFORE appending the new turn — this is what
    // gets sent to the AI proxy as context.
    final history = List<Map<String, dynamic>>.from(_messageNotifier.value);

    // Save user message to Firestore only
    await FirebaseFirestore.instance
        .collection('Users')
        .doc(studId)
        .collection('messages')
        .add({
          'sender': 'User',
          'text': userMessage,
          'timestamp': FieldValue.serverTimestamp(),
        });

    // Show typing indicator using setState
    setState(() {
      _isTyping = true;
    });

    // Run the pipeline while the typing indicator is visible, keeping a
    // minimum "thinking" time so the UI doesn't flicker on fast replies.
    Map<String, dynamic> botResponse;
    try {
      final results = await Future.wait([
        Future.delayed(Duration(milliseconds: 1200)),
        _computeBotResponse(userMessage, history),
      ]);
      botResponse = results[1] as Map<String, dynamic>;
    } catch (e) {
      botResponse = {
        'text':
            "I'm sorry, I didn't understand that. Would you like to send this question to your counselor?",
        'escalate': true,
        'src': 'error',
      };
    }

    // Hide typing indicator
    setState(() {
      _isTyping = false;
    });

    // Save bot response to Firestore WITH follow_up / flags
    Map<String, dynamic> messageData = {
      'sender': 'Bot',
      'text': botResponse['text'] ?? 'Sorry, I didn\'t quite understand that.',
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Suggestion chips (AI-generated or admin-authored)
    if (botResponse['follow_up'] != null) {
      messageData['follow_up'] = botResponse['follow_up'];
    }

    // 🚩 Mark crisis replies so the UI can offer a direct counselor path
    if (botResponse['crisis'] == true) {
      messageData['crisis'] = true;
    }

    // Replies that should always offer the "Contact My Counselor" button
    if (botResponse['escalate'] == true) {
      messageData['escalate'] = true;
    }

    // Which path produced this reply: 'ai' | 'rule' | 'crisis' | 'error'
    if (botResponse['src'] != null) {
      messageData['src'] = botResponse['src'];
    }

    await FirebaseFirestore.instance
        .collection('Users')
        .doc(studId)
        .collection('messages')
        .add(messageData);
  }

  /// NLP chatbot pipeline:
  /// [1] local crisis pre-check → [2] Firestore RAG retrieval →
  /// [3] Groq AI call (via Supabase edge proxy) → [4] local crisis post-check →
  /// [5] rule-based fallback if the AI call fails.
  Future<Map<String, dynamic>> _computeBotResponse(
    String userMessage,
    List<Map<String, dynamic>> history,
  ) async {
    // [1] Crisis pre-check — deterministic, never reaches the model.
    final preCrisis = CrisisDetector.preCheck(userMessage);
    if (preCrisis != null) {
      await CrisisDetector.logFlaggedEvent(
        studentId: studId,
        triggerType: 'pre-check',
        message: userMessage,
        severity: preCrisis.severity,
      );
      return {
        'text': CrisisDetector.fixedSafetyResponse(preCrisis),
        'crisis': true,
        'src': 'crisis',
      };
    }

    // [2] RAG: pull relevant school knowledge base entries.
    final context = await ChatbotKnowledgeService.retrieveContext(userMessage);

    // [3] Groq via the Supabase edge proxy (system prompt lives server-side).
    final aiResult = await ChatbotAiService.generateReply(
      userMessage: userMessage,
      history: history,
      context: context,
    );

    if (aiResult == null) {
      // [5] AI unavailable (offline / quota / proxy error) → rule fallback.
      try {
        final rule = await ChatbotKnowledgeService.ruleFallback(userMessage);
        rule['src'] = 'rule';
        return rule;
      } catch (e) {
        return {
          'text':
              "I'm sorry, I didn't understand that. Would you like to send this question to your counselor?",
          'escalate': true,
          'src': 'error',
        };
      }
    }

    final aiText = aiResult['text'] as String;

    // [4] Post-check on the model's own output.
    final postCrisis = CrisisDetector.postCheck(aiText);
    if (postCrisis != null) {
      await CrisisDetector.logFlaggedEvent(
        studentId: studId,
        triggerType: 'post-check',
        message: aiText,
        severity: postCrisis.severity,
      );
      return {
        'text': CrisisDetector.fixedSafetyResponse(postCrisis),
        'crisis': true,
        'src': 'crisis',
      };
    }

    return {
      'text': aiText,
      'src': 'ai',
      if (aiResult['follow_up'] != null)
        'follow_up': aiResult['follow_up'],
    };
  }

  Future<void> escalateInquiry(String originalMessage) async {
    if (assignedCounselorId.isEmpty) {
      // ✅ ONLY save to Firestore
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(studId)
          .collection('messages')
          .add({
            'sender': 'Bot',
            'text':
                'You don\'t have an assigned counselor yet. Please contact the admin for assistance.',
            'timestamp': FieldValue.serverTimestamp(),
          });
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('inquiry_escalations').add({
        'studentId': studId,
        'studentName': userName,
        'counselorId': assignedCounselorId,
        'inquiry': originalMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'responded': false,
      });

      // ✅ ONLY save to Firestore
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(studId)
          .collection('messages')
          .add({
            'sender': 'Bot',
            'text': 'Your inquiry has been sent to your counselor.',
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error escalating inquiry: $e');
      // ✅ ONLY save to Firestore
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(studId)
          .collection('messages')
          .add({
            'sender': 'Bot',
            'text':
                'Sorry, there was an error sending your question. Please try again.',
            'timestamp': FieldValue.serverTimestamp(),
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          setState(() {
            if (details.primaryVelocity! > 0) {
              _isHidden = true;
            } else if (details.primaryVelocity! < 0) {
              _isHidden = false;
            }
          });
        },
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: _isHidden
              ? FloatingActionButton(
                  key: ValueKey("ArrowButton"),
                  backgroundColor: const Color.fromARGB(255, 114, 192, 77),
                  mini: true,
                  onPressed: () {
                    setState(() {
                      _isHidden = false;
                    });
                  },
                  child: Icon(Icons.arrow_left, color: Colors.black),
                )
              : FloatingActionButton(
                  key: ValueKey("ChatbotButton"),
                  backgroundColor: const Color.fromARGB(255, 114, 192, 77),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return ValueListenableBuilder<
                          List<Map<String, dynamic>>
                        >(
                          valueListenable: _messageNotifier,
                          builder: (context, currentMessages, _) {
                            return ChatbotDialog(
                              messages: currentMessages,
                              controller: _controller,
                              isTyping: _isTyping,
                              userName: userName,
                              onSendMessage: ({String? prefilled}) async {
                                await sendMessage(prefilled: prefilled);
                              },
                              onEscalate: (originalMessage) async {
                                await escalateInquiry(originalMessage);
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                  child: Icon(Icons.chat, color: Colors.black),
                ),
        ),
      ),
    );
  }
}

class ChatbotDialog extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  final TextEditingController controller;
  final bool isTyping;
  final String userName;
  final Function({String? prefilled}) onSendMessage;
  final Function(String) onEscalate;

  const ChatbotDialog({
    super.key,
    required this.messages,
    required this.controller,
    required this.isTyping,
    required this.userName,
    required this.onSendMessage,
    required this.onEscalate,
  });

  @override
  _ChatbotDialogState createState() => _ChatbotDialogState();
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  _TypingIndicatorState createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double t = (_controller.value + (i * 0.2)) % 1.0;
            double opacity = (t < 0.5) ? 1.0 : 0.3;
            double scale = (t < 0.5) ? 1.0 : 0.7;
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _ChatbotDialogState extends State<ChatbotDialog> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, String> _senderInfoCache = {};

  @override
  void didUpdateWidget(covariant ChatbotDialog oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Scroll when messages change OR when typing indicator appears
    if (oldWidget.messages.length != widget.messages.length ||
        oldWidget.isTyping != widget.isTyping) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollToBottom();
        }
      });
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<String> _getDisplayNameForMessage(Map<String, dynamic> message) async {
    final senderId = message['sender'];

    if (senderId == 'User') return widget.userName;
    if (senderId == 'Bot') return 'Bot';

    if (_senderInfoCache.containsKey(senderId)) {
      return _senderInfoCache[senderId]!;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('counId', isEqualTo: senderId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first.data();
        final firstName = userDoc['firstName'] ?? '';
        final lastName = userDoc['lastName'] ?? '';
        final role = userDoc['role'] ?? 'Staff';
        final name = '$firstName $lastName'.trim();

        final displayName = name.isNotEmpty ? '$name ($role)' : role;

        _senderInfoCache[senderId] = displayName;
        return displayName;
      }
    } catch (e) {
      print("Error fetching sender details for ID $senderId: $e");
    }

    _senderInfoCache[senderId] = 'Staff';
    return 'Staff';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollToBottom();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final availableHeight = screenHeight - keyboardHeight;
    final dialogHeight = availableHeight * 0.8;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Container(
          width: mediaQuery.size.width * 0.95,
          constraints: BoxConstraints(maxHeight: dialogHeight),
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF81BF36), Color(0xFFFFFFFF)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chatbot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Flexible(
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount:
                              widget.messages.length +
                              (widget.isTyping
                                  ? 1
                                  : 0), // ← Add typing as extra item
                          itemBuilder: (context, index) {
                            // ✅ Show typing indicator as the LAST item
                            if (widget.isTyping &&
                                index == widget.messages.length) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 8,
                                        bottom: 2,
                                      ),
                                      child: Text(
                                        'Bot',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: EdgeInsets.symmetric(vertical: 4),
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: TypingIndicator(),
                                    ),
                                  ],
                                ),
                              );
                            }
                            // ✅ Regular messages
                            final message = widget.messages[index];

                            return FutureBuilder<String>(
                              future: _getDisplayNameForMessage(message),
                              builder: (context, snapshot) {
                                String displayName = snapshot.hasData
                                    ? snapshot.data!
                                    : '...';
                                bool isUser = message['sender'] == 'User';

                                return Align(
                                  alignment: isUser
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment: isUser
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left: isUser ? 0 : 8,
                                          right: isUser ? 8 : 0,
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          displayName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.56,
                                        ),
                                        margin: EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isUser
                                              ? Colors.green
                                              : message['sender'] == 'Bot'
                                              ? Colors.blue
                                              : Colors.orange,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              message['text'] ?? '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                              ),
                                            ),

                                            // 🚩 Offer the direct counselor path
                                            // on crisis or flagged replies
                                            // (flag-based, not text matching).
                                            if (message['sender'] == 'Bot' &&
                                                (message['crisis'] == true ||
                                                    message['escalate'] == true))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8.0,
                                                ),
                                                child: ElevatedButton.icon(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.white,
                                                        foregroundColor:
                                                            message['crisis'] ==
                                                                    true
                                                                ? Colors.red
                                                                : Colors.blue,
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 8,
                                                            ),
                                                      ),
                                                  icon: Icon(
                                                    Icons.person,
                                                    size: 18,
                                                  ),
                                                  label: Text(
                                                    message['crisis'] == true
                                                        ? 'Talk to My Counselor Now'
                                                        : 'Contact My Counselor',
                                                  ),
                                                  onPressed: () {
                                                    // Get the previous user message
                                                    final messages =
                                                        widget.messages;
                                                    final currentIndex =
                                                        messages.indexOf(
                                                          message,
                                                        );
                                                    String userQuestion = '';

                                                    // Find the user's question (should be right before this bot response)
                                                    if (currentIndex > 0 &&
                                                        messages[currentIndex -
                                                                1]['sender'] ==
                                                            'User') {
                                                      userQuestion =
                                                          messages[currentIndex -
                                                              1]['text'] ??
                                                          '';
                                                    }

                                                    widget.onEscalate(
                                                      userQuestion,
                                                    );
                                                  },
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (message.containsKey('follow_up') &&
                                          message['follow_up'] is List)
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 4,
                                          children: List<Widget>.from(
                                            (message['follow_up'] as List)
                                                .whereType<String>()
                                                .map<Widget>((followUp) {
                                                  return ElevatedButton(
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.white,
                                                          foregroundColor:
                                                              Colors.black,
                                                        ),
                                                    onPressed: () =>
                                                        widget.onSendMessage(
                                                          prefilled: followUp,
                                                        ),
                                                    child: Text(followUp),
                                                  );
                                                }),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 12),
                      // 💬 Always-available counselor path — students should
                      // never have to hunt for help.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue[900],
                            side: BorderSide(
                              color: const Color.fromARGB(255, 25, 118, 210),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(Icons.person_add_alt, size: 18),
                          label: Text('Talk to my counselor'),
                          onPressed: () {
                            // Send along the last thing the student said so
                            // the counselor has context; otherwise a generic
                            // request is escalated.
                            String lastUserMessage = '';
                            for (final m in widget.messages.reversed) {
                              if (m['sender'] == 'User') {
                                lastUserMessage =
                                    (m['text'] ?? '').toString();
                                break;
                              }
                            }
                            if (lastUserMessage.trim().isEmpty) {
                              lastUserMessage =
                                  'Student tapped "Talk to my counselor" in the chatbot.';
                            }
                            widget.onEscalate(lastUserMessage);
                          },
                        ),
                      ),
                      SizedBox(height: 8),
                      SafeArea(
                        child: TextField(
                          controller: widget.controller,
                          decoration: InputDecoration(
                            hintText: "Say what's on your mind :)",
                            filled: true,
                            fillColor: const Color.fromARGB(
                              255,
                              241,
                              241,
                              241,
                            ).withOpacity(0.8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.send, color: Colors.green),
                              onPressed: () => widget.onSendMessage(),
                            ),
                          ),
                          onSubmitted: (_) => widget.onSendMessage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
