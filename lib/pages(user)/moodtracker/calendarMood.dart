import 'package:rumini/pages(user)/moodtracker/calendarEmotion.dart';
import 'package:rumini/pages(user)/moodtracker/seemoreMood.dart';
import 'package:rumini/utils(mood)/pdf_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class Calendarmood extends StatefulWidget {
  final Map<String, dynamic> userData;
  const Calendarmood({super.key, required this.userData});

  @override
  _CalendarmoodState createState() => _CalendarmoodState();
}

class _CalendarmoodState extends State<Calendarmood> {
  List<DateTime> months = [];
  Map<String, List<Color>> loggedColors = {};

  // 🔹 Filter states
  DateTime? _filteredMonth;
  bool _isFiltered = false;
  String? _filteredMonthName;

  // Mood categories and their colors
  final List<String> moodLabels = ["Negative", "Neutral", "Positive"];
  final List<List<Color>> moodColors = [
    [Color.lerp(Colors.red[900], Colors.red, 0)!, Color.lerp(Colors.red, Colors.white, 0)!],
    [Colors.black38, Colors.grey[300]!],
    [Color.lerp(Colors.greenAccent[700]!, Colors.white, 0.5)!, Color.lerp(Colors.greenAccent[700]!, Colors.white, 0.9)!]
  ];

  final List<List<Color>> displayColors = [
    [Colors.black, Colors.red],
    [Colors.black, Colors.grey[50]!],
    [Colors.greenAccent[700]!, Colors.white]
  ];

  @override
  void initState() {
    super.initState();
    _fetchMoodLogs();
    _saveLastVisited("Calendarmood");
  }

