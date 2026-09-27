import 'dart:async';
import 'package:rumini/pages(admin)/forms/export.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:rumini/components/sidebar.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting
import 'dart:math' show min, max;

class Formsanalytics extends StatefulWidget {
  final String? currentformId;
  final Map<String, dynamic> userData;
  const Formsanalytics({super.key, required this.currentformId, required this.userData});

  @override
  State<Formsanalytics> createState() => _FormsanalyticsState();
}

class _FormsanalyticsState extends State<Formsanalytics> {
  List<Map<String, dynamic>> questions = [];
  List<Map<String, dynamic>> answers = [];
  bool isLoading = true;
  String? formTitle;
  String? formStatus; // Track form status

  // Add stream subscriptions to manage listeners
  StreamSubscription? _questionsSubscription;
  StreamSubscription? _answersSubscription;
  StreamSubscription? _formSubscription;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void dispose() {
    // Cancel all subscriptions when the widget is disposed
    _questionsSubscription?.cancel();
    _answersSubscription?.cancel();
    _formSubscription?.cancel();
    super.dispose();
  }

  // New method to set up real-time listeners
  void _setupListeners() {
    if (widget.currentformId == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // Listen for form title changes
      _formSubscription = FirebaseFirestore.instance
          .collection('forms')
          .doc(widget.currentformId)
          .snapshots()
          .listen((formDoc) {
        if (formDoc.exists) {
          setState(() {
            formTitle = formDoc.data()?['title'] ?? 'Form Analytics';
            formStatus = formDoc.data()?['status'] ?? 'open';
          });
        }
      });

      // Listen for questions changes
      _questionsSubscription = FirebaseFirestore.instance
          .collection('questions')
          .where('formId', isEqualTo: widget.currentformId)
          .orderBy('order')
          .snapshots()
          .listen((snapshot) {
        setState(() {
          questions = snapshot.docs.map((doc) => doc.data()).toList();
        });
      });

      // Listen for answers changes
      _answersSubscription = FirebaseFirestore.instance
          .collection('answer_form')
          .where('formId', isEqualTo: widget.currentformId)
          .snapshots()
          .listen((snapshot) {
        setState(() {
          answers = snapshot.docs.map((doc) => doc.data()).toList();
          isLoading = false;
        });
      });
    } catch (e) {
      print('Error setting up Firestore listeners: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateFormStatus(String newStatus) async {
  try {
    await FirebaseFirestore.instance
        .collection('forms')
        .doc(widget.currentformId)
        .update({'status': newStatus});
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Form status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating form status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
Future<void> _deleteAllResponses() async {
  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('answer_form')
        .where('formId', isEqualTo: widget.currentformId)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All responses deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting responses: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
void _showResetDialog() {
  if (formStatus == 'open') {
    // Show dialog to close form first
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Form is Active',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        content: const Text(
          'The form is currently open and accepting responses. You need to close the form before resetting responses.\n\nWould you like to close the form now?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _updateFormStatus('close');
            },
            icon: const Icon(Icons.lock, size: 18),
            label: const Text('Close Form'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  } else {
    // Form is closed, show deletion confirmation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Reset All Responses',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action will permanently delete all responses for this form.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This cannot be undone!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAllResponses();
            },
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 232, 232, 232),
      
      body: Row(
        children: [
          Sidebar(userData: widget.userData),
          // <-- your custom sidebar widget
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: const Color.fromARGB(255, 232, 232, 232),
                title: const Row(
                  children: [
                    Icon(Icons.analytics, color: Color(0xFF345F00)),
                    SizedBox(width: 8),
                    Text("Forms Analytics"),
                  ],
                ),
                titleTextStyle: const TextStyle(
                  color: Color(0xFF345F00),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ), 
              body: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : widget.currentformId == null
                      ? const Center(child: Text("No form selected"))
                      : questions.isEmpty
                          ? const Center(
                              child: Text("No questions found for this form"))
                          : answers.isEmpty
                              ? const Center(
                                  child: Text("No responses yet for this form"))
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: questions.length +
                                      1, // +1 for the top card
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 20),
                                  itemBuilder: (context, index) {
                                    // Top card with 3 buttons 
                                    if (index == 0) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 100.0),
    child: Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER TITLE ROW ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title section
                Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      formTitle ?? "Loading...", // Display the form title dynamically
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF345F00),
        letterSpacing: 0.5,
      ),
    ),
    const SizedBox(height: 6),
    const Text(
      "Export summarized data and insights for this form.",
      style: TextStyle(
        fontSize: 14,
        color: Colors.black54,
        letterSpacing: 0.2,
      ),
    ),
  ],
),
              ],
            ),

            const SizedBox(height: 40),

            // --- EXPORT BUTTON AREA ---
            Center(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text(
                            'Export Analytics',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF345F00),
                            ),
                          ),
                          content: const Text(
                            'Choose export format below:',
                            style: TextStyle(fontSize: 15),
                          ),
                          actionsPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          actionsAlignment: MainAxisAlignment.spaceEvenly,
                          actions: [
                            // TextButton.icon(
                            //   onPressed: () async {
                            //     Navigator.pop(context);
                            //     await AnalyticsExporter.exportFormAnalytics(
                            //       formId: widget.currentformId,
                            //       format: 'pdf',
                            //     );
                            //   },
                            //   icon: const Icon(Icons.picture_as_pdf,
                            //       color: Colors.red),
                            //   label: const Text(
                            //     'PDF',
                            //     style: TextStyle(
                            //       fontWeight: FontWeight.w600,
                            //       color: Colors.red,
                            //     ),
                            //   ),
                            // ),
                            TextButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await AnalyticsExporter.exportFormAnalytics(
                                  formId: widget.currentformId,
                                  format: 'docx',
                                );
                              },
                              icon: const Icon(Icons.description,
                                  color: Colors.blue),
                              label: const Text(
                                'Word',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.download_rounded,
                      color: Color(0xFF345F00),
                    ),
                    label: const Text(
                      "Export Analytics",
                      style: TextStyle(
                        color: Color(0xFF345F00),
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD9F0D0),
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Download analytics as PDF or Word document",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
      
        ElevatedButton.icon(
          onPressed: answers.isEmpty ? null : _showResetDialog,
          icon: const Icon(
            Icons.delete_sweep_rounded,
            color: Colors.white,
          ),
          label: const Text(
            "Reset Responses",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: answers.isEmpty 
                ? Colors.grey.shade400 
                : Colors.red.shade600,
            padding: const EdgeInsets.symmetric(
                vertical: 16, horizontal: 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          answers.isEmpty 
              ? "No responses to reset"
              : "Delete all form responses",
          style: TextStyle(
            color: answers.isEmpty 
                ? Colors.grey 
                : Colors.black54,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}



                                    // Adjusted index for questions list
                                    final q = questions[index - 1];
                                    final qId = q['questionId'];
                                    final qText =
                                        q['question'] ?? 'No question text';
                                    final qType =
                                        q['questionType'] ?? 'Unknown';

                                    // Process answers with potential timestamp formatting
                                    final List<String> qAnswers = [];
                                    for (final a in answers) {
                                      for (int i = 1; i <= 100; i++) {
                                        if (a['question$i'] == qId &&
                                            a.containsKey('answer$i')) {
                                          // Check if this is a timestamp for Date Picker
                                          var answer = a['answer$i'];
                                          if (qType == 'Date Picker' &&
                                              answer is Timestamp) {
                                            // Convert to UTC+8 and format as Month name, day, year
                                            DateTime dateTime = answer
                                                .toDate()
                                                .add(const Duration(hours: 8));
                                            String formattedDate =
                                                DateFormat('MMMM d, yyyy')
                                                    .format(dateTime);
                                            qAnswers.add(formattedDate);
                                          } else {
                                            qAnswers.add(answer.toString());
                                          }
                                          break;
                                        }
                                      }
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 100.0),
                                      child: Card(
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Question title only (removed the type chip)
                                              Text(
                                                qText,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: 16),
                                              const SizedBox(height: 16),

                                              if (qAnswers.isEmpty)
                                                const Text(
                                                    "No responses yet for this question.")
                                              else if ([
                                                'Short Answer',
                                                'Long Answer',
                                                'Date Picker',
                                                'Time Picker'
                                              ].contains(qType))
                                                // Keep the original scrollable text responses, but with fixed height
                                                SizedBox(
                                                  height: 300,
                                                  child: Scrollbar(
                                                    thickness: 6,
                                                    radius:
                                                        const Radius.circular(
                                                            10),
                                                    child: ListView.builder(
                                                      itemCount:
                                                          qAnswers.length,
                                                      itemBuilder:
                                                          (context, i) {
                                                        final bgColor = i.isEven
                                                            ? Colors.white
                                                            : Colors
                                                                .grey.shade100;
                                                        return Container(
                                                          color: bgColor,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 12,
                                                                  horizontal:
                                                                      16),
                                                          child: Text(
                                                            qAnswers[i],
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        14),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                )
                                              else if (qType == 'Checkboxes')
                                                // For Checkboxes - Bar Chart
                                                CheckboxesChart(
                                                  answers: qAnswers,
                                                  options: q['options'] ??
                                                      [], // Pass the options list
                                                )
                                              else if ([
                                                'Multiple Choice',
                                                'Dropdown'
                                              ].contains(qType))
                                                // For Multiple Choice and Dropdown - Pie Chart
                                                PieChartWidget(
                                                  answers: qAnswers,
                                                  options: q['options'] ??
                                                      [], // Pass the options list
                                                )
                                              else
                                                // For any other question types
                                                const Text(
                                                    "Visualization not available for this question type."),
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
    );
  }
}

// Separate widget for Checkboxes chart
class CheckboxesChart extends StatefulWidget {
  final List<String> answers;
  final List<dynamic> options;

  const CheckboxesChart({
    super.key,
    required this.answers,
    required this.options, // Add this line
  });

  @override
  State<CheckboxesChart> createState() => _CheckboxesChartState();
}

class _CheckboxesChartState extends State<CheckboxesChart> {
  int? touchedIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400, // Fixed height to prevent layout issues
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Centered Horizontal Bar Chart
          Expanded(
            flex: 3,
            child: _buildHorizontalBarChart(
              widget.answers,
              touchedIndex,
              (index) {
                setState(() {
                  touchedIndex = index;
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          // Total count at the bottom right
          Align(
            alignment: Alignment.bottomRight,
            child: _buildTotalCount(widget.answers),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalBarChart(
      List<String> answers, int? touchedIndex, Function(int) onTouch) {
    final Map<String, int> counts = _getAnswerCounts(answers);
    final List<MapEntry<String, int>> sortedEntries = counts.entries.toList()
      ..sort((a, b) =>
          b.value.compareTo(a.value)); // Sort by value in descending order

    // Define a list of colors for the bar sections
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.lime,
      Colors.brown,
    ];

    // Find the maximum value for scaling
    final int maxValue =
        sortedEntries.isNotEmpty ? sortedEntries.first.value : 0;
    final int total = counts.values.fold(0, (sum, count) => sum + count);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate how many items we can fit
        final int itemCount = sortedEntries.length;

        // Define minimum heights and spacing
        final double minBarHeight = 20.0;
        final double minSpacing = 4.0;
        final double scaleHeight = 25.0; // Height for the scale at bottom

        // Calculate available height for bars
        final double availableHeight = constraints.maxHeight - scaleHeight;

        // Calculate actual bar height and spacing
        double barHeight =
            (availableHeight - (itemCount - 1) * minSpacing) / itemCount;

        // If bars would be too small, use the minimum and allow scrolling
        final bool needsScrolling = barHeight < minBarHeight;
        barHeight = max(minBarHeight, barHeight);

        // Define the width for the bar area
        final availableBarWidth = constraints.maxWidth * 0.6;

        // Widget to display the bars
        Widget barsWidget;

        if (needsScrolling) {
          // If we need scrolling, use ListView
          barsWidget = ListView.separated(
            itemCount: itemCount,
            separatorBuilder: (_, __) => SizedBox(height: minSpacing),
            itemBuilder: (context, index) => _buildBarItem(
              sortedEntries[index],
              index,
              touchedIndex,
              onTouch,
              barHeight,
              availableBarWidth,
              maxValue,
              total,
              colors,
              constraints,
            ),
          );
        } else {
          // If everything fits, use Column
          barsWidget = Column(
            children: List.generate(
              itemCount,
              (index) => Padding(
                padding: EdgeInsets.only(
                  bottom: index < itemCount - 1 ? minSpacing : 0,
                ),
                child: _buildBarItem(
                  sortedEntries[index],
                  index,
                  touchedIndex,
                  onTouch,
                  barHeight,
                  availableBarWidth,
                  maxValue,
                  total,
                  colors,
                  constraints,
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            // Main content (bars)
            Expanded(child: barsWidget),

            // Number scale at the bottom
            SizedBox(
              height: scaleHeight,
              child: Padding(
                padding: EdgeInsets.only(left: constraints.maxWidth * 0.25),
                child: Row(
                  children: [
                    const Text('0',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.grey.shade300,
                        child: Stack(
                          children: List.generate(5, (index) {
                            final value = (maxValue / 4) * (index + 1);
                            return Positioned(
                              left: (availableBarWidth / 4) * index,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 1,
                                    height: 5,
                                    color: Colors.grey,
                                  ),
                                  Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

// Helper method to build a single bar item
  Widget _buildBarItem(
    MapEntry<String, int> entry,
    int index,
    int? touchedIndex,
    Function(int) onTouch,
    double barHeight,
    double availableBarWidth,
    int maxValue,
    int total,
    List<Color> colors,
    BoxConstraints constraints,
  ) {
    final isSelected = touchedIndex == index;
    final value = entry.value;
    final percentage = total > 0 ? (value / total) * 100 : 0.0;
    final barValueWidth =
        maxValue > 0 ? (value / maxValue) * availableBarWidth : 0.0;

    // Truncate option text if too long
    String displayText = entry.key;
    if (displayText.length > 20) {
      displayText = '${displayText.substring(0, 17)}...';
    }

    // Scale font size based on bar height
    final double fontSize = min(12.0, barHeight * 0.5);

    return MouseRegion(
      onEnter: (_) => onTouch(index),
      onExit: (_) => onTouch(-1),
      child: Tooltip(
        message:
            '${entry.key}\n$value responses (${percentage.toStringAsFixed(1)}%)',
        preferBelow: false,
        verticalOffset: 20,
        child: Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: isSelected ? Colors.grey.shade100 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: colors[index % colors.length], width: 1)
                : null,
          ),
          child: Row(
            children: [
              // Option text on the left
              SizedBox(
                width: constraints.maxWidth * 0.25,
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Bar
              Expanded(
                child: Stack(
                  children: [
                    // Background bar
                    Container(
                      height: barHeight * 0.6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius:
                            BorderRadius.circular(min(12.0, barHeight * 0.3)),
                      ),
                    ),
                    // Value bar
                    Container(
                      width: barValueWidth,
                      height: barHeight * 0.6,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors[index % colors.length]
                            : colors[index % colors.length].withOpacity(0.7),
                        borderRadius:
                            BorderRadius.circular(min(12.0, barHeight * 0.3)),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: colors[index % colors.length]
                                      .withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
              ),

              // Response count and percentage at the end
              SizedBox(
                width: constraints.maxWidth * 0.15,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    '$value (${percentage.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCount(List<String> answers) {
    // Count unique documents (form responses)
    final int totalResponses = answers.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Total Responses",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            totalResponses.toString(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _getAnswerCounts(List<String> answers) {
    final Map<String, int> counts = {};

    // First, initialize counts for all options (with zero)
    for (var option in widget.options) {
      // Handle both string and map format for options
      String optionText =
          option is Map ? option['text'] ?? '' : option.toString();
      counts[optionText.trim()] = 0;
    }

    // Count each document that selected each option
    for (var answer in answers) {
      // Split the answer if it contains multiple selections (comma-separated)
      if (answer.contains(',')) {
        List<String> selectedOptions =
            answer.split(',').map((part) => part.trim()).toList();

        // Count each selected option once per document
        for (var option in selectedOptions) {
          counts[option] = (counts[option] ?? 0) + 1;
        }
      } else {
        // Single option selected
        String trimmedAnswer = answer.trim();
        counts[trimmedAnswer] = (counts[trimmedAnswer] ?? 0) + 1;
      }
    }

    return counts;
  }
}

// Separate widget for Pie chart
class PieChartWidget extends StatefulWidget {
  final List<String> answers;
  final List<dynamic> options;

  const PieChartWidget({
    super.key,
    required this.answers,
    required this.options, // Add this line
  });

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget> {
  int? touchedIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400, // Fixed height to prevent layout issues
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Pie Chart
          Expanded(
            flex: 3,
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: _getPieSections(widget.answers, touchedIndex),
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Right side: Interactive Legend and Total Count
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Interactive legend
                Expanded(
                  child: _buildInteractiveLegend(widget.answers, touchedIndex,
                      (index) {
                    setState(() {
                      touchedIndex = touchedIndex == index ? -1 : index;
                    });
                  }),
                ),
                // Total count at the bottom right
                Align(
                  alignment: Alignment.bottomRight,
                  child: _buildTotalCount(widget.answers),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getPieSections(
      List<String> answers, int? touchedIndex) {
    final Map<String, int> counts = _getAnswerCounts(answers);

    // Define a list of colors for the pie sections
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.lime,
      Colors.brown,
    ];

    final total = counts.values.fold(0, (sum, count) => sum + count);

    return counts.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value.value;
      final percentage = (value / total) * 100;

      final isTouched = touchedIndex == index;
      final fontSize = isTouched ? 18.0 : 12.0;
      final radius = isTouched ? 90.0 : 80.0;
      final borderWidth = isTouched ? 2.0 : 0.0;
      final borderColor = isTouched ? Colors.white : Colors.transparent;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: isTouched
              ? [
                  const Shadow(
                    color: Colors.black26,
                    blurRadius: 2,
                  )
                ]
              : [],
        ),
        borderSide: BorderSide(
          color: borderColor,
          width: borderWidth,
        ),
      );
    }).toList();
  }

  Widget _buildInteractiveLegend(
      List<String> answers, int? touchedIndex, Function(int) onHover) {
    final Map<String, int> counts = _getAnswerCounts(answers);

    // Sort entries by value in descending order for checkboxes
    final List<MapEntry<String, int>> entries = counts.entries.toList();
    if (answers.any((a) => a.contains(','))) {
      // This means it's likely checkboxes with multiple selections
      entries.sort((a, b) => b.value.compareTo(a.value));
    }

    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.lime,
      Colors.brown,
    ];

    return ListView(
      shrinkWrap: true,
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final key = entry.value.key;
        final value = entry.value.value;
        final isSelected = touchedIndex == index;

        return MouseRegion(
          onEnter: (_) => onHover(index),
          onExit: (_) => onHover(-1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors[index % colors.length].withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: colors[index % colors.length], width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colors[index % colors.length]
                                  .withOpacity(0.3),
                              blurRadius: 4,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    key,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors[index % colors.length].withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? colors[index % colors.length]
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTotalCount(List<String> answers) {
    // Count unique documents (form responses)
    final int totalResponses = answers.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Total Responses",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            totalResponses.toString(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _getAnswerCounts(List<String> answers) {
    final Map<String, int> counts = {};

    // First, initialize counts for all options (with zero)
    for (var option in widget.options) {
      // Handle both string and map format for options
      String optionText =
          option is Map ? option['text'] ?? '' : option.toString();
      counts[optionText.trim()] = 0;
    }

    // Count each document that selected each option
    for (var answer in answers) {
      // Split the answer if it contains multiple selections (comma-separated)
      if (answer.contains(',')) {
        List<String> selectedOptions =
            answer.split(',').map((part) => part.trim()).toList();

        // Count each selected option once per document
        for (var option in selectedOptions) {
          counts[option] = (counts[option] ?? 0) + 1;
        }
      } else {
        // Single option selected
        String trimmedAnswer = answer.trim();
        counts[trimmedAnswer] = (counts[trimmedAnswer] ?? 0) + 1;
      }
    }

    return counts;
  }
}
