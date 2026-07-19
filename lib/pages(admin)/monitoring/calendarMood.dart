import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomCalendarMood extends StatefulWidget {
  final String title;
  final String studId;

  const CustomCalendarMood({
    super.key,
    required this.title,
    required this.studId,
  });

  @override
  State<CustomCalendarMood> createState() => _CustomCalendarMoodState();
}

class _CustomCalendarMoodState extends State<CustomCalendarMood> {
  DateTime _focusedMonth = DateTime.now();

  DateTime get _firstDayOfMonth {
    DateTime first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    int shift = first.weekday % 7; // Sunday = 0
    return first.subtract(Duration(days: shift));
  }

  /// 🔹 Convert hex string to Flutter Color (simple)
  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex"; // add opacity if missing
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  /// 🔹 Robust color parser (named colors and hex variants)
  Color _parseColor(String? colorString) {
    if (colorString == null) return Colors.grey.shade200;
    String s = colorString.toString().trim();
    if (s.isEmpty) return Colors.grey.shade200;

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

    s = s.replaceAll('#', '');
    s = s.replaceAll('0x', '');
    s = s.replaceAll('0X', '');

    if (s.length == 6) s = 'FF$s';
    if (s.length == 8) {
      try {
        return Color(int.parse('0x$s'));
      } catch (e) {
        return Colors.grey.shade200;
      }
    }

    if (s.length > 8) {
      try {
        final last6 = s.substring(s.length - 6);
        return Color(int.parse('0xFF$last6'));
      } catch (e) {
        return Colors.grey.shade200;
      }
    }

    // fallback
    return Colors.grey.shade200;
  }

  /// 🔹 Show journal in a popup (single log per day)
  void _showJournalDialog(DateTime day, Map<String, dynamic>? log) {
    String formattedDate = DateFormat.yMMMMd().format(day);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text("Mood Log - $formattedDate"),
        content: log != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (log["mood"] != null) ...[
                    Text(
                      "Mood: ${log["mood"]}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (log["color"] != null)
                    Wrap(
                      spacing: 6,
                      children:
                          (log["color"] is List
                                  ? List<String>.from(log["color"])
                                  : [log["color"].toString()])
                              .map(
                                (c) => Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: _parseColor(c),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    log["journal"]?.toString().isNotEmpty == true
                        ? log["journal"]
                        : "No journal entry.",
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              )
            : const Text("No mood log for this day."),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// 🔹 Month-Year Picker
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
          .collection("moodLogs")
          .where("studId", isEqualTo: widget.studId)
          .where("timestamp", isGreaterThanOrEqualTo: firstDay)
          .where("timestamp", isLessThanOrEqualTo: lastDay)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 🔹 Map logs by "yyyy-MM-dd" — single log per day
        Map<String, Map<String, dynamic>> moodLogsByDay = {};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = (data["timestamp"] as Timestamp).toDate();
            final key = DateFormat("yyyy-MM-dd").format(ts);
            moodLogsByDay[key] = data; // single log per day
          }
        }

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
                  // Header: title + filter button
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
                                Icons.mood,
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

                  // Month navigation
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
              height: 30,
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = constraints.maxWidth / 7;
                  final cellHeight = constraints.maxHeight / 6;
                  final aspect = (cellWidth > 0 && cellHeight > 0)
                      ? (cellWidth / cellHeight)
                      : 1.0;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: aspect,
                    ),
                    itemCount: 42,
                    itemBuilder: (context, index) {
                      DateTime startDay = _firstDayOfMonth;
                      DateTime day = startDay.add(Duration(days: index));
                      bool isCurrentMonth = day.month == _focusedMonth.month;
                      bool isToday = DateUtils.isSameDay(day, DateTime.now());

                      String key = DateFormat("yyyy-MM-dd").format(day);
                      final log = moodLogsByDay[key];

                      BoxDecoration decoration;
                      if (log != null && log["color"] != null) {
                        List<Color> colors = [];
                        if (log["color"] is List) {
                          for (var c in List.from(log["color"])) {
                            colors.add(_parseColor(c?.toString()));
                          }
                        } else {
                          colors.add(_parseColor(log["color"].toString()));
                        }

                        final seen = <int>{};
                        final unique = <Color>[];
                        for (final c in colors) {
                          if (!seen.contains(c.value)) {
                            seen.add(c.value);
                            unique.add(c);
                          }
                        }
                        final use = unique.isEmpty ? [Colors.blue] : unique;

                        if (use.length == 1) {
                          decoration = BoxDecoration(
                            color: use.first,
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(
                                    color: Colors.green.shade900,
                                    width: 3,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: use.first.withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          );
                        } else {
                          final stops = List<double>.generate(
                            use.length,
                            (i) =>
                                use.length == 1 ? 0.0 : (i / (use.length - 1)),
                          );
                          decoration = BoxDecoration(
                            gradient: LinearGradient(
                              colors: use,
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
                                color: use.first.withOpacity(0.3),
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
                        onTap: () => _showJournalDialog(day, log),
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: decoration,
                          child: Center(
                            child: Text(
                              "${day.day}",
                              style: TextStyle(
                                fontSize: 14,
                                color: log != null
                                    ? Colors.white
                                    : (isCurrentMonth
                                          ? Colors.black87
                                          : Colors.grey.shade400),
                                fontWeight: isCurrentMonth || log != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                shadows: log != null
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
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
