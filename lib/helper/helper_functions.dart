import 'dart:ui';
import 'package:rumini/model/appointment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

//display error message to the user

void displayMessageError(String message, BuildContext context) {
  showDialog(
      context: context,
      builder: (context) => AlertDialog(
            title: Text(message),
          ));
}

Widget buildImageWidget(
  String? path, {
  double height = 100,
  double width = 100,
  double borderRadius = 10,
}) {
  if (path == null || path.isEmpty) {
    return const Icon(
      Icons.image_not_supported,
      size: 40,
      color: Colors.grey,
    );
  }

  if (path.startsWith('http')) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        path,
        height: height,
        width: width,
        fit: BoxFit.cover,
      ),
    );
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: Image.asset(
      path,
      height: height,
      width: width,
      fit: BoxFit.cover,
    ),
  );
}

Widget buildSelectableContainerColumn() {
  // Example data
  final List<Map<String, String>> items = [
    {
      'image': 'assets/pleasant.png',
      'label': 'Pleasant',
    },
    {
      'image': 'assets/unpleasant.png',
      'label': 'Unpleasant',
    },
    {
      'image': 'assets/neutral.png',
      'label': 'Neutral',
    },
  ];

  return StatefulBuilder(
    builder: (context, setState) {
      int selectedIndex = -1; // no selection by default

      return Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = selectedIndex == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedIndex = index;
                print('Selected: ${item['label']}');
              });
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: isSelected ? Colors.green.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.green : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    item['image']!,
                    height: 80,
                    width: 80,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item['label']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.green.shade800 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    },
  );
}

//methods na labas sa add appointments
void showAppointmentDetails(
    BuildContext context, AppointmentModel appointment) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Appointment Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Full Name: ${appointment.firstName} ${appointment.middleName} ${appointment.lastName} ${appointment.extensionName}"),
            Text("Extension Name: ${appointment.extensionName}"),
            Text("Student No.: ${appointment.studId}"),
            Text("Department: ${appointment.college}"),
            Text("Course: ${appointment.course}"),
            Text("Year&Section: ${appointment.section}"),
            Text("Assigned Counselor: ${appointment.assignedCounselor}"),
            Text("Concern: ${appointment.concern}"),
            Text(
                "Date: ${appointment.date.toLocal().toString().split(' ')[0]}"),
            Text("Time: ${appointment.time}"),
            Text("Status: ${appointment.status}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Close"),
          ),
        ],
      );
    },
  );
}

void showStudentDetailsDialog(BuildContext context, DocumentSnapshot doc) {
  final fullName =
      "${doc['firstName'] ?? ''} ${doc['middleName'] ?? ''} ${doc['lastName'] ?? ''} ${doc['extensionName'] ?? ''}";

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(fullName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Student ID: ${doc['studId'] ?? ''}"),
          Text("College: ${doc['college'] ?? ''}"),
          Text("Course: ${doc['course'] ?? ''}"),
          Text("Academic Year: ${doc['academicYear'] ?? ''}"),
          Text("Assigned Counselor: ${doc['assignedCounselor'] ?? ''}"),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    ),
  );
}

class WebCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.trackpad,
      };
}
final _templatesRef = FirebaseFirestore.instance.collection('templates');

 Future<void> showEditSchedule(BuildContext context, String counId) async {
    final docQuery = await _templatesRef
        .where('templateType', isEqualTo: 'Schedule')
        .where('counId', isEqualTo: counId)
        .limit(1)
        .get();

    DocumentSnapshot? scheduleDoc = docQuery.docs.isNotEmpty
        ? docQuery.docs.first
        : null;

    Map<String, dynamic> scheduleData = {
      'monday': [],
      'tuesday': [],
      'wednesday': [],
      'thursday': [],
      'friday': [],
      'saturday': [],
      'sunday': [],
    };

    if (scheduleDoc != null) {
      final data = scheduleDoc.data() as Map<String, dynamic>? ?? {};
      for (var key in scheduleData.keys) {
        final value = data[key];
        if (value is Iterable) {
          scheduleData[key] = List<String>.from(value);
        } else if (value is String && value.isNotEmpty) {
          scheduleData[key] = [value];
        } else {
          scheduleData[key] = [];
        }
      }
    }

    final List<String> timeSlots = [
      "8:00 AM - 9:00 AM",
      "9:00 AM - 10:00 AM",
      "10:00 AM - 11:00 AM",
      "11:00 AM - 12:00 PM",
      "12:00 PM - 1:00 PM",
      "1:00 PM - 2:00 PM",
      "2:00 PM - 3:00 PM",
    ];

    final isWide = MediaQuery.of(context).size.width > 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            if (isSaving) {
              return const Center(
                child: AlertDialog(
                  backgroundColor: Colors.white,
                  content: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF345F00)),
                        SizedBox(height: 16),
                        Text("Saving schedule... Please wait"),
                      ],
                    ),
                  ),
                ),
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: Color(0xFF345F00),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Edit Schedule — $counId",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: isWide ? 500 : double.maxFinite,
                height: 480,
                child: SingleChildScrollView(
                  child: Column(
                    children: scheduleData.keys.map((day) {
                      final selectedTimes = List<String>.from(
                        scheduleData[day] ?? [],
                      );
                      return Card(
                        color: const Color(0xFFF8F9F8),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.today_rounded,
                                    size: 18,
                                    color: Color(0xFF345F00),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    day[0].toUpperCase() + day.substring(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Color(0xFF2D2D2D),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: timeSlots.map((slot) {
                                  final isSelected = selectedTimes.contains(
                                    slot,
                                  );
                                  return ChoiceChip(
                                    label: Text(
                                      slot,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFF345F00),
                                    backgroundColor: Colors.grey.shade100,
                                    onSelected: (bool selected) {
                                      setState(() {
                                        if (selected) {
                                          selectedTimes.add(slot);
                                        } else {
                                          selectedTimes.remove(slot);
                                        }
                                        scheduleData[day] = selectedTimes;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.refresh, color: Colors.orange),
                  label: const Text("Reset"),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text("Confirm Reset"),
                        content: const Text(
                          "Are you sure you want to clear all schedule selections?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Reset"),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      setState(() {
                        for (var key in scheduleData.keys) {
                          scheduleData[key] = [];
                        }
                      });
                    }
                  },
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                  label: const Text("Cancel"),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text("Save"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF345F00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () async {
                    setState(() => isSaving = true);
                    try {
                      // 🔹 Ensure each day's time slots are sorted
                      for (var day in scheduleData.keys) {
                        final List<String> selectedTimes = List<String>.from(
                          scheduleData[day],
                        );
                        selectedTimes.sort(
                          (a, b) => timeSlots
                              .indexOf(a)
                              .compareTo(timeSlots.indexOf(b)),
                        );
                        scheduleData[day] = selectedTimes;
                      }

                      final dataToSave = {
                        'counId': counId,
                        'templateType': 'Schedule',
                        ...scheduleData,
                        'modifiedAt': FieldValue.serverTimestamp(),
                      };

                      if (scheduleDoc == null) {
                        await _templatesRef.add(dataToSave);
                      } else {
                        await _templatesRef
                            .doc(scheduleDoc.id)
                            .update(dataToSave);
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("✅ Schedule saved successfully"),
                            backgroundColor: Color(0xFF345F00),
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("❌ Error saving schedule: $e"),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    } finally {
                      if (context.mounted) setState(() => isSaving = false);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }