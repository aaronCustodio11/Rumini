import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomCalendarEmotion extends StatefulWidget {
  final String title;
  final String studId;

  const CustomCalendarEmotion({
    super.key,
    required this.title,
    required this.studId,
  });

  @override
  State<CustomCalendarEmotion> createState() => _CustomCalendarEmotionState();
}

class _CustomCalendarEmotionState extends State<CustomCalendarEmotion> {
  DateTime _focusedMonth = DateTime.now();

  DateTime get _firstDayOfMonth {
    DateTime first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    int shift = first.weekday % 7; // Sunday = 0
    return first.subtract(Duration(days: shift));
  }

  /// Robust color parser:
  /// supports named colors ("red"), "#RRGGBB", "RRGGBB", "AARRGGBB", "ffe3ab2f"
  Color _parseColor(String? colorString) {
    if (colorString == null) return Colors.grey;
    String s = colorString.toString().trim();

    if (s.isEmpty) return Colors.grey;

    // common named colors (extend if you need)
    final Map<String, Color> named = {
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
      'yellow': Colors.yellow,
      'purple': Colors.purple,
      'orange': Colors.orange,
      'pink': Colors.pink,
      'grey': Colors.grey,
      'gray': Colors.grey,
      'black': Colors.black,
      'white': Colors.white,
      'brown': Colors.brown,
    };

    if (named.containsKey(s.toLowerCase())) return named[s.toLowerCase()]!;

    // remove common prefixes
    s = s.replaceAll('#', '');
    s = s.replaceAll('0x', '');
    s = s.replaceAll('0X', '');

    // now s should be hex like "RRGGBB" or "AARRGGBB"
    // If 6 chars -> assume RRGGBB, prepend FF for opacity
    if (s.length == 6) {
      s = 'FF$s';
    }

    // If 8 chars -> AARRGGBB (ok)
    if (s.length == 8) {
      try {
        return Color(int.parse('0x$s'));
      } catch (e) {
        return Colors.grey;
      }
    }

    // Fallback: try to use last 6 chars as RRGGBB
    if (s.length > 8) {
      try {
        final last6 = s.substring(s.length - 6);
        return Color(int.parse('0xFF$last6'));
      } catch (e) {
        return Colors.grey;
      }
    }

    return Colors.grey;
  }

