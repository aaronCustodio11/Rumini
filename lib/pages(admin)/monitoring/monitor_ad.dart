import 'package:rumini/components/sidebar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'monitorst.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class MonitorAd extends StatefulWidget {
  final Map<String, dynamic> userData;
  const MonitorAd({super.key, required this.userData});

  @override
  State<MonitorAd> createState() => _MonitorAdState();
}

class _MonitorAdState extends State<MonitorAd> {
  String searchQuery = "";
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedCollege;
  bool _showRow1 = false;
  bool _showRow2 = false;

    final ScrollController _scrollController = ScrollController();

      @override
  void dispose() {
    _scrollController.dispose(); // ✅ Don't forget to dispose
    super.dispose();
  }

  Future<List<String>> _getStudentIdsForCollege(String? college) async {
    Query query = FirebaseFirestore.instance
        .collection('Users')
        .where('role', isEqualTo: 'Student')
        .where('consent', isEqualTo: true);

    if (college != null && college.isNotEmpty) {
      query = query.where('college', isEqualTo: college);
    }

    final snap = await query.get();
    final ids = snap.docs
        .map((d) => (d.data() as Map<String, dynamic>)['studId'] ?? '')
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList();

    return ids;
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }

  /// 🔹 Function to format names
  String formatFullName(String firstName, String middleName, String lastName) {
    String capFirst(String name) => name.isNotEmpty
        ? "${name[0].toUpperCase()}${name.substring(1).toLowerCase()}"
        : "";

    String first = capFirst(firstName);
    String last = capFirst(lastName);
    String middle = middleName.isNotEmpty
        ? "${middleName[0].toUpperCase()}."
        : "";

    return [first, middle, last].where((e) => e.isNotEmpty).join(" ");
  }

  Future<Map<String, int>> _fetchMoodCounts({
    DateTime? startDate,
    DateTime? endDate,
    String? college,
  }) async {
    // 1) get studIds that match college + consent
    final studIds = await _getStudentIdsForCollege(college);
    if (studIds.isEmpty) {
      return {"Neutral": 0, "Positive": 0, "Negative": 0};
    }

    final Map<String, int> counts = {
      "Neutral": 0,
      "Positive": 0,
      "Negative": 0,
    };

    // convert to Firestore Timestamps for range queries
    Timestamp? tsStart = startDate != null
        ? Timestamp.fromDate(startDate)
        : null;
    Timestamp? tsEnd = endDate != null ? Timestamp.fromDate(endDate) : null;

    // 2) chunk studIds into batches of at most 10 (Firestore whereIn limit)
    final batches = _chunkList<String>(studIds, 10);

    for (final batch in batches) {
      Query q = FirebaseFirestore.instance
          .collection('moodLogs')
          .where('studId', whereIn: batch);

      if (tsStart != null && tsEnd != null) {
        q = q
            .where('timestamp', isGreaterThanOrEqualTo: tsStart)
            .where('timestamp', isLessThanOrEqualTo: tsEnd);
      }

      final snap = await q.get();
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final mood = (data['mood'] ?? '').toString();
        if (counts.containsKey(mood)) {
          counts[mood] = counts[mood]! + 1;
        }
      }
    }

    return counts;
  }

  Future<Map<String, int>> _fetchEmotionCounts({
    DateTime? startDate,
    DateTime? endDate,
    String? college,
  }) async {
    final studIds = await _getStudentIdsForCollege(college);
    if (studIds.isEmpty) return {};

    final Map<String, int> counts = {};

    Timestamp? tsStart = startDate != null
        ? Timestamp.fromDate(startDate)
        : null;
    Timestamp? tsEnd = endDate != null ? Timestamp.fromDate(endDate) : null;

    final batches = _chunkList<String>(studIds, 10);

    for (final batch in batches) {
      Query q = FirebaseFirestore.instance
          .collection('emotionLogs')
          .where('studId', whereIn: batch);

      if (tsStart != null && tsEnd != null) {
        q = q
            .where('timestamp', isGreaterThanOrEqualTo: tsStart)
            .where('timestamp', isLessThanOrEqualTo: tsEnd);
      }

      final snap = await q.get();
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final emotion = (data['emotion'] ?? 'Unknown').toString();
        counts[emotion] = (counts[emotion] ?? 0) + 1;
      }
    }

    return counts;
  }

