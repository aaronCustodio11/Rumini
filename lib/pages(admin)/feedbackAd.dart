import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rumini/components/sidebar.dart';

class FeedbackAd extends StatefulWidget {
  final Map<String, dynamic> userData;
  const FeedbackAd({super.key, required this.userData});

  @override
  State<FeedbackAd> createState() => _FeedbackAdState();
}

class _FeedbackAdState extends State<FeedbackAd> {
  final Map<String, String> studentCache = {};
  final Map<String, String> counselorCache = {};
  String? selectedCollege;
  String searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String? selectedCounselorId;
  String? selectedCounselorName;
  bool _showAnalytics = true; // default: visible

  // ✅ Firestore stream with filters applied dynamically
  Stream<QuerySnapshot<Map<String, dynamic>>> _getFeedbackStream() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'feedback',
    );

    // Apply date filter
    if (_startDate != null && _endDate != null) {
      query = query
          .where(
            'submittedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
          )
          .where(
            'submittedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(_endDate!),
          );
    }

    // Apply counselor filter
    if (selectedCounselorId != null && selectedCounselorId!.isNotEmpty) {
      query = query.where('counId', isEqualTo: selectedCounselorId);
    }

    // ✅ Apply college filter
    if (selectedCollege != null &&
        selectedCollege!.isNotEmpty &&
        selectedCollege != "ALL") {
      query = query.where('college', isEqualTo: selectedCollege);
    }

    return query.orderBy('submittedAt', descending: true).snapshots();
  }

  /// 📊 Get Average Rating and Count
  Future<Map<String, dynamic>> _getFeedbackStats() async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'feedback',
    );

    // Apply filters
    if (_startDate != null && _endDate != null) {
      query = query
          .where(
            'submittedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
          )
          .where(
            'submittedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(_endDate!),
          );
    }
    if (selectedCounselorId != null && selectedCounselorId!.isNotEmpty) {
      query = query.where('counId', isEqualTo: selectedCounselorId);
    }
    if (selectedCollege != null &&
        selectedCollege != "ALL" &&
        selectedCollege!.isNotEmpty) {
      query = query.where('college', isEqualTo: selectedCollege);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) {
      return {
        'average': 0.0,
        'count': 0,
        'distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      };
    }

    final ratings = <double>[];
    final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    for (var doc in snapshot.docs) {
      final rate = doc.data()['rate'];
      final value = (rate is num)
          ? rate.toDouble()
          : double.tryParse(rate.toString()) ?? 0;
      if (value >= 1 && value <= 5) {
        ratings.add(value);
        distribution[value.toInt()] = distribution[value.toInt()]! + 1;
      }
    }

    final average = ratings.isEmpty
        ? 0.0
        : ratings.reduce((a, b) => a + b) / ratings.length;

    return {
      'average': average,
      'count': ratings.length,
      'distribution': distribution,
    };
  }

  /// 🧾 Get Student Name
  Future<String> getStudentName(String studId) async {
    if (studentCache.containsKey(studId)) return studentCache[studId]!;
    final query = await FirebaseFirestore.instance
        .collection('Users')
        .where('studId', isEqualTo: studId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final name = formatName(query.docs.first.data());
      studentCache[studId] = name;
      return name;
    }
    return "Unknown Student";
  }

  /// 🧾 Get Counselor Name
  Future<String> getCounselorName(String counId) async {
    if (counselorCache.containsKey(counId)) return counselorCache[counId]!;
    final query = await FirebaseFirestore.instance
        .collection('Users')
        .where('counId', isEqualTo: counId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final name = formatName(query.docs.first.data());
      counselorCache[counId] = name;
      return name;
    }
    return "Unknown Counselor";
  }

  /// 🧩 Name formatter
  String formatName(Map<String, dynamic> user) {
    final first = user['firstName'] ?? '';
    final middle = user['middleName'] ?? '';
    final last = user['lastName'] ?? '';
    final ext = user['extensionName'] ?? '';
    String middleInitial = middle.isNotEmpty
        ? '${middle[0].toUpperCase()}.'
        : '';
    return '$first $middleInitial $last $ext'.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(userData: widget.userData),
          Expanded(
            child: Scaffold(
              backgroundColor: const Color.fromARGB(255, 232, 232, 232),
              appBar: AppBar(
                backgroundColor: const Color.fromARGB(255, 232, 232, 232),
                elevation: 0,
                title: Row(
                  children: [
                    Icon(
                      Icons.feedback_outlined,
                      color: Colors.green.shade900,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Feedback Management",
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      /// 🔹 Search & Filter Card
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  /// 🔍 Search
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText:
                                            "Search student or counselor...",
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          color: Color(0xFF4CAF50),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF4CAF50),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF4CAF50),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          searchQuery = value.toLowerCase();
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  /// 📅 Date Filter
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF4CAF50),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.date_range,
                                      size: 18,
                                    ),
                                    label: const Text("Date"),
                                    onPressed: () async {
                                      final picked = await showDateRangePicker(
                                        context: context,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _startDate = picked.start;
                                          _endDate = picked.end.add(
                                            const Duration(
                                              hours: 23,
                                              minutes: 59,
                                              seconds: 59,
                                            ),
                                          );
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),

                                  /// ❌ Clear Date
                                  if (_startDate != null && _endDate != null)
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Color(0xFFEF5350),
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        foregroundColor: const Color(
                                          0xFFEF5350,
                                        ),
                                      ),
                                      icon: const Icon(Icons.clear, size: 18),
                                      label: const Text("Clear Date"),
                                      onPressed: () {
                                        setState(() {
                                          _startDate = null;
                                          _endDate = null;
                                        });
                                      },
                                    ),
                                  const SizedBox(width: 8),

                                  /// 👨‍🏫 Counselor Filter (Admin only)
                                  if (widget.userData?['role'] == 'Admin')
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Color(0xFF4CAF50),
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        foregroundColor: const Color(
                                          0xFF4CAF50,
                                        ),
                                      ),
                                      icon: const Icon(Icons.person, size: 18),
                                      label: Text(
                                        selectedCounselorName ?? "Counselor",
                                      ),
                                      onPressed: () async {
                                        final counselorSnap =
                                            await FirebaseFirestore.instance
                                                .collection('Users')
                                                .where(
                                                  'role',
                                                  whereIn: [
                                                    'Counselor',
                                                    'Admin',
                                                  ],
                                                )
                                                .get();

                                        if (counselorSnap.docs.isEmpty) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "No counselors found.",
                                                ),
                                              ),
                                            );
                                          }
                                          return;
                                        }

                                        String? tempId = selectedCounselorId;
                                        String? tempName =
                                            selectedCounselorName;

                                        await showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              title: const Text(
                                                "Select Counselor",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF4CAF50),
                                                ),
                                              ),
                                              content: DropdownButtonFormField<String>(
                                                value: tempId,
                                                isExpanded: true,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: "Counselor",
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                items: counselorSnap.docs.map((
                                                  doc,
                                                ) {
                                                  final data = doc.data();
                                                  final name =
                                                      "${data['firstName']} ${data['lastName'] ?? ''}"
                                                          .trim();
                                                  return DropdownMenuItem<
                                                    String
                                                  >(
                                                    value: data['counId'],
                                                    child: Text(name),
                                                  );
                                                }).toList(),
                                                onChanged: (value) {
                                                  final selectedDoc = counselorSnap
                                                      .docs
                                                      .firstWhere(
                                                        (d) =>
                                                            d.data()['counId'] ==
                                                            value,
                                                      );
                                                  final data = selectedDoc
                                                      .data();
                                                  tempId = value;
                                                  tempName =
                                                      "${data['firstName']} ${data['lastName'] ?? ''}"
                                                          .trim();
                                                },
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text(
                                                    "Cancel",
                                                    style: TextStyle(
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF4CAF50,
                                                            ),
                                                      ),
                                                  onPressed: () {
                                                    setState(() {
                                                      selectedCounselorId =
                                                          tempId;
                                                      selectedCounselorName =
                                                          tempName;
                                                    });
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text("Apply"),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  if (selectedCounselorId != null &&
                                      widget.userData?['role'] == 'Admin')
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Color(0xFFEF5350),
                                            width: 1.5,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                          ),
                                          foregroundColor: const Color(
                                            0xFFEF5350,
                                          ),
                                        ),
                                        icon: const Icon(Icons.clear, size: 18),
                                        label: const Text("Clear Counselor"),
                                        onPressed: () {
                                          setState(() {
                                            selectedCounselorId = null;
                                            selectedCounselorName = null;
                                          });
                                        },
                                      ),
                                    ),

                                  const SizedBox(width: 8),

                                  /// 🏫 College Filter (All Users)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFF4CAF50),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      foregroundColor: const Color(0xFF4CAF50),
                                    ),
                                    icon: const Icon(Icons.school, size: 18),
                                    label: Text(selectedCollege ?? "College"),
                                    onPressed: () async {
                                      const colleges = [
                                        'ALL'
                                            'CAS',
                                        'CEIT',
                                        'CABA',
                                        'COED',
                                        'CPAG',
                                      ];
                                      String? tempCollege = selectedCollege;

                                      await showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            title: const Text(
                                              "Select College",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF4CAF50),
                                              ),
                                            ),
                                            content:
                                                DropdownButtonFormField<String>(
                                                  value: tempCollege,
                                                  isExpanded: true,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: "College",
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
                                                  items: colleges.map((
                                                    college,
                                                  ) {
                                                    return DropdownMenuItem<
                                                      String
                                                    >(
                                                      value: college,
                                                      child: Text(college),
                                                    );
                                                  }).toList(),
                                                  onChanged: (value) {
                                                    tempCollege = value;
                                                  },
                                                ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text(
                                                  "Cancel",
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF4CAF50,
                                                  ),
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    selectedCollege =
                                                        tempCollege;
                                                  });
                                                  Navigator.pop(context);
                                                },
                                                child: const Text("Apply"),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),

                                  const SizedBox(width: 8),

                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFF4CAF50),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      foregroundColor: const Color(0xFF4CAF50),
                                    ),
                                    icon: Icon(
                                      _showAnalytics
                                          ? Icons.visibility_off_outlined
                                          : Icons.analytics_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _showAnalytics
                                          ? "Hide Analytics"
                                          : "Show Analytics",
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showAnalytics = !_showAnalytics;
                                      });
                                    },
                                  ),
                                ],
                              ),

                              /// Show Selected Filters
                              if (_startDate != null && _endDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "Selected range: ${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}",
                                    style: const TextStyle(
                                      color: Color(0xFF4CAF50),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (selectedCounselorName != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "Filtered by Counselor: $selectedCounselorName",
                                    style: const TextStyle(
                                      color: Color(0xFF4CAF50),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (selectedCollege != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "Filtered by College: $selectedCollege",
                                    style: const TextStyle(
                                      color: Color(0xFF4CAF50),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      if (_showAnalytics)
                        /// 📊 Enhanced Feedback Analytics Section (with enriched visuals)
                        FutureBuilder<Map<String, dynamic>>(
                          future: _getFeedbackStats(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (!snapshot.hasData) return const SizedBox();

                            final stats = snapshot.data!;
                            final avgRating = stats['average'] as double;
                            final count = stats['count'] as int;
                            final distribution =
                                stats['distribution'] as Map<int, int>;
                            final todayFeedback =
                                stats['today'] ??
                                0; // optional: count for today
                            final lastMonthCount = stats['lastMonth'] ?? count;
                            final trendUp = count >= lastMonthCount;
                            final percentChange = lastMonthCount == 0
                                ? 0
                                : (((count - lastMonthCount) / lastMonthCount) *
                                          100)
                                      .round();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🔹 ROW 1 — Average Rating + Total Count
                                Row(
                                  children: [
                                    // 🟩 Average Rating Overview
                                    Expanded(
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        elevation: 6,
                                        margin: const EdgeInsets.only(
                                          right: 8,
                                          bottom: 16,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.green.shade700,
                                                Colors.green.shade400,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: const [
                                                  Icon(
                                                    Icons.favorite,
                                                    color: Colors.white,
                                                    size: 28,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    "Average Rating Overview",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    avgRating.toStringAsFixed(
                                                      1,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 46,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Text(
                                                    "/ 5",
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "Based on $count feedback${_startDate != null ? ' (filtered)' : ' this month'}.",
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 🟩 Total Feedback Count
                                    Expanded(
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        elevation: 4,
                                        margin: const EdgeInsets.only(
                                          left: 8,
                                          bottom: 16,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.feedback_outlined,
                                                    color:
                                                        Colors.green.shade700,
                                                    size: 26,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    "Total Feedback Count",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    "$count",
                                                    style: TextStyle(
                                                      fontSize: 42,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.green.shade900,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    trendUp
                                                        ? Icons.arrow_upward
                                                        : Icons.arrow_downward,
                                                    color: trendUp
                                                        ? Colors.green
                                                        : Colors.redAccent,
                                                    size: 24,
                                                  ),
                                                  Text(
                                                    "${percentChange.abs()}%",
                                                    style: TextStyle(
                                                      color: trendUp
                                                          ? Colors.green
                                                          : Colors.redAccent,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              const Text(
                                                "Feedbacks received from students.",
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.today,
                                                    size: 20,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    "$todayFeedback new today",
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              // Mini progress indicator (visual gauge)
                                              LinearProgressIndicator(
                                                value: (count / (count + 10))
                                                    .clamp(0.0, 1.0),
                                                minHeight: 6,
                                                backgroundColor:
                                                    Colors.grey.shade200,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.green.shade600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // 🔹 ROW 2 — Rating Distribution Chart (Improved)
                                Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 4,
                                  margin: const EdgeInsets.only(bottom: 20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.bar_chart_rounded,
                                              color: Colors.green.shade700,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              "Feedback Rating Distribution",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),

                                        // Chart
                                        SizedBox(
                                          height: 220,
                                          child: BarChart(
                                            BarChartData(
                                              alignment:
                                                  BarChartAlignment.spaceAround,
                                              borderData: FlBorderData(
                                                show: false,
                                              ),
                                              gridData: FlGridData(
                                                show: true,
                                                drawHorizontalLine: true,
                                                horizontalInterval: 1,
                                                getDrawingHorizontalLine:
                                                    (value) {
                                                      return FlLine(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                        strokeWidth: 0.8,
                                                      );
                                                    },
                                              ),
                                              titlesData: FlTitlesData(
                                                bottomTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    reservedSize: 35,
                                                    getTitlesWidget: (value, meta) {
                                                      final rating = value
                                                          .toInt();
                                                      return Column(
                                                        children: [
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: List.generate(
                                                              rating,
                                                              (i) => Icon(
                                                                Icons.favorite,
                                                                color: Colors
                                                                    .green
                                                                    .shade400,
                                                                size: 14,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ),
                                                leftTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    reservedSize: 28,
                                                    getTitlesWidget:
                                                        (value, meta) => Text(
                                                          value
                                                              .toInt()
                                                              .toString(),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                  ),
                                                ),
                                                topTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: false,
                                                  ),
                                                ),
                                                rightTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: false,
                                                  ),
                                                ),
                                              ),
                                              barGroups: List.generate(5, (i) {
                                                final rating = i + 1;
                                                final countValue =
                                                    distribution[rating] ?? 0;

                                                return BarChartGroupData(
                                                  x: rating,
                                                  barRods: [
                                                    BarChartRodData(
                                                      toY: countValue
                                                          .toDouble(),
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Colors.green.shade700,
                                                          Colors.green.shade400,
                                                        ],
                                                        begin: Alignment
                                                            .bottomCenter,
                                                        end:
                                                            Alignment.topCenter,
                                                      ),
                                                      width: 26,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ],
                                                );
                                              }),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 16),

                                        // Legend
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "❤️ 1-2 = Needs Improvement",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              "💚 4-5 = Excellent",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                      const SizedBox(height: 20),

                      /// 🟩 Feedback List
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Feedback List',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Divider(),

                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: _getFeedbackStream(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  if (!snapshot.hasData ||
                                      snapshot.data!.docs.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        "No feedback found.",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    );
                                  }

                                  final feedbackDocs = snapshot.data!.docs;

                                  return FutureBuilder<
                                    List<Map<String, dynamic>>
                                  >(
                                    future: Future.wait(
                                      feedbackDocs.map((doc) async {
                                        final data = doc.data();
                                        final studId = data['studId'] ?? '';
                                        final counId = data['counId'] ?? '';
                                        final studentName =
                                            await getStudentName(studId);
                                        final counselorName =
                                            await getCounselorName(counId);
                                        return {
                                          ...data,
                                          'studentName': studentName,
                                          'counselorName': counselorName,
                                        };
                                      }),
                                    ),
                                    builder: (context, asyncSnap) {
                                      if (!asyncSnap.hasData) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }

                                      final feedbackList = asyncSnap.data!;

                                      final filteredFeedbacks = feedbackList
                                          .where((f) {
                                            final query = searchQuery
                                                .toLowerCase();
                                            return f['studentName']
                                                    .toLowerCase()
                                                    .contains(query) ||
                                                f['counselorName']
                                                    .toLowerCase()
                                                    .contains(query);
                                          })
                                          .toList();

                                      if (filteredFeedbacks.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Text(
                                            "No matching feedback found.",
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        );
                                      }

                                      return ListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: filteredFeedbacks.length,
  itemBuilder: (context, index) {
    final data = filteredFeedbacks[index];
    final rating = int.tryParse(data['rate'].toString()) ?? 0;
    final date = (data['submittedAt'] as Timestamp?)?.toDate();
    final formattedDate =
        date != null ? DateFormat.yMMMd().add_jm().format(date) : 'No date';

    return InkWell(
      onTap: () async {
  try {
    final appointmentId = data['appointmentId'];
    DocumentSnapshot? appointmentDoc;

    if (appointmentId != null) {
      appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
    }

    Map<String, dynamic>? appointmentData =
        appointmentDoc?.data() as Map<String, dynamic>?;

    if (appointmentData == null) {
      appointmentData = {};
    }

    // ✅ Convert UTC date field to local
    String formattedAppointmentDate = 'N/A';
    if (appointmentData['date'] != null) {
      DateTime utcDate = (appointmentData['date'] as Timestamp).toDate().toUtc();
      DateTime localDate = utcDate.toLocal();
      formattedAppointmentDate =
          DateFormat.yMMMd().add_jm().format(localDate);
    }

    // ✅ Convert feedback submittedAt timestamp to local
    final feedbackDate = (data['submittedAt'] as Timestamp?)?.toDate().toLocal();
    final formattedFeedbackDate = feedbackDate != null
        ? DateFormat.yMMMd().add_jm().format(feedbackDate)
        : 'No date';

    // Format full name
    final String firstName = (appointmentData['firstName'] ?? '').toString();
    final String middleName = (appointmentData['middleName'] ?? '').toString();
    final String lastName = (appointmentData['lastName'] ?? '').toString();
    final String extensionName =
        (appointmentData['extensionName'] ?? '').toString();

    String middleInitial =
        middleName.isNotEmpty ? '${middleName[0].toUpperCase()}.' : '';
    String fullName =
        '$firstName $middleInitial $lastName ${extensionName.isNotEmpty ? extensionName : ''}'
            .trim();

    // Capitalize each word
    fullName = fullName
        .split(' ')
        .map((word) =>
            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Feedback Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Date', formattedAppointmentDate),
              _buildDetailRow('Time', appointmentData?['time']),
              _buildDetailRow('Full Name', fullName),
              _buildDetailRow('Student Number', appointmentData?['studId']),
              _buildDetailRow('College', appointmentData?['college']),
              _buildDetailRow('Status', appointmentData?['status']),
              _buildDetailRow(
                  'Counselor', appointmentData?['assignedCounselor']),
              const SizedBox(height: 8),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.favorite,
                    size: 20,
                    color: i < rating
                        ? Colors.green.shade700
                        : Colors.grey.shade300,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Feedback', data['feedback']),
              _buildDetailRow('Submitted At', formattedFeedbackDate),
            ],
          ),
        ),
      ),
    );
  } catch (e) {
    print('Error fetching appointment details: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to load appointment details.'),
      ),
    );
  }
},
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.favorite,
                    size: 20,
                    color:
                        i < rating ? Colors.green.shade700 : Colors.grey.shade300,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Submitted by: ${data['studentName']}"),
                    Text(
                      "Counselor: ${data['counselorName']}",
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Text(
                formattedDate,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
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
                                },
                              ),
                            ],
                          ),
                        ),
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

  /// Helper widget for clean display
Widget _buildDetailRow(String label, dynamic value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 14),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: value?.toString().isNotEmpty == true
                ? value.toString()
                : 'N/A',
          ),
        ],
      ),
    ),
  );
}
}
