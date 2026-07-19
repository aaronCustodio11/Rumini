import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatbotFAB extends StatefulWidget {
  const ChatbotFAB({super.key, required Map<String, dynamic> userData});

  @override
  _ChatbotFABState createState() => _ChatbotFABState();
}

class _ChatbotFABState extends State<ChatbotFAB> {
  bool _isHidden = false;
  String assignedCounselorId = '';
  final ValueNotifier<List<Map<String, dynamic>>> _messageNotifier =
      ValueNotifier([]);
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;
  int _dotIndex = 0;
  Timer? _dotTimer;
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
    _dotTimer?.cancel();
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
          "Hello! I'm your mental health chatbot. I'm here to provide support and guidance. What can I do for you?";

      _messageNotifier.value = List.from(_messageNotifier.value)
        ..add({'sender': 'Bot', 'typing': true});
      setState(() {
        _isTyping = true;
      });

      _dotTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
        setState(() {
          _dotIndex = (_dotIndex + 1) % 3;
        });
      });

      await Future.delayed(Duration(seconds: 2));

      _messageNotifier.value = List.from(_messageNotifier.value)
        ..removeWhere((msg) => msg.containsKey('typing'))
        ..add({'sender': 'Bot', 'text': welcomeMessageText});

      _isTyping = false;
      _dotTimer?.cancel();

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
  
  _dotTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
    setState(() {
      _dotIndex = (_dotIndex + 1) % 3;
    });
  });

  await Future.delayed(Duration(seconds: 2));
  var botResponse = await getBotResponse(userMessage);

  // Hide typing indicator
  setState(() {
    _isTyping = false;
  });
  _dotTimer?.cancel();

  if (botResponse.containsKey('responses')) {
    showResponseOptions(botResponse['responses']);
  } else {
    // ✅ Save bot response to Firestore WITH follow_up field
    Map<String, dynamic> messageData = {
      'sender': 'Bot',
      'text': botResponse['text'] ?? 'Sorry, I didn\'t quite understand that.',
      'timestamp': FieldValue.serverTimestamp(),
    };
    
    // ✅ Add follow_up if it exists
    if (botResponse.containsKey('follow_up') && botResponse['follow_up'] != null) {
      messageData['follow_up'] = botResponse['follow_up'];
    }
    
    await FirebaseFirestore.instance
        .collection('Users')
        .doc(studId)
        .collection('messages')
        .add(messageData);
  }
}

void showResponseOptions(List<Map<String, dynamic>> matchedResponses) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(
          "Multiple responses found",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Please choose the response you want based on your inquiry:",
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 10),
            ...matchedResponses.map((response) {
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    
                    // ✅ Build message data with follow_up
                    Map<String, dynamic> messageData = {
                      'sender': 'Bot',
                      'text': response['text'] ?? 'No response found',
                      'timestamp': FieldValue.serverTimestamp(),
                    };
                    
                    // ✅ Add follow_up if it exists
                    if (response.containsKey('follow_up') && response['follow_up'] != null) {
                      messageData['follow_up'] = response['follow_up'];
                    }
                    
                    // Save to Firestore with follow_up
                    FirebaseFirestore.instance
                        .collection('Users')
                        .doc(studId)
                        .collection('messages')
                        .add(messageData);

                    setState(() {
                      _isTyping = false;
                    });
                  },
                  child: Text(response['text'] ?? 'Suggested Response'),
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

Future<Map<String, dynamic>> getBotResponse(String message) async {
  final firestore = FirebaseFirestore.instance;
  final responses = await firestore.collection('chatbot_responses').get();

  List<Map<String, dynamic>> matchedResponses = [];
  int maxMatches = 0;

  for (var doc in responses.docs) {
    final keywords = List<String>.from(doc['keywords']);
    int matches = 0;

    for (var keyword in keywords) {
      if (message.trim().toLowerCase().contains(keyword.toLowerCase())) {
        matches++;
      }
    }

    if (matches > 0) {
      if (matches >= maxMatches) {
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
  }

  if (matchedResponses.isEmpty) {
    // Return a CONSISTENT message that we can check for later
    return {
      'text':
          "I'm sorry, I didn't understand that. Would you like to send this question to your counselor?",
    };
  }

  if (matchedResponses.length == 1) {
    return matchedResponses[0];
  }

  return {'responses': matchedResponses};
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
      'text': 'You don\'t have an assigned counselor yet. Please contact the admin for assistance.',
      'timestamp': FieldValue.serverTimestamp(),
    });
    return;
  }

  try {
    await FirebaseFirestore.instance
        .collection('inquiry_escalations')
        .add({
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
      'text': 'Sorry, there was an error sending your question. Please try again.',
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
                        return ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: _messageNotifier,
                          builder: (context, currentMessages, _) {
                            return ChatbotDialog(
                              messages: currentMessages,
                              controller: _controller,
                              isTyping: _isTyping,
                              dotIndex: _dotIndex,
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
  final int dotIndex;
  final String userName;
  final Function({String? prefilled}) onSendMessage;
  final Function(String) onEscalate;

  const ChatbotDialog({
    super.key,
    required this.messages,
    required this.controller,
    required this.isTyping,
    required this.dotIndex,
    required this.userName,
    required this.onSendMessage,
    required this.onEscalate,
  });

  @override
  _ChatbotDialogState createState() => _ChatbotDialogState();
}

class TypingIndicator extends StatefulWidget {
  final int dotIndex;
  const TypingIndicator({super.key, required this.dotIndex});

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
    itemCount: widget.messages.length + (widget.isTyping ? 1 : 0), // ← Add typing as extra item
    itemBuilder: (context, index) {
      // ✅ Show typing indicator as the LAST item
      if (widget.isTyping && index == widget.messages.length) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 8, bottom: 2),
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
                child: TypingIndicator(dotIndex: widget.dotIndex),
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
          String displayName = snapshot.hasData ? snapshot.data! : '...';
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
    maxWidth: MediaQuery.of(context).size.width * 0.56,
  ),
  margin: EdgeInsets.symmetric(vertical: 4),
  padding: EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: isUser
        ? Colors.green
        : message['sender'] == 'Bot'
            ? Colors.blue
            : Colors.orange,
    borderRadius: BorderRadius.circular(10),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        message['text'] ?? '',
        style: TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      
      // ✅ NEW: Check if message is the "unknown response" message
      if (message['sender'] == 'Bot' && 
          message['text'] != null &&
          message['text'].contains("I'm sorry, I didn't understand that"))
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            icon: Icon(Icons.person, size: 18),
            label: Text('Contact My Counselor'),
            onPressed: () {
              // Get the previous user message
              final messages = widget.messages;
              final currentIndex = messages.indexOf(message);
              String userQuestion = '';
              
              // Find the user's question (should be right before this bot response)
              if (currentIndex > 0 && 
                  messages[currentIndex - 1]['sender'] == 'User') {
                userQuestion = messages[currentIndex - 1]['text'] ?? '';
              }
              
              widget.onEscalate(userQuestion);
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