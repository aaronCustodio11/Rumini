import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';

class Seemoreemotion extends StatelessWidget {
  final Map<String, dynamic> userData;
  final DateTime selectedDate;

  const Seemoreemotion({
    super.key,
    required this.userData,
    required this.selectedDate,
  });

  Future<List<Map<String, dynamic>>> fetchemotionLogs() async {
    DateTime startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
    DateTime endOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

    var snapshot = await FirebaseFirestore.instance
        .collection('emotionLogs')
        .where('studId', isEqualTo: userData['studId'])
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      return {
        'emotion': doc['emotion'],
        'journal': doc['journal'],
        'timestamp': doc['timestamp'].toDate(),
        'image': doc['image'], // Get the image path
        'color': doc['color'], // Get the color string
      };
    }).toList();
  }

  Color _parseColor(dynamic colorData) {
    // Handle if color is a String
    if (colorData is String && colorData.isNotEmpty) {
      String colorCode = colorData.replaceAll('#', '');
      return Color(int.parse('FF$colorCode', radix: 16));
    }
    // Default fallback color
    return Color(0xFF4CAF50);
  }

  @override
  Widget build(BuildContext context) {
    String formattedSelectedDate = DateFormat("EEEE, MMMM d, y").format(selectedDate);
    bool isToday = DateFormat("yMd").format(selectedDate) == DateFormat("yMd").format(DateTime.now());

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 500,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isToday ? "Today's Journey" : "Emotion Timeline",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              formattedSelectedDate,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchemotionLogs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Loading your emotions...",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                          SizedBox(height: 16),
                          Text(
                            "Oops! Something went wrong",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    var emotionLogs = snapshot.data!;
                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: emotionLogs.length,
                      itemBuilder: (context, index) {
                        var log = emotionLogs[index];
                        String formattedTimestamp = DateFormat("h:mm a").format(log['timestamp']);
                        Color emotionColor = _parseColor(log['color']);
                        String imagePath = log['image'] ?? '';

                        return TimelineTile(
                          alignment: TimelineAlign.manual,
                          lineXY: 0.1,
                          isFirst: index == 0,
                          isLast: index == emotionLogs.length - 1,
                          indicatorStyle: IndicatorStyle(
                            width: 50,
                            height: 50,
                            indicator: Container(
                              decoration: BoxDecoration(
                                color: emotionColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: emotionColor.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(4),
                              child: imagePath.isNotEmpty
                                  ? ClipOval(
                                      child: Image.asset(
                                        imagePath,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.mood_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      Icons.mood_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                            ),
                          ),
                          beforeLineStyle: LineStyle(
                            color: emotionColor.withOpacity(0.3),
                            thickness: 2,
                          ),
                          endChild: Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 24),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: emotionColor.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            log['emotion'],
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: emotionColor,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: emotionColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 12,
                                                color: emotionColor,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                formattedTimestamp,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: emotionColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (log['journal'] != null && log['journal'].isNotEmpty) ...[
                                      SizedBox(height: 12),
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          log['journal'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[800],
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  } else {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.sentiment_neutral,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "No emotions logged",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              isToday 
                                ? "Start your day by logging how you feel!"
                                : "No emotion logs for this date.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
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