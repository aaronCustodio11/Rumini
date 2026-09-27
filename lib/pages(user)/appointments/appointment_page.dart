import 'package:rumini/pages(user)/notifications/notif.dart';
import 'package:rumini/profilePage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AppointmentPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AppointmentPage({super.key, required this.userData});

  @override
  _AppointmentPageState createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Filter values
  String _statusFilter = 'All';
  String _dateRangeFilter = 'Last 7 days'; // Default
  String _timeRangeFilter = 'All';
  String _concernFilter = 'All';

  // Filter options
  final List<String> _statusOptions = ['All', 'missed', 'completed'];
  final List<String> _dateRangeOptions = [
    'Last 7 days',
    'Last month',
    'Last year',
    'All appointments',
  ];
  final List<String> _timeRangeOptions = [
    'All',
    '8:00 AM - 9:00 AM',
    '9:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
    '11:00 AM - 12:00 PM',
    '1:00 PM - 2:00 PM',
    '2:00 PM - 3:00 PM',
    '3:00 PM - 4:00 PM',
  ];
  final List<String> _concernOptions = [
    'All',
    'Career',
    'Relationship',
    'Self Development',
    'Studies',
    'Social Relationship',
    'Family',
    'Abused/Sensitive Cases',
    'Others',
  ];

  // Function to show appointment details dialog
  void _showAppointmentDetailsDialog(
    String appointmentId,
    Map<String, dynamic> appointmentData,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Appointment Details',
            style: TextStyle(
              color: Color(0xFF1B5E20),
              fontWeight: FontWeight.bold,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                _buildDetailRow(
                  'Date',
                  DateFormat(
                    'MMMM dd, yyyy',
                  ).format(appointmentData['date'].toDate()),
                ),
                _buildDetailRow('Time', appointmentData['time']),
                _buildDetailRow(
                  'Counselor',
                  appointmentData['assignedCounselor'],
                ),
                _buildDetailRow('Status', appointmentData['status']),
                _buildDetailRow(
                  'Concern',
                  appointmentData['concern'] ?? 'No concern specified',
                ),
                _buildDetailRow(
                  'Submitted On',
                  DateFormat(
                    'MMMM dd, yyyy - hh:mm a',
                  ).format(appointmentData['createdAt'].toDate()),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            // 🌿 Improved "Give Feedback" Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _showFeedbackBottomSheet(appointmentId, appointmentData);
              },
              icon: const Icon(Icons.favorite, color: Colors.white),
              label: const Text(
                'Give Feedback',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                backgroundColor: const Color(0xFF2E7D32),
                shadowColor: Colors.greenAccent.shade200,
                elevation: 6,
              ),
            ),

            // 🧭 Close Button (simple outlined style)
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1B5E20), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Color(0xFF1B5E20),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFeedbackBottomSheet(
    String appointmentId,
    Map<String, dynamic> appointmentData,
  ) async {
    int selectedRating = 0;
    bool isSubmitting = false;
    final TextEditingController feedbackController = TextEditingController();

    // 🔹 Check if feedback already exists
    final existingFeedback = await FirebaseFirestore.instance
        .collection('feedback')
        .where('appointmentId', isEqualTo: appointmentId)
        .limit(1)
        .get();

    if (existingFeedback.docs.isNotEmpty) {
      final feedbackDoc = existingFeedback.docs.first;
      final feedbackData = feedbackDoc.data();
      final submittedAt = (feedbackData['submittedAt'] as Timestamp?)?.toDate();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Feedback Already Submitted",
            style: TextStyle(
              color: Color(0xFF1B5E20),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "You have already submitted feedback for this appointment. Thank you for sharing your thoughts 💚",
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < (feedbackData['rate'] ?? 0)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: Colors.green,
                    size: 22,
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                "Submitted on: ${submittedAt != null ? DateFormat('MMMM dd, yyyy - hh:mm a').format(submittedAt) : 'Unknown date'}",
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Close",
                style: TextStyle(color: Color(0xFF1B5E20)),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // 🔹 Feedback form if not yet submitted
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 60,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      "We value your feedback 💚",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your feedback helps the Guidance Office enhance and improve mental health support for all students.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Rating Section
                  const Text(
                    "Rate your appointment:",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: Colors.green,
                          size: 30,
                        ),
                        onPressed: () {
                          setState(() => selectedRating = index + 1);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 10),

                  // Feedback Text
                  const Text(
                    "Additional feedback (optional):",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: feedbackController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Share your experience or suggestions...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.green.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (selectedRating == 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Please rate your appointment first 💚",
                                    ),
                                  ),
                                );
                                return;
                              }

                              setState(() => isSubmitting = true);
                              final feedbackText =
                                  feedbackController.text.trim().isEmpty
                                  ? "The student has no text feedback"
                                  : feedbackController.text.trim();

                              await FirebaseFirestore.instance
                                  .collection('feedback')
                                  .add({
                                    'appointmentId': appointmentId,
                                    'counId': appointmentData['counId'],
                                    'rate': selectedRating,
                                    'feedback': feedbackText,
                                    'submittedAt': FieldValue.serverTimestamp(),
                                    'studId': widget.userData['studId'],
                                    'college': widget.userData['college'],
                                  });

                              setState(() => isSubmitting = false);
                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Thank you for your feedback 💚",
                                  ),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Submit Feedback",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to build detail rows in dialog
  Widget _buildDetailRow(String label, String value) {
    // Define icon based on label
    IconData labelIcon;
    switch (label) {
      case 'Date':
        labelIcon = Icons.calendar_today;
        break;
      case 'Time':
        labelIcon = Icons.access_time;
        break;
      case 'Counselor':
        labelIcon = Icons.person;
        break;
      case 'Status':
        labelIcon = Icons.check_circle;
        break;
      case 'Concern':
        labelIcon = Icons.psychology;
        break;
      case 'Submitted On':
        labelIcon = Icons.event_note;
        break;
      default:
        labelIcon = Icons.info;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(labelIcon, size: 16, color: Color(0xFF1B5E20)),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Function to build filter section with responsiveness
  Widget _buildFilterSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt, color: Color(0xFF1B5E20), size: 20),
                SizedBox(width: 8),
                Text(
                  'Filter Appointments',
                  style: TextStyle(
                    color: const Color(0xFF1B5E20),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Always use 2x2 grid layout for filters
            Column(
              children: [
                // Row 1: Status and Date Range filters
                Row(
                  children: [
                    // Status Filter
                    Expanded(
                      child: _buildDropdownFilter(
                        'Status',
                        _statusFilter,
                        _statusOptions,
                        (newValue) {
                          setState(() {
                            _statusFilter = newValue!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Date Range Filter
                    Expanded(
                      child: _buildDropdownFilter(
                        'Date Range',
                        _dateRangeFilter,
                        _dateRangeOptions,
                        (newValue) {
                          setState(() {
                            _dateRangeFilter = newValue!;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Row 2: Time Range and Concern filters
                Row(
                  children: [
                    // Time Range Filter
                    Expanded(
                      child: _buildDropdownFilter(
                        'Time',
                        _timeRangeFilter,
                        _timeRangeOptions,
                        (newValue) {
                          setState(() {
                            _timeRangeFilter = newValue!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Concern Filter
                    Expanded(
                      child: _buildDropdownFilter(
                        'Concern',
                        _concernFilter,
                        _concernOptions,
                        (newValue) {
                          setState(() {
                            _concernFilter = newValue!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build dropdown filters with improved responsiveness

  Widget _buildDropdownFilter(
    String label,
    String currentValue,
    List<String> options,
    Function(String?) onChanged,
  ) {
    // Define icon based on label
    IconData labelIcon;
    switch (label) {
      case 'Status':
        labelIcon = Icons.check_circle_outline;
        break;
      case 'Date Range':
        labelIcon = Icons.date_range;
        break;
      case 'Time':
        labelIcon = Icons.schedule;
        break;
      case 'Concern':
        labelIcon = Icons.psychology;
        break;
      default:
        labelIcon = Icons.label;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(labelIcon, size: 14, color: Color(0xFF1B5E20)),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF1B5E20).withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Rest of the method remains the same
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
            color: const Color.fromARGB(255, 237, 237, 237),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF4CAF50)),
              items: options.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // Function to filter appointments based on selected filters
  bool _filterAppointment(Map<String, dynamic> appointment) {
    // Status filter
    bool matchesStatus =
        _statusFilter == 'All' || appointment['status'] == _statusFilter;

    // Date range filter
    DateTime appointmentDate = appointment['date'].toDate();
    bool matchesDateRange = true;

    if (_dateRangeFilter == 'Last 7 days') {
      DateTime sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      matchesDateRange = appointmentDate.isAfter(sevenDaysAgo);
    } else if (_dateRangeFilter == 'Last month') {
      DateTime oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
      matchesDateRange = appointmentDate.isAfter(oneMonthAgo);
    } else if (_dateRangeFilter == 'Last year') {
      DateTime oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      matchesDateRange = appointmentDate.isAfter(oneYearAgo);
    }

    // Time range filter
    bool matchesTimeRange =
        _timeRangeFilter == 'All' || appointment['time'] == _timeRangeFilter;

    // Concern filter
    bool matchesConcern = true;

    if (_concernFilter != 'All') {
      if (_concernFilter == 'Others') {
        // Check if the concern is not one of the standard concerns
        List<String> standardConcerns = [
          'Career',
          'Relationship',
          'Self Development',
          'Studies',
          'Social Relationship',
          'Family',
          'Abused/Sensitive Cases',
        ];
        matchesConcern = !standardConcerns.contains(appointment['concern']);
      } else {
        matchesConcern = appointment['concern'] == _concernFilter;
      }
    }

    return matchesStatus &&
        matchesDateRange &&
        matchesTimeRange &&
        matchesConcern;
  }

  Widget _buildAppointmentListItem(
    String appointmentId,
    Map<String, dynamic> appointment,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feedback')
          .where('appointmentId', isEqualTo: appointmentId)
          .snapshots(), // ✅ live listener
      builder: (context, snapshot) {
        bool hasFeedback = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            title: Text(
              DateFormat('MMMM dd, yyyy').format(appointment['date'].toDate()),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Color(0xFF4CAF50),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      appointment['time'],
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 14,
                      color: Color(0xFF4CAF50),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      appointment['assignedCounselor'],
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.label, size: 14, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        appointment['concern'] ?? 'No concern specified',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      hasFeedback ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: hasFeedback ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasFeedback ? 'Rated' : 'Not Rated',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasFeedback ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF4CAF50),
            ),
            onTap: () =>
                _showAppointmentDetailsDialog(appointmentId, appointment),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Green background
          Container(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            color: Colors.green[900],
          ),

          // Curved white background
          Positioned(
            top: MediaQuery.of(context).size.height * 0.27,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              width: MediaQuery.of(context).size.width,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F0F0),
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
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Appointments',
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
                                .where('studId', isEqualTo: widget.userData['studId'])
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

                // ✅ Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Filter Section
                        _buildFilterSection(),
                        const SizedBox(height: 16),

                        // Appointment History
                        Row(
                          children: const [
                            Icon(
                              Icons.history,
                              color: Color(0xFF1B5E20),
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Appointment History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('appointments')
                              .where(
                                'studId',
                                isEqualTo: widget.userData['studId'],
                              )
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF4CAF50),
                                ),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: Text(
                                    'No appointments found',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                              );
                            }

                            // Filtered results
                            var filteredAppointments = snapshot.data!.docs
                                .map((doc) {
                                  Map<String, dynamic> data =
                                      doc.data() as Map<String, dynamic>;
                                  data['docId'] = doc.id;
                                  return data;
                                })
                                .where(_filterAppointment)
                                .toList();

                            if (filteredAppointments.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: Text(
                                    'No matching appointments found',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredAppointments.length,
                              itemBuilder: (context, index) {
                                final appointment = filteredAppointments[index];
                                return _buildAppointmentListItem(
                                  appointment['docId'],
                                  appointment,
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
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
