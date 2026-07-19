import 'dart:math';
import 'package:rumini/components/chatbot_fab.dart';
import 'package:rumini/pages(user)/forms/answer.dart';
import 'package:rumini/pages(user)/appointments/RequestApt.dart';
import 'package:rumini/pages(user)/home/welcome.dart';
import 'package:rumini/pages(user)/moodtracker/logemotion.dart';
import 'package:rumini/pages(user)/notifications/notif.dart';
import 'package:rumini/profilePage.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  HomePage({super.key, required this.userData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowWelcomeDialog(widget.userData);
    });
  }

  Stream<List<DocumentSnapshot>> _getOpenFormsStream() {
    return FirebaseFirestore.instance
        .collection('forms')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Stream<String?> _getTodayEmotionStream(String studId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return FirebaseFirestore.instance
        .collection('emotionLogs')
        .where('studId', isEqualTo: studId)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return snapshot.docs.first['image'];
          } else {
            return null;
          }
        });
  }

  Future<void> _checkAndShowWelcomeDialog(Map<String, dynamic> userData) async {
    try {
      final uid = userData['uid'];
      if (uid == null) return;

      final docRef = FirebaseFirestore.instance.collection('Users').doc(uid);

      final docSnap = await docRef.get();
      if (!docSnap.exists) return;

      final data = docSnap.data() ?? {};

      // If 'welcome' doesn't exist, create it with false
      if (!data.containsKey('welcome')) {
        await docRef.update({'welcome': false});
      }

      // If 'welcome' is false (or just created), show the dialog
      if (data['welcome'] == false || !data.containsKey('welcome')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => WelcomeDialog(userData: widget.userData),
          ).then((_) async {
            // After dialog completes, mark welcome and first login as true
            await docRef.update({'welcome': true});
          });
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error checking welcome dialog: $e');
    }
  }

  // Show dialog with enhanced UI for list of forms
  void _showFormsDialog(BuildContext context, List<DocumentSnapshot> forms) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: const Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        color: const Color(0xFF1B5E20),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Select a Form',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Form list
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: forms.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final form = forms[index];
                      final String formTitle =
                          form.get('title') ?? 'Untitled Form';
                      final String formDescription =
                          form.get('description') ?? 'No description provided';

                      // Show first 40 characters of description
                      final String truncatedDescription =
                          formDescription.length > 40
                          ? '${formDescription.substring(0, 40)}...'
                          : formDescription;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 16.0,
                        ),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.description,
                            color: const Color(0xFF4CAF50),
                            size: 28,
                          ),
                        ),
                        title: Text(
                          formTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          truncatedDescription,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: const Color(0xFF4CAF50),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onTap: () {
                          Navigator.pop(context); // Close dialog
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AnswerForms(
                                formId: form.id,
                                userData: widget.userData,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int> _calculateDaysRemaining(
    Timestamp dateTimestamp,
    String timeSlot,
  ) async {
    if (dateTimestamp == null || timeSlot.isEmpty) return 0; // Safety check

    // Convert Firestore Timestamp to DateTime
    DateTime appointmentDate = dateTimestamp.toDate();

    // Extract the start time from the time slot
    String startTime = timeSlot.split(
      ' - ',
    )[0]; // Get "2:00 PM" from "2:00 PM - 3:00 PM"

    // Parse the start time into DateTime format
    DateTime fullAppointmentDateTime = DateFormat(
      'MMMM d, yyyy h:mm a',
    ).parse('${DateFormat('MMMM d, yyyy').format(appointmentDate)} $startTime');

    // Get current DateTime
    DateTime now = DateTime.now();

    // Calculate the exact time difference
    Duration difference = fullAppointmentDateTime.difference(now);

    // Convert to days, round up to avoid incorrect countdown
    int daysRemaining = (difference.inHours / 24.0).ceil();

    return daysRemaining;
  }

  // Request Appointment Card - Updated for the new design
  Widget _buildRequestAppointmentCard(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Left Side - Text and Button
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Request an Appointment?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              Requestapt(userData: widget.userData),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50), // Green color
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Request Now'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.calendar_today,
              size: 48,
              color: Color(0xFF4CAF50), // Green color
            ),
          ],
        ),
      ),
    );
  }

  // Pending Appointment Card with Waiting Icon and Cancel Button - Updated for new design
  Widget _buildPendingAppointmentCard(
    BuildContext context,
    Map<String, dynamic> appointmentData,
  ) {
    String formattedDate = 'N/A';
    if (appointmentData['date'] is Timestamp) {
      DateTime dateTime = appointmentData['date'].toDate();
      formattedDate = DateFormat('MMMM d, yyyy').format(dateTime);
    }

    String time = appointmentData['time'] ?? 'N/A';
    String assignedCounselorId = appointmentData['counId'] ?? 'N/A';
    String concern = appointmentData['concern'] ?? 'N/A';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.pending_outlined,
                    color: Colors.green[900],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Confirmation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Please wait for counselor approval',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.green[100],
                  ),
                ),
              ],
            ),

            const Divider(height: 30),

            // Appointment details section
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Date',
                        formattedDate,
                        Colors.green.shade400,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.access_time,
                        'Time',
                        time,
                        Colors.green.shade400,
                      ),
                    ],
                  ),
                ),
                Container(height: 80, width: 1, color: Colors.grey.shade300),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('Users')
                            .where('counId', isEqualTo: assignedCounselorId)
                            .where('role', whereIn: ['Counselor', 'Admin'])
                            .limit(1)
                            .snapshots(),
                        builder: (context, snapshot) {
                          String counselorName = 'Loading...';

                          if (snapshot.hasData &&
                              snapshot.data!.docs.isNotEmpty) {
                            var counselorData =
                                snapshot.data!.docs.first.data()
                                    as Map<String, dynamic>;
                            String firstName = counselorData['firstName'] ?? '';
                            String middleName =
                                counselorData['middleName'] ?? '';
                            String lastName = counselorData['lastName'] ?? '';
                            String extensionName =
                                counselorData['extensionName'] ?? '';

                            // Format middle name as first letter capital with a period (e.g., "C.")
                            String middleInitial = middleName.isNotEmpty
                                ? '${middleName[0].toUpperCase()}.'
                                : '';

                            // Format full name properly
                            counselorName =
                                '$firstName '
                                        '${middleInitial.isNotEmpty ? middleInitial + ' ' : ''}'
                                        '$lastName'
                                        '${extensionName.isNotEmpty ? ' ' + extensionName : ''}'
                                    .trim();
                          }

                          return _buildDetailRow(
                            Icons.person,
                            'Counselor',
                            counselorName,
                            Colors.green.shade400,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Concern section
            _buildDetailRow(
              Icons.subject,
              'Concern',
              concern,
              Colors.green.shade400,
            ),

            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white, // White icon
                ),
                label: const Text(
                  'Cancel Request',
                  style: TextStyle(color: Colors.white), // White text
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red, // Red background
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(
                      color: Colors.red, // Red border
                    ),
                  ),
                ),
                onPressed: () {
                  _showCancelConfirmationDialog(
                    context,
                    appointmentData['docId'],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Accepted Appointment Card
  Widget _buildAcceptedAppointmentCard(
    BuildContext context,
    Map<String, dynamic> appointmentData,
  ) {
    String formattedDate = 'N/A';
    DateTime? appointmentDateTime;

    if (appointmentData['date'] is Timestamp) {
      appointmentDateTime = appointmentData['date'].toDate();
      formattedDate = DateFormat('MMMM d, yyyy').format(appointmentDateTime!);
    }

    String time = appointmentData['time'] ?? 'N/A';
    String assignedCounselorId = appointmentData['counId'] ?? 'N/A';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appointment Confirmed',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your request has been accepted',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 30),

            // Appointment details section
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Date',
                        formattedDate,
                        Color.fromARGB(255, 26, 97, 50),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.access_time,
                        'Time',
                        time,
                        Color.fromARGB(255, 26, 97, 50),
                      ),
                    ],
                  ),
                ),
                Container(height: 80, width: 1, color: Colors.grey.shade300),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('Users')
                            .where('counId', isEqualTo: assignedCounselorId)
                            .where('role', whereIn: ['Admin', 'Counselor'])
                            .limit(1)
                            .snapshots(),
                        builder: (context, snapshot) {
                          String counselorName = 'Loading...';

                          if (snapshot.hasData &&
                              snapshot.data!.docs.isNotEmpty) {
                            var counselorData =
                                snapshot.data!.docs.first.data()
                                    as Map<String, dynamic>;
                            String firstName = counselorData['firstName'] ?? '';
                            String middleName =
                                counselorData['middleName'] ?? '';
                            String lastName = counselorData['lastName'] ?? '';
                            String extensionName =
                                counselorData['extensionName'] ?? '';

                            // Format middle name as first letter capital with a period (e.g., "C.")
                            String middleInitial = middleName.isNotEmpty
                                ? '${middleName[0].toUpperCase()}.'
                                : '';

                            // Format full name properly
                            counselorName =
                                '$firstName '
                                        '${middleInitial.isNotEmpty ? middleInitial + ' ' : ''}'
                                        '$lastName'
                                        '${extensionName.isNotEmpty ? ' ' + extensionName : ''}'
                                    .trim();
                          }

                          return _buildDetailRow(
                            Icons.person,
                            'Counselor',
                            counselorName,
                            Colors.green.shade400,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Days remaining with countdown visuals
            FutureBuilder<int>(
              future: _calculateDaysRemaining(
                appointmentData['date'],
                appointmentData['time'],
              ),
              builder: (context, snapshot) {
                int daysRemaining = snapshot.data ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.hourglass_top,
                        size: 28,
                        color: const Color.fromARGB(255, 26, 97, 50),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$daysRemaining day${daysRemaining == 1 ? '' : 's'} to go!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 26, 97, 50),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Cancel Appointment Button - Red background
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text(
                  'Cancel Appointment',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red, // Red background
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(
                      color: Colors.red, // Red border
                    ),
                  ),
                ),
                onPressed: () {
                  _showCancelConfirmationDialog(
                    context,
                    appointmentData['docId'],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for building detail rows with icon
  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Confirmation Dialog before Cancel - Exact copy from AppointmentPage
  void _showCancelConfirmationDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Appointment'),
          content: const Text(
            'Are you sure you want to cancel this appointment?',
          ),
          actions: [
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close dialog
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close dialog
                _cancelAppointment(context, docId);
              },
            ),
          ],
        );
      },
    );
  }

  // Cancel appointment logic - Exact copy from AppointmentPage
  void _cancelAppointment(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(docId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment canceled successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error canceling appointment: $e')),
      );
    }
  }

  Future<String?> getTodayEmotionImagePath(String studId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final querySnapshot = await FirebaseFirestore.instance
        .collection('emotionLogs')
        .where('studId', isEqualTo: studId)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot
          .docs
          .first['image']; // Assuming the field name is 'image'
    } else {
      return null; // No emotion log today
    }
  }

  Widget _buildGreetingCard(
    BuildContext context,
    String firstName,
    String? emotionImagePath,
  ) {
    final noEmotion = emotionImagePath == null;

    // Capitalize first letter of the name
    final formattedName = firstName.isNotEmpty
        ? firstName[0].toUpperCase() + firstName.substring(1)
        : "";

    // Determine greeting and video based on device time
    final hour = DateTime.now().hour;
    String greeting;
    String videoPath;

    if (hour >= 5 && hour < 12) {
      greeting = "Good Morning";
      videoPath = "assets/videos/morning.mp4";
    } else if (hour >= 12 && hour < 18) {
      greeting = "Good Afternoon";
      videoPath = "assets/videos/afternoon.mp4";
    } else {
      greeting = "Good Evening";
      videoPath = "assets/videos/night.mp4";
    }

    // Random emotion prompt
    final emotionPrompts = [
      "How's\ntoday?",
      "Feeling\nokay?",
      "Your\nvibe?",
      "All\ngood?",
      "What's\nnew?",
      "How's it\ngoing?",
      "You\nalright?",
      "State of\nmind?",
      "Today's\npulse?",
      "Emo\ncheck?",
      "Mind\nmeter?",
      "Mood\nlog?",
    ];

    final randomPrompt =
        emotionPrompts[DateTime.now().day % emotionPrompts.length];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // LEFT SIDE — looping video
            _VideoLoopWidget(videoPath: videoPath),

            const SizedBox(width: 16),

            // CENTER — greeting text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    formattedName,
                    style: const TextStyle(fontSize: 20, color: Colors.green),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // RIGHT SIDE — emotion button or image
            noEmotion
                ? SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, __, ___) =>
                                        LogEmotion(userData: widget.userData),
                                    transitionsBuilder:
                                        (_, animation, __, child) =>
                                            FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                  ),
                                );
                              },
                              customBorder: const CircleBorder(),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                child: const Icon(
                                  Icons.mood_outlined,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          randomPrompt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF666666),
                            height: 1.2,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  )
                : Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(emotionImagePath!, fit: BoxFit.cover),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // Build a card for the forms section with a cleaner look
  Widget _buildFormsCard(BuildContext context, List<DocumentSnapshot> forms) {
    final bool isSingleForm = forms.length == 1;
    final String? formTitle = isSingleForm ? forms.first.get('title') : null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons
                        .assignment, // You can replace this with another form-related icon if needed
                    color: Colors
                        .green[800], // Choose a color that matches your theme
                    size: 35,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSingleForm
                              ? "You may need to answer this form"
                              : "Checkout the forms you may need to answer",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black, // Add color to match the icon
                          ),
                        ),
                        if (isSingleForm && formTitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            formTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.black54,
              ),
              onPressed: () {
                if (isSingleForm) {
                  final String formId = forms.first.id;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnswerForms(
                        formId: formId,
                        userData: widget.userData,
                      ),
                    ),
                  );
                } else {
                  _showFormsDialog(context, forms);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String firstName = widget.userData['firstName'] ?? 'User';
    String currentStudId = widget.userData['studId'];

    return Scaffold(
      body: Stack(
        children: [
          // Green background for top half
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            color: const Color(0xFF1B5E20), // Dark green color
          ),

          // White background for bottom half with top curve
          Positioned(
            top: MediaQuery.of(context).size.height * 0.27,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Title at the top center
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Home',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('notifications')
                                .where('seen', isEqualTo: false)
                                .where(
                                  'studId',
                                  isEqualTo: widget.userData['studId'],
                                )
                                .snapshots(),

                            builder: (context, snapshot) {
                              int unseenCount = snapshot.hasData
                                  ? snapshot.data!.docs.length
                                  : 0;

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.notifications,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              NotificationsPage(
                                                userData: widget.userData,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (unseenCount > 0)
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Text(
                                          unseenCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.account_circle,
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      Profilepage(userData: widget.userData),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListView(
                      children: [
                        const SizedBox(height: 16),
                        StreamBuilder<String?>(
                          stream: _getTodayEmotionStream(currentStudId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }

                            final imagePath = snapshot.data;
                            return _buildGreetingCard(
                              context,
                              firstName,
                              imagePath,
                            );
                          },
                        ),

                        // Appointment Card Section
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('appointments')
                              .where('studId', isEqualTo: currentStudId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return _buildRequestAppointmentCard(context);
                            }

                            var pendingAppointments = snapshot.data!.docs.where(
                              (doc) => doc['status'] == 'pending',
                            );

                            var pendingAppointment =
                                pendingAppointments.isNotEmpty
                                ? pendingAppointments.first
                                : null;

                            if (pendingAppointment != null) {
                              Map<String, dynamic> appointmentData =
                                  pendingAppointment.data()
                                      as Map<String, dynamic>;
                              appointmentData['docId'] = pendingAppointment.id;

                              return _buildPendingAppointmentCard(
                                context,
                                appointmentData,
                              );
                            }

                            var acceptedAppointments = snapshot.data!.docs
                                .where((doc) => doc['status'] == 'accepted');

                            var acceptedAppointment =
                                acceptedAppointments.isNotEmpty
                                ? acceptedAppointments.first
                                : null;

                            if (acceptedAppointment != null) {
                              Map<String, dynamic> appointmentData =
                                  acceptedAppointment.data()
                                      as Map<String, dynamic>;
                              appointmentData['docId'] = acceptedAppointment.id;

                              return _buildAcceptedAppointmentCard(
                                context,
                                appointmentData,
                              );
                            }

                            return _buildRequestAppointmentCard(context);
                          },
                        ),

                        // Forms Section
                        StreamBuilder<List<DocumentSnapshot>>(
                          stream: _getOpenFormsStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const SizedBox(); // No open forms
                            }

                            final openForms = snapshot.data!;
                            return _buildFormsCard(context, openForms);
                          },
                        ),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('templates')
                              .where('templateType', isEqualTo: 'Announcement')
                              .where('status', isEqualTo: 'Active')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const SizedBox();
                            }

                            final announcements = snapshot.data!.docs;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🟢 Section Header
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8, top: 16),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.announcement_rounded,
                                        color: Color(0xFF2E7D32),
                                        size: 22,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "Announcements",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 17,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 📢 Announcement Cards
                                ...announcements.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final title = data['title'] ?? 'Untitled';
                                  final announcement =
                                      data['announcement'] ??
                                      'No details available.';
                                  final createdAt = data['createdAt'] != null
                                      ? (data['createdAt'] as Timestamp)
                                            .toDate()
                                      : DateTime.now();

                                  final formattedDate = DateFormat(
                                    'MMMM d, yyyy',
                                  ).format(createdAt);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12.withOpacity(
                                            0.06,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: const Color(0xFFE5E5E5),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // 🏷️ Title with cleaner icon
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.campaign_rounded,
                                                color: Color(0xFF2E7D32),
                                                size: 22,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          // 📄 Announcement text
                                          Text(
                                            announcement,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              color: Colors.black87,
                                              height: 1.4,
                                            ),
                                          ),

                                          const SizedBox(height: 12),

                                          // 🗓️ Date without emoji
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: Text(
                                              "Posted on $formattedDate",
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          },
                        ),

                        // Additional space at the bottom for FAB
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: ChatbotFAB(userData: widget.userData),
    );
  }
}

class _VideoLoopWidget extends StatefulWidget {
  final String videoPath;
  const _VideoLoopWidget({required this.videoPath});

  @override
  State<_VideoLoopWidget> createState() => _VideoLoopWidgetState();
}

class _VideoLoopWidgetState extends State<_VideoLoopWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        _controller.setLooping(true);
        _controller.setVolume(0);
        _controller.play();
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _controller.value.isInitialized
          ? SizedBox(width: 100, height: 100, child: VideoPlayer(_controller))
          : const SizedBox(
              width: 100,
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
    );
  }
}
