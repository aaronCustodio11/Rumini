import 'dart:convert';
import 'dart:ui';
import 'package:rumini/model/appointment_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Requestapt extends StatefulWidget {
  final Map<String, dynamic> userData;
  const Requestapt({super.key, required this.userData});

  @override
  State<Requestapt> createState() => _RequestaptState();
}

class _RequestaptState extends State<Requestapt> with TickerProviderStateMixin {
  Map<String, dynamic>? selectedCounselorSchedule;
  List<String> availableTimeSlots = [];
  bool isLoadingTimeSlots = false;
  int? selectedCounselorIndex;
  DateTime? selectedDate;
  String? selectedTimeSlot;
  List<String> selectedConcerns = [];
  TextEditingController othersController = TextEditingController();
  List<Map<String, dynamic>> counselors = [];
  List<String> reservedTimeSlots = [];
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Modern color scheme
  final Color primaryGreen = const Color.fromARGB(255, 26, 97, 50);
  final Color lightGreen = const Color(0xFFD1FAE5);
  final Color mediumGreen = const Color(0xFF6EE7B7);
  final Color darkGreen = const Color.fromARGB(255, 26, 97, 50);
  final Color accentColor = const Color.fromARGB(255, 26, 97, 50);
  final Color backgroundColor = const Color.fromARGB(255, 232, 232, 232);

