import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Seemoremood extends StatelessWidget {
  final Map<String, dynamic> userData;
  final DateTime selectedDate;

  const Seemoremood({
    super.key,
    required this.userData,
    required this.selectedDate, 
  });

  Future<Map<String, dynamic>?> fetchMoodLog() async {
    DateTime startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
    DateTime endOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

    var snapshot = await FirebaseFirestore.instance
        .collection('moodLogs')
        .where('studId', isEqualTo: userData['studId'])
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    var doc = snapshot.docs.first;
    return {
      'mood': doc['mood'],
      'journal': doc['journal'],
      'timestamp': doc['timestamp'].toDate(),
      'image': doc['image'], // Get the image path
      'color': doc['color'], // Get the color array
    };
  }

  Color _parseColor(dynamic colorData) {
    // Handle if color is a List (array of color codes)
    if (colorData is List && colorData.isNotEmpty) {
      String colorCode = colorData[0].toString();
      // Remove # if present and parse
      colorCode = colorCode.replaceAll('#', '');
      return Color(int.parse('FF$colorCode', radix: 16));
    }
    // Handle if color is a String
    else if (colorData is String) {
      String colorCode = colorData.replaceAll('#', '');
      return Color(int.parse('FF$colorCode', radix: 16));
    }
    // Default fallback color
    return Color(0xFF4CAF50);
  }

  List<Color> _parseGradientColors(dynamic colorData) {
    if (colorData is List && colorData.length >= 2) {
      return colorData.map((color) {
        String colorCode = color.toString().replaceAll('#', '');
        return Color(int.parse('FF$colorCode', radix: 16));
      }).toList();
    }
    // Default gradient if only one color or none
    Color mainColor = _parseColor(colorData);
    return [mainColor, mainColor.withOpacity(0.7)];
  }

  @override
  Widget build(BuildContext context) {
    String formattedSelectedDate = DateFormat("EEEE, MMMM d, y").format(selectedDate);
    bool isToday = DateFormat("yMd").format(selectedDate) == DateFormat("yMd").format(DateTime.now());

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 450,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.wb_sunny_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isToday ? "Today's Mood" : "Daily Mood",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          formattedSelectedDate,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: FutureBuilder<Map<String, dynamic>?>(
                future: fetchMoodLog(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 20),
                          Text(
                            "Loading mood...",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.error_outline_rounded,
                                size: 64,
                                color: Colors.red[300],
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Oops! Something went wrong",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              "Unable to load mood data",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (snapshot.hasData && snapshot.data != null) {
                    var log = snapshot.data!;
                    String formattedTimestamp = DateFormat("h:mm a").format(log['timestamp']);
                    Color moodColor = _parseColor(log['color']);
                    List<Color> gradientColors = _parseGradientColors(log['color']);
                    String imagePath = log['image'] ?? '';

                    return SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Large mood display
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  gradientColors[0].withOpacity(0.15),
                                  gradientColors.length > 1 
                                    ? gradientColors[1].withOpacity(0.05)
                                    : gradientColors[0].withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: moodColor.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Mood image
                                if (imagePath.isNotEmpty)
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: moodColor.withOpacity(0.3),
                                          blurRadius: 20,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        imagePath,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: moodColor.withOpacity(0.2),
                                            child: Icon(
                                              Icons.mood_rounded,
                                              size: 60,
                                              color: moodColor,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.mood_rounded,
                                    size: 80,
                                    color: moodColor,
                                  ),
                                SizedBox(height: 16),
                                // Mood text
                                Text(
                                  log['mood'],
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: moodColor,
                                  ),
                                ),
                                SizedBox(height: 12),
                                // Timestamp badge
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        gradientColors[0].withOpacity(0.2),
                                        gradientColors.length > 1 
                                          ? gradientColors[1].withOpacity(0.2)
                                          : gradientColors[0].withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 16,
                                        color: moodColor,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "Logged at $formattedTimestamp",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: moodColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Journal section
                          if (log['journal'] != null && log['journal'].isNotEmpty) ...[
                            SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.edit_note_rounded,
                                        color: moodColor,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "Journal Entry",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    log['journal'],
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey[700],
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  } else {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.wb_sunny_outlined,
                                size: 72,
                                color: Colors.grey[400],
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              "No mood logged",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              isToday 
                                ? "How are you feeling today?\nLog your daily mood!"
                                : "No mood was logged on this date.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[600],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}