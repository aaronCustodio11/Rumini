import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'dart:ui';

class LogMood extends StatefulWidget {
  final Map<String, dynamic> userData;
  const LogMood({super.key, required this.userData});

  @override
  State<LogMood> createState() => _LogMoodState();
}

class _LogMoodState extends State<LogMood> with SingleTickerProviderStateMixin {
  // Define the moods with their properties
  final List<Map<String, dynamic>> moods = [
    {
      'name': 'Negative',
      'image': 'assets/images/negative.png', // Add appropriate images
      'colors': [
        Color.lerp(Colors.red[900], Colors.red, 0)!,
        Color.lerp(Colors.red, Colors.white, 0)!,
      ],
    },
    {
      'name': 'Neutral',
      'image': 'assets/images/neutral.png',
      'colors': [Colors.black38, Colors.grey[300]!],
    },
    {
      'name': 'Positive',
      'image': 'assets/images/positive.png',
      'colors': [
        Color.lerp(Colors.greenAccent[700]!, Colors.white, 0.5)!,
        Color.lerp(Colors.greenAccent[700]!, Colors.white, 0.9)!,
      ],
    },
  ];

  // Display colors for the cards (darker version)
  final List<List<Color>> displayColors = [
    [Colors.black, Colors.red],
    [Colors.black, Colors.grey[50]!],
    [Colors.greenAccent[700]!, Colors.white],
  ];

