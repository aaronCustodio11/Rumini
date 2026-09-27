import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DynamicGreetingCard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DynamicGreetingCard({super.key, required this.userData});

  @override
  State<DynamicGreetingCard> createState() => _DynamicGreetingCardState();
}

class _DynamicGreetingCardState extends State<DynamicGreetingCard> {
  late VideoPlayerController _controller;
  String _greeting = '';
  String _videoAsset = '';
  String _fullName = 'Loading...';
  String _role = '';
  bool _isLoadingName = true;

  @override
  void initState() {
    super.initState();
    _setGreetingByTime();
    _initializeVideo();
    _fetchFullName();
  }

  void _setGreetingByTime() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      _greeting = 'Good Morning';
      _videoAsset = 'assets/videos/morning.mp4';
    } else if (hour >= 12 && hour < 18) {
      _greeting = 'Good Afternoon';
      _videoAsset = 'assets/videos/afternoon.mp4';
    } else {
      _greeting = 'Good Evening';
      _videoAsset = 'assets/videos/night.mp4';
    }
  }

  void _initializeVideo() {
    _controller = VideoPlayerController.asset(_videoAsset)
      ..initialize().then((_) {
        setState(() {});
        _controller.setLooping(true);
        _controller.play();
      });
  }

  Future<void> _fetchFullName() async {
    try {
      // Get counId from userData
      final counId = widget.userData['counId'];
      
      if (counId == null) {
        setState(() {
          _fullName = 'User';
          _isLoadingName = false;
        });
        return;
      }

      // Query Users collection where counId matches
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('counId', isEqualTo: counId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first.data();
        
        // Extract name fields and role
        final firstName = userDoc['firstName'] ?? '';
        final middleName = userDoc['middleName'] ?? '';
        final lastName = userDoc['lastName'] ?? '';
        final extensionName = userDoc['extensionName'] ?? '';
        final role = userDoc['role'] ?? ''; // Get role from Users collection

        // Get middle initial (first letter of middle name + period)
        String middleInitial = '';
        if (middleName.isNotEmpty) {
          middleInitial = '${middleName[0]}.';
        }

        // Format full name with middle initial
        String formattedName = firstName;
        
        if (middleInitial.isNotEmpty) {
          formattedName += ' $middleInitial';
        }
        
        if (lastName.isNotEmpty) {
          formattedName += ' $lastName';
        }
        
        if (extensionName.isNotEmpty) {
          formattedName += ' $extensionName';
        }

        setState(() {
          _role = role; // Store the role from Users collection
          _fullName = formattedName.trim().isEmpty ? 'User' : formattedName.trim();
          _isLoadingName = false;
        });
      } else {
        setState(() {
          _role = '';
          _fullName = 'User';
          _isLoadingName = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching full name: $e');
      setState(() {
        _role = '';
        _fullName = 'User';
        _isLoadingName = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            /// Video Animation
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF345F00),
                        ),
                      ),
              ),
            ),

            const SizedBox(width: 24),

            /// Greeting Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _greeting,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF345F00),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _isLoadingName
                      ? const SizedBox(
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF345F00),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_role.isNotEmpty)
                              Text(
                                _role,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF345F00),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            if (_role.isNotEmpty) const SizedBox(height: 4),
                            Text(
                              _fullName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}