Stream<QuerySnapshot> _getStudentsStream() {
  final userRole = widget.userData["role"]; // ✅ role of logged-in user
  final userId = widget.userData["counId"]; // ✅ counselor id of logged-in user (if any)

  Query q = FirebaseFirestore.instance
      .collection('Users')
      .where('role', isEqualTo: 'Student')
      .where('consent', isEqualTo: true);

  // ✅ If logged-in user is a Counselor, filter by assignedCounselor
  if (userRole == "Counselor" && userId != null) {
    q = q.where('assignedCounselor', isEqualTo: userId);
  }

  // ✅ If Admin, no extra filter → see all students with consent true
  return q.snapshots();
}


  Stream<Map<String, int>> _getConsentCounts() {
    Query q = FirebaseFirestore.instance
        .collection('Users')
        .where('role', isEqualTo: 'Student');

    if (_selectedCollege != null && _selectedCollege!.isNotEmpty) {
      q = q.where('college', isEqualTo: _selectedCollege);
    }

    return q.snapshots().map((snapshot) {
      int withConsent = 0;
      int withoutConsent = 0;

      for (var doc in snapshot.docs) {
        final consent = doc['consent'] ?? false;
        if (consent == true) {
          withConsent++;
        } else {
          withoutConsent++;
        }
      }

      return {"withConsent": withConsent, "withoutConsent": withoutConsent};
    });
  }

  // Helper: produce list of DateTime days inclusive
  List<DateTime> _generateDateRangeDays(DateTime start, DateTime end) {
    final days = <DateTime>[];
    DateTime cur = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cur.isAfter(last)) {
      days.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return days;
  }

  // Fetch counts per day for a single collection (returns Map<DateTime, int>)
  Future<Map<DateTime, int>> _fetchLogsPerDayRaw({
    required String collectionName, // "moodLogs" or "emotionLogs"
    required DateTime startDate,
    required DateTime endDate,
    String? college,
  }) async {
    final Map<DateTime, int> counts = {};

    // initialize all days so days with zero exist
    final days = _generateDateRangeDays(startDate, endDate);
    for (final d in days) {
      counts[d] = 0;
    }

    // If college filter is present, get studIds and use whereIn batching
    List<String> studIds = [];
    if (college != null && college.isNotEmpty) {
      studIds = await _getStudentIdsForCollege(college);
      if (studIds.isEmpty) {
        // no students in that college -> return zeros
        return counts;
      }
    }

    // Convert to Firestore timestamps
    final tsStart = Timestamp.fromDate(
      DateTime(startDate.year, startDate.month, startDate.day),
    );
    final tsEnd = Timestamp.fromDate(
      DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59),
    );

    if (studIds.isNotEmpty) {
      // multiple batched queries
      final batches = _chunkList<String>(studIds, 10);
      for (final batch in batches) {
        Query q = FirebaseFirestore.instance
            .collection(collectionName)
            .where('studId', whereIn: batch)
            .where('timestamp', isGreaterThanOrEqualTo: tsStart)
            .where('timestamp', isLessThanOrEqualTo: tsEnd);

        final snap = await q.get();
        for (final doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final rawTs = data['timestamp'];
          if (rawTs is Timestamp) {
            final dt = rawTs.toDate();
            final day = DateTime(dt.year, dt.month, dt.day);
            counts[day] = (counts[day] ?? 0) + 1;
          }
        }
      }
    } else {
      // No college filter -> single query by timestamp only
      Query q = FirebaseFirestore.instance
          .collection(collectionName)
          .where('timestamp', isGreaterThanOrEqualTo: tsStart)
          .where('timestamp', isLessThanOrEqualTo: tsEnd);

      final snap = await q.get();
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final rawTs = data['timestamp'];
        if (rawTs is Timestamp) {
          final dt = rawTs.toDate();
          final day = DateTime(dt.year, dt.month, dt.day);
          counts[day] = (counts[day] ?? 0) + 1;
        }
      }
    }

    return counts;
  }

  // Combined fetcher: returns both mood & emotion maps keyed by DateTime
  Future<Map<String, Map<DateTime, int>>> _fetchLogsSeries({
    DateTime? startDate,
    DateTime? endDate,
    String? college,
  }) async {
    // default to last 30 days if not provided
    if (startDate == null || endDate == null) {
      final now = DateTime.now();
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      startDate = endDate.subtract(
        const Duration(days: 29),
      ); // last 30 days inclusive
    } else {
      // ensure endDate includes full day
      endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
    }

    final moodMap = await _fetchLogsPerDayRaw(
      collectionName: 'moodLogs',
      startDate: startDate,
      endDate: endDate,
      college: college,
    );

    final emotionMap = await _fetchLogsPerDayRaw(
      collectionName: 'emotionLogs',
      startDate: startDate,
      endDate: endDate,
      college: college,
    );

    return {'mood': moodMap, 'emotion': emotionMap};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          /// 🔹 Sidebar
          Sidebar(userData: widget.userData),

          /// 🔹 Main content
          Expanded(
            child: Scaffold(
              backgroundColor: const Color.fromARGB(255, 232, 232, 232),
              appBar: AppBar(
                backgroundColor:const Color.fromARGB(
          255, 232, 232, 232),
                elevation: 0,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monitor_heart,
                     color: Colors.green.shade900,
                      size: 28,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Monitoring",
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                centerTitle: false,
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
            /// 🔍 Search Bar
            Expanded(
              flex: 3,
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search student by name...",
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF4CAF50),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: Color(0xFF4CAF50),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: Color(0xFF4CAF50),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
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

            /// 📅 Date Range Filter
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.date_range, size: 18),
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
                      const Duration(hours: 23, minutes: 59, seconds: 59),
                    );
                  });
                }
              },
            ),

            const SizedBox(width: 8),

            /// ❌ Clear Date Button (visible only when range selected)
            if (_startDate != null && _endDate != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: Color(0xFFEF5350), width: 1.5), // red outline
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  foregroundColor: const Color(0xFFEF5350),
                ),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text("Clear"),
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                },
              ),

            const SizedBox(width: 8),

            /// 🏫 College Filter
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: Color(0xFF4CAF50),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                foregroundColor: const Color(0xFF4CAF50),
              ),
              icon: const Icon(Icons.school, size: 18),
              label: const Text("College"),
              onPressed: () async {
                String? selectedCollege = _selectedCollege ?? "All";
                await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Select college"),
                    content: StatefulBuilder(
                      builder: (context, setStateDialog) {
                        return DropdownButton<String>(
                          value: selectedCollege,
                          isExpanded: true,
                          items: [
                            "All",
                            "CEIT",
                            "COED",
                            "CABA",
                            "CPAG",
                            "CAS",
                          ]
                              .map(
                                (college) => DropdownMenuItem(
                                  value: college,
                                  child: Text(college),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setStateDialog(() {
                              selectedCollege = value;
                            });
                          },
                        );
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Save"),
                      ),
                    ],
                  ),
                );
                if (selectedCollege != null) {
                  setState(() {
                    _selectedCollege =
                        selectedCollege == "All" ? null : selectedCollege;
                  });
                }
              },
            ),

            const SizedBox(width: 8),

            /// 📊 Analytics Toggle
            FilterChip(
              selected: _showRow1 && _showRow2,
              avatar: Icon(
                _showRow1 && _showRow2
                    ? Icons.visibility
                    : Icons.visibility_off,
                color:
                    _showRow1 && _showRow2 ? Colors.white : Colors.grey,
                size: 20,
              ),
              label: Text(
                "Analytics",
                style: TextStyle(
                  color: _showRow1 && _showRow2
                      ? Colors.white
                      : Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              selectedColor: const Color(0xFFFFC107),
              backgroundColor: Colors.yellow.shade50,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              onSelected: (bool selected) {
                setState(() {
                  _showRow1 = selected;
                  _showRow2 = selected;
                });
              },
            ),
          ],
        ),

        /// 🗓️ Selected Date Range Display
        if (_startDate != null && _endDate != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              "Selected range: "
              "${DateFormat('MMM d, yyyy').format(_startDate!)} - "
              "${DateFormat('MMM d, yyyy').format(_endDate!)}",
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    ),
  ),
),

                      const SizedBox(height: 16),

                      Column(
                        children: [
                          /// 🔹 Row 1
                          if (_showRow1)
                            Row(
                              children: [
                                // Total Students with Consent
                                Expanded(
                                  flex: 1,
                                  child: Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 4,
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: StreamBuilder<Map<String, int>>(
                                        stream: _getConsentCounts(),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }

                                          final counts = snapshot.data!;
                                          final withConsent =
                                              counts["withConsent"] ?? 0;
                                          final withoutConsent =
                                              counts["withoutConsent"] ?? 0;
                                          final total =
                                              withConsent + withoutConsent;

                                          // for the circle's visual fill
                                          final percent = total > 0
                                              ? withConsent / total
                                              : 0.0;

                                          return Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                "Consent Overview",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 20),

                                              // Circle indicator
                                              CircularPercentIndicator(
                                                radius: 80,
                                                lineWidth: 12,
                                                percent: percent,
                                                animation: true,
                                                circularStrokeCap:
                                                    CircularStrokeCap.round,
                                                progressColor:
                                                    const Color(0xFF4CAF50),
                                                backgroundColor:
                                                    Colors.grey.shade300,
                                                center: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      "$withConsent / $total",
                                                      style: const TextStyle(
                                                        fontSize: 22,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xFF4CAF50),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    const Text(
                                                      "Students",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              const SizedBox(height: 15),
                                              Text(
                                                "Without Consent: $withoutConsent",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Logs Over Time (Line Graph)
                                Expanded(
                                  flex: 2,
                                  child: Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 4,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: FutureBuilder<
                                          Map<String, Map<DateTime, int>>>(
                                        future: _fetchLogsSeries(
                                          startDate: _startDate,
                                          endDate: _endDate,
                                          college: _selectedCollege,
                                        ),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const SizedBox(
                                              height: 200,
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            );
                                          }
                                          if (snapshot.hasError) {
                                            return SizedBox(
                                              height: 200,
                                              child: Center(
                                                child: Text(
                                                  "Error: ${snapshot.error}",
                                                ),
                                              ),
                                            );
                                          }

                                          final map = snapshot.data;
                                          if (map == null) {
                                            return const SizedBox(
                                              height: 200,
                                              child: Center(
                                                child: Text("No logs found"),
                                              ),
                                            );
                                          }

                                          final effectiveEnd =
                                              _endDate ?? DateTime.now();
                                          final effectiveStart = _startDate ??
                                              effectiveEnd.subtract(
                                                const Duration(days: 29),
                                              );

                                          final moodMap = map['mood'] ?? {};
                                          final emotionMap =
                                              map['emotion'] ?? {};

                                          return _buildLogsLineChart(
                                            moodMap,
                                            emotionMap,
                                            effectiveStart,
                                            effectiveEnd,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 16),

                          /// 🔹 Row 2
                          if (_showRow2)
                            Row(
                              children: [
                                // Mood Distribution
                                Expanded(
                                  child: Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 4,
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: FutureBuilder<Map<String, int>>(
                                        future: _fetchMoodCounts(
                                          startDate: _startDate,
                                          endDate: _endDate,
                                          college: _selectedCollege,
                                        ),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                          if (!snapshot.hasData) {
                                            return const Center(
                                              child: Text("No data"),
                                            );
                                          }

                                          final moodCounts = snapshot.data!;
                                          int touchedIndex = -1;

                                          return Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                "Total Mood Distribution",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                height: 200,
                                                child: StatefulBuilder(
                                                  builder: (context,
                                                      setStateSB) {
                                                    return _buildPieChart(
                                                      moodCounts,
                                                      touchedIndex,
                                                      (index) => setStateSB(
                                                        () => touchedIndex =
                                                            index,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 16),

                                // Emotion Distribution
                                Expanded(
                                  child: Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 4,
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: FutureBuilder<Map<String, int>>(
                                        future: _fetchEmotionCounts(
                                          startDate: _startDate,
                                          endDate: _endDate,
                                          college: _selectedCollege,
                                        ),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                          if (!snapshot.hasData ||
                                              snapshot.data!.isEmpty) {
                                            return const Center(
                                              child: Text("No emotion data"),
                                            );
                                          }

                                          final emotionCounts = snapshot.data!;
                                          int touchedIndex = -1;

                                          return Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                "Total Emotion Distribution",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                height: 200,
                                                child: StatefulBuilder(
                                                  builder: (context,
                                                      setStateSB) {
                                                    return _buildEmotionPieChart(
                                                      emotionCounts,
                                                      touchedIndex,
                                                      (index) => setStateSB(
                                                        () => touchedIndex =
                                                            index,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),


                      const SizedBox(height: 16),
                      /// 📹 Students List
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Section
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade900,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.people_alt,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Students with Consent",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  StreamBuilder<QuerySnapshot>(
                                    stream: _getStudentsStream(),
                                    builder: (context, snapshot) {
                                      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          "$count Student${count != 1 ? 's' : ''}",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // List Content
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                height: 520,
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: _getStudentsStream(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF1B5E20),
                                        ),
                                      );
                                    }

                                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.people_outline,
                                              size: 64,
                                              color: Colors.grey.shade300,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              "No students with consent enabled.",
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    final students = snapshot.data!.docs.where((doc) {
                                      final firstName =
                                          (doc["firstName"] ?? "").toString().toLowerCase();
                                      final lastName =
                                          (doc["lastName"] ?? "").toString().toLowerCase();
                                      final fullName = "$firstName $lastName";
                                      return fullName.contains(searchQuery);
                                    }).toList();

                                    if (students.isEmpty) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.search_off,
                                              size: 64,
                                              color: Colors.grey.shade300,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              "No students match your search.",
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    return Scrollbar(
                                      thumbVisibility: true,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        physics: const AlwaysScrollableScrollPhysics(),
                                        itemCount: students.length,
                                        itemBuilder: (context, index) {
  final student = students[index];
  
  // ✅ Safely extract data from DocumentSnapshot
  final studentData = student.data() as Map<String, dynamic>;
  
  final studId = studentData["studId"] ?? "No ID";
  final firstName = studentData["firstName"] ?? "";
  final middleName = studentData["middleName"] ?? "";
  final lastName = studentData["lastName"] ?? "";
  final fullName = formatFullName(
    firstName,
    middleName,
    lastName,
  );

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.grey.shade200,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Monitorst(
  userData: widget.userData,
  studentData: {
    "studId": studId,
    "firstName": firstName,
    "middleName": middleName,
    "lastName": lastName,
  },
)
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Left: Avatar with emotion-based color
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("emotionLogs")
                    .where("studId", isEqualTo: studId)
                    .orderBy("timestamp", descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, logSnapshot) {
                  Color avatarColor = Colors.green.shade900;
                  
                  if (logSnapshot.hasData &&
                      logSnapshot.data!.docs.isNotEmpty) {
                    final log = logSnapshot.data!.docs.first;
                    final colorHex = log["color"] ?? "";
                    if (colorHex.isNotEmpty) {
                      avatarColor = Color(
                        int.parse("0xff$colorHex"),
                      );
                    }
                  }

                  return Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          avatarColor,
                          avatarColor.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: avatarColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        firstName.isNotEmpty
                            ? firstName[0].toUpperCase()
                            : "?",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(width: 16),

              // Middle: Name and ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.badge,
                          size: 14,
                          color: Colors.green.shade900,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          studId,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right: Recent emotion log
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("emotionLogs")
                    .where("studId", isEqualTo: studId)
                    .orderBy("timestamp", descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, logSnapshot) {
                  if (logSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return SizedBox(
                      width: 90,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.green.shade900,
                        ),
                      ),
                    );
                  }

                  if (!logSnapshot.hasData ||
                      logSnapshot.data!.docs.isEmpty) {
                    return Container(
                      width: 90,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.mood_bad,
                            size: 32,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "No log",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final log = logSnapshot.data!.docs.first;
                  final emotionImage = log["image"] ??
                      "assets/images/default.png";
                  final outlineColor = Color(
                    int.parse("0xff${log["color"]}"),
                  );
                  final timestamp =
                      (log["timestamp"] as Timestamp).toDate();
                  final formattedDate =
                      DateFormat("MMM d").format(timestamp);
                  final emotion = log["emotion"] ?? "";

                  return Container(
                    width: 90,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: outlineColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: outlineColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: outlineColor,
                              width: 2.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.asset(
                              emotionImage,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          emotion,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: outlineColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
},
                                      ),
                                    );
                                  },
                                ),
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
          ),
        ],
      ),
    );
  }

  int touchedIndex = -1; // put this in your State class

  /// 🔹 Pie Chart Builder
  Widget _buildPieChart(
    Map<String, int> moodCounts,
    int touchedIndex,
    void Function(int) onTouch,
  ) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 50,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.touchedSection == null) {
              onTouch(-1);
              return;
            }
            onTouch(response.touchedSection!.touchedSectionIndex);
          },
        ),
        sections: [
          _buildPieSection(
            "Neutral",
            moodCounts["Neutral"] ?? 0,
            Colors.blue,
            touchedIndex == 0,
          ),
          _buildPieSection(
            "Positive",
            moodCounts["Positive"] ?? 0,
            Colors.green,
            touchedIndex == 1,
          ),
          _buildPieSection(
            "Negative",
            moodCounts["Negative"] ?? 0,
            Colors.red,
            touchedIndex == 2,
          ),
        ],
      ),
    );
  }

  /// 🔹 Pie Chart Section Builder
  PieChartSectionData _buildPieSection(
    String title,
    int value,
    Color color,
    bool isTouched,
  ) {
    final double radius = isTouched ? 70 : 60; // expand slice on hover
    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      title: "$title\n$value",
      radius: radius,
      titleStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildEmotionPieChart(
    Map<String, int> emotionCounts,
    int touchedIndex,
    void Function(int) onTouch,
  ) {
    final emotions = emotionCounts.keys.toList();

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 50,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.touchedSection == null) {
              onTouch(-1);
              return;
            }
            onTouch(response.touchedSection!.touchedSectionIndex);
          },
        ),
        sections: List.generate(emotions.length, (index) {
          final emotion = emotions[index];
          final value = emotionCounts[emotion]!;
          final color = _getEmotionColor(emotion); // 🔹 assign colors

          return _buildPieSection(emotion, value, color, touchedIndex == index);
        }),
      ),
    );
  }

  /// Assign consistent colors per emotion
  Color _getEmotionColor(String emotion) {
    switch (emotion) {
      case "Joy":
        return const Color(0xFFE3AB2F);
      case "Sad":
        return const Color(0xFF2F5FA7);
      case "Surprise":
        return const Color(0xFF3DA3A3);
      case "Fear":
        return const Color(0xFF563A88);
      case "Disgusted":
        return const Color(0xFF4C913B);
      case "Contempt":
        return const Color(0xFFB16645);
      case "Angry":
        return const Color(0xFFA2352D);
      default:
        return Colors.grey; // fallback for unexpected values
    }
  }

  Widget _buildLogsLineChart(
    Map<DateTime, int> moodMap,
    Map<DateTime, int> emotionMap,
    DateTime startDate,
    DateTime endDate,
  ) {
    // sorted list of days
    final days = _generateDateRangeDays(startDate, endDate);
    // build spots (use ms since epoch as x)
    final moodSpots = <FlSpot>[];
    final emotionSpots = <FlSpot>[];

    for (final d in days) {
      final x = d.millisecondsSinceEpoch.toDouble();
      final yMood = moodMap[d] ?? 0;
      final yEmotion = emotionMap[d] ?? 0;
      moodSpots.add(FlSpot(x, yMood.toDouble()));
      emotionSpots.add(FlSpot(x, yEmotion.toDouble()));
    }

    // helper to format bottom labels (MM/dd)
    String _formatDateLabel(double ms) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
      return "${dt.month}/${dt.day}";
    }

    // choose how many bottom ticks to show to avoid clutter
    final int showEvery = days.length <= 7 ? 1 : (days.length ~/ 6) + 1;

    return Column(
      children: [
        const Text(
          "Logs Over Time",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: null,
                    getTitlesWidget: (value, meta) {
                      // only show labels on some ticks
                      final dt = DateTime.fromMillisecondsSinceEpoch(
                        value.toInt(),
                      );
                      final index = days.indexWhere(
                        (d) =>
                            d.year == dt.year &&
                            d.month == dt.month &&
                            d.day == dt.day,
                      );
                      if (index == -1) return const SizedBox.shrink();
                      if (index % showEvery != 0)
                        return const SizedBox.shrink();
                      return SideTitleWidget(
                        space: 6,
                        meta: meta,
                        child: Text(
                          _formatDateLabel(value),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: moodSpots,
                  isCurved: true,
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                  color: Colors.blue,
                ),
                LineChartBarData(
                  spots: emotionSpots,
                  isCurved: true,
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                  color: Colors.orange,
                ),
              ],
              minY: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(width: 12, height: 8, color: Colors.blue),
                const SizedBox(width: 6),
                const Text("Mood Logs"),
              ],
            ),
            const SizedBox(width: 18),
            Row(
              children: [
                Container(width: 12, height: 8, color: Colors.orange),
                const SizedBox(width: 6),
                const Text("Emotion Logs"),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
