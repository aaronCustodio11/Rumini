import 'package:rumini/components/sidebar.dart';
import 'package:rumini/pages(admin)/monitoring/analytic_Emotion.dart';
import 'package:rumini/pages(admin)/monitoring/analytic_Mood.dart';
import 'package:rumini/pages(admin)/monitoring/calendarEmotion.dart';
import 'package:rumini/pages(admin)/monitoring/calendarMood.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Monitorst extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> studentData;
  
  const Monitorst({
    super.key,
    required this.userData,
    required this.studentData,
  });

  @override
  State<Monitorst> createState() => _MonitorstState();
}

class _MonitorstState extends State<Monitorst> {
  DateTime? _startDate;
  DateTime? _endDate;

  /// 🔹 Function to format full name
  String formatFullName(String firstName, String middleName, String lastName) {
    String capFirst(String name) => name.isNotEmpty
        ? "${name[0].toUpperCase()}${name.substring(1).toLowerCase()}"
        : "";

    String first = capFirst(firstName);
    String last = capFirst(lastName);
    String middle = middleName.isNotEmpty ? "${middleName[0].toUpperCase()}." : "";

    return [first, middle, last].where((e) => e.isNotEmpty).join(" ");
  }

  /// 🔹 Date picker function
  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // 🔹 Function to show Notification Alert Dialog
  Future<void> _showNotifyDialog() async {
    String? selectedTemplateId;
    String? selectedMessage;
    List<Map<String, dynamic>> templates = [];

    // Fetch templates from Firestore
    final snapshot = await FirebaseFirestore.instance
        .collection('templates')
        .where('templateType', isEqualTo: 'Notification')
        .get();

    templates = snapshot.docs
        .map((doc) => {
              'id': doc.id,
              'title': doc['title'],
              'message': doc['message'],
            })
        .toList();

    if (templates.isEmpty) {
      // Show message if no templates
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("No Templates Found"),
          content: const Text("There are no notification templates available."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Send Notification",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select Template:"),
                  const SizedBox(height: 8),

                  // 🔹 Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    value: selectedTemplateId,
                    hint: const Text("Choose a template"),
                    items: templates.map((template) {
                      return DropdownMenuItem<String>(
                        value: template['id'],
                        child: Text(template['title']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedTemplateId = value;
                        selectedMessage = templates
                            .firstWhere((t) => t['id'] == value)['message'];
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Show message of selected template
                  if (selectedMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        selectedMessage!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: selectedTemplateId == null
                      ? null
                      : () async {
                          // 🔹 Confirmation before sending
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Confirm Notification"),
                              content: const Text(
                                  "Are you sure you want to notify this student?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("No"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Yes"),
                                ),
                              ],
                            ),
                          );

                         if (confirm == true) {
  // ✅ Store context before async operation
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  
  // Close dialog
  navigator.pop();

  try {
    await FirebaseFirestore.instance
        .collection('notificationRequests')
        .add({
      'studId': widget.studentData["studId"],
      'templateId': selectedTemplateId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ✅ Use stored reference
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text("Notification sent successfully."),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  } catch (e) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text("Error sending notification: $e"),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade900,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Notify"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Use studentData instead of userData for student info
    final fullName = formatFullName(
      widget.studentData["firstName"] ?? "",   // Changed
      widget.studentData["middleName"] ?? "",  // Changed
      widget.studentData["lastName"] ?? "",    // Changed
    );

    return Scaffold(
      body: Row(
        children: [
          Sidebar(userData: widget.userData), // ✅ Keep for logged-in user

          Expanded(
            child: Scaffold(
              // ... rest stays the same
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /// Student Info Card
                      Card(
                        // ... card decoration
                        child: Container(
                          // ... container decoration
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            child: Row(
                              children: [
                                // ... icon container
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Student Profile",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color.fromARGB(255, 19, 102, 22),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        fullName.isEmpty
                                            ? "Unnamed Student"
                                            : fullName,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: Color.fromARGB(255, 12, 99, 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    widget.studentData["studId"] ?? "N/A", // ✅ Changed
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// Date Range + Buttons + Analytics
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _startDate != null && _endDate != null
                                      ? "From ${DateFormat.yMMMd().format(_startDate!)} to ${DateFormat.yMMMd().format(_endDate!)}"
                                      : "Select Date Range",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _pickDateRange,
                                      icon: const Icon(
                                        Icons.date_range,
                                        color: Colors.green,
                                      ),
                                      label: Text(
                                        "Pick Range",
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: _showNotifyDialog,
                                      icon: const Icon(
                                        Icons.notifications_active,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        "Notify",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            const Text(
                              "Mood Analytics",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            MoodAnalyticsScreen(
                              userId: widget.studentData["studId"] ?? "", // ✅ Changed
                              startDate: _startDate,
                              endDate: _endDate,
                            ),

                            const SizedBox(height: 24),

                            const Text(
                              "Emotion Analytics",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            EmotionAnalyticsScreen(
                              userId: widget.studentData["studId"] ?? "", // ✅ Changed
                              startDate: _startDate,
                              endDate: _endDate,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// Mood & Emotion Calendars
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: SizedBox(
                                  height: 400,
                                  child: CustomCalendarMood(
                                    title: "Mood Calendar",
                                    studId: widget.studentData["studId"] ?? "", // ✅ Changed
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: SizedBox(
                                  height: 400,
                                  child: CustomCalendarEmotion(
                                    title: "Emotion Calendar",
                                    studId: widget.studentData["studId"] ?? "", // ✅ Changed
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}