  /// Show all emotions in a popup. Now includes `emotion` label and journal.
  void _showEmotionDialog(DateTime day, List<Map<String, dynamic>> logs) {
    String formattedDate = DateFormat.yMMMMd().format(day);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text("Emotions - $formattedDate"),
        content: logs.isNotEmpty
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: logs.map((log) {
                    final color = _parseColor(log["color"]?.toString() ?? "");
                    final emotionLabel =
                        log["emotion"]?.toString() ?? "Unknown";
                    final journalText = log["journal"]?.toString();
                    final imagePath = log["image"]?.toString();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // color circle
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),

                          // emotion + journal (stacked)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  emotionLabel,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (journalText?.isNotEmpty == true)
                                      ? journalText!
                                      : "No journal entry.",
                                  style: const TextStyle(fontSize: 14),
                                ),
                                if (imagePath != null && imagePath.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      "Image: $imagePath",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              )
            : const Text("No emotion logs for this day."),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Month-year picker (same as before)
  Future<void> _pickMonthYear() async {
    int selectedYear = _focusedMonth.year;
    int selectedMonth = _focusedMonth.month;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Select Month & Year"),
              content: Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      value: selectedMonth,
                      isExpanded: true,
                      items: List.generate(12, (i) {
                        return DropdownMenuItem(
                          value: i + 1,
                          child: Text(
                            DateFormat.MMMM().format(DateTime(0, i + 1)),
                          ),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedMonth = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<int>(
                      value: selectedYear,
                      isExpanded: true,
                      items: List.generate(50, (i) {
                        int year = DateTime.now().year - 25 + i;
                        return DropdownMenuItem(
                          value: year,
                          child: Text("$year"),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedYear = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: const Text("Apply"),
                  onPressed: () {
                    setState(() {
                      _focusedMonth = DateTime(selectedYear, selectedMonth);
                    });
                    Navigator.pop(context);
                  },
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
    String monthName = DateFormat.yMMMM().format(_focusedMonth);

    DateTime firstDay = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
      0,
      0,
      0,
    );
    DateTime lastDay = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
      23,
      59,
      59,
    );

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("emotionLogs")
          .where("studId", isEqualTo: widget.studId)
          .where("timestamp", isGreaterThanOrEqualTo: firstDay)
          .where("timestamp", isLessThanOrEqualTo: lastDay)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Group logs by day
        Map<String, List<Map<String, dynamic>>> emotionLogsByDay = {};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = (data["timestamp"] as Timestamp).toDate();
            final key = DateFormat("yyyy-MM-dd").format(ts);

            emotionLogsByDay.putIfAbsent(key, () => []);
            emotionLogsByDay[key]!.add(data);
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            double headerHeight = 60;
            double weekdayHeight = 30;
            double availableHeight =
                constraints.maxHeight - headerHeight - weekdayHeight - 16;

            double cellHeight = availableHeight / 6;
            double cellWidth = constraints.maxWidth / 7;

            return Column(
              children: [
                // Enhanced Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.green.shade900.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 40,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.emoji_emotions,
                                    color: Colors.green.shade900,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: IconButton(
                                icon: Icon(
                                  Icons.filter_alt,
                                  color: Colors.green.shade900,
                                ),
                                tooltip: "Filter by month & year",
                                onPressed: _pickMonthYear,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_left,
                              color: Colors.green.shade900,
                            ),
                            onPressed: () {
                              setState(() {
                                _focusedMonth = DateTime(
                                  _focusedMonth.year,
                                  _focusedMonth.month - 1,
                                );
                              });
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            
                            child: Text(
                              monthName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.arrow_right,
                              color: Colors.green.shade900,
                            ),
                            onPressed: () {
                              setState(() {
                                _focusedMonth = DateTime(
                                  _focusedMonth.year,
                                  _focusedMonth.month + 1,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Weekday header
                SizedBox(
                  height: weekdayHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                        .map(
                          (day) => Text(
                            day,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),

                // Calendar grid
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: (cellWidth > 0 && cellHeight > 0)
                          ? cellWidth / cellHeight
                          : 1,
                    ),
                    itemCount: 42,
                    itemBuilder: (context, index) {
                      DateTime startDay = _firstDayOfMonth;
                      DateTime day = startDay.add(Duration(days: index));
                      bool isCurrentMonth = day.month == _focusedMonth.month;
                      bool isToday = DateUtils.isSameDay(day, DateTime.now());

                      String key = DateFormat("yyyy-MM-dd").format(day);
                      final logs = emotionLogsByDay[key] ?? [];

                      BoxDecoration decoration;
                      if (logs.isNotEmpty) {
                        final parsed = logs
                            .map(
                              (log) =>
                                  _parseColor(log["color"]?.toString() ?? ""),
                            )
                            .toList();
                        final seen = <int>{};
                        final unique = <Color>[];
                        for (final c in parsed) {
                          if (!seen.contains(c.value)) {
                            seen.add(c.value);
                            unique.add(c);
                          }
                        }
                        final colors = unique.take(4).toList();

                        if (colors.length == 1) {
                          decoration = BoxDecoration(
                            color: colors.first,
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(
                                    color: Colors.green.shade900,
                                    width: 3,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: colors.first.withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          );
                        } else {
                          final stops = List<double>.generate(
                            colors.length,
                            (i) => i / (colors.length - 1),
                          );
                          decoration = BoxDecoration(
                            gradient: LinearGradient(
                              colors: colors,
                              stops: stops,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(
                                    color: Colors.green.shade900,
                                    width: 3,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: colors.first.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          );
                        }
                      } else {
                        decoration = BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(
                            color: isCurrentMonth
                                ? Colors.grey.shade300
                                : Colors.grey.shade100,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        );
                      }

                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showEmotionDialog(day, logs),
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: decoration,
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  "${day.day}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: logs.isNotEmpty
                                        ? Colors.white
                                        : (isCurrentMonth
                                              ? Colors.black87
                                              : Colors.grey.shade400),
                                    fontWeight:
                                        isCurrentMonth || logs.isNotEmpty
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    shadows: logs.isNotEmpty
                                        ? [
                                            const Shadow(
                                              color: Colors.black26,
                                              offset: Offset(0, 1),
                                              blurRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                              
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
