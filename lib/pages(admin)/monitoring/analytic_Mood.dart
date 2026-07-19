import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class MoodAnalyticsScreen extends StatefulWidget {
  final String userId;
  final DateTime? startDate;
  final DateTime? endDate;

  const MoodAnalyticsScreen({
    super.key,
    required this.userId,
    this.startDate,
    this.endDate,
  });

  @override
  State<MoodAnalyticsScreen> createState() => _MoodAnalyticsScreenState();
}

class _MoodAnalyticsScreenState extends State<MoodAnalyticsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _moodLogs = [];
  int? touchedIndex;

  @override
  void initState() {
    super.initState();
    loadAnalytics();
  }

  @override
  void didUpdateWidget(covariant MoodAnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate ||
        widget.userId != oldWidget.userId) {
      loadAnalytics();
    }
  }

  Future<void> loadAnalytics() async {
    setState(() => _loading = true);

    final query = FirebaseFirestore.instance
        .collection("moodLogs")
        .where("studId", isEqualTo: widget.userId)
        .orderBy("timestamp", descending: false);

    final snapshot = await query.get();

    List<Map<String, dynamic>> logs = snapshot.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .toList();

    if (widget.startDate != null && widget.endDate != null) {
      logs = logs.where((log) {
        final logDate = (log["timestamp"] as Timestamp).toDate();
        return logDate.isAfter(
              widget.startDate!.subtract(const Duration(days: 1)),
            ) &&
            logDate.isBefore(widget.endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    setState(() {
      _moodLogs = logs;
      _loading = false;
    });
  }

  /// ---- ANALYTICS ----
  Map<String, int> _getMoodCounts() {
    Map<String, int> counts = {"Neutral": 0, "Positive": 0, "Negative": 0};
    for (var log in _moodLogs) {
      counts[log["mood"]] = (counts[log["mood"]] ?? 0) + 1;
    }
    return counts;
  }

  String _getMostCommonMood() {
    if (_moodLogs.isEmpty) return "None";

    final counts = _getMoodCounts();

    // find the max frequency
    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);

    // collect all moods with that frequency
    final mostCommon = counts.entries
        .where((entry) => entry.value == maxCount && entry.value > 0)
        .map((entry) => entry.key)
        .toList();

    if (mostCommon.isEmpty) {
      return "None"; // no moods logged
    } else if (mostCommon.length == 1) {
      return mostCommon.first; // clear winner
    } else {
      return "No dominant mood";
      // OR return mostCommon.join(", ") if you want to display the tied ones
    }
  }

  int _getLongestStreak() {
    if (_moodLogs.isEmpty) return 0;
    final logs = [..._moodLogs]
      ..sort(
        (a, b) => (a["timestamp"] as Timestamp).compareTo(
          (b["timestamp"] as Timestamp),
        ),
      );

    int longest = 1, current = 1;
    for (int i = 1; i < logs.length; i++) {
      final prev = (logs[i - 1]["timestamp"] as Timestamp).toDate();
      final curr = (logs[i]["timestamp"] as Timestamp).toDate();
      if (curr.difference(prev).inDays == 1) {
        current++;
        longest = current > longest ? current : longest;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  double _getConsistency() {
    if (_moodLogs.isEmpty || widget.startDate == null || widget.endDate == null)
      return 0;
    final uniqueDays = _moodLogs
        .map(
          (log) => (log["timestamp"] as Timestamp)
              .toDate()
              .toString()
              .substring(0, 10),
        )
        .toSet()
        .length;
    final totalDays = widget.endDate!.difference(widget.startDate!).inDays + 1;
    return (uniqueDays / totalDays) * 100;
  }

  List<String> _getTopWords([int topN = 3]) {
    final stopWords = {"the", "and", "is", "a", "to", "in", "of", "it"};
    Map<String, int> wordCount = {};
    for (var log in _moodLogs) {
      final entry = (log["journal"] ?? "").toString().toLowerCase();
      for (var word in entry.split(RegExp(r"[^a-zA-Z]+"))) {
        if (word.isEmpty || stopWords.contains(word)) continue;
        wordCount[word] = (wordCount[word] ?? 0) + 1;
      }
    }
    if (wordCount.isEmpty) return ["None"];

    final sorted = wordCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(topN).map((e) => "${e.key} (${e.value})").toList();
  }

  /// ---- UI ----
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: Colors.green.shade900),
      );
    }

    if (_moodLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              "No mood logs in this range",
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final moodCounts = _getMoodCounts();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 📹 Left Side - Pie Chart
          Expanded(
            flex: 1,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              shadowColor: Colors.green.shade900.withOpacity(0.2),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.green.shade900.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Header
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
                            Icons.pie_chart_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Mood Distribution",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Chart content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SizedBox(
                        width: 300,
                        height: 300,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 60,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      response == null ||
                                      response.touchedSection == null) {
                                    touchedIndex = -1;
                                    return;
                                  }
                                  touchedIndex = response
                                      .touchedSection!
                                      .touchedSectionIndex;
                                });
                              },
                            ),
                            sections: [
                              _buildPieSection(
                                0,
                                "Neutral",
                                moodCounts["Neutral"]!,
                                Colors.blue,
                              ),
                              _buildPieSection(
                                1,
                                "Positive",
                                moodCounts["Positive"]!,
                                Colors.green,
                              ),
                              _buildPieSection(
                                2,
                                "Negative",
                                moodCounts["Negative"]!,
                                Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          /// 📹 Right Side - Analytics Cards
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoCard(
                  "Most Common Mood",
                  _getMostCommonMood(),
                  Icons.mood,
                  Colors.orange,
                ),
                _buildInfoCard(
                  "Longest Streak",
                  "${_getLongestStreak()} days",
                  Icons.local_fire_department,
                  Colors.redAccent,
                ),
                _buildInfoCard(
                  "Logging Consistency",
                  widget.startDate == null || widget.endDate == null
                      ? "N/A"
                      : "${_getConsistency().toStringAsFixed(1)}%",
                  Icons.bar_chart,
                  Colors.blueAccent,
                ),
                _buildTopWordsCard(
                  "Most Common Words",
                  _getTopWords(),
                  Icons.edit_note,
                  Colors.teal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopWordsCard(
    String title,
    List<String> words,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      shadowColor: Colors.green.shade900.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.shade900.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...words.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.green.shade900,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        w,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pie chart section builder
  /// Pie chart section builder
  PieChartSectionData _buildPieSection(
    int index,
    String title,
    int value,
    Color color,
  ) {
    final isTouched = index == touchedIndex;
    final double radius = isTouched ? 70 : 60;

    // 👉 Calculate percentage
    final total = _moodLogs.length;
    final percentage = total > 0
        ? (value / total * 100).toStringAsFixed(1)
        : "0";

    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      radius: radius,

      // 👇 show percentage inside slice
      title: "$percentage%",
      titleStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),

      // 👇 keep mood + icon outside slice
      badgeWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            title == "Positive"
                ? Icons.sentiment_satisfied
                : title == "Neutral"
                ? Icons.sentiment_neutral
                : Icons.sentiment_dissatisfied,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            "$title ($value)",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      badgePositionPercentageOffset: 1.7, // outside circle
    );
  }

  /// Info card builder
  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      shadowColor: Colors.green.shade900.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.shade900.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.grey.shade800,
            ),
          ),
          trailing: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade900,
            ),
          ),
        ),
      ),
    );
  }
}
