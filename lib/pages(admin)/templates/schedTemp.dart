import 'package:rumini/helper/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void showSchedTemp(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const ScheduleTemplateDialog(),
  );
}

class ScheduleTemplateDialog extends StatefulWidget {
  const ScheduleTemplateDialog({super.key});

  @override
  State<ScheduleTemplateDialog> createState() => _ScheduleTemplateDialogState();
}

class _ScheduleTemplateDialogState extends State<ScheduleTemplateDialog> {
  final _usersRef = FirebaseFirestore.instance.collection('Users');
  final _templatesRef = FirebaseFirestore.instance.collection('templates');

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.all(16),
      title: Row(
        children: const [
          Icon(Icons.schedule_rounded, color: Color(0xFF345F00)),
          SizedBox(width: 8),
          Text(
            "Schedule Templates",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Color(0xFF2D2D2D),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isWide ? 700 : double.maxFinite,
        height: isWide ? 500 : 480,
        child: StreamBuilder<QuerySnapshot>(
          stream: _usersRef
              .where('role', whereIn: ['Counselor', 'Admin'])
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No counselors found."));
            }

            final users = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final data = user.data() as Map<String, dynamic>;

                final String firstName = (data['firstName'] ?? '').trim();
                final String middleName = (data['middleName'] ?? '').trim();
                final String lastName = (data['lastName'] ?? '').trim();
                final String extensionName = (data['extensionName'] ?? '')
                    .trim();
                final String middleInitial = middleName.isNotEmpty
                    ? "${middleName[0].toUpperCase()}."
                    : "";
                String formattedName =
                    "${_capitalize(lastName)}, ${_capitalize(firstName)}";
                if (middleInitial.isNotEmpty)
                  formattedName += " $middleInitial";
                if (extensionName.isNotEmpty) {
                  formattedName += " ${_capitalize(extensionName)}";
                }

                final String role = data['role'] ?? 'Unknown';
                final String counId = data['counId'] ?? 'N/A';

                return FutureBuilder<QuerySnapshot>(
                  future: _templatesRef
                      .where('templateType', isEqualTo: 'Schedule')
                      .where('counId', isEqualTo: counId)
                      .limit(1)
                      .get(),
                  builder: (context, schedSnap) {
                    String modifiedAt = "No schedule yet";
                    if (schedSnap.hasData && schedSnap.data!.docs.isNotEmpty) {
                      final schedData =
                          schedSnap.data!.docs.first.data()
                              as Map<String, dynamic>;
                      if (schedData.containsKey('modifiedAt')) {
                        final ts = schedData['modifiedAt'] as Timestamp;
                        final dt = ts.toDate();
                        modifiedAt = "Last modified: ${_formatDateTime(dt)}";
                      }
                    }

                    String initials = "";
                    if (firstName.isNotEmpty)
                      initials += firstName[0].toUpperCase();
                    if (lastName.isNotEmpty)
                      initials += lastName[0].toUpperCase();

                    return Card(
                      color: const Color(0xFFF8F9F8),
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF345F00),
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formattedName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Role: $role",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    "Counselor ID: $counId",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    modifiedAt,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF345F00),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: () {
                                showEditSchedule(context, counId);
                              },
                              icon: const Icon(
                                Icons.edit_calendar_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                "Edit Schedule",
                                style: TextStyle(fontWeight: FontWeight.w500),
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
          },
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.grey),
          label: const Text("Close", style: TextStyle(color: Colors.black87)),
        ),
      ],
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _formatDateTime(DateTime date) {
    final month = _monthName(date.month);
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return "$month $day, $year — $hour:$minute $ampm";
  }

  String _monthName(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[month - 1];
  }
}
