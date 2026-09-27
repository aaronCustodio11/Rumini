import 'dart:convert';

import 'package:rumini/model/appointment_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddOrUpdateAppointmentDialog extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AddOrUpdateAppointmentDialog({super.key, required this.userData});

  @override
  State<AddOrUpdateAppointmentDialog> createState() =>
      _AddOrUpdateAppointmentDialogState();
}

class _AddOrUpdateAppointmentDialogState
    extends State<AddOrUpdateAppointmentDialog> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> studentsData = [];
  List<Map<String, dynamic>> filteredData = [];
  Map<String, dynamic>? selectedStudent;

  List<String> selectedConcerns = [];
  Map<String, dynamic>? selectedCounselor;
  String? otherConcernText;
  List<String> reservedTimeSlots = [];
  DateTime? selectedDate;
  String? selectedTimeSlot;
  late ScrollController _counselorScrollController;
  late ScrollController _studentScrollController;

  List<String> timeSlots = []; // now dynamic, no predefined static list

  List<String> concerns = [
    'Career',
    'Relationship',
    'Self Development',
    'Studies',
    'Social Relationship',
    'Family',
    'Abused/Sensitive Cases',
    'Others',
  ];
  List<Map<String, dynamic>> counselors = [
    {
      'fullName': 'John Doe',
      'studId': 'C123456',
      'assignedCollege': 'College of Science',
      'description': 'Handles personal development counseling.',
      'imageUrl': 'https://your-image-link.jpg',
    },
    // Add more counselors...
  ];

  @override
  void initState() {
    super.initState();
    fetchStudents();

    // Only fetch counselors if the current user is an Admin
    if (widget.userData['role'] == 'Admin') {
      fetchCounselors();
    } else if (widget.userData['role'] == 'Counselor') {
      // Set the current counselor as selected
      selectedCounselor = {
        'fullName': _buildFullName(widget.userData),
        'counId': widget.userData['counId'] ?? '',
        'assignedCollege': widget.userData['assignedCollege'] ?? '',
        'description': widget.userData['description'] ?? '',
        'imageBase64': widget.userData['image'] ?? '',
      };
    }

    _counselorScrollController = ScrollController();
    _studentScrollController = ScrollController();
  }

  @override
  void dispose() {
    _counselorScrollController.dispose();
    _studentScrollController.dispose();
    super.dispose();
  }

  Future<void> fetchStudents() async {
    try {
      QuerySnapshot snapshot;

      // If user is a Counselor, only fetch students assigned to them
      if (widget.userData['role'] == 'Counselor') {
        final counselorId = widget.userData['counId'] ?? '';
        snapshot = await FirebaseFirestore.instance
            .collection('Users')
            .where('role', isEqualTo: 'Student')
            .where('assignedCounselor', isEqualTo: counselorId)
            .get();
      } else {
        // For Admin, fetch all students
        snapshot = await FirebaseFirestore.instance
            .collection('Users')
            .where('role', isEqualTo: 'Student')
            .get();
      }

      final List<Map<String, dynamic>> loadedStudents = snapshot.docs
          .map((doc) => {
                'firstName': doc['firstName'] ?? '',
                'middleName': doc['middleName'] ?? '',
                'lastName': doc['lastName'] ?? '',
                'extensionName': doc['extensionName'] ?? '',
                'studId': doc['studId'] ?? '',
                'college': doc['college'] ?? '',
                'course': doc['course'] ?? '',
                'academicYear': doc['academicYear'] ?? '',
                'section': doc['section'] ?? '',
                'assignedCounselor': doc['assignedCounselor'] ?? '',
              })
          .toList();

      setState(() {
        studentsData = loadedStudents;
        filteredData = List.from(studentsData);
      });
    } catch (e) {
      print('Error fetching students: $e');
    }
  }

  Future<void> fetchCounselors() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('role', whereIn: ['Counselor', 'Admin'])
          .get();

      final List<Map<String, dynamic>> loadedCounselors =
          snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        return {
          'fullName': _buildFullName(data),
          'counId': data['counId'] ?? '',
          'assignedCollege': data['assignedCollege'] ?? '',
          'description': data['description'] ?? '',
          'imageBase64': data['image'] ?? '',
        };
      }).toList();

      setState(() {
        counselors = loadedCounselors;
      });
    } catch (e) {
      print('Error fetching counselors: $e');
    }
  }

  String _buildFullName(Map<String, dynamic> data) {
    String firstName = data['firstName'] ?? '';
    String middleName = data['middleName'] ?? '';
    String lastName = data['lastName'] ?? '';
    String extensionName = data['extensionName'] ?? '';

    return '$firstName $middleName $lastName $extensionName'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _onSearchChanged(String value) {
    value = value.toLowerCase();

    setState(() {
      filteredData = studentsData.where((student) {
        return student.entries.any((entry) {
          final fieldValue = (entry.value ?? '').toString().toLowerCase();
          return fieldValue.contains(value);
        });
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green
                  .shade900, // ✅ Changes the selected date circle to green
              onPrimary: Colors.white, // ✅ Text inside the selected date circle
              onSurface: const Color.fromARGB(
                  255, 35, 35, 35), // ✅ General text color in the date picker
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.green, // ✅ OK and CANCEL button color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
  setState(() {
    selectedDate = picked;
    selectedTimeSlot = null;
    reservedTimeSlots.clear();
    timeSlots = []; // reset
  });

  if (selectedCounselor != null) {
    await fetchTemplateForDate(selectedCounselor!['counId'], picked);
  }

  await _fetchReservedTimeSlotsForDate(picked);
}

  }
  Future<void> fetchTemplateForDate(String counId, DateTime date) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('templates')
        .where('counId', isEqualTo: counId)
        .where('templateType', isEqualTo: 'Schedule') // ✅ new filter
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      print('No schedule template found for counselor $counId');
      setState(() => timeSlots = []);
      return;
    }

    final data = snapshot.docs.first.data() as Map<String, dynamic>;

    // ✅ Determine weekday text: monday, tuesday, etc.
    final weekday = DateFormat('EEEE').format(date).toLowerCase();

    // ✅ Get slots for that weekday
    final List<dynamic>? slots = data[weekday];

    if (slots == null || slots.isEmpty) {
      print("No schedule for $weekday");
      setState(() => timeSlots = []);
      return;
    }

    setState(() {
      timeSlots = List<String>.from(slots);
    });

    print("Time slots for $weekday: $timeSlots");

  } catch (e) {
    print("Error loading template: $e");
  }
}


  Future<void> _fetchReservedTimeSlotsForDate(DateTime date) async {
    // ✅ Validate first before continuing
    if (selectedCounselor == null ||
        selectedCounselor!['counId'] == null ||
        selectedDate == null) {
      print('No counselor selected or no date selected.');
      return; // ✅ Exit early to prevent errors
    }

    try {
      final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('counId',
              isEqualTo: selectedCounselor!['counId']) // ✅ Filter by counselor
          .where('status', whereIn: [
        'pending',
        'accepted'
      ]) // ✅ Optional filter (adjust if needed)
          .get();

      final List<String> reservedSlots = snapshot.docs
          .map((doc) => doc['time'] as String?)
          .where((time) => time != null)
          .cast<String>()
          .toList();

      setState(() {
        reservedTimeSlots = reservedSlots;
      });

      print(
        'Reserved slots for counselor ${selectedCounselor!['counId']} on ${DateFormat('yyyy-MM-dd').format(date)}: $reservedSlots',
      );
    } catch (e) {
      print('Error fetching reserved time slots: $e');
    }
  }

  void _selectTimeSlot(String slot) {
    setState(() {
      selectedTimeSlot = slot;
    });
  }

  void _toggleConcern(String concern) {
    setState(() {
      if (selectedConcerns.contains(concern)) {
        selectedConcerns.remove(concern);
        if (concern == 'Others') {
          otherConcernText = null;
        }
      } else {
        selectedConcerns.add(concern);
      }
    });
  }

  Widget _buildCounselorImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return const Icon(Icons.person, size: 50, color: Colors.grey);
    }

    try {
      final bytes = base64Decode(base64String);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
        ),
      );
    } catch (e) {
      print('Error decoding image: $e');
      return const Icon(Icons.person, size: 50, color: Colors.grey);
    }
  }

  Future<void> saveAppointment() async {
  if (selectedStudent == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a student!')),
    );
    return;
  }

  if (selectedDate == null || selectedTimeSlot == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select date and time!')),
    );
    return;
  }

  if (selectedCounselor == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a counselor!')),
    );
    return;
  }

  if (selectedConcerns.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select at least one concern!')),
    );
    return;
  }

  // Check if student already has an accepted appointment
  try {
    final String studentId = selectedStudent!['studId'] ?? '';
    
    if (studentId.isNotEmpty) {
      final QuerySnapshot existingAppointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('studId', isEqualTo: studentId)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (existingAppointments.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('There is already an accepted appointment for this student.'),
            backgroundColor: Colors.red,
          ),
        );
        return; // Exit without saving
      }
    }

    // Combine concerns with otherConcernText if needed
    String finalConcerns;
    if (selectedConcerns.contains('Others') &&
        otherConcernText != null &&
        otherConcernText!.isNotEmpty) {
      finalConcerns = (selectedConcerns + [otherConcernText!]).join(", ");
    } else {
      finalConcerns = selectedConcerns.join(", ");
    }

    // Create AppointmentModel
    final appointment = AppointmentModel(
      id: '', // Firestore will generate an ID
      firstName: selectedStudent!['firstName'] ?? '',
      middleName: selectedStudent!['middleName'] ?? '',
      lastName: selectedStudent!['lastName'] ?? '',
      extensionName: selectedStudent!['extensionName'] ?? '',
      studId: selectedStudent!['studId'] ?? '',
      college: selectedStudent!['college'] ?? '',
      course: selectedStudent!['course'] ?? '',
      academicYear: selectedStudent!['academicYear'] ?? '',
      section: selectedStudent!['section'] ?? '',
      assignedCounselor: selectedCounselor!['fullName'] ?? '',
      date: selectedDate!,
      time: selectedTimeSlot!,
      concern: finalConcerns,
      status: 'pending',
      createdAt: DateTime.now(),
      counId: selectedCounselor!['counId'] ?? '',
    );

    await FirebaseFirestore.instance
        .collection('appointments')
        .add(appointment.toFirestore());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appointment saved successfully!')),
    );

    Navigator.pop(context); // Close dialog after saving
  } catch (e) {
    print('Error saving appointment: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save appointment. $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 700,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Title with Icon
            Row(
              children: [
                Icon(Icons.event_available, color: Colors.black, size: 24),
                SizedBox(width: 8),
                Text(
                  "Add Appointment",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    /// MAIN ROW: LEFT (First + Second) and RIGHT (Fourth)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// LEFT SIDE: First + Second Card
                        Expanded(
                          flex: widget.userData['role'] == 'Admin'
                              ? 1
                              : 2, // Wider student section for counselors
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // First card (Student search) remains the same
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  height: 400,
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: _searchController,
                                        onChanged: _onSearchChanged,
                                        decoration: InputDecoration(
                                          hintText: 'Search students...',
                                          prefixIcon: const Icon(Icons.search),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Search Student Results:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Student list remains the same
                                      Expanded(
                                        child: filteredData.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'No students found.',
                                                  style:
                                                      TextStyle(fontSize: 14),
                                                ),
                                              )
                                            : Scrollbar(
                                                controller:
                                                    _studentScrollController,
                                                thumbVisibility: true,
                                                child: ListView.builder(
                                                  controller:
                                                      _studentScrollController,
                                                  itemCount:
                                                      filteredData.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    // Keep the existing ListView.builder code
                                                    final student =
                                                        filteredData[index];
                                                    final fullName =
                                                        '${student['firstName']} ${student['middleName']} ${student['lastName']} ${student['extensionName']}';
                                                    final studId =
                                                        student['studId'] ?? '';
                                                    final Color defaultColor =
                                                        index % 2 == 0
                                                            ? Colors.white
                                                            : Colors
                                                                .grey.shade200;
                                                    bool isHovered = false;

                                                    return StatefulBuilder(
                                                      builder: (context,
                                                          setInnerState) {
                                                        return MouseRegion(
                                                          onEnter: (_) =>
                                                              setInnerState(() =>
                                                                  isHovered =
                                                                      true),
                                                          onExit: (_) =>
                                                              setInnerState(() =>
                                                                  isHovered =
                                                                      false),
                                                          child:
                                                              GestureDetector(
                                                            onTap: () {
                                                              setState(() {
                                                                selectedStudent =
                                                                    student;

                                                                // Only for Admin role
                                                                if (widget.userData[
                                                                        'role'] ==
                                                                    'Admin') {
                                                                  /// Get selected student's college
                                                                  final studentCollege =
                                                                      student[
                                                                          'college'];

                                                                  /// Find the counselor with matching assignedCollege
                                                                  final Map<
                                                                          String,
                                                                          dynamic>?
                                                                      autoCounselor =
                                                                      counselors
                                                                          .firstWhere(
                                                                    (counselor) =>
                                                                        counselor[
                                                                            'assignedCollege'] ==
                                                                        studentCollege,
                                                                    orElse:
                                                                        () =>
                                                                            {},
                                                                  );

                                                                  if (autoCounselor !=
                                                                      null) {
                                                                    selectedCounselor =
                                                                        autoCounselor;
                                                                    reservedTimeSlots
                                                                        .clear();
                                                                    selectedTimeSlot =
                                                                        null;

                                                                    /// If a date was already selected, refetch available time slots
                                                                    if (selectedDate !=
                                                                        null) {
                                                                      _fetchReservedTimeSlotsForDate(
                                                                          selectedDate!);
                                                                    }
                                                                  } else {
                                                                    selectedCounselor =
                                                                        null;
                                                                    reservedTimeSlots
                                                                        .clear();
                                                                    selectedTimeSlot =
                                                                        null;

                                                                    ScaffoldMessenger.of(
                                                                            context)
                                                                        .showSnackBar(
                                                                      SnackBar(
                                                                        content:
                                                                            Text('No counselor found for college: $studentCollege'),
                                                                      ),
                                                                    );
                                                                  }
                                                                }
                                                                // For Counselor role, check if there's a date selected and fetch times
                                                                else if (selectedDate !=
                                                                    null) {
                                                                  _fetchReservedTimeSlotsForDate(
                                                                      selectedDate!);
                                                                }
                                                              });
                                                            },
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: isHovered
                                                                    ? Colors
                                                                        .blue
                                                                        .shade100
                                                                    : defaultColor,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                border:
                                                                    Border.all(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade300,
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 16,
                                                                vertical: 8,
                                                              ),
                                                              child: Text(
                                                                '$fullName ($studId)',
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            14),
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Second card (Selected student info) remains the same
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Selected Student',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey, width: 1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: selectedStudent == null
                                            ? const Center(
                                                child: Text(
                                                    'No student selected.'))
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '${selectedStudent!['firstName']} ${selectedStudent!['middleName']} ${selectedStudent!['lastName']} ${selectedStudent!['extensionName']}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      Text(
                                                        '(${selectedStudent!['studId']})',
                                                        style: const TextStyle(
                                                            fontSize: 14),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    '${selectedStudent!['college']} | ${selectedStudent!['course']} | ${selectedStudent!['academicYear']} | ${selectedStudent!['section']}',
                                                    style: const TextStyle(
                                                        fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        /// RIGHT SIDE: Counselor selection (Only for Admin)
                        if (widget.userData['role'] == 'Admin')
                          Expanded(
                            flex: 1,
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                height: 500,
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Select Counselor',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: Scrollbar(
                                        controller: _counselorScrollController,
                                        thumbVisibility: true,
                                        child: ListView.builder(
                                          controller:
                                              _counselorScrollController,
                                          itemCount: counselors.length,
                                          itemBuilder: (context, index) {
                                            // Keep the existing counselor list code
                                            final counselor = counselors[index];
                                            final isSelected =
                                                selectedCounselor != null &&
                                                    selectedCounselor![
                                                            'counId'] ==
                                                        counselor['counId'];

                                            return GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  selectedCounselor = counselor;
                                                  reservedTimeSlots.clear();
                                                  selectedTimeSlot = null;
                                                });

                                                if (selectedDate != null) {
                                                  _fetchReservedTimeSlotsForDate(
                                                      selectedDate!);
                                                }
                                              },
                                              child: Card(
                                                elevation: 2,
                                                shape: RoundedRectangleBorder(
                                                  side: BorderSide(
                                                    color: isSelected
                                                        ? Colors.blue
                                                        : Colors.grey.shade300,
                                                    width: isSelected ? 2 : 1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                margin: const EdgeInsets.only(
                                                    bottom: 12),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Container(
                                                        width: 70,
                                                        height: 70,
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          color:
                                                              Colors.grey[300],
                                                        ),
                                                        child: _buildCounselorImage(
                                                            counselor[
                                                                'imageBase64']),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              counselor[
                                                                      'fullName'] ??
                                                                  'No Name',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Text(
                                                              'Counselor ID: ${counselor['counId'] ?? ''}',
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          14),
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Text(
                                                              'Assigned College: ${counselor['assignedCollege'] ?? ''}',
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          14),
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Text(
                                                              counselor[
                                                                      'description'] ??
                                                                  'No description provided.',
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          14),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
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
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Date/Time/Concerns card and save button remain the same
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// LEFT SIDE: Date & Time Slots
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Select Date',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          selectedDate != null
                                              ? DateFormat('MMMM dd, yyyy')
                                                  .format(selectedDate!)
                                              : 'No date selected',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => _selectDate(context),
                                        child: const Text('Pick Date',
                                            style: TextStyle(
                                              color:
                                                  Color.fromARGB(255, 0, 62, 2),
                                              fontWeight: FontWeight.bold,
                                            )),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Available Time Slots:',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: timeSlots.map((slot) {
                                      final isSelected =
                                          selectedTimeSlot == slot;
                                      final isDateSelected =
                                          selectedDate != null;
                                      final isReserved =
                                          reservedTimeSlots.contains(slot);
                                      final isEnabled =
                                          isDateSelected && !isReserved;

                                      return ChoiceChip(
                                        label: Text(
                                          slot,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isEnabled
                                                ? (isSelected
                                                    ? Colors.black
                                                    : Colors.black87)
                                                : Colors.grey,
                                          ),
                                        ),
                                        selected: isSelected,
                                        onSelected: isEnabled
                                            ? (_) => _selectTimeSlot(slot)
                                            : null,
                                        selectedColor: isEnabled
                                            ? Colors.green[200]
                                            : Colors.grey[300],
                                        backgroundColor: isEnabled
                                            ? Colors.grey[200]
                                            : Colors.grey[300],
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          side: BorderSide(
                                            color: isEnabled
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 16),

                            /// RIGHT SIDE: Concerns
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Concerns',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: concerns.map((concern) {
                                      final isSelected =
                                          selectedConcerns.contains(concern);
                                      return ChoiceChip(
                                        label: Text(
                                          concern,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        selected: isSelected,
                                        onSelected: (_) =>
                                            _toggleConcern(concern),
                                        selectedColor: Colors.green[200],
                                        backgroundColor: Colors.grey[200],
                                        labelStyle: TextStyle(
                                          color: isSelected
                                              ? Colors.black
                                              : Colors.black87,
                                          fontSize: 14,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  if (selectedConcerns.contains('Others')) ...[
                                    const SizedBox(height: 16),
                                    TextField(
                                      onChanged: (value) {
                                        setState(() {
                                          otherConcernText = value;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        labelText:
                                            'Please specify your concern',
                                        labelStyle:
                                            const TextStyle(fontSize: 14),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// SAVE BUTTON
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text(
                        'Save Appointment',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.blue,
                      ),
                      onPressed: saveAppointment,
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
