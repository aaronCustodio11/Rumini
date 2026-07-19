import 'dart:io';
import 'package:rumini/pages(user)/moodtracker/calendarEmotion.dart';
import 'package:rumini/pages(user)/moodtracker/calendarMood.dart';
import 'package:rumini/pages(user)/moodtracker/logmood.dart';
import 'package:rumini/pages(user)/moodtracker/seemoreEmotion.dart';
import 'package:rumini/pages(user)/moodtracker/seemoreMood.dart';
import 'package:rumini/pages(user)/notifications/notif.dart';
import 'package:rumini/profilePage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logemotion.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Moodtracker extends StatefulWidget {
  final Map<String, dynamic> userData;

  const Moodtracker({super.key, required this.userData});

  @override
  State<Moodtracker> createState() => _MoodtrackerState();
}

class _MoodtrackerState extends State<Moodtracker>
    with SingleTickerProviderStateMixin {
  String? latestMood;
  String? latestMoodImage;
  List<Color> cardGradientColors = [Colors.white, Colors.white];
  Map<String, dynamic>? recentEmotion;
  bool isLoadingRecentEmotion = true;
  List<Map<String, dynamic>> emotionLogs = [];
  bool hasMultipleEmotionLogs = false;
  late Stream<QuerySnapshot> _emotionLogsStream;

  @override
  void initState() {
    super.initState();
    fetchLatestMood();
    _recentEmotionStream();
    _setupEmotionLogsStream();
    fetchLatestMood();
    _recentEmotionStream();
    _checkFirstTimeConsent();
  }

  Future<void> _checkFirstTimeConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenConsent = prefs.getBool("hasSeenConsent") ?? false;

    if (!hasSeenConsent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showConsentDialog(context); // 👈 show first popup
      });
      await prefs.setBool(
        "hasSeenConsent",
        true,
      ); // Save so it won’t show again
    }
  }

  void _setupEmotionLogsStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    _emotionLogsStream = FirebaseFirestore.instance
        .collection('emotionLogs')
        .where('studId', isEqualTo: widget.userData['studId'])
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Add this method to fetch the most recent emotion from today only
  Stream<DocumentSnapshot?> _recentEmotionStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return FirebaseFirestore.instance
        .collection('emotionLogs')
        .where('studId', isEqualTo: widget.userData['studId'])
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first : null,
        );
  }

  void fetchLatestMood() async {
  if (widget.userData == null || widget.userData['studId'] == null) {
    return;
  }

  DateTime now = DateTime.now();
  DateTime startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
  DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

  FirebaseFirestore.instance
      .collection('moodLogs')
      .where('studId', isEqualTo: widget.userData['studId'])
      .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
      .orderBy('timestamp', descending: true)
      .limit(1)
      .snapshots()
      .listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          var doc = snapshot.docs.first;
          setState(() {
            latestMood = doc['mood'];
            latestMoodImage = doc['image']; // 👈 store image path

            // Extract color values from Firestore
            List<dynamic> colorArray = doc['color'];
            if (colorArray.length >= 2) {
              Color color1 = Color(int.parse("0x${colorArray[0]}"));
              Color color2 = Color(int.parse("0x${colorArray[1]}"));

              if (doc['mood'] == "Neutral") {
                Color lighterColor1 = Color.lerp(color1, Colors.white, 0.1)!;
                Color lighterColor2 = Color.lerp(color2, Colors.white, 0.5)!;
                cardGradientColors = [lighterColor1, lighterColor2];
              } else {
                Color lighterColor1 = Color.lerp(color1, Colors.white, 0.2)!;
                Color lighterColor2 = Color.lerp(color2, Colors.white, 0.6)!;
                cardGradientColors = [lighterColor1, lighterColor2];
              }
            } else {
              cardGradientColors = [Colors.white, Colors.white];
            }
          });
        } else {
          setState(() {
            latestMood = null;
            latestMoodImage = null;
            cardGradientColors = [Colors.white, Colors.white];
          });
        }
      });
}


  Gradient _getEmotionGradient(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return const LinearGradient(
        colors: [
          Color.fromARGB(255, 255, 255, 255),
          Color.fromARGB(255, 255, 255, 255),
        ], // Default gradient
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    List<Color> colors = logs.map((log) {
      Color baseColor = _parseColor(log['color'] ?? 'FF999999');
      return Color.lerp(baseColor, Colors.white, 0.4)!;
    }).toList();

    if (colors.length == 1) {
      colors.add(Colors.white);
    }

    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');

    if (hexColor.length == 8) {
      return Color(int.parse('0x$hexColor'));
    } else if (hexColor.length == 6) {
      return Color(int.parse('0xFF$hexColor'));
    }
    return Colors.grey;
  }

  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonSize = screenWidth * 0.18;

    return Scaffold(
      body: Stack(
        children: [
          // Green background at the top
          Container(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            color: Colors.green[900],
          ),

          // Curved white background below
          Positioned(
            top:
                MediaQuery.of(context).size.height *
                0.27, // Adjust this value to control where the white part starts
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: Color(0xFFF0F0F0), // Light gray/white background
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
            ),
          ),

          // Content goes here
          SafeArea(
            child: Column(
              children: [
                // App bar equivalent
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mood Tracker',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('notifications')
                                .where('seen', isEqualTo: false)
                                .where('studId', isEqualTo: widget.userData['studId'])
                                .snapshots(),

                            builder: (context, snapshot) {
                              int unseenCount = snapshot.hasData
                                  ? snapshot.data!.docs.length
                                  : 0;

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.notifications,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              NotificationsPage(
                                                userData: widget.userData,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (unseenCount > 0)
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Text(
                                          unseenCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.account_circle,
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      Profilepage(userData: widget.userData),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Content area with padding
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          /// New firstcard - date and calendar
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.white, // Solid white background
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Left-aligned date with outline stroke
                                  Stack(
                                    children: [
                                      // Filled text (on top)
                                      Text(
                                        _getFormattedDate(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Colors.black, // Main text color
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Right-aligned calendar button with outlined icon
                                  IconTheme(
                                    data: IconThemeData(
                                      color: Colors.black, // Main icon color
                                      shadows: [
                                        Shadow(
                                          blurRadius: 1.5, // Slight glow effect
                                          offset: const Offset(1, 1),
                                          color: Colors.black, // Outline color
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.calendar_today),
                                      onPressed: () async {
                                        SharedPreferences prefs =
                                            await SharedPreferences.getInstance();
                                        String? lastPage =
                                            prefs.getString(
                                              "lastCalendarPage",
                                            ) ??
                                            "Calendarmood";

                                        Widget targetPage =
                                            lastPage == "Calendaremotion"
                                            ? Calendaremotion(
                                                userData: widget.userData,
                                              )
                                            : Calendarmood(
                                                userData: widget.userData,
                                              );

                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder: (_, __, ___) =>
                                                targetPage,
                                            transitionsBuilder:
                                                (_, animation, __, child) =>
                                                    FadeTransition(
                                                      opacity: animation,
                                                      child: child,
                                                    ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          _buildRecentEmotionCard(),

                          const SizedBox(height: 16),

                          /// Second Card - Mood for the Day
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: latestMood == null
                                    ? LinearGradient(
                                        colors: [
                                          Color.fromARGB(255, 255, 255, 255),
                                          Color.fromARGB(255, 255, 255, 255),
                                        ], // Default gradient
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : LinearGradient(
                                        colors:
                                            cardGradientColors, // Firestore gradient colors
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      alignment: Alignment.centerLeft,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.mood,
                                              size: 22,
                                              color: Colors.green[900],
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Mood for the Day',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors
                                                    .black, // Always black
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    /// Change UI based on mood log availability
                                    Center(
  child: latestMood == null
      ? ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.white,
            fixedSize: const Size(72, 72),
          ),
          onPressed: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => LogMood(userData: widget.userData),
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
              ),
            );
          },
          child: Icon(
            Icons.add,
            size: 36,
            color: Colors.green[900],
          ),
        )
      : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (latestMoodImage != null) // 👈 display the image
              Image.asset(
                latestMoodImage!,
                height: 180,
                width: 180,
                fit: BoxFit.contain,
              ),
            const SizedBox(height: 8),
            Text(
              latestMood!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
),

                                    const SizedBox(height: 12),

                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: GestureDetector(
                                        onTap: () {
                                          // Show the MoodLogDialog when 'See More' is clicked, using the current date
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return Seemoremood(
                                                userData: widget.userData,
                                                selectedDate:
                                                    DateTime.now(), // Always pass the current date
                                              );
                                            },
                                          );
                                        },
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Text(
                                              'See More',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                // Modified conditional color logic:
                                                // Keep text grey for null or "Positive" mood, otherwise make it white
                                                color:
                                                    (latestMood == null ||
                                                        latestMood ==
                                                            "Positive")
                                                    ? Colors.grey[700]
                                                    : Colors.white,
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
                          ),

                          const SizedBox(height: 16),

                          /// new thirdcard - emotionLogs
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            child: StreamBuilder<QuerySnapshot>(
                              stream: _emotionLogsStream,
                              builder: (context, snapshot) {
                                // Default values when waiting or no data
                                List<Map<String, dynamic>> currentLogs = [];
                                bool hasMultipleLogs = false;

                                // Update values if we have data
                                if (snapshot.hasData) {
                                  currentLogs = snapshot.data!.docs
                                      .map(
                                        (doc) =>
                                            doc.data() as Map<String, dynamic>,
                                      )
                                      .toList();
                                  hasMultipleLogs = currentLogs.length >= 2;
                                }

                                // Calculate gradient from the current logs
                                Gradient cardGradient = _getEmotionGradient(
                                  currentLogs,
                                );

                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: cardGradient,
                                  ),
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Outlined "Emotion Logs:" Text
                                      Stack(
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.sentiment_satisfied_alt,
                                                size: 22,
                                                color: Colors.green[900],
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                "Emotion Logs:",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors
                                                      .black, // Outline color
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Emotion Buttons
                                      Center(
                                        child:
                                            snapshot.connectionState ==
                                                ConnectionState.waiting
                                            ? CircularProgressIndicator()
                                            : Wrap(
                                                spacing: 12,
                                                runSpacing: 12,
                                                alignment: WrapAlignment.center,
                                                children:
                                                    _buildEmotionButtonsFromLogs(
                                                      currentLogs,
                                                      MediaQuery.of(
                                                            context,
                                                          ).size.width *
                                                          0.18,
                                                    ),
                                              ),
                                      ),
                                      const SizedBox(height: 16),

                                      // Outlined "See More" Text Button
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: GestureDetector(
                                          onTap: () {
                                            // Show the EmotionLogDialog when 'See More' is clicked, using the current date
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return Seemoreemotion(
                                                  userData: widget.userData,
                                                  selectedDate:
                                                      DateTime.now(), // Always pass the current date
                                                );
                                              },
                                            );
                                          },
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Text(
                                                'See More',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: hasMultipleLogs
                                                      ? Colors.white
                                                      : Colors
                                                            .grey[700], // Change to white only with 2+ logs
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEmotionButtonsFromLogs(
    List<Map<String, dynamic>> logs,
    double size,
  ) {
    List<Widget> buttons = [];

    for (int i = 0; i < logs.length && i < 4; i++) {
      final log = logs[i];
      final emotionTime = _formatTime(log['timestamp']);

      /// Get background color (default to grey if not available)
      Color bgColor = log['color'] != null
          ? _parseColor(log['color'])
          : Colors.grey[300]!;

      buttons.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 500),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background color circle
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bgColor,
                    ),
                    child: Center(
                      child: log['image'].toString().startsWith('assets/')
                          ? Image.asset(
                              log['image'],
                              width:
                                  size * 0.8, // smaller size to show full image
                              height: size * 0.8,
                              fit: BoxFit.contain,
                            )
                          : Image.network(
                              log['image'],
                              width: size * 0.8,
                              height: size * 0.8,
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            /// Emotion Name with Outline Effect (Centered)
            SizedBox(
              width: size,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Main Text
                    Text(
                      log['emotion'] ?? 'Emotion',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // Text color
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// Time Below Emotion Name with Outline Effect (Centered)
            SizedBox(
              width: size,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Main Text
                    Text(
                      emotionTime,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.normal,
                        color: Colors.white, // Text color
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    /// Add the "Log" button if less than 4
    if (logs.length < 4) {
      buttons.add(
        _buildCircleButton(context: context, icon: Icons.add, size: size),
      );
    }

    return buttons;
  }

  List<Widget> _buildEmotionButtons(double size) {
    return [
      StreamBuilder<QuerySnapshot>(
        stream: _emotionLogsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: size * 2 + 12, // Accommodate for the spacing
              height: size,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          List<Widget> buttons = [];

          if (snapshot.hasData) {
            emotionLogs = snapshot.data!.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList();

            hasMultipleEmotionLogs = emotionLogs.length >= 2;

            for (int i = 0; i < emotionLogs.length && i < 4; i++) {
              final log = emotionLogs[i];
              final emotionTime = _formatTime(log['timestamp']);

              // Get background color (default to grey if not available)
              Color bgColor = log['color'] != null
                  ? _parseColor(log['color'])
                  : Colors.grey[300]!;

              buttons.add(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background color circle
                          Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: bgColor,
                            ),
                            child: Center(
                              child:
                                  log['image'].toString().startsWith('assets/')
                                  ? Image.asset(
                                      log['image'],
                                      width: size * 0.8,
                                      height: size * 0.8,
                                      fit: BoxFit.contain,
                                    )
                                  : Image.network(
                                      log['image'],
                                      width: size * 0.8,
                                      height: size * 0.8,
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Emotion Name with Outline Effect (Centered)
                    SizedBox(
                      width: size,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Main Text
                            Text(
                              log['emotion'] ?? 'Emotion',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white, // Text color
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Time Below Emotion Name with Outline Effect (Centered)
                    SizedBox(
                      width: size,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Main Text
                            Text(
                              emotionTime,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.normal,
                                color: Colors.white, // Text color
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          }

          // Add the "Log" button if less than 4
          if (emotionLogs.length < 4) {
            buttons.add(
              _buildCircleButton(context: context, icon: Icons.add, size: size),
            );
          }

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: buttons,
          );
        },
      ),
    ];
  }

  /// Convert Hex String to Color

  String _getFormattedDate() {
    final now = DateTime.now();
    final formatter = DateFormat('EEEE, MMMM d, yyyy');
    return formatter.format(now);
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final dateTime = (timestamp as Timestamp).toDate();
    final formatter = DateFormat('h:mm a');
    return formatter.format(dateTime);
  }

  Widget _buildCircleButton({
    required BuildContext context,
    required IconData icon,
    required double size,
  }) {
    return GestureDetector(
      onTap: () async {
        // Get current count of emotion logs from Firestore directly
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

        final snapshot = await FirebaseFirestore.instance
            .collection('emotionLogs')
            .where('studId', isEqualTo: widget.userData['studId'])
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where(
              'timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
            )
            .get();

        if (snapshot.docs.length >= 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can only log 4 emotions per day!'),
            ),
          );
          return;
        }

        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => LogEmotion(userData: widget.userData),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );

        // No need to call _fetchEmotionLogs() anymore as we're using a stream
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white, // Circle color
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                0.2,
              ), // Shadow color with transparency
              blurRadius: 1, // Softness of the shadow
              spreadRadius: 1, // How much the shadow spreads
              offset: const Offset(0, 1), // Position of the shadow
            ),
          ],
        ),
        child: Icon(icon, color: Colors.green[900], size: size * 0.5),
      ),
    );
  }

  Widget _buildRecentEmotionCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 255, 255, 255),
              Color.fromARGB(255, 255, 255, 255),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_emotions, size: 22, color: Colors.green[900]),
                SizedBox(width: 8),
                Text(
                  'Recent Emotion',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // StreamBuilder HERE
            StreamBuilder<DocumentSnapshot?>(
              stream: _recentEmotionStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final doc = snapshot.data;

                if (!snapshot.hasData || doc == null) {
                  return Center(
                    child: Column(
                      children: [
                        Text(
                          'No emotion logs today',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.white,
                            fixedSize: const Size(60, 60),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) =>
                                    LogEmotion(userData: widget.userData),
                                transitionsBuilder: (_, animation, __, child) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.add,
                            size: 30,
                            color: Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final emotionData = doc.data() as Map<String, dynamic>;

                return Center(
                  child: Column(
                    children: [
                      // Image without circular shape
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: _buildEmotionImage(
                          emotionData['image'],
                          200,
                          200,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        emotionData['emotion'] ?? 'Unknown Emotion',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _parseColor(
                            emotionData['color'] ?? 'FF999999',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        _getTimeAgo(
                          (emotionData['timestamp'] as Timestamp).toDate(),
                        ),
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  // Helper method to build emotion image based on path type
  Widget _buildEmotionImage(String? imagePath, double width, double height) {
    if (imagePath == null || imagePath.isEmpty) {
      return Container(color: Colors.grey[300]);
    }

    // Check if it's an asset path
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading asset image: $error');
          return Icon(
            Icons.image_not_supported,
            size: width * 0.5,
            color: Colors.white,
          );
        },
      );
    }
    // Check if it's a file path
    else if (imagePath.startsWith('file:///') || imagePath.startsWith('/')) {
      try {
        return Image.file(
          File(imagePath.replaceFirst('file://', '')),
          fit: BoxFit.cover,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading file image: $error');
            return Icon(
              Icons.image_not_supported,
              size: width * 0.5,
              color: Colors.white,
            );
          },
        );
      } catch (e) {
        print('Exception while loading file: $e');
        return Icon(
          Icons.image_not_supported,
          size: width * 0.5,
          color: Colors.white,
        );
      }
    }
    // Assume it's a network URL
    else {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading network image: $error');
          return Icon(
            Icons.image_not_supported,
            size: width * 0.5,
            color: Colors.white,
          );
        },
      );
    }
  }

  void _showConsentDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Consent for Monitoring",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "We kindly ask for your consent to allow the guidance counselor "
                "to view your logged moods and emotions, including your notes.\n\n"
                "The purpose is to provide better support and understanding of your well-being. "
                "Your participation is voluntary, and your choice will always be respected.",
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                "You can change this anytime in your Profile page.",
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () async {
              if (widget.userData != null &&
                  widget.userData['studId'] != null) {
                print(
                  "🔍 Searching for user with studId = ${widget.userData['studId']}",
                );

                final query = await FirebaseFirestore.instance
                    .collection("Users")
                    .where("studId", isEqualTo: widget.userData['studId'])
                    .limit(1)
                    .get();

                print("📊 Query result count: ${query.docs.length}");

                if (query.docs.isNotEmpty) {
                  final docId = query.docs.first.id;
                  print("✅ Found user docId: $docId");

                  await query.docs.first.reference.update({"consent": false});
                  print("📝 Updated consent=false for $docId");
                } else {
                  print("❌ No matching user found for studId");
                }
              } else {
                print("⚠️ widget.userData or studId is null");
              }
              Navigator.pop(context);
            },
            child: const Text("Turn Off"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (widget.userData != null &&
                  widget.userData['studId'] != null) {
                print(
                  "🔍 Searching for user with studId = ${widget.userData['studId']}",
                );

                final query = await FirebaseFirestore.instance
                    .collection("Users")
                    .where("studId", isEqualTo: widget.userData['studId'])
                    .limit(1)
                    .get();

                print("📊 Query result count: ${query.docs.length}");

                if (query.docs.isNotEmpty) {
                  final docId = query.docs.first.id;
                  print("✅ Found user docId: $docId");

                  await query.docs.first.reference.update({"consent": true});
                  print("📝 Updated consent=true for $docId");
                } else {
                  print("❌ No matching user found for studId");
                }
              } else {
                print("⚠️ widget.userData or studId is null");
              }
              Navigator.pop(context);
            },
            child: const Text("Turn On"),
          ),
        ],
      ),
    );
  }
}
