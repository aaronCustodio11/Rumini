import 'package:rumini/components/add_post.dart';
import 'package:rumini/components/sidebar.dart';
import 'package:rumini/model/post_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class PsychoeducAd extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const PsychoeducAd({super.key, required this.userData});

  @override
  State<PsychoeducAd> createState() => _PsychoeducAdState();
}

class _PsychoeducAdState extends State<PsychoeducAd> {
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
    // Get current user's counId
    final String? counId = widget.userData?['counId'];

    if (counId != null) {
      // Query for posts with the current user's counId
      _postsStream = FirebaseFirestore.instance
          .collection('psychoeduc_ads')
          .where('counId', isEqualTo: counId)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      // Fallback if no user data
      _postsStream = FirebaseFirestore.instance
          .collection('psychoeduc_ads')
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  // Updated method to show add dialog using PsychoeducDialog
  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return PsychoeducDialog(
          userData: widget.userData ?? {'counId': 'unknown'},
          onPostChanged: () {
            // Refresh posts after adding a new one
            setState(() {
              _initPostsStream();
            });
          },
          // No existingPost parameter - this indicates we're adding a new post
        );
      },
    );
  }

  // New method to show edit dialog using PsychoeducDialog
  void _showEditDialog(Map<String, dynamic> postData) {
    showDialog(
      context: context,
      builder: (context) {
        return PsychoeducDialog(
          userData: widget.userData ?? {'counId': 'unknown'},
          onPostChanged: () {
            // Refresh posts after editing
            setState(() {
              _initPostsStream();
            });
          },
          existingPost: postData, // Pass the existing post data for editing
        );
      },
    );
  }

