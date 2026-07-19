import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rumini/components/sidebar.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatbotAd extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ChatbotAd({super.key, required this.userData});

  @override
  State<ChatbotAd> createState() => _ChatbotAdState();
}

class _ChatbotAdState extends State<ChatbotAd> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _responseController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _chatbotResponses = [];

  String searchQuery = "";
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchChatbotData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _responseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchChatbotData() async {
    try {
      final snapshot = await _firestore.collection('chatbot_responses').get();
      final responses = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'title': doc['title'] ?? 'No Title',
          'response': doc['response'] ?? 'No Response',
          'follow_up':
              doc.data().containsKey('follow_up') ? doc['follow_up'] : [],
          'keywords': doc['keywords'] ?? [],
          'timestamp': doc['timestamp'] ?? FieldValue.serverTimestamp(),
        };
      }).toList();

      setState(() {
        _chatbotResponses = responses;
      });
    } catch (e) {
      print('Error fetching chatbot data: $e');
    }
  }

  Future<void> _saveToFirestore() async {
    String title = _titleController.text.trim();
    String response = _responseController.text.trim();

    if (title.isEmpty || response.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in Title and Response")),
      );
      return;
    }

    Map<String, dynamic> data = {
      'title': title,
      'response': response,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection('chatbot_responses').add(data);
      _titleController.clear();
      _responseController.clear();
      _fetchChatbotData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved Successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _showEditDialog(Map<String, dynamic> response) {
    final titleController = TextEditingController(text: response['title']);
    final responseController =
        TextEditingController(text: response['response']);
    List<TextEditingController> followUpControllers = [];
    List<TextEditingController> keywordControllers = [];

    // Populate initial follow-up text boxes
    for (var item in response['follow_up']) {
      followUpControllers.add(TextEditingController(text: item));
    }

    // Populate initial keyword text boxes
    for (var item in response['keywords']) {
      keywordControllers.add(TextEditingController(text: item));
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              // Use Dialog instead of AlertDialog for more flexibility with size
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Edit Chatbot Response',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: titleController,
                                decoration: InputDecoration(labelText: 'Title'),
                              ),
                              TextField(
                                controller: responseController,
                                decoration: InputDecoration(labelText: 'Response'),
                                maxLines: null,
                              ),
                              const SizedBox(height: 12),
                              // Follow-Up Section
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text("Follow-Ups:",
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ...followUpControllers.map((controller) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: TextField(
                                      controller: controller,
                                      decoration: const InputDecoration(
                                          border: OutlineInputBorder()),
                                      maxLines: null,
                                    ),
                                  )),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    followUpControllers.add(TextEditingController());
                                  });
                                },
                                icon: Icon(Icons.add),
                                label: Text("Add Follow-Up"),
                              ),

                              const SizedBox(height: 12),
                              // Keywords Section
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text("Keywords:",
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ...keywordControllers.map((controller) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: TextField(
                                      controller: controller,
                                      decoration: const InputDecoration(
                                          border: OutlineInputBorder()),
                                      maxLines: null,
                                    ),
                                  )),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    keywordControllers.add(TextEditingController());
                                  });
                                },
                                icon: Icon(Icons.add),
                                label: Text("Add Keyword"),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ButtonBar(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final updatedFollowUps = followUpControllers
                                  .map((c) => c.text.trim())
                                  .where((t) => t.isNotEmpty)
                                  .toList();
                              final updatedKeywords = keywordControllers
                                  .map((c) => c.text.trim())
                                  .where((t) => t.isNotEmpty)
                                  .toList();

                              if (titleController.text.trim().isEmpty ||
                                  responseController.text.trim().isEmpty ||
                                  updatedKeywords.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Please fill in Title, Response, and Keywords")),
                                );
                                return;
                              }

                              // Check for duplicates across other responses
                              final snapshot =
                                  await _firestore.collection('chatbot_responses').get();
                              final Map<String, List<String>> duplicateKeywordsMap =
                                  {}; // keyword -> [titles]

                              for (var doc in snapshot.docs) {
                                if (doc.id == response['id']) continue; // skip self

                                final data = doc.data();
                                final List<dynamic> existingKeywords =
                                    data['keywords'] ?? [];
                                final String existingTitle = data['title'] ?? 'Untitled';

                                for (var existingKeyword in existingKeywords) {
                                  for (var newKeyword in updatedKeywords) {
                                    if (existingKeyword.toString().toLowerCase() ==
                                        newKeyword.toLowerCase()) {
                                      duplicateKeywordsMap.putIfAbsent(
                                          newKeyword, () => []);
                                      duplicateKeywordsMap[newKeyword]!
                                          .add(existingTitle);
                                    }
                                  }
                                }
                              }

                              if (duplicateKeywordsMap.isNotEmpty) {
                                // Format message
                                StringBuffer warningMessage = StringBuffer(
                                    "There is a same keyword in other response(s):\n\n");

                                duplicateKeywordsMap.forEach((keyword, titles) {
                                  warningMessage.writeln(
                                      'The keyword "$keyword" is also in these responses:');
                                  for (var t in titles) {
                                    warningMessage.writeln('- $t');
                                  }
                                  warningMessage.writeln();
                                });

                                warningMessage.writeln("Do you still want to continue?");

                                bool shouldContinue = false;

                                await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text("Duplicate Keyword Detected"),
                                    content: SingleChildScrollView(
                                      child: Text(warningMessage.toString()),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: Text("No"),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          shouldContinue = true;
                                          Navigator.of(context).pop();
                                        },
                                        child: Text("Yes"),
                                      ),
                                    ],
                                  ),
                                );

                                if (!shouldContinue) return;
                              }

                              // Proceed with update
                              await _firestore
                                  .collection('chatbot_responses')
                                  .doc(response['id'])
                                  .update({
                                'title': titleController.text.trim(),
                                'response': responseController.text.trim(),
                                'follow_up': updatedFollowUps,
                                'keywords': updatedKeywords,
                                'timestamp': Timestamp.now(),
                              });

                              _fetchChatbotData();
                              Navigator.of(context).pop();
                            },
                            child: Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Chatbot Response'),
        content: Text('Are you sure you want to delete this response?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _firestore.collection('chatbot_responses').doc(id).delete();
              _fetchChatbotData();
              Navigator.of(context).pop();
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddResponseDialog() {
    List<TextEditingController> followUpControllers = [];
    List<TextEditingController> keywordControllers = [];

    showDialog(
  context: context,
  builder: (context) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isLoading = false;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              minWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Add New Chatbot Response',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Field
                        Text(
                          'Title *',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: 'Enter a descriptive title',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            prefixIcon: const Icon(Icons.title),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Response Field
                        Text(
                          'Response *',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _responseController,
                          decoration: InputDecoration(
                            hintText: 'Enter the chatbot response',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            prefixIcon: const Icon(Icons.chat_bubble_outline),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                          minLines: 3,
                        ),
                        const SizedBox(height: 24),

                        // Keywords Section
                        Row(
                          children: [
                            Icon(Icons.key, size: 20, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Keywords *',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Add keywords that trigger this response',
                              child: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...keywordControllers.asMap().entries.map((entry) {
                          int index = entry.key;
                          TextEditingController controller = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    decoration: InputDecoration(
                                      hintText: 'e.g., greeting, help, pricing',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      prefixIcon: const Icon(Icons.label_outline, size: 20),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      keywordControllers.removeAt(index);
                                    });
                                  },
                                  tooltip: 'Remove keyword',
                                ),
                              ],
                            ),
                          );
                        }),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              keywordControllers.add(TextEditingController());
                            });
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Keyword'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Follow-Ups Section
                        Row(
                          children: [
                            Icon(Icons.question_answer_outlined, size: 20, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Follow-Up Questions',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Optional suggestions for users',
                              child: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (followUpControllers.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lightbulb_outline, color: Colors.grey.shade600),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No follow-up questions yet. Add some to help guide the conversation.',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ...followUpControllers.asMap().entries.map((entry) {
                          int index = entry.key;
                          TextEditingController controller = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    decoration: InputDecoration(
                                      hintText: 'e.g., Tell me more about...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      prefixIcon: const Icon(Icons.arrow_forward, size: 20),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      followUpControllers.removeAt(index);
                                    });
                                  },
                                  tooltip: 'Remove follow-up',
                                ),
                              ],
                            ),
                          );
                        }),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              followUpControllers.add(TextEditingController());
                            });
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Follow-Up'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // Footer with Actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                                setState(() {
                                  isLoading = true;
                                });

                                String title = _titleController.text.trim();
                                String response = _responseController.text.trim();
                                List<String> followUps = followUpControllers
                                    .map((c) => c.text.trim())
                                    .where((text) => text.isNotEmpty)
                                    .toList();
                                List<String> keywords = keywordControllers
                                    .map((c) => c.text.trim())
                                    .where((text) => text.isNotEmpty)
                                    .toList();

                                if (title.isEmpty || response.isEmpty || keywords.isEmpty) {
                                  setState(() {
                                    isLoading = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.warning_amber, color: Colors.white),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                                "Please fill in Title, Response, and at least one Keyword"),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.orange.shade700,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                // Fetch existing keywords from Firestore
                                final snapshot =
                                    await _firestore.collection('chatbot_responses').get();
                                final Map<String, List<String>> duplicateKeywordsMap =
                                    {}; // keyword -> [titles]

                                for (var doc in snapshot.docs) {
                                  final data = doc.data();
                                  final List<dynamic> existingKeywords =
                                      data['keywords'] ?? [];
                                  final String existingTitle = data['title'] ?? 'Untitled';

                                  for (var existingKeyword in existingKeywords) {
                                    for (var newKeyword in keywords) {
                                      if (existingKeyword.toString().toLowerCase() ==
                                          newKeyword.toLowerCase()) {
                                        duplicateKeywordsMap.putIfAbsent(
                                            newKeyword, () => []);
                                        duplicateKeywordsMap[newKeyword]!
                                            .add(existingTitle);
                                      }
                                    }
                                  }
                                }

                                if (duplicateKeywordsMap.isNotEmpty) {
                                  // Format warning message
                                  StringBuffer warningMessage = StringBuffer(
                                      "The following keywords already exist in other responses:\n\n");

                                  duplicateKeywordsMap.forEach((keyword, titles) {
                                    warningMessage.writeln(
                                        '• "$keyword" appears in:');
                                    for (var t in titles) {
                                      warningMessage.writeln('  - $t');
                                    }
                                    warningMessage.writeln();
                                  });

                                  warningMessage.writeln(
                                      "Multiple responses may be triggered. Continue anyway?");

                                  bool shouldContinue = false;

                                  await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      title: Row(
                                        children: [
                                          Icon(Icons.warning_amber, color: Colors.orange.shade700),
                                          const SizedBox(width: 12),
                                          const Text("Duplicate Keywords Found"),
                                        ],
                                      ),
                                      content: SingleChildScrollView(
                                        child: Text(warningMessage.toString()),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text("Cancel"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            shouldContinue = true;
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text("Continue Anyway"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (!shouldContinue) {
                                    setState(() {
                                      isLoading = false;
                                    });
                                    return;
                                  }
                                }

                                // Save to Firestore
                                Map<String, dynamic> data = {
                                  'title': title,
                                  'response': response,
                                  'keywords': keywords,
                                  'timestamp': FieldValue.serverTimestamp(),
                                };

                                if (followUps.isNotEmpty) {
                                  data['follow_up'] = followUps;
                                }

                                try {
                                  await _firestore
                                      .collection('chatbot_responses')
                                      .add(data);
                                  _titleController.clear();
                                  _responseController.clear();
                                  followUpControllers.clear();
                                  keywordControllers.clear();
                                  _fetchChatbotData();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.white),
                                          SizedBox(width: 12),
                                          Text("Response saved successfully!"),
                                        ],
                                      ),
                                      backgroundColor: Colors.green.shade600,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  Navigator.of(context).pop();
                                } catch (e) {
                                  setState(() {
                                    isLoading = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.white),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text("Error: $e")),
                                        ],
                                      ),
                                      backgroundColor: Colors.red.shade700,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        icon: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(isLoading ? 'Saving...' : 'Save Response'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the current screen size
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 600;
    final double contentPadding = isSmallScreen ? 8.0 : 20.0;

    return Scaffold(
      
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 196, 220, 198),
              Color.fromARGB(255, 196, 220, 198)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            // Sidebar - Collapsible for small screens
            if (!isSmallScreen) Sidebar(userData: widget.userData),

            // Main Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 100.0),
                child: Column(
                  children: [
                    // Mobile screen sidebar toggle button
                    if (isSmallScreen)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: Icon(Icons.menu),
                          onPressed: () {
                            // Show a drawer or modal bottom sheet with sidebar content
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => SizedBox(
                                height: MediaQuery.of(context).size.height * 0.8,
                                child: Sidebar(userData: widget.userData),
                              ),
                            );
                          },
                        ),
                      ),

                    // Row with Search Card and Add Response Button side by side
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6.0,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Search box with border
                          Expanded(
                            flex: 2, // Takes 2/3 of the space
                            child: Container(
                              height: 45, // Fixed height for the search box
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(25.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.search, color: Colors.grey),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: "Search chatbot responses...",
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          searchQuery = value.toLowerCase();
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Spacing between search box and button
                          SizedBox(width: isSmallScreen ? 8.0 : 16.0),
                          
                          // Add Response button
                          ElevatedButton(
                            onPressed: () {
                              _showAddResponseDialog();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF56ab2f), // Green background
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12.0 : 16.0, 
                                vertical: isSmallScreen ? 10.0 : 12.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: Text(
                              'Add Response',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 14.0 : 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Expanded List of Chatbot Responses to fill remaining space
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6.0,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _chatbotResponses.isEmpty
                            ? const Center(
                                child: Text("No chatbot responses found."),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: _chatbotResponses
                                    .where((response) => response['title']
                                        .toLowerCase()
                                        .contains(searchQuery))
                                    .length,
                                itemBuilder: (context, index) {
                                  final filteredResponses = _chatbotResponses
                                      .where((response) => response['title']
                                          .toLowerCase()
                                          .contains(searchQuery))
                                      .toList();
                                  
                                  if (index >= filteredResponses.length) {
                                    return null;
                                  }
                                  
                                  final response = filteredResponses[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10.0),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                                      title: Text(
                                        response['title'],
                                        style: TextStyle(fontSize: isSmallScreen ? 15.0 : 17.0),
                                      ),
                                      subtitle: Text(
                                        'Updated ${timeago.format((response['timestamp'] as Timestamp).toDate())}',
                                        style: TextStyle(fontSize: 12.0),
                                      ),
                                      trailing: isSmallScreen
                                          ? IconButton(
                                              icon: Icon(Icons.more_vert),
                                              onPressed: () {
                                                showModalBottomSheet(
                                                  context: context,
                                                  builder: (context) {
                                                    return SafeArea(
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          ListTile(
                                                            leading: Icon(Icons.edit, color: Colors.blue),
                                                            title: Text('Edit'),
                                                            onTap: () {
                                                              Navigator.pop(context);
                                                              _showEditDialog(response);
                                                            },
                                                          ),
                                                          ListTile(
                                                            leading: Icon(Icons.delete, color: Colors.red),
                                                            title: Text('Delete'),
                                                            onTap: () {
                                                              Navigator.pop(context);
                                                              _showDeleteConfirmationDialog(response['id']);
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            )
                                          : Wrap(
                                              spacing: 10,
                                              children: [
                                                IconButton(
                                                  icon: Icon(Icons.edit),
                                                  color: Colors.blue,
                                                  onPressed: () {
                                                    _showEditDialog(response);
                                                  },
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.delete),
                                                  color: const Color.fromARGB(255, 235, 70, 58),
                                                  onPressed: () {
                                                    _showDeleteConfirmationDialog(response['id']);
                                                  },
                                                ),
                                              ],
                                            ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}