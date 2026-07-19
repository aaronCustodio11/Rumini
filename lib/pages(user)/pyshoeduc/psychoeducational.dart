import 'package:rumini/components/add_post.dart';
import 'package:rumini/model/post_model.dart';
import 'package:rumini/pages(user)/notifications/notif.dart';
import 'package:rumini/pages(user)/pyshoeduc/psycho_detailed.dart';
import 'package:rumini/profilePage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class Psychoeducational extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const Psychoeducational({super.key, required this.userData});

  @override
  State<Psychoeducational> createState() => _PsychoeducationalState();
}

class _PsychoeducationalState extends State<Psychoeducational> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  Stream<QuerySnapshot>? _postsStream;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initPostsStream();
  }

  void _initPostsStream() {
    // Query all posts in the collection without filtering by user
    _postsStream = FirebaseFirestore.instance
        .collection('psychoeduc_ads')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Method to get a valid image URL from Firebase Storage
  Future<String> _getValidImageUrl(String url) async {
    if (url.isEmpty) return '';

    try {
      // If it's already a download URL with http/https
      if (url.startsWith('http')) {
        // Add a cache buster for web
        if (kIsWeb) {
          if (url.contains('?')) {
            return '$url&_cb=${DateTime.now().millisecondsSinceEpoch}';
          } else {
            return '$url?_cb=${DateTime.now().millisecondsSinceEpoch}';
          }
        }
        return url;
      }

      // For gs:// URLs or storage paths
      final ref = url.startsWith('gs://')
          ? FirebaseStorage.instance.refFromURL(url)
          : FirebaseStorage.instance.ref(url);

      // Get download URL with token for web
      final downloadUrl = await ref.getDownloadURL();

      // For web, ensure we have a token
      if (kIsWeb) {
        if (downloadUrl.contains('?')) {
          return '$downloadUrl&_cb=${DateTime.now().millisecondsSinceEpoch}';
        } else {
          return '$downloadUrl?_cb=${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      return downloadUrl;
    } catch (e) {
      print('ERROR getting download URL: $e');
      return '';
    }
  }

  // Navigate to post details page instead of showing dialog
  void _navigateToPostDetails(PsychoeducPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailsPage(
          post: post,
          getValidImageUrl: _getValidImageUrl,
          userData: widget.userData,
        ),
      ),
    );
  }

  // Calculate the number of grid columns based on screen width
  int _calculateColumnCount(double width) {
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    // Define our green color constant for consistent use
    final Color primaryGreen = const Color(0xFF1B5E20);

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
                        'Psychoeducational',
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
                                .where(
                                  'studId',
                                  isEqualTo: widget.userData?['studId'],
                                )
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
                SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: Colors.grey[700]),
                        decoration: InputDecoration(
                          hintText: 'Search posts...',
                          hintStyle: TextStyle(color: Colors.grey),
                          prefixIcon: Icon(Icons.search, color: primaryGreen),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: BorderSide(
                              color: primaryGreen,
                              width: 2.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                            borderSide: BorderSide(
                              color: Colors.green[300]!,
                              width: 2.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0.0,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: primaryGreen),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 5),
                // Main content with white background and rounded corners
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Posts display section - Pinterest style
                              Expanded(
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: _postsStream,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text('Error: ${snapshot.error}'),
                                      );
                                    }

                                    if (!snapshot.hasData ||
                                        snapshot.data!.docs.isEmpty) {
                                      return const Center(
                                        child: Text(
                                          'No posts found. Create your first post!',
                                        ),
                                      );
                                    }

                                    // Filter posts based on search query
                                    final filteredDocs = snapshot.data!.docs
                                        .where((doc) {
                                          if (_searchQuery.isEmpty) return true;

                                          final data =
                                              doc.data()
                                                  as Map<String, dynamic>;
                                          final title =
                                              (data['title'] as String)
                                                  .toLowerCase();
                                          final description =
                                              (data['description'] as String)
                                                  .toLowerCase();
                                          final tags =
                                              (data['tags'] as List<dynamic>?)
                                                  ?.map(
                                                    (tag) => tag
                                                        .toString()
                                                        .toLowerCase(),
                                                  )
                                                  .toList() ??
                                              [];

                                          return title.contains(_searchQuery) ||
                                              description.contains(
                                                _searchQuery,
                                              ) ||
                                              tags.any(
                                                (tag) =>
                                                    tag.contains(_searchQuery),
                                              );
                                        })
                                        .toList();

                                    if (filteredDocs.isEmpty) {
                                      return const Center(
                                        child: Text(
                                          'No posts match your search criteria.',
                                        ),
                                      );
                                    }

                                    // Convert docs to post objects with likedBy field
                                    final posts = filteredDocs
                                        .map(
                                          (doc) =>
                                              PsychoeducPost.fromFirestore(doc),
                                        )
                                        .toList();

                                    // Calculate number of columns based on screen width
                                    return LayoutBuilder(
                                      builder: (context, constraints) {
                                        final columnCount =
                                            _calculateColumnCount(
                                              constraints.maxWidth,
                                            );

                                        return MasonryGridView.count(
                                          crossAxisCount: columnCount,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          itemCount: posts.length,
                                          itemBuilder: (context, index) {
                                            final post = posts[index];
                                            return PinterestStyleCard(
                                              post: post,
                                              getValidImageUrl:
                                                  _getValidImageUrl,
                                              onTap: () =>
                                                  _navigateToPostDetails(post),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Global loading indicator
                        if (_isLoading)
                          Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Pinterest style card component with hover effects
class PinterestStyleCard extends StatefulWidget {
  final PsychoeducPost post;
  final Future<String> Function(String) getValidImageUrl;
  final VoidCallback onTap;

  const PinterestStyleCard({
    required this.post,
    required this.getValidImageUrl,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  State<PinterestStyleCard> createState() => _PinterestStyleCardState();
}

class _PinterestStyleCardState extends State<PinterestStyleCard> {
  bool _isHovering = false;
  String? _cachedImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Pre-load image URL to avoid reloading on hover
    if (widget.post.imageUrl.isNotEmpty) {
      widget.getValidImageUrl(widget.post.imageUrl).then((url) {
        if (mounted) {
          setState(() {
            _cachedImageUrl = url;
            _isLoading = false;
          });
        }
      });
    } else {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format the date for display
    final formattedDate = DateFormat(
      'MMM d, yyyy',
    ).format(widget.post.createdAt);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovering
            ? Matrix4.translationValues(0.0, -5.0, 0.0)
            : Matrix4.identity(),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: _isHovering ? 8 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with overlay
                if (widget.post.imageUrl.isNotEmpty)
                  Stack(
                    children: [
                      // Image - using cached URL to avoid reload on hover
                      _isLoading
                          ? AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            )
                          : _cachedImageUrl == null || _cachedImageUrl!.isEmpty
                          ? AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(Icons.image_not_supported),
                                ),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: _cachedImageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (context, url) => AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) {
                                return AspectRatio(
                                  aspectRatio: 4 / 3,
                                  child: Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(
                                        Icons.error,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                      // Hover overlay with animation
                      if (_isHovering)
                        Positioned.fill(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _isHovering ? 0.2 : 0,
                            child: Container(
                              color: Theme.of(context).colorScheme.primary,
                              child: Center(
                                child: Icon(
                                  Icons.touch_app,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                // Info section with title, likes and date
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        widget.post.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Row with likes and date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Likes counter
                          Row(
                            children: [
                              const Icon(
                                Icons.favorite,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text('${widget.post.currentLikes}'),
                            ],
                          ),

                          // Date
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
        ),
      ),
    );
  }
}