  void _saveLastVisited(String page) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("lastCalendarPage", page);
  }

  Future<void> _fetchMoodLogs() async {
    String userStudId = widget.userData['studId'];
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('moodLogs')
        .where('studId', isEqualTo: userStudId)
        .get();

    Set<String> uniqueMonths = {};
    DateTime now = DateTime.now();
    String currentMonth = DateFormat('yyyy-MM').format(now);

    setState(() {
      loggedColors.clear();
      for (var doc in snapshot.docs) {
        Timestamp timestamp = doc['timestamp'];
        DateTime date = timestamp.toDate();
        String dateString = DateFormat('yyyy-MM-dd').format(date);
        String monthString = DateFormat('yyyy-MM').format(date);
        uniqueMonths.add(monthString);

        var colorData = doc['color'];
        List<Color> colors = [];
        if (colorData is List) {
          colors = colorData.map((hex) {
            return Color(int.parse(hex, radix: 16) + 0xFF000000);
          }).toList();
        } else if (colorData is String) {
          colors = [Color(int.parse(colorData, radix: 16) + 0xFF000000)];
        }

        loggedColors.putIfAbsent(dateString, () => []);
        loggedColors[dateString]!.addAll(colors);
      }

      uniqueMonths.add(currentMonth);
      months = uniqueMonths.map((month) {
        List<String> parts = month.split('-');
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      }).toList()
        ..sort((a, b) => b.compareTo(a));
    });
  }

  Color getTextColor(Color bgColor) {
    String hexValue = bgColor.value.toRadixString(16).padLeft(8, '0').toLowerCase();
    if (hexValue == "ffb2ff59" || hexValue == "ffffffff") {
      return Colors.black;
    } else {
      return Colors.white;
    }
  }

  void _showMoodLegendDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              const Text(
                "Mood Color Legend",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Color(0xFF1B5E20),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),

              // Sub info
              const Text(
                "Each mood is represented by a unique color.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 20),
              const Divider(thickness: 0.8, color: Colors.black26),
              const SizedBox(height: 20),

              // Legend list (use indices because moodColors is a List)
              Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: List.generate(moodLabels.length, (index) {
                  final label = moodLabels[index];
                  final colors = moodColors[index];

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Gradient swatch
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: colors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12, width: 0.8),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),

              const SizedBox(height: 28),

              // Close button
              SizedBox(
                width: 120,
                height: 40,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text("Close"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}



  Widget _buildCalendar(DateTime month) {
    int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    int firstWeekday = DateTime(month.year, month.month, 1).weekday % 7;
    DateTime now = DateTime.now();

    List<Widget> dayWidgets = [];
    List<String> weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    dayWidgets.addAll(
      weekdays.map(
        (day) => Center(
          child: Text(
            day,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );

    for (int i = 0; i < firstWeekday; i++) {
      dayWidgets.add(Container());
    }

    for (int i = 1; i <= daysInMonth; i++) {
      String dateString = DateFormat('yyyy-MM-dd').format(DateTime(month.year, month.month, i));
      List<Color>? colors = loggedColors[dateString];
      bool isToday = (now.year == month.year && now.month == month.month && now.day == i);

      BoxDecoration decoration;
      if (colors != null && colors.isNotEmpty) {
        decoration = BoxDecoration(
          gradient: colors.length == 1
              ? null
              : LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: colors.length == 1 ? colors.first : null,
          borderRadius: BorderRadius.circular(8),
        );
      } else {
        decoration = BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8));
      }

      if (isToday) {
        decoration = decoration.copyWith(
          color: const Color(0xFFC8E6C9),
          border: Border.all(color: Colors.green.shade700, width: 2),
        );
      } else {
        decoration = decoration.copyWith(
          border: Border.all(color: Colors.grey.shade300, width: 1),
        );
      }

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return Seemoremood(
                  userData: widget.userData,
                  selectedDate: DateTime(month.year, month.month, i),
                );
              },
            );
          },
          child: Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(6),
            decoration: decoration,
            child: Text(
              '$i',
              style: TextStyle(
                color: (colors != null && colors.isNotEmpty) ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Text(
              DateFormat('MMMM yyyy').format(month),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.0,
              children: dayWidgets,
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Month Filter Dialog
  Future<void> _showMonthFilterDialog(BuildContext context) async {
    List<DateTime> allMonths = loggedColors.keys
        .map((key) {
          try {
            return DateFormat('yyyy-MM-dd').parse(key);
          } catch (_) {
            return null;
          }
        })
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    List<String> availableMonths = allMonths.map((m) => DateFormat('MMMM yyyy').format(m)).toList();
    availableMonths.insert(0, "Show All");

    String? selectedMonth = _isFiltered ? DateFormat('MMMM yyyy').format(_filteredMonth!) : "Show All";

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                "Filter by Month",
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
              ),
              content: DropdownButtonFormField<String>(
                isExpanded: true,
                value: selectedMonth,
                hint: const Text("Select Month"),
                items: availableMonths
                    .map((month) => DropdownMenuItem(value: month, child: Text(month)))
                    .toList(),
                onChanged: (value) => setDialogState(() => selectedMonth = value),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() {
                      if (selectedMonth == "Show All" || selectedMonth == null) {
                        _filteredMonth = null;
                        _isFiltered = false;
                      } else {
                        _filteredMonth = DateFormat('MMMM yyyy').parse(selectedMonth!);
                        _isFiltered = true;
                      }
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
    );
  }

  void _navigateWithSlideAnimation(BuildContext context, Widget page) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  List<DateTime> visibleMonths = _isFiltered && _filteredMonth != null
      ? months
          .where((m) =>
              m.year == _filteredMonth!.year && m.month == _filteredMonth!.month)
          .toList()
      : months;

  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 232, 232, 232), // ✅ Consistent background

    appBar: AppBar(
      elevation: 0,
      backgroundColor: const Color.fromARGB(255, 232, 232, 232),
      foregroundColor: Colors.black,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 🧭 Title (dynamic for filter state)
          Expanded(
            child: Text(
              _isFiltered && _filteredMonthName != null
                  ? "Mood Calendar - $_filteredMonthName"
                  : "Mood Calendar",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 🎨 Legend Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                color: Color(0xFF4CAF50),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              foregroundColor: const Color(0xFF388E3C),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            icon: const Icon(Icons.palette_outlined, size: 20),
            label: const Text(
              "Legend",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            onPressed: _showMoodLegendDialog,
          ),
        ],
      ),
      centerTitle: false,
    ),

    body: SingleChildScrollView(
      child: Column(
        children: [
          // 🗓️ Filter label display
          if (_isFiltered && _filteredMonthName != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Filtered: $_filteredMonthName",
                style: const TextStyle(
                  color: Color(0xFF388E3C),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // 📅 Render all (or filtered) calendars
          ...visibleMonths.map((month) => _buildCalendar(month)).toList(),
        ],
      ),
    ),

    // ✅ Modern Floating Action Button SpeedDial
    floatingActionButton: SpeedDial(
      animatedIcon: AnimatedIcons.menu_close,
      backgroundColor: const Color(0xFF4CAF50),
      overlayColor: Colors.black,
      overlayOpacity: 0.25,
      spacing: 12,
      spaceBetweenChildren: 10,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

      children: [
        // 🌿 Filter Toggle
        SpeedDialChild(
          child: Icon(
            _isFiltered ? Icons.close : Icons.filter_list_rounded,
            color: Colors.white,
          ),
          backgroundColor:
              _isFiltered ? Colors.red.shade600 : const Color(0xFF81C784),
          label: _isFiltered ? "Clear Filter" : "Filter by Month",
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          onTap: () async {
            if (_isFiltered) {
              await _fetchMoodLogs();
              setState(() {
                _isFiltered = false;
                _filteredMonth = null;
                _filteredMonthName = null;
              });
            } else {
              await _showMonthFilterDialog(context);
            }
          },
        ),

        // 🔁 Switch Calendar View
        SpeedDialChild(
          child: const Icon(Icons.swap_horiz, color: Colors.white),
          backgroundColor: const Color(0xFF009688),
          label: "Switch View",
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          onTap: () {
            _navigateWithSlideAnimation(
              context,
              Calendaremotion(userData: widget.userData),
            );
          },
        ),

        // 📄 Export PDF
        SpeedDialChild(
          child: const Icon(Icons.picture_as_pdf, color: Colors.white),
          backgroundColor: const Color(0xFFF57C00),
          label: "Export as PDF",
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          onTap: _showPrintDialog,
        ),
      ],
    ),
  );
}

  void _showPrintDialog() {
    String? selectedYear;
    List<String> selectedMonths = [];
    bool selectAll = false;

    // Extract available years
    List<String> availableYears = months
        .map((DateTime month) => month.year.toString())
        .toSet()
        .toList()
      ..sort(
          (a, b) => int.parse(b).compareTo(int.parse(a))); // Latest year first

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Get available months for the selected year
            List<DateTime> availableMonthDates = selectedYear == null
                ? []
                : months
                    .where((month) => month.year.toString() == selectedYear)
                    .toList();

            List<String> availableMonths = availableMonthDates
                .map((month) => DateFormat('MMMM').format(month))
                .toList();

            return AlertDialog(
              title: Text("Convert Mood Logs"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Select Year & Month(s) to Convert"),
                  SizedBox(height: 10),

                  // Year Dropdown
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedYear,
                    hint: Text("Select Year"),
                    items: availableYears.map((String year) {
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedYear = newValue;
                        selectedMonths.clear();
                        selectAll = false;
                      });
                    },
                  ),

                  SizedBox(height: 10),

                  if (selectedYear != null) ...[
                    // "All" Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: selectAll,
                          onChanged: (bool? newValue) {
                            setState(() {
                              selectAll = newValue ?? false;
                              selectedMonths =
                                  selectAll ? List.from(availableMonths) : [];
                            });
                          },
                        ),
                        Text("All Months"),
                      ],
                    ),

                    SizedBox(height: 10),

                    // Multi-Select Checkboxes for Months
                    Wrap(
                      children: availableMonths.map((month) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: selectedMonths.contains(month),
                              onChanged: selectAll
                                  ? null // Disable individual selection if "All" is checked
                                  : (bool? checked) {
                                      setState(() {
                                        if (checked == true) {
                                          selectedMonths.add(month);
                                        } else {
                                          selectedMonths.remove(month);
                                        }
                                      });
                                    },
                            ),
                            Text(month),
                          ],
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 10),

                    // Display selected months as removable chips
                    Wrap(
                      children: selectedMonths.map((month) {
                        return Chip(
                          label: Text(month),
                          onDeleted: selectAll
                              ? null // Disable deletion when "All" is checked
                              : () {
                                  setState(() {
                                    selectedMonths.remove(month);
                                  });
                                },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedMonths.isNotEmpty && selectedYear != null) {
                      // Append selected year to months for correct Firestore query
                      List<String> formattedMonths = selectedMonths
                          .map((month) => "$month $selectedYear")
                          .toList();
                      _printSelectedMonths(formattedMonths);
                      Navigator.pop(context);
                    }
                  },
                  child: Text("Confirm"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _printSelectedMonths(List<String> selectedMonths) async {
    final pdf = pw.Document();
    int year = DateTime.now().year;

    print("⏳ Fetching Firestore data for selected months...");

    Map<String, Map<int, List<PdfColor>>> allMoodColors = {};
    for (String month in selectedMonths) {
      int monthNum = DateFormat('MMMM yyyy').parse(month).month;
      allMoodColors[month] = await _fetchMoodColorsFromFirestore(
          year, monthNum, widget.userData['studId']);
    }

    print("✅ All Firestore data fetched successfully!");

    // **📌 Sort months in descending order (latest first)**
    selectedMonths.sort((a, b) {
      int monthA = DateFormat('MMMM yyyy').parse(a).month;
      int monthB = DateFormat('MMMM yyyy').parse(b).month;
      return monthB.compareTo(monthA); // 🔹 Latest first
    });

    // Add legend to PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Mood Logs",
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    for (String month in selectedMonths) {
      int monthNum = DateFormat('MMMM yyyy').parse(month).month;
      Map<int, List<PdfColor>> moodColors = allMoodColors[month]!;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // 📌 **Month Title (Only Month Name)**
                pw.Text(
                  month.split(" ")[0], // ✅ Only month name (year removed)
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),

                // 📅 **Generate Calendar**
                _generateCalendarPdf(year, monthNum, moodColors, 75),
              ],
            );
          },
        ),
      );
    }
    print("📄 Saving PDF...");

    Uint8List pdfBytes = await pdf.save();

    await PdfDownloader.download(pdfBytes);

    print("🎉 PDF Generated Successfully!");
  }

  // Helper method to build PDF legend items
  pw.Widget _buildPdfLegendItem(PdfColor color, String label) {
    return pw.Row(
      children: [
        pw.Container(
          width: 15,
          height: 15,
          decoration: pw.BoxDecoration(
            color: color,
            border: pw.Border.all(color: PdfColors.black, width: 0.5),
          ),
        ),
        pw.SizedBox(width: 5),
        pw.Text(label),
      ],
    );
  }

  Future<Map<int, List<PdfColor>>> _fetchMoodColorsFromFirestore(
      int year, int month, String userStudId) async {
    Map<int, List<PdfColor>> moodMap = {};

    print("📡 Fetching logs for: Year $year, Month $month, User: $userStudId");

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('moodLogs')
        .where('studId', isEqualTo: userStudId)
        .get();

    print("📥 Firestore Data Retrieved: ${snapshot.docs.length} logs found.");

    for (var doc in snapshot.docs) {
      Timestamp timestamp = doc['timestamp'];
      DateTime date = timestamp.toDate();

      if (date.year == year && date.month == month) {
        int day = date.day;
        String dateString = DateFormat('yyyy-MM-dd').format(date);

        var colorData = doc['color'];
        List<PdfColor> pdfColors = [];

        if (colorData is String) {
          print("🎨 Found String Color for $dateString: $colorData");
          pdfColors.add(_hexToPdfColor(colorData));
        } else if (colorData is List) {
          print("🎨 Found List Color for $dateString: $colorData");
          pdfColors =
              colorData.map((c) => _hexToPdfColor(c.toString())).toList();
        } else {
          print("⚠️ Unexpected color format for $dateString: $colorData");
        }

        if (pdfColors.isNotEmpty) {
          if (!moodMap.containsKey(day)) {
            moodMap[day] = [];
          }
          moodMap[day]!.addAll(pdfColors);
        }

        print("📅 $dateString → Colors: $pdfColors");
      }
    }

    print("✅ Finished Fetching Mood Data for Month $month");
    return moodMap;
  }

  // 🔹 Generate Calendar with Gradient Mood Colors
  pw.Widget _generateCalendarPdf(int year, int month,
      Map<int, List<PdfColor>> moodColors, double cellSize) {
    DateTime firstDay = DateTime(year, month, 1);
    int daysInMonth = DateTime(year, month + 1, 0).day;
    int firstWeekday = firstDay.weekday % 7; // Sunday = 0, Monday = 1

    List<pw.Widget> rows = [];

    // 📌 **Weekday Headers**
    rows.add(
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            .map((day) => pw.Container(
                  width: cellSize,
                  height: cellSize,
                  alignment: pw.Alignment.center,
                  child: pw.Text(day,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ))
            .toList(),
      ),
    );

    List<pw.Widget> weekRow = [];

    // 🔹 **Offset for First Week**
    for (int i = 0; i < firstWeekday; i++) {
      weekRow.add(pw.Container(width: cellSize, height: cellSize));
    }

    // 🔹 **Fill Calendar Days**
    for (int day = 1; day <= daysInMonth; day++) {
      List<PdfColor> colors = moodColors[day] ?? [];
      pw.BoxDecoration? decoration;

      if (colors.isNotEmpty) {
        decoration = colors.length == 1
            ? pw.BoxDecoration(
                color: colors.first,
                border: pw.Border.all(color: PdfColors.black, width: 0.5))
            : pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: colors,
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                ),
                border: pw.Border.all(color: PdfColors.black, width: 0.5),
              );
      } else {
        decoration = pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.5));
      }

      weekRow.add(
        pw.Container(
          width: cellSize,
          height: cellSize,
          alignment: pw.Alignment.center,
          decoration: decoration,
          child: pw.Text("$day", style: pw.TextStyle(color: PdfColors.black)),
        ),
      );

      // ✅ **Ensure 7 Columns Per Row**
      if ((day + firstWeekday) % 7 == 0 || day == daysInMonth) {
        rows.add(pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.start,
          children: List.from(weekRow),
        ));
        weekRow.clear();
      }
    }

    return pw.Column(children: rows);
  }

  // 🔹 Convert Hex Color to PdfColor
  PdfColor _hexToPdfColor(String hex) {
    print("🔍 Converting HEX: $hex"); // Debugging log

    hex = hex.replaceFirst("#", ""); // Remove '#' if present
    if (hex.length == 8) {
      hex = hex.substring(2); // Strip the first two characters (alpha)
    }

    if (hex.length == 6) {
      double r = int.parse(hex.substring(0, 2), radix: 16) / 255;
      double g = int.parse(hex.substring(2, 4), radix: 16) / 255;
      double b = int.parse(hex.substring(4, 6), radix: 16) / 255;

      PdfColor pdfColor = PdfColor(r, g, b);
      print("✅ Converted to PdfColor: $pdfColor");
      return pdfColor;
    }

    print("⚠️ Invalid HEX color: $hex");
    return PdfColors.white;
  }

}