Future<void> _deletePost(String postId, String imageUrl) async {
  try {
    setState(() => _isLoading = true);

    // Delete Firestore doc
    await FirebaseFirestore.instance
        .collection('psychoeduc_ads')
        .doc(postId)
        .delete();

    // Delete Storage image
    if (imageUrl.isNotEmpty) {
      try {
        Reference ref = _getStorageRefFromUrl(imageUrl);
        await ref.delete();
      } catch (e) {
        print("Error deleting image from storage: $e");
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Post deleted successfully")),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error deleting post: $e")),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

Reference _getStorageRefFromUrl(String imageUrl) {
  // Case 1: already a gs:// URL
  if (imageUrl.startsWith("gs://")) {
    return FirebaseStorage.instance.refFromURL(imageUrl);
  }

  // Case 2: raw path (not a URL)
  if (!imageUrl.startsWith("http")) {
    return FirebaseStorage.instance.ref(imageUrl);
  }

  // Case 3: normal download URL with `psychoeduc_ads%2FpostId.jpg?alt=media...`
  // Remove cache-buster or extra params
  final cleanUrl = imageUrl.split('&').first.split('?').first;

  final uri = Uri.parse(cleanUrl);
  final encodedFullPath = uri.pathSegments.last; // psychoeduc_ads%2Fabc123.jpg
  
  final decodedPath = Uri.decodeComponent(encodedFullPath); // psychoeduc_ads/abc123.jpg

  return FirebaseStorage.instance.ref(decodedPath);
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

  // Updated method to handle likes with likedBy array
  Future<void> _toggleLike(String postId, int currentLikes, List<String> likedBy) async {
    try {
      // Get current user's ID
      final String? userId = widget.userData?['uid'] as String?;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to like: User not logged in')),
        );
        return;
      }

      // Check if user already liked this post
      if (likedBy.contains(userId)) {
        // User already liked, remove the like
        likedBy.remove(userId);
        await FirebaseFirestore.instance
            .collection('psychoeduc_ads')
            .doc(postId)
            .update({
          'likedBy': likedBy,
          'currentLikes': likedBy.length, // Update count based on array length
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Like removed')),
        );
      } else {
        // User hasn't liked, add the like
        likedBy.add(userId);
        await FirebaseFirestore.instance
            .collection('psychoeduc_ads')
            .doc(postId)
            .update({
          'likedBy': likedBy,
          'currentLikes': likedBy.length, // Update count based on array length
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post liked!')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating likes: $error')),
      );
    }
  }

  // Method to show post details dialog
  void _showPostDetails(PsychoeducPost post) {
    // Convert the PsychoeducPost to Map<String, dynamic> for edit functionality
    final Map<String, dynamic> postData = {
      'postId': post.id,
      'counId': post.counId,
      'title': post.title,
      'description': post.description,
      'tags': post.tags,
      'image': post.imageUrl,
      'currentLikes': post.currentLikes,
      'likedBy': post.likedBy,
      'createdAt': post.createdAt,
    };

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: PostDetailsDialog(
          post: post,
          getValidImageUrl: _getValidImageUrl,
          onToggleLike: _toggleLike,
          onDelete: () => _deletePost(post.id, post.imageUrl),
          onEdit: () => _showEditDialog(postData),
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
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 232, 232, 232),
      body: Row(
        children: [
          Sidebar(userData: widget.userData ?? {}),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  title: Row(
                    children: [
                      Icon(Icons.psychology, color: Colors.green.shade900),
                      const SizedBox(width: 8),
                      Text(
                        'Psychoeducational Posts',
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color.fromARGB(255, 232, 232, 232),
                  elevation: 0,
                ),
                Expanded(
                  
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 100.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // First card with search bar and add post button
                            Card(
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    // Search bar - made shorter with more rounded borders
                                    Expanded(
                                      flex: 2, // Make search bar take less space
                                      child: TextField(
                                        controller: _searchController,
                                        decoration: InputDecoration(
                                          hintText: 'Search posts...',
                                          prefixIcon: const Icon(Icons.search),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(20.0), // More rounded borders
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 0.0),
                                          suffixIcon: _searchController
                                                  .text.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.clear),
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
                                    const SizedBox(width: 16),
                                    // Spacer to make search bar appear shorter
                                    Expanded(
                                      flex: 1,
                                      child: Container(),
                                    ),
                                    // Add post button
                                    ElevatedButton.icon(
                                      onPressed: _showAddDialog,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Post'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20.0), // More rounded button
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Posts display section - Pinterest style
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: _postsStream,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                        child: CircularProgressIndicator());
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
                                          'No posts found. Create your first post!'),
                                    );
                                  }

                                  // Filter posts based on search query
                                  final filteredDocs =
                                      snapshot.data!.docs.where((doc) {
                                    if (_searchQuery.isEmpty) return true;

                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final title =
                                        (data['title'] as String).toLowerCase();
                                    final description =
                                        (data['description'] as String)
                                            .toLowerCase();
                                    final tags = (data['tags']
                                                as List<dynamic>?)
                                            ?.map((tag) =>
                                                tag.toString().toLowerCase())
                                            .toList() ??
                                        [];

                                    return title.contains(_searchQuery) ||
                                        description.contains(_searchQuery) ||
                                        tags.any((tag) =>
                                            tag.contains(_searchQuery));
                                  }).toList();

                                  if (filteredDocs.isEmpty) {
                                    return const Center(
                                      child: Text(
                                          'No posts match your search criteria.'),
                                    );
                                  }

                                  // Convert docs to post objects with likedBy field
                                  final posts = filteredDocs
                                      .map((doc) =>
                                          PsychoeducPost.fromFirestore(doc))
                                      .toList();

                                  // Calculate number of columns based on screen width
                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      final columnCount = _calculateColumnCount(
                                          constraints.maxWidth);

                                      return MasonryGridView.count(
                                        crossAxisCount: columnCount,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        itemCount: posts.length,
                                        itemBuilder: (context, index) {
                                          final post = posts[index];
                                          return PinterestStyleCard(
                                            post: post,
                                            getValidImageUrl: _getValidImageUrl,
                                            onTap: () => _showPostDetails(post),
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
    final formattedDate =
        DateFormat('MMM d, yyyy').format(widget.post.createdAt);

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
                                    child: CircularProgressIndicator()),
                              ),
                            )
                          : _cachedImageUrl == null || _cachedImageUrl!.isEmpty
                              ? AspectRatio(
                                  aspectRatio: 1,
                                  child: Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                        child: Icon(Icons.image_not_supported)),
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
                                          child: CircularProgressIndicator()),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    return AspectRatio(
                                      aspectRatio: 4 / 3,
                                      child: Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(Icons.error,
                                              color: Colors.red),
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
                              const Icon(Icons.favorite,
                                  color: Colors.red, size: 16),
                              const SizedBox(width: 4),
                              Text('${widget.post.currentLikes}'),
                            ],
                          ),

                          // Date
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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

// Post details dialog component - Updated with likedBy support
class PostDetailsDialog extends StatelessWidget {
  final PsychoeducPost post;
  final Future<String> Function(String) getValidImageUrl;
  final Function(String, int, List<String>) onToggleLike;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Map<String, dynamic>? userData;

  const PostDetailsDialog({
    required this.post,
    required this.getValidImageUrl,
    required this.onToggleLike,
    required this.onDelete,
    required this.onEdit,
    required this.userData,
    Key? key,
  }) : super(key: key);

  // Check if current user has liked this post
  bool _hasUserLiked() {
    final String? userId = userData?['uid'] as String?;
    return userId != null && post.likedBy.contains(userId);
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat.yMMMd().add_jm().format(post.createdAt);
    final bool userLiked = _hasUserLiked();

    return Container(
      constraints: BoxConstraints(
        maxWidth: 900,
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      post.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable content area
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image if available
                    if (post.imageUrl.isNotEmpty)
                      FutureBuilder<String>(
                        future: getValidImageUrl(post.imageUrl),
                        builder: (context, urlSnapshot) {
                          if (urlSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return SizedBox(
                              height: 350,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final validUrl = urlSnapshot.data ?? '';
                          if (validUrl.isEmpty) {
                            return const SizedBox(
                              height: 250,
                              child: Center(
                                child: Text('Image unavailable'),
                              ),
                            );
                          }

                          return CachedNetworkImage(
                            imageUrl: validUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: MediaQuery.of(context).size.height * 0.5,
                            placeholder: (context, url) => const SizedBox(
                              height: 350,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) {
                              return const SizedBox(
                                height: 250,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.error,
                                          color: Colors.red, size: 40),
                                      SizedBox(height: 8),
                                      Text('Image failed to load'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                    // Content section
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Description
                          Text(
                            post.description,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 30),

                          // Tags section
                          if (post.tags.isNotEmpty) ...[
                            const Text(
                              'Tags',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: post.tags.map((tag) {
                                return Chip(
                                  label: Text(
                                    tag,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  labelStyle: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions footer
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Like button - now interactive
                  InkWell(
                    onTap: () {
                      onToggleLike(post.id, post.currentLikes, List<String>.from(post.likedBy));
                      Navigator.of(context).pop(); // Close dialog after action
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            userLiked ? Icons.favorite : Icons.favorite_border,
                            color: Colors.red,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${post.currentLikes} ${post.currentLikes == 1 ? 'like' : 'likes'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Action buttons
                  Row(
                    children: [
                      // Edit button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          // Close the details dialog first
                          Navigator.of(context).pop();
                          // Then show edit dialog
                          onEdit();
                        },
                      ),
                      const SizedBox(width: 12),
                      // Delete button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          // Close the details dialog first
                          Navigator.of(context).pop();
                          // Then delete the post
                          onDelete();
                        },
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