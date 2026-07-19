import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'dart:ui';

class LogEmotion extends StatefulWidget {
  final Map<String, dynamic> userData;
  const LogEmotion({super.key, required this.userData});

  @override
  State<LogEmotion> createState() => _LogEmotionState();
}

class _LogEmotionState extends State<LogEmotion>
    with SingleTickerProviderStateMixin {
  // Updated emotion order as requested
  final List<Map<String, dynamic>> emotions = [
    {
      'name': 'Joy',
      'image': 'assets/images/enjoyment.png',
      'color': const Color(0xFFE3AB2F),
    },
    {
      'name': 'Sad',
      'image': 'assets/images/sad.png',
      'color': const Color(0xFF2F5FA7),
    },
    {
      'name': 'Surprise',
      'image': 'assets/images/surprise.png',
      'color': const Color(0xFF3DA3A3),
    },
    {
      'name': 'Fear',
      'image': 'assets/images/fear.png',
      'color': const Color(0xFF563A88),
    },
    {
      'name': 'Disgusted',
      'image': 'assets/images/disgust.png',
      'color': const Color(0xFF4C913B),
    },
    {
      'name': 'Contempt',
      'image': 'assets/images/contempt.png',
      'color': const Color(0xFFB16645),
    },
    {
      'name': 'Angry',
      'image': 'assets/images/anger.png',
      'color': const Color(0xFFA2352D),
    },
  ];

  String? selectedEmotion;
  Color bgColor = Colors.white;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final TextEditingController _reasonController = TextEditingController();
  final GlobalKey<SlideActionState> _slideActionKey = GlobalKey();
  PageController _pageController = PageController(viewportFraction: 0.85);
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
    _reasonController.dispose();
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> saveEmotionLog({
    required String? emotion,
    required String? imagePath,
    required Color? color,
    required String? journal,
    required String? studId,
  }) async {
    try {
      if (emotion == null ||
          imagePath == null ||
          color == null ||
          journal == null ||
          studId == null) {
        print("Error: One or more required fields are null.");
        return;
      }

      await FirebaseFirestore.instance.collection('emotionLogs').add({
        'emotion': emotion,
        'color': color.value.toRadixString(16),
        'image': imagePath,
        'journal': journal.isEmpty ? "No journal entry" : journal,
        'timestamp': Timestamp.now(),
        'studId': studId,
      });

      print("Emotion log saved successfully!");
    } catch (e) {
      print("Error saving emotion log: $e");
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
        ? 160
        : isLargeScreen
        ? 220
        : 180;
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

    // Determine background colors based on selected emotion
    List<Color> gradientColors = selectedEmotion != null
        ? [
            emotions
                .firstWhere((e) => e['name'] == selectedEmotion)['color']
                .withOpacity(0.2 + (_animation.value * 0.2)),
            Colors.white.withOpacity(0.9),
            emotions
                .firstWhere((e) => e['name'] == selectedEmotion)['color']
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
      color: _isSaving ? Colors.grey : Colors.black87,
    ),
  ),
  onPressed: _isSaving ? null : () => Navigator.pop(context),
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
                            "Select the emotion that best describes how you feel",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: subHeaderFontSize,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.03),

                          // Emotion Carousel - Responsive height
                          SizedBox(
                            height: carouselHeight,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: emotions.length,
                              physics: const BouncingScrollPhysics(),
                              itemBuilder: (context, index) {
                                final emotion = emotions[index];
                                final bool isSelected =
                                    selectedEmotion == emotion['name'];

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedEmotion = emotion['name'];
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
                                              ? emotion['color'].withOpacity(
                                                  0.3,
                                                )
                                              : Colors.black12,
                                          blurRadius: isSelected ? 12 : 5,
                                          spreadRadius: isSelected ? 2 : 0,
                                        ),
                                      ],
                                      border: Border.all(
                                        color: isSelected
                                            ? emotion['color']
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          height: isSelected
                                              ? iconSize * 1.5
                                              : iconSize * 1.2,
                                          width: isSelected
                                              ? iconSize * 1.5
                                              : iconSize * 1.2,
                                          child: Image.asset(
                                            emotion['image'],
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade200,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            15,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.image_not_supported,
                                                      size: iconSize * 0.5,
                                                      color: Colors.grey,
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                        SizedBox(
                                          height: constraints.maxHeight * 0.01,
                                        ),
                                        Text(
                                          emotion['name'],
                                          style: TextStyle(
                                            fontSize: isSelected
                                                ? subHeaderFontSize * 1.1
                                                : subHeaderFontSize,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? emotion['color']
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Emotion Selection Indicator
                          SizedBox(height: constraints.maxHeight * 0.015),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              emotions.length,
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
                                      ? selectedEmotion != null
                                            ? emotions.firstWhere(
                                                (e) =>
                                                    e['name'] ==
                                                    selectedEmotion,
                                              )['color']
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
                            child: selectedEmotion != null
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
                                          "Why do you feel ${selectedEmotion?.toLowerCase()}?",
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
                                          "Express yourself freely. This helps track your emotional patterns.",
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 12 : 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        SizedBox(
                                          height: constraints.maxHeight * 0.015,
                                        ),
                                        TextField(
                                          controller: _reasonController,
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
                                                color: emotions.firstWhere(
                                                  (e) =>
                                                      e['name'] ==
                                                      selectedEmotion,
                                                )['color'],
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
                          if (selectedEmotion != null) ...[
                            SizedBox(height: constraints.maxHeight * 0.03),
                            Container(
                              margin: EdgeInsets.only(
                                bottom: constraints.maxHeight * 0.02,
                              ),
                              width: isLargeScreen
                                  ? constraints.maxWidth * 0.7
                                  : constraints.maxWidth,
                              child: // Replace the SlideAction widget with this updated version
                              SlideAction(
                                key: _slideActionKey,
                                onSubmit: () async {
  if (selectedEmotion != null && widget.userData != null) {
    setState(() {
      _isSaving = true;
    });

    final emotionData = emotions.firstWhere(
      (e) => e['name'] == selectedEmotion,
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
            const Text('Saving your emotions...'),
          ],
        ),
        backgroundColor: emotionData['color'],
        duration: const Duration(seconds: 1),
      ),
    );

    await saveEmotionLog(
      emotion: selectedEmotion!,
      imagePath: emotionData['image'],
      color: emotionData['color'],
      journal: _reasonController.text.trim().isEmpty
          ? "No journal entry"
          : _reasonController.text.trim(),
      studId: studId ?? "Unknown",
    );

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        Navigator.pop(context);
      }
    });
  } else {
    _slideActionKey.currentState?.reset();
  }
},

                                text: "Slide to submit",
                                textStyle: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                  // Adaptive text color based on the selected emotion
                                  color: selectedEmotion != null
                                      ? emotions.firstWhere(
                                          (e) => e['name'] == selectedEmotion,
                                        )['color']
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
                                innerColor: selectedEmotion != null
                                    ? emotions.firstWhere(
                                        (e) => e['name'] == selectedEmotion,
                                      )['color']
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
                              "Select an emotion to continue",
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