  String? selectedMood;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final TextEditingController _journalController = TextEditingController();
  final GlobalKey<SlideActionState> _slideActionKey = GlobalKey();
  PageController _pageController = PageController(
    initialPage: 1, // Start with Neutral (middle) mood
    viewportFraction: 0.85,
  );
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Listen to page changes for indicator updates
    _pageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _journalController.dispose();
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> saveMoodLog({
    required String? mood,
    required List<Color>? colors,
    required String? journal,
    required String? studId,
    required String? image, // 👈 add this
  }) async {
    try {
      if (mood == null || colors == null || studId == null || image == null) {
        print("Error: One or more required fields are null.");
        return;
      }

      await FirebaseFirestore.instance.collection('moodLogs').add({
        'mood': mood,
        'image': image, // 👈 save image path
        'color': colors
            .map((c) => c.value.toRadixString(16).padLeft(8, '0'))
            .toList(),
        'journal': journal?.isEmpty == true ? "No journal entry" : journal,
        "timestamp": FieldValue.serverTimestamp(),
        'studId': studId,
      });

      print("Mood log saved successfully!");
    } catch (e) {
      print("Error saving mood log: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 360;
    final bool isLargeScreen = screenSize.width > 600;

    // Adjust dimensions based on screen size
    final double headerFontSize = isSmallScreen
        ? 24
        : isLargeScreen
        ? 32
        : 28;
    final double subHeaderFontSize = isSmallScreen
        ? 14
        : isLargeScreen
        ? 18
        : 16;
    final double carouselHeight = isSmallScreen
        ? 180
        : isLargeScreen
        ? 240
        : 200;
    final double iconSize = isSmallScreen
        ? 65
        : isLargeScreen
        ? 95
        : 80;
    final double horizontalPadding = isSmallScreen
        ? 15
        : isLargeScreen
        ? 30
        : 20;

    // Determine background colors based on selected mood
    List<Color> gradientColors = selectedMood != null
        ? [
            moods
                .firstWhere((e) => e['name'] == selectedMood)['colors'][0]
                .withOpacity(0.2 + (_animation.value * 0.2)),
            Colors.white.withOpacity(0.9),
            moods
                .firstWhere((e) => e['name'] == selectedMood)['colors'][1]
                .withOpacity(0.1 + (_animation.value * 0.1)),
          ]
        : [
            Colors.blue.withOpacity(0.05),
            Colors.white,
            Colors.purple.withOpacity(0.05),
          ];

    // Adjust viewport fraction based on screen size
    if (_pageController.hasClients) {
      if (isSmallScreen && _pageController.viewportFraction != 0.9) {
        _pageController.dispose();
        final PageController newController = PageController(
          viewportFraction: 0.9,
        );
        Future.microtask(
          () => setState(() {
            _pageController = newController;
          }),
        );
      } else if (isLargeScreen && _pageController.viewportFraction != 0.5) {
        _pageController.dispose();
        final PageController newController = PageController(
          viewportFraction: 0.5,
        );
        Future.microtask(
          () => setState(() {
            _pageController = newController;
          }),
        );
      } else if (!isSmallScreen &&
          !isLargeScreen &&
          _pageController.viewportFraction != 0.85) {
        _pageController.dispose();
        final PageController newController = PageController(
          viewportFraction: 0.85,
        );
        Future.microtask(
          () => setState(() {
            _pageController = newController;
          }),
        );
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: _isSaving ? Colors.grey : Colors.black87, // 🆕
            ),
          ),
          onPressed: _isSaving
              ? null
              : () => Navigator.pop(context), // 🆕 disable if saving
        ),

        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return AnimatedContainer(
            // Animate background color changes
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            // Make sure container fills entire available space
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
            child: SafeArea(
              // Make SafeArea maintain full screen width/height
              bottom: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: constraints.maxHeight * 0.02),
                          Text(
                            "How are you feeling today?",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: headerFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              shadows: [
                                Shadow(
                                  color: Colors.white.withOpacity(0.5),
                                  offset: const Offset(0, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.015),
                          Text(
                            "Select the mood that best describes how you feel",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: subHeaderFontSize,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.03),

                          // Mood Carousel - Responsive height
                          SizedBox(
                            height: carouselHeight,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: moods.length,
                              physics: const BouncingScrollPhysics(),
                              itemBuilder: (context, index) {
                                final mood = moods[index];
                                final bool isSelected =
                                    selectedMood == mood['name'];

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedMood = mood['name'];
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: EdgeInsets.symmetric(
                                      horizontal: constraints.maxWidth * 0.02,
                                      vertical: constraints.maxHeight * 0.01,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isSelected
                                              ? mood['colors'][0].withOpacity(
                                                  0.3,
                                                )
                                              : Colors.black12,
                                          blurRadius: isSelected ? 12 : 5,
                                          spreadRadius: isSelected ? 2 : 0,
                                        ),
                                      ],
                                      border: Border.all(
                                        color: isSelected
                                            ? mood['colors'][0]
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          mood['name'] == 'Negative'
                                              ? 'assets/images/negative.png'
                                              : mood['name'] == 'Neutral'
                                              ? 'assets/images/neutral.png'
                                              : 'assets/images/positive.png',
                                          height: isSelected
                                              ? iconSize * 1.5
                                              : iconSize * 1.3,
                                          width: isSelected
                                              ? iconSize * 1.5
                                              : iconSize * 1.3,
                                          fit: BoxFit.contain,
                                        ),
                                        SizedBox(
                                          height: constraints.maxHeight * 0.01,
                                        ),
                                        Text(
                                          mood['name'],
                                          style: TextStyle(
                                            fontSize: isSelected
                                                ? subHeaderFontSize * 1.1
                                                : subHeaderFontSize,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Mood Selection Indicator
                          SizedBox(height: constraints.maxHeight * 0.015),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              moods.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                height: 8,
                                width:
                                    _pageController.hasClients &&
                                        _pageController.page!.round() == index
                                    ? 20
                                    : 8,
                                decoration: BoxDecoration(
                                  color:
                                      _pageController.hasClients &&
                                          _pageController.page!.round() == index
                                      ? selectedMood != null
                                            ? moods.firstWhere(
                                                (e) =>
                                                    e['name'] == selectedMood,
                                              )['colors'][0]
                                            : Colors.blueGrey
                                      : Colors.grey.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),

                          // Journal Section - Responsive sizing
                          AnimatedSize(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            child: selectedMood != null
                                ? Container(
                                    margin: EdgeInsets.only(
                                      top: constraints.maxHeight * 0.03,
                                    ),
                                    padding: EdgeInsets.all(
                                      constraints.maxWidth * 0.05,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Why do you feel ${selectedMood?.toLowerCase()}?",
                                          style: TextStyle(
                                            fontSize: subHeaderFontSize * 1.1,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        SizedBox(
                                          height: constraints.maxHeight * 0.005,
                                        ),
                                        Text(
                                          "Express yourself freely. This helps track your mood patterns.",
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 12 : 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        SizedBox(
                                          height: constraints.maxHeight * 0.015,
                                        ),
                                        TextField(
                                          controller: _journalController,
                                          decoration: InputDecoration(
                                            hintText: "Start typing here...",
                                            hintStyle: TextStyle(
                                              color: Colors.grey.shade400,
                                            ),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal:
                                                      constraints.maxWidth *
                                                      0.04,
                                                  vertical:
                                                      constraints.maxHeight *
                                                      0.02,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              borderSide: BorderSide(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              borderSide: BorderSide(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              borderSide: BorderSide(
                                                color: moods.firstWhere(
                                                  (e) =>
                                                      e['name'] == selectedMood,
                                                )['colors'][0],
                                                width: 2,
                                              ),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                          ),
                                          maxLines: isSmallScreen ? 3 : 4,
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 14 : 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // Submit Button - Responsive sizing
                          if (selectedMood != null) ...[
                            SizedBox(height: constraints.maxHeight * 0.03),
                            Container(
                              margin: EdgeInsets.only(
                                bottom: constraints.maxHeight * 0.02,
                              ),
                              width: isLargeScreen
                                  ? constraints.maxWidth * 0.7
                                  : constraints.maxWidth,
                              child: SlideAction(
                                key: _slideActionKey,
                                onSubmit: () async {
  if (selectedMood != null && widget.userData != null) {
    setState(() {
      _isSaving = true; // 🆕 lock UI
    });

    final moodData = moods.firstWhere(
      (e) => e['name'] == selectedMood,
      orElse: () => {},
    );
    String? studId = widget.userData['studId'];

    // Show saving indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 15),
            const Text('Saving your mood...'),
          ],
        ),
        backgroundColor: moodData.isNotEmpty
            ? moodData['colors'][0]
            : Colors.blueGrey,
        duration: const Duration(seconds: 1),
      ),
    );

    // Perform save
    await saveMoodLog(
      mood: selectedMood!,
      colors: moodData.isNotEmpty
          ? moodData['colors']
          : [Colors.grey, Colors.grey.shade300],
      journal: _journalController.text.trim().isEmpty
          ? "No journal entry"
          : _journalController.text.trim(),
      studId: studId ?? "Unknown",
      image: moodData['image'],
    );

    // Wait a bit then navigate back
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _isSaving = false; // 🆕 unlock before exit
        });
        Navigator.pop(context);
      }
    });
  } else {
    print("Error: Mood or user data is missing.");
    _slideActionKey.currentState?.reset();
  }
},

                                text: "Slide to submit",
                                textStyle: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: selectedMood != null
                                      ? moods.firstWhere(
                                          (e) => e['name'] == selectedMood,
                                        )['colors'][0]
                                      : Colors.white70,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                                outerColor: Colors.white,
                                innerColor: selectedMood != null
                                    ? moods.firstWhere(
                                        (e) => e['name'] == selectedMood,
                                      )['colors'][0]
                                    : Colors.grey.shade400,
                                sliderButtonIcon: const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                ),
                                borderRadius: 12,
                                elevation: 5,
                                height: isSmallScreen ? 50 : 60,
                                sliderRotate: false,
                                submittedIcon: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                          ] else ...[
                            SizedBox(height: constraints.maxHeight * 0.04),
                            Text(
                              "Select a mood to continue",
                              style: TextStyle(
                                fontSize: subHeaderFontSize,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            SizedBox(height: constraints.maxHeight * 0.02),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
