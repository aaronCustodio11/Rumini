import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const NotificationsPage({super.key, required this.userData});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _showAll = false;

  Stream<QuerySnapshot> _getNotifications() {
    if (widget.userData == null || widget.userData!['studId'] == null) {
      debugPrint("⚠️ No userData or studId provided");
      return const Stream<QuerySnapshot>.empty();
    }

    final studId = widget.userData!['studId'].toString();
    debugPrint("🔍 Fetching notifications for studId: $studId");

    try {
      return FirebaseFirestore.instance
          .collection('notifications')
          .where('studId', isEqualTo: studId)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } catch (e) {
      debugPrint("❌ Firestore query failed: $e");
      rethrow;
    }
  }

  Future<void> _deleteOldNotifications(QuerySnapshot snapshot) async {
    final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['createdAt'] as Timestamp?;
      if (ts != null && ts.toDate().isBefore(oneMonthAgo)) {
        debugPrint("🗑 Deleting old notification: ${doc.id}");
        await doc.reference.delete();
      }
    }
  }

  Future<void> _markAsSeen(DocumentSnapshot doc) async {
    try {
      await doc.reference.update({"seen": true});
      debugPrint("👁 Notification marked as seen → ${doc.id}");
    } catch (e) {
      debugPrint("❌ Failed to mark notification as seen: $e");
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return "";

    final date = ts.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    final timeFormat = DateFormat("h:mm a");
    final dayNameFormat = DateFormat("EEEE");
    final fullDateFormat = DateFormat("MMMM d, yyyy");

    if (difference.inDays == 0 &&
        date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return "Today • ${timeFormat.format(date)}";
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year) {
      return "Yesterday • ${timeFormat.format(date)}";
    }

    if (difference.inDays < 7) {
      String dayName = dayNameFormat.format(date);
      return "$dayName • ${timeFormat.format(date)}";
    }

    return "${fullDateFormat.format(date)} • ${timeFormat.format(date)}";
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.notifications_none,
              size: 60,
              color: Colors.green.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No Notifications Yet",
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Stay tuned, updates will appear here.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(DocumentSnapshot doc) {
    final notif = doc.data() as Map<String, dynamic>;
    final bool isSeen = notif['seen'] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            _markAsSeen(doc);

            // Check if userData exists before navigating
            if (widget.userData == null) {
              debugPrint("⚠️ Cannot navigate: userData is null");
              return;
            }

            final String? path = notif['path'];
            debugPrint("📌 Notification tapped → path: $path");

            if (path != null && path.isNotEmpty) {
              int? tabIndex;

              switch (path) {
                case "/home_page":
                  tabIndex = 0;
                  break;
                case "/moodtracker":
                  tabIndex = 1;
                  break;
                case "/appointments_ad":
                  tabIndex = 2;
                  break;
                case "/psychoeducational_ad":
                  tabIndex = 3;
                  break;
              }

              if (tabIndex != null) {
                Navigator.pushNamed(
                  context,
                  "/navbar",
                  arguments: {
                    ...widget.userData!,
                    "initialIndex": tabIndex,
                  },
                );
              } else {
                // fallback for non-tab notifications
                Navigator.pushNamed(
                  context,
                  path,
                  arguments: widget.userData,
                );
              }
            } else {
              debugPrint("⚠️ No path found in this notification");
            }
          },

          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSeen 
                        ? Colors.grey.shade100 
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications,
                    color: isSeen 
                        ? Colors.grey.shade500 
                        : Colors.green.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif['message'] ?? 'No message',
                              style: TextStyle(
                                fontWeight: isSeen ? FontWeight.w500 : FontWeight.w600,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (!isSeen)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTimestamp(notif['createdAt'] as Timestamp?),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeeMoreButton(int totalCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            setState(() {
              _showAll = !_showAll;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showAll ? "Show Less" : "Show All ($totalCount)",
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _showAll ? Icons.expand_less : Icons.expand_more,
                  color: Colors.green.shade700,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade600,
      body: SafeArea(
        child: Column(
          children: [
            // Top green section with title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  ),
                  const Expanded(
                    child: Text(
                      "Notifications",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // Balance the row
                ],
              ),
            ),

            // White section with notifications
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getNotifications(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: Colors.green.shade600,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      debugPrint("❌ Firestore error: ${snapshot.error}");
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 60,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Error loading notifications",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    _deleteOldNotifications(snapshot.data!);

                    final notifications = snapshot.data!.docs;
                    final displayList = _showAll 
                        ? notifications 
                        : notifications.take(7).toList();

                    return Column(
                      children: [
                        const SizedBox(height: 20),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: displayList.length,
                            itemBuilder: (context, index) {
                              return _buildNotificationCard(displayList[index]);
                            },
                          ),
                        ),
                        if (notifications.length > 7) 
                          _buildSeeMoreButton(notifications.length),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}