  final List<String> concerns = [
    'Career',
    'Relationship',
    'Self Development',
    'Studies',
    'Social Relationship',
    'Family',
    'Abused/Sensitive Cases',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    fetchCounselors();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    othersController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (selectedDate == null ||
        selectedTimeSlot == null ||
        selectedConcerns.isEmpty ||
        selectedCounselorIndex == null) {
      _showSnackBar('Please fill in all fields', isError: true);
      return;
    }

    if (selectedConcerns.contains("Others") && othersController.text.trim().isEmpty) {
      _showSnackBar('Please specify your concern', isError: true);
      return;
    }

    try {
      String firstName = widget.userData['firstName'] ?? 'Unknown';
      String middleName = widget.userData['middleName'] ?? '';
      String lastName = widget.userData['lastName'] ?? 'Unknown';
      String extensionName = widget.userData['extensionName'] ?? '';
      String studId = widget.userData['studId'] ?? '000000';
      String college = widget.userData['college'] ?? 'Not Specified';
      String course = widget.userData['course'] ?? 'Not Specified';
      String section = widget.userData['section'] ?? 'Not Specified';
      String academicYear = widget.userData['academicYear'] ?? 'Not Specified';

      final counselor = counselors[selectedCounselorIndex!];
      String counId = counselor['counId'] ?? 'No Counselor';

      String counselorFullName = '${counselor['firstName']} '
          '${counselor['middleName'] != null && counselor['middleName'].isNotEmpty ? counselor['middleName'][0].toUpperCase() + ". " : ""}'
          '${counselor['lastName']}'
          '${counselor['extensionName'] != null && counselor['extensionName'].isNotEmpty ? " " + counselor['extensionName'] : ""}';

      String concern = selectedConcerns.contains("Others")
          ? [...selectedConcerns.where((c) => c != "Others"), othersController.text.trim()].join(", ")
          : selectedConcerns.join(", ");

      AppointmentModel newAppointment = AppointmentModel(
        id: '',
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        extensionName: extensionName,
        studId: studId,
        college: college,
        course: course,
        section: section,
        academicYear: academicYear,
        assignedCounselor: counselorFullName,
        date: selectedDate!,
        time: selectedTimeSlot!,
        concern: concern,
        createdAt: DateTime.now(),
        status: 'pending',
        counId: counId,
      );

      await FirebaseFirestore.instance.collection('appointments').add(newAppointment.toFirestore());

      _showSnackBar('Appointment Request Submitted Successfully!', isError: false);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> fetchCounselors() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('role', whereIn: ['Counselor', 'Admin'])
          .get();

      List<Map<String, dynamic>> loadedCounselors = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'counId': data['counId'] ?? '',
          'image': data['image'],
          'firstName': data['firstName'] ?? '',
          'middleName': data['middleName'] ?? '',
          'lastName': data['lastName'] ?? '',
          'extensionName': data['extensionName'] ?? '',
          'assignedCollege': data['assignedCollege'] ?? '',
          'description': data['description'] ?? '',
        };
      }).toList();

      setState(() {
        counselors = loadedCounselors;
      });

      for (int i = 0; i < counselors.length; i++) {
        if (counselors[i]['assignedCollege'] == widget.userData['college']) {
          setState(() {
            selectedCounselorIndex = i;
          });
          final selectedCounselorId = counselors[i]['counId'];
          await _fetchCounselorSchedule(selectedCounselorId);
          if (selectedDate != null) {
            await _fetchReservedTimeSlotsForDate(selectedDate!);
            _updateAvailableTimeSlots(selectedDate!);
          }
          break;
        }
      }
    } catch (e) {
      print('Error fetching counselors: $e');
    }
  }

  Future<void> _fetchCounselorSchedule(String counId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('templates')
          .where('counId', isEqualTo: counId)
          .where('templateType', isEqualTo: 'Schedule')
          .limit(1)
          .get();

      setState(() {
        selectedCounselorSchedule = snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null;
      });
    } catch (e) {
      print('Error fetching schedule: $e');
    }
  }

  Future<void> _fetchReservedTimeSlotsForDate(DateTime date) async {
    if (selectedCounselorIndex == null) {
      setState(() => reservedTimeSlots = []);
      return;
    }

    final selectedCounselorId = counselors[selectedCounselorIndex!]['counId'];
    if (selectedCounselorId == null || selectedCounselorId.isEmpty) return;

    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final timestampDate = Timestamp.fromDate(startOfDay);

      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('date', isEqualTo: timestampDate)
          .where('counId', isEqualTo: selectedCounselorId)
          .where('status', whereIn: ['pending', 'accepted'])
          .get();

      final List<String> reservedSlots = snapshot.docs
          .map((doc) => doc['time'] as String?)
          .where((time) => time != null)
          .cast<String>()
          .toList();

      setState(() {
        reservedTimeSlots = reservedSlots;
      });
    } catch (e) {
      print('Error fetching reserved time slots: $e');
    }
  }

  Future<void> _showDatePicker() async {
    try {
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      DateTime initialDate = selectedDate ?? today;

      while (initialDate.weekday == DateTime.sunday || initialDate.isBefore(today)) {
        initialDate = initialDate.add(const Duration(days: 1));
      }

      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: today,
        lastDate: DateTime(now.year + 1),
        selectableDayPredicate: (DateTime day) {
          final dayOnly = DateTime(day.year, day.month, day.day);
          return day.weekday != DateTime.sunday && !dayOnly.isBefore(today);
        },
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: primaryGreen,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
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
          isLoadingTimeSlots = true;
        });

        if (selectedCounselorIndex != null) {
          await _fetchReservedTimeSlotsForDate(picked);
          _updateAvailableTimeSlots(picked);
        }

        setState(() {
          isLoadingTimeSlots = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error opening date picker. Please try again.', isError: true);
      }
    }
  }

  void _updateAvailableTimeSlots(DateTime date) {
    if (selectedCounselorSchedule == null) {
      setState(() => availableTimeSlots = []);
      return;
    }

    String weekday = DateFormat('EEEE').format(date).toLowerCase();

    if (selectedCounselorSchedule![weekday] != null &&
        selectedCounselorSchedule![weekday] is List &&
        (selectedCounselorSchedule![weekday] as List).isNotEmpty) {
      setState(() {
        availableTimeSlots = List<String>.from(selectedCounselorSchedule![weekday]);
      });
    } else {
      setState(() {
        availableTimeSlots = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Book Appointment",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: darkGreen,
            fontSize: 20,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildUserInfoSection(isSmallScreen),
              _buildMainContent(isSmallScreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoSection(bool isSmallScreen) {
  // Helper to capitalize each word
  String _capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // Properly formatted full name
  String fullName = '${_capitalize(widget.userData['firstName'])} '
      '${widget.userData['middleName'] != null && widget.userData['middleName'].isNotEmpty ? widget.userData['middleName'][0].toUpperCase() + ". " : ""}'
      '${_capitalize(widget.userData['lastName'])}'
      '${widget.userData['extensionName'] != null && widget.userData['extensionName'].isNotEmpty ? " ${_capitalize(widget.userData['extensionName'])}" : ""}';

  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [primaryGreen.withOpacity(0.9), accentColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    padding: EdgeInsets.symmetric(
      horizontal: isSmallScreen ? 16 : 28,
      vertical: isSmallScreen ? 20 : 28,
    ),
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: isSmallScreen ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🧑‍🎓 Left side (Name + ID)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.trim(),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.badge, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        widget.userData['studId'] ?? 'N/A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 🔸 Vertical Divider
          Container(
            width: 1,
            height: isSmallScreen ? 40 : 50,
            margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 20),
            color: Colors.white.withOpacity(0.3),
          ),

          // 🎓 Right side (Course, Year, College, Section)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${widget.userData['course'] ?? 'N/A'} • ${widget.userData['academicYear'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: isSmallScreen ? 13 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.apartment, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${widget.userData['college'] ?? 'N/A'} • ${widget.userData['section'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: isSmallScreen ? 13 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildMainContent(bool isSmallScreen) {
    return Container(
      constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 800),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildSectionHeader('Select Your Counselor', Icons.psychology),
          const SizedBox(height: 16),
          _buildCounselorGrid(isSmallScreen),
          const SizedBox(height: 32),
          _buildSectionHeader('Choose Date & Time', Icons.calendar_today),
          const SizedBox(height: 16),
          _buildDateTimeSelection(isSmallScreen),
          const SizedBox(height: 32),
          _buildSectionHeader('What brings you here?', Icons.favorite),
          const SizedBox(height: 16),
          _buildConcernsSection(isSmallScreen),
          const SizedBox(height: 32),
          _buildSubmitButton(isSmallScreen),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: primaryGreen, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: darkGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildCounselorGrid(bool isSmallScreen) {
    if (counselors.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final crossAxisCount = isSmallScreen ? 2 : 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: counselors.length,
      itemBuilder: (context, index) {
        final counselor = counselors[index];
        final isSelected = selectedCounselorIndex == index;
        String formattedName = '${counselor['firstName']} '
            '${counselor['middleName'] != null && counselor['middleName'].isNotEmpty ? counselor['middleName'][0].toUpperCase() + ". " : ""}'
            '${counselor['lastName']}'
            '${counselor['extensionName'] != null && counselor['extensionName'].isNotEmpty ? " ${counselor['extensionName']}" : ""}';

        return GestureDetector(
          onTap: () async {
            setState(() {
              selectedCounselorIndex = index;
              reservedTimeSlots = [];
              selectedTimeSlot = null;
              availableTimeSlots = [];
              isLoadingTimeSlots = true;
            });

            final selectedCounselorId = counselors[index]['counId'];
            await _fetchCounselorSchedule(selectedCounselorId);

            if (selectedDate != null) {
              await _fetchReservedTimeSlotsForDate(selectedDate!);
              _updateAvailableTimeSlots(selectedDate!);
            }

            setState(() {
              isLoadingTimeSlots = false;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? primaryGreen : Colors.grey[300]!,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? primaryGreen.withOpacity(0.3) : Colors.black.withOpacity(0.05),
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          color: Colors.grey[200],
                          image: counselor['image'] != null
                              ? DecorationImage(
                                  image: MemoryImage(base64Decode(counselor['image'])),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: counselor['image'] == null
                            ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                            : null,
                      ),
                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 16),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formattedName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: lightGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            counselor['assignedCollege'] ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 9 : 10,
                              color: darkGreen,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      },
    );
  }

  Widget _buildDateTimeSelection(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _showDatePicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: lightGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.calendar_today, color: primaryGreen, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedDate == null
                              ? 'No date selected'
                              : DateFormat('EEEE, MMMM d, yyyy').format(selectedDate!),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: selectedDate == null ? Colors.grey : darkGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Available Time Slots',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
          ),
          const SizedBox(height: 12),
          isLoadingTimeSlots
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                )
              : availableTimeSlots.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'No available schedule',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableTimeSlots.map((time) {
                        bool noCounselorOrDate = (selectedCounselorIndex == null || selectedDate == null);
                        bool isReserved = reservedTimeSlots.contains(time);
                        bool isSelected = selectedTimeSlot == time;

                        return InkWell(
                          onTap: (noCounselorOrDate || isReserved)
                              ? null
                              : () {
                                  setState(() {
                                    selectedTimeSlot = isSelected ? null : time;
                                  });
                                },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryGreen
                                  : (noCounselorOrDate || isReserved)
                                      ? Colors.grey[200]
                                      : Colors.white,
                              border: Border.all(
                                color: isSelected
                                    ? primaryGreen
                                    : (noCounselorOrDate || isReserved)
                                        ? Colors.grey[300]!
                                        : lightGreen,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: isSelected
                                      ? Colors.white
                                      : (noCounselorOrDate || isReserved)
                                          ? Colors.grey[500]
                                          : primaryGreen,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  time,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (noCounselorOrDate || isReserved)
                                            ? Colors.grey[500]
                                            : darkGreen,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
        ],
      ),
    );
  }

  Widget _buildConcernsSection(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: concerns.map((concern) {
              final isSelected = selectedConcerns.contains(concern);
              return InkWell(
                onTap: () {
                  setState(() {
                    if (concern == "Others") {
                      selectedConcerns = ["Others"];
                    } else {
                      selectedConcerns.remove("Others");
                      isSelected ? selectedConcerns.remove(concern) : selectedConcerns.add(concern);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(25),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryGreen : Colors.white,
                    border: Border.all(
                      color: isSelected ? primaryGreen : Colors.grey[300]!,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    concern,
                    style: TextStyle(
                      color: isSelected ? Colors.white : darkGreen,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (selectedConcerns.contains("Others")) ...[
            const SizedBox(height: 16),
            TextField(
              controller: othersController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Please specify your concern',
                hintText: 'Tell us more about what you\'d like to discuss...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryGreen, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                prefixIcon: Icon(Icons.edit_note, color: primaryGreen),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isSmallScreen) {
    final isFormComplete = selectedDate != null &&
        selectedTimeSlot != null &&
        selectedConcerns.isNotEmpty &&
        selectedCounselorIndex != null &&
        (!selectedConcerns.contains("Others") || othersController.text.trim().isNotEmpty);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 400),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isFormComplete ? primaryGreen : Colors.grey[400],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: isFormComplete ? 8 : 2,
          shadowColor: isFormComplete ? primaryGreen.withOpacity(0.5) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: isFormComplete ? _submitRequest : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 24),
            const SizedBox(width: 12),
            Text(
              'Submit Request',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}