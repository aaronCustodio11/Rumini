import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rumini/components/sidebar.dart';

class ChatHistoryAd extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ChatHistoryAd({super.key, required this.userData});

  @override
  _ChatHistoryAdState createState() => _ChatHistoryAdState();
}

class _ChatHistoryAdState extends State<ChatHistoryAd> {
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> filteredStudents = [];
  Map<String, dynamic>? selectedStudent;
  List<Map<String, dynamic>> chatHistory = [];
  final ScrollController _scrollController = ScrollController();
  bool isLoading = true;
  String searchQuery = '';
  final TextEditingController messageController = TextEditingController();
  String userRole = '';
  String counselorId = '';
  String loggedInUserFirstName = '';
  String loggedInUserLastName = '';
  String loggedInStaffId = '';

  Map<String, Map<String, dynamic>> staffDetails = {};

  // ==========================================
  // NEW: Add these three state variables
  // ==========================================
  int pendingEscalationsCount = 0;
  bool showEscalationModal = false;
  List<Map<String, dynamic>> escalations = [];
  // ==========================================

  // 🚩 Crisis-flagged chatbot events (chatbot_flagged_events)
  int flaggedCount = 0;
  List<Map<String, dynamic>> flaggedEvents = [];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    // ==========================================
    // NEW: Add this line
    // ==========================================
    _listenToEscalations();
    // ==========================================
  }

  Future<void> _fetchInitialData() async {
    await _fetchUserRole();
    await Future.wait([_fetchStaffDetails(), _fetchStudents()]);

    // Flagged events need role + student list for counselor filtering.
    _listenToFlaggedEvents();

    if (selectedStudent != null) {
      await _loadChatHistory(selectedStudent!['userId']);
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchUserRole() async {
    try {
      final userId = widget.userData['uid'];
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          userRole = userData['role'];
          counselorId = userData['counId'] ?? '';
          loggedInStaffId = userData['counId'] ?? '';
          loggedInUserFirstName = userData['firstName'] ?? 'Unknown';
          loggedInUserLastName = userData['lastName'] ?? '';
        }
      }
    } catch (error) {
      print("Error fetching user role: $error");
    }
  }

  Future<void> _fetchStaffDetails() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('role', whereIn: ['Counselor', 'Admin'])
          .get();

      final Map<String, Map<String, dynamic>> loadedStaff = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['counId'] != null) {
          loadedStaff[data['counId']] = {
            'firstName': data['firstName'] ?? 'Staff',
            'lastName': data['lastName'] ?? '',
            'role': data['role'] ?? '',
          };
        }
      }
      if (mounted) {
        setState(() {
          staffDetails = loadedStaff;
        });
      }
    } catch (e) {
      print("Error fetching staff details: $e");
    }
  }

  Future<void> _fetchStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .get();

      final List<Map<String, dynamic>> loadedStudents = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['role'] != 'Student') continue;

        final student = {
          'firstName': data['firstName'] ?? 'Unknown',
          'middleName': data['middleName'] ?? '',
          'lastName': data['lastName'] ?? '',
          'studId': data['studId'] ?? 'Unknown',
          'userId': doc.id,
          'assignedCounselor': data['assignedCounselor'] ?? '',
        };

        if (userRole == 'Admin') {
          loadedStudents.add(student);
        } else if (userRole == 'Counselor' &&
            student['assignedCounselor'] == counselorId) {
          loadedStudents.add(student);
        }
      }

      setState(() {
        students = loadedStudents;
        filteredStudents = loadedStudents;
        if (loadedStudents.isNotEmpty) {
          selectedStudent = loadedStudents[0];
        }
      });
    } catch (error) {
      print("Error fetching students: $error");
      setState(() => isLoading = false);
    }
  }

  void _filterStudents(String query) {
    setState(() {
      searchQuery = query.toLowerCase();
      filteredStudents = students.where((student) {
        final fullName =
            '${student['firstName']} ${student['middleName']} ${student['lastName']}'
                .toLowerCase();
        return fullName.contains(searchQuery) ||
            student['studId'].toLowerCase().contains(searchQuery);
      }).toList();
    });

    if (filteredStudents.isNotEmpty) {
      _selectStudent(filteredStudents[0]);
    }
  }

  void _selectStudent(Map<String, dynamic> student) {
    setState(() {
      selectedStudent = student;
      chatHistory = [];
      isLoading = true;
    });

    _loadChatHistory(student['userId']).then((_) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  Future<void> _loadChatHistory(String userId) async {
    try {
      // Load regular messages
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('messages')
          .orderBy('timestamp')
          .get();

      final history = messagesSnapshot.docs.map((doc) {
        final data = doc.data();
        final ts = data['timestamp'];
        return {
          'sender': data['sender'] ?? 'Unknown',
          'text': data['text'] ?? '',
          'timestamp': ts is Timestamp
              ? ts.toDate()
              : DateTime.now(), // pending serverTimestamp
          'isEscalation': false, // Mark as regular message
          // Safety context for staff: which path answered + crisis flag
          'crisis': data['crisis'] == true,
          'src': data['src'] ?? '',
        };
      }).toList();

      // NEW: Load escalations for this student
      Query escalationQuery = FirebaseFirestore.instance
          .collection('inquiry_escalations')
          .where('studentId', isEqualTo: userId);

      // Filter by counselor if not admin
      if (userRole == 'Counselor') {
        escalationQuery = escalationQuery.where(
          'counselorId',
          isEqualTo: counselorId,
        );
      }

      final escalationsSnapshot = await escalationQuery.get();

      // Add escalations to history
      for (var doc in escalationsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['timestamp'] != null) {
          history.add({
            'sender': 'Escalation',
            'text': data['inquiry'] ?? '',
            'timestamp': (data['timestamp'] as Timestamp).toDate(),
            'isEscalation': true, // Mark as escalation
            'status': data['status'] ?? 'pending',
          });
        }
      }

      // Sort all messages by timestamp
      history.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

      if (mounted) {
        setState(() {
          chatHistory = history;
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      print("Error loading chat history for userId $userId: $error");
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty || selectedStudent == null) return;

    final senderId =
        widget.userData['counId'] ??
        (userRole == 'Counselor' ? counselorId : 'Admin');

    await FirebaseFirestore.instance
        .collection('Users')
        .doc(selectedStudent!['userId'])
        .collection('messages')
        .add({
          'sender': senderId,
          'text': message,
          'timestamp': FieldValue.serverTimestamp(),
        });

    messageController.clear();
    await _loadChatHistory(selectedStudent!['userId']);
  }

  // ==========================================
  // NEW METHOD 1: Listen to escalations in real-time
  // INSERT AFTER _sendMessage() method
  // ==========================================
  void _listenToEscalations() {
    Query query = FirebaseFirestore.instance
        .collection('inquiry_escalations')
        .where('status', isEqualTo: 'pending');

    // If counselor, only show their assigned students
    if (userRole == 'Counselor') {
      query = query.where('counselorId', isEqualTo: counselorId);
    }

    query.snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          pendingEscalationsCount = snapshot.docs.length;
          escalations = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'studentId': data['studentId'],
              'studentName': data['studentName'],
              'inquiry': data['inquiry'],
              'timestamp': data['timestamp'],
            };
          }).toList();
        });
      }
    });
  }
  // ==========================================

  // ==========================================
  // NEW METHOD 2: Mark escalation as responded
  // INSERT AFTER _listenToEscalations() method
  // ==========================================
  Future<void> _markEscalationResponded(String escalationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('inquiry_escalations')
          .doc(escalationId)
          .update({
            'status': 'responded',
            'responded': true,
            'respondedAt': FieldValue.serverTimestamp(),
          });

      // NEW: Update the UI immediately by removing from local list
      setState(() {
        escalations.removeWhere((e) => e['id'] == escalationId);
        pendingEscalationsCount = escalations.length;
      });
    } catch (e) {
      print('Error marking escalation as responded: $e');
    }
  }
  // ==========================================

  // ==========================================
  // NEW METHOD 3: Show escalation modal
  // INSERT AFTER _markEscalationResponded() method
  // ==========================================
  void _showEscalationModal() {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: _getEscalationsStream(),
        builder: (context, snapshot) {
          // Get real-time escalation data
          final modalEscalations = snapshot.hasData
              ? snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'id': doc.id,
                    'studentId': data['studentId'],
                    'studentName': data['studentName'],
                    'inquiry': data['inquiry'],
                    'timestamp': data['timestamp'],
                  };
                }).toList()
              : [];

          return Dialog(
            child: Container(
              width: 500,
              constraints: BoxConstraints(maxHeight: 600),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF81BF36),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pending Student Inquiries',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // List of escalations
                  Expanded(
                    child: modalEscalations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: Colors.green,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No pending inquiries',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: modalEscalations.length,
                            itemBuilder: (context, index) {
                              final escalation = modalEscalations[index];
                              final timestamp =
                                  escalation['timestamp'] as Timestamp?;
                              final date = timestamp?.toDate();
                              final timeStr = date != null
                                  ? '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
                                  : 'Unknown';

                              return Card(
                                margin: EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Student name and time
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            escalation['studentName'] ??
                                                'Unknown',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),

                                      // Inquiry text
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          escalation['inquiry'] ?? '',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      SizedBox(height: 12),

                                      // Action buttons
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            icon: Icon(Icons.check, size: 18),
                                            label: Text('Mark as Responded'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.green,
                                            ),
                                            onPressed: () async {
                                              await _markEscalationResponded(
                                                escalation['id'],
                                              );
                                            },
                                          ),
                                          SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            icon: Icon(Icons.chat, size: 18),
                                            label: Text('Open Chat'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color(
                                                0xFF81BF36,
                                              ),
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              // Find and select this student
                                              final student = students
                                                  .firstWhere(
                                                    (s) =>
                                                        s['userId'] ==
                                                        escalation['studentId'],
                                                    orElse: () => {},
                                                  );
                                              if (student.isNotEmpty) {
                                                _selectStudent(student);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // NEW: Helper method to get escalations stream
  Stream<QuerySnapshot> _getEscalationsStream() {
    Query query = FirebaseFirestore.instance
        .collection('inquiry_escalations')
        .where('status', isEqualTo: 'pending');

    if (userRole == 'Counselor') {
      query = query.where('counselorId', isEqualTo: counselorId);
    }

    return query.snapshots();
  }
  // ==========================================

  // ==========================================================================
  // 🚩 Crisis-flagged events — real-time list of chatbot safety interceptions
  // ==========================================================================
  void _listenToFlaggedEvents() {
    FirebaseFirestore.instance
        .collection('chatbot_flagged_events')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          final all = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'studentId': data['studentId'] ?? '',
              'triggerType': data['triggerType'] ?? '',
              'severity': data['severity'] ?? 'medium',
              'messageSnippet': data['messageSnippet'] ?? '',
              'timestamp': data['timestamp'],
              'reviewed': data['reviewedByCounselor'] == true,
            };
          }).toList();

          // Counselor: only events from their assigned students.
          final assigned = students.map((s) => s['userId']).toSet();
          final visible = userRole == 'Counselor'
              ? all
                    .where((e) => assigned.contains(e['studentId']))
                    .toList()
              : all;

          setState(() {
            flaggedEvents = visible;
            flaggedCount = visible.where((e) => e['reviewed'] != true).length;
          });
        });
  }

  String _flagStudentName(dynamic studentId) {
    for (final s in students) {
      if (s['userId'] == studentId) {
        return '${s['firstName']} ${s['lastName']}'.trim();
      }
    }
    return 'Unknown student';
  }

  Future<void> _markFlagReviewed(String eventId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chatbot_flagged_events')
          .doc(eventId)
          .update({
            'reviewedByCounselor': true,
            'reviewedAt': FieldValue.serverTimestamp(),
            'reviewedBy': loggedInStaffId,
          });
    } catch (e) {
      print('Error marking flagged event as reviewed: $e');
    }
  }

  void _showFlaggedModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🚨 Crisis-Flagged Chatbot Events',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: flaggedEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 64,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No crisis-flagged events',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : StatefulBuilder(
                        builder: (context, setModalState) => ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: flaggedEvents.length,
                          itemBuilder: (context, index) {
                            final event = flaggedEvents[index];
                            final ts = event['timestamp'];
                            final date = ts is Timestamp ? ts.toDate() : null;
                            final timeStr = date != null
                                ? '${date.month}/${date.day}/${date.year} '
                                      '${date.hour}:${date.minute.toString().padLeft(2, '0')}'
                                : 'Unknown';
                            final isHigh = event['severity'] == 'high';
                            final reviewed = event['reviewed'] == true;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _flagStudentName(
                                              event['studentId'],
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isHigh
                                                ? Colors.red
                                                : Colors.orange,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            isHigh ? 'HIGH' : 'MEDIUM',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${event['triggerType']} • $timeStr'
                                      '${reviewed ? ' • ✓ Reviewed' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: reviewed
                                            ? Colors.green[700]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        '"${event['messageSnippet']}"',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          icon: const Icon(
                                            Icons.chat,
                                            size: 18,
                                          ),
                                          label: const Text('Open Chat'),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            final student = students
                                                .firstWhere(
                                                  (s) =>
                                                      s['userId'] ==
                                                      event['studentId'],
                                                  orElse: () => {},
                                                );
                                            if (student.isNotEmpty) {
                                              _selectStudent(student);
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        if (!reviewed)
                                          ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.check,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Mark Reviewed',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF81BF36),
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () async {
                                              await _markFlagReviewed(
                                                event['id'],
                                              );
                                              setModalState(() {
                                                flaggedEvents[index]['reviewed']
                                                    = true;
                                              });
                                              setState(() {
                                                flaggedCount = flaggedEvents
                                                    .where(
                                                      (e) =>
                                                          e['reviewed'] != true,
                                                    )
                                                    .length;
                                              });
                                            },
                                          ),
                                      ],
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
    );
  }
  // ==========================================================================

  @override
  void dispose() {
    _scrollController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(userData: widget.userData),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Color.fromARGB(255, 182, 177, 177),
                  width: 1.75,
                ),
              ),
            ),
            child: Container(
              width: 300,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              color: const Color(0xFFE8F5E9),
              child: Column(
                children: [
                  // ==========================================
                  // MODIFIED: Replace "Students" title section with this
                  // ==========================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Students",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🚩 Crisis-flagged events
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.flag_outlined),
                                onPressed: _showFlaggedModal,
                                tooltip: 'Crisis-flagged events',
                              ),
                              if (flaggedCount > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    child: Text(
                                      flaggedCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // NEW: Notification badge button
                          Stack(
                            children: [
                              IconButton(
                                icon: Icon(Icons.notifications_outlined),
                                onPressed: _showEscalationModal,
                                tooltip: 'View pending inquiries',
                              ),
                              if (pendingEscalationsCount > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    child: Text(
                                      pendingEscalationsCount.toString(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  // ==========================================

                  // ==========================================
                  // NEW: Add this banner after the header
                  // ==========================================
                  if (pendingEscalationsCount > 0)
                    Container(
                      margin: EdgeInsets.only(bottom: 10),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.priority_high, color: Colors.orange[800]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$pendingEscalationsCount pending ${pendingEscalationsCount == 1 ? "inquiry" : "inquiries"}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _showEscalationModal,
                            child: Text('View'),
                          ),
                        ],
                      ),
                    ),

                  // ==========================================
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by Name or Student ID',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: _filterStudents,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: (students.isEmpty && !isLoading)
                        ? const Center(child: Text('No students found.'))
                        : isLoading && filteredStudents.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = filteredStudents[index];

                              // ==========================================
                              // NEW: Check if this student has pending escalations
                              // ==========================================
                              final hasPendingEscalation = escalations.any(
                                (e) => e['studentId'] == student['userId'],
                              );
                              // ==========================================

                              return Card(
                                color: Colors.white,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  // ==========================================
                                  // MODIFIED: Replace leading with this Stack
                                  // ==========================================
                                  leading: Stack(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.green,
                                        child: Text(student['firstName'][0]),
                                      ),
                                      // NEW: Red dot indicator
                                      if (hasPendingEscalation)
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  // ==========================================
                                  title: Text(
                                    '${student['firstName']} ${student['lastName']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Student ID: ${student['studId']}',
                                  ),
                                  // ==========================================
                                  // NEW: Add trailing badge
                                  // ==========================================
                                  trailing: hasPendingEscalation
                                      ? Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            'NEW',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                                  // ==========================================
                                  onTap: () => _selectStudent(student),
                                  selected:
                                      selectedStudent?['userId'] ==
                                      student['userId'],
                                  selectedTileColor: const Color(0xFFD0F0C0),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: selectedStudent == null
                ? Center(
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : const Text("No student selected"),
                  )
                : Column(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppBar(
                            automaticallyImplyLeading: false,
                            title: Text(
                              '${selectedStudent!['firstName']} ${selectedStudent!['lastName']}',
                            ),
                            backgroundColor: const Color.fromARGB(
                              255,
                              188,
                              237,
                              193,
                            ),
                            elevation: 0,
                          ),
                          Container(
                            height: 1.75,
                            color: const Color.fromARGB(255, 178, 182, 177),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Container(
                          color: const Color(0xFFF1F8E9),
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : chatHistory.isEmpty
                              ? const Center(
                                  child: Text("No chat history available."),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: chatHistory.length,
                                  itemBuilder: (context, index) {
                                    final msg = chatHistory[index];
                                    String senderName;
                                    final senderId = msg['sender'];
                                    final isStudentMessage = senderId == 'User';
                                    final isEscalation =
                                        msg['isEscalation'] == true;
                                    final escalationStatus =
                                        msg['status'] ?? '';

                                    // Determine sender name
                                    if (isEscalation) {
                                      senderName =
                                          '${selectedStudent!['firstName']} ${selectedStudent!['lastName']} ';
                                    } else if (isStudentMessage) {
                                      senderName =
                                          '${selectedStudent!['firstName']} ${selectedStudent!['lastName']}';
                                    } else if (senderId == loggedInStaffId) {
                                      senderName =
                                          '$loggedInUserFirstName $loggedInUserLastName ($userRole)'
                                              .trim();
                                    } else if (staffDetails.containsKey(
                                      senderId,
                                    )) {
                                      final staff = staffDetails[senderId]!;
                                      final staffRole = staff['role'];
                                      senderName =
                                          '${staff['firstName']} ${staff['lastName']} ($staffRole)'
                                              .trim();
                                    } else {
                                      senderName = senderId;
                                    }

                                    final timestamp =
                                        msg['timestamp'] as DateTime;
                                    final formattedTime =
                                        '${timestamp.month.toString().padLeft(2, '0')}/'
                                        '${timestamp.day.toString().padLeft(2, '0')}/'
                                        '${timestamp.year} - '
                                        '${timestamp.hour.toString().padLeft(2, '0')}:'
                                        '${timestamp.minute.toString().padLeft(2, '0')}';

                                    return Align(
                                      alignment:
                                          isStudentMessage || isEscalation
                                          ? Alignment.centerLeft
                                          : Alignment.centerRight,
                                      child: Column(
                                        crossAxisAlignment:
                                            isStudentMessage || isEscalation
                                            ? CrossAxisAlignment.start
                                            : CrossAxisAlignment.end,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 6.0,
                                              right: 5.0,
                                              bottom: 2.0,
                                            ),
                                            child: Text(
                                              senderName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign:
                                                  isStudentMessage ||
                                                      isEscalation
                                                  ? TextAlign.left
                                                  : TextAlign.right,
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              // NEW: Different color for escalations
                                              color: isEscalation
                                                  ? (escalationStatus ==
                                                            'pending'
                                                        ? Colors.orange.shade100
                                                        : Colors.grey.shade200)
                                                  : (isStudentMessage
                                                        ? Colors
                                                              .lightGreen
                                                              .shade100
                                                        : Colors
                                                              .lightBlue
                                                              .shade100),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              // NEW: Add border for escalations
                                              border: isEscalation
                                                  ? Border.all(
                                                      color:
                                                          escalationStatus ==
                                                              'pending'
                                                          ? Colors.orange
                                                          : Colors.grey,
                                                      width: 2,
                                                    )
                                                  : null,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // 🚩 Crisis flag on the
                                                // message that was intercepted
                                                if (msg['crisis'] == true)
                                                  Container(
                                                    margin: const EdgeInsets
                                                        .only(bottom: 8),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(4),
                                                    ),
                                                    child: const Text(
                                                      '🚨 CRISIS — SAFETY REPLY SENT',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                // NEW: Show status badge for escalations
                                                if (isEscalation)
                                                  Container(
                                                    margin: EdgeInsets.only(
                                                      bottom: 8,
                                                    ),
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          escalationStatus ==
                                                              'pending'
                                                          ? Colors.orange
                                                          : Colors.green,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      escalationStatus ==
                                                              'pending'
                                                          ? '⚠️ NEEDS RESPONSE'
                                                          : '✓ Responded',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                Text(msg['text']),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 5.0,
                                              right: 5.0,
                                              bottom: 8.0,
                                            ),
                                            child: Text(
                                              formattedTime,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                              textAlign:
                                                  isStudentMessage ||
                                                      isEscalation
                                                  ? TextAlign.left
                                                  : TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      Container(
                        color: const Color(0xFFF1F8E9),
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: messageController,
                                decoration: const InputDecoration(
                                  hintText: "Type your message...",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: () {
                                _sendMessage(messageController.text);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
