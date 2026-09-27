import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rumini/model/post_model.dart';
import 'dart:math' as math;

class PostDetailsPage extends StatefulWidget {
  final PsychoeducPost post;
  final Future<String> Function(String) getValidImageUrl;
  final Map<String, dynamic>? userData;

  const PostDetailsPage({
    required this.post,
    required this.getValidImageUrl,
    required this.userData,
    Key? key,
  }) : super(key: key);

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  bool _isLoading = false;
  late PsychoeducPost _post;
  String? _imageUrl;
  List<PsychoeducPost> _suggestedPosts = [];
  bool _loadingSuggestions = true;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadImageUrl();
    _loadSuggestedPosts();
    _debugImageUrls();
  }

  Future<void> _loadImageUrl() async {
    if (_post.imageUrl.isNotEmpty) {
      final url = await widget.getValidImageUrl(_post.imageUrl);
      if (mounted) {
        setState(() {
          _imageUrl = url;
        });
      }
    }
  }

  // Load suggested posts based on tags or other criteria
  Future<void> _loadSuggestedPosts() async {
    try {
      setState(() {
        _loadingSuggestions = true;
      });

      // Query Firestore for posts with similar tags
      if (_post.tags.isNotEmpty) {
        final query = FirebaseFirestore.instance
            .collection('psychoeduc_ads')
            .where('tags', arrayContainsAny: _post.tags)
            .limit(10);

        final snapshot = await query.get();
        final List<PsychoeducPost> posts = [];

        for (var doc in snapshot.docs) {
          // Skip the current post
          if (doc.id == _post.id) continue;

          try {
            final data = doc.data();

            // Ensure likedBy is properly handled as List<String>
            List<String> likedBy = [];
            if (data['likedBy'] != null) {
              likedBy = (data['likedBy'] as List)
                  .map((item) => item.toString())
                  .toList();
            }

            // IMPORTANT FIX: Use 'image' field instead of 'imageUrl'
            final imageUrl = data['image'] ?? '';

            // Print debug info for each post's image
            print(
                'Loading suggested post: ${data['title']} - Image URL: $imageUrl');

            posts.add(PsychoeducPost(
              id: doc.id,
              counId: data['counId'] ?? '',
              title: data['title'] ?? '',
              description: data['description'] ?? '',
              tags: List<String>.from(data['tags'] ?? []),
              imageUrl:
                  imageUrl, // Store retrieved URL in the imageUrl property of PsychoeducPost
              currentLikes: data['currentLikes'] ?? 0,
              likedBy: likedBy,
              createdAt: (data['createdAt'] as Timestamp).toDate(),
            ));
          } catch (docError) {
            print('Error processing document ${doc.id}: $docError');
          }
        }

        // If no related posts by tag, get some random posts instead
        if (posts.isEmpty) {
          await _loadRandomPosts();
        } else {
          setState(() {
            _suggestedPosts = posts;
            _loadingSuggestions = false;
          });

          // Debug image URLs after loading
          _debugImageUrls();
        }
      } else {
        // If current post has no tags, load random posts
        await _loadRandomPosts();
      }
    } catch (error) {
      print('Error loading suggested posts: $error');
      setState(() {
        _loadingSuggestions = false;
      });
    }
  }

// Also fix the random posts loader to use 'image' field
  Future<void> _loadRandomPosts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('psychoeduc_ads')
          .orderBy(FieldPath.documentId)
          .limit(10)
          .get();

      final List<PsychoeducPost> posts = [];

      for (var doc in snapshot.docs) {
        // Skip current post
        if (doc.id == _post.id) continue;

        final data = doc.data();

        // Ensure likedBy is properly handled as List<String>
        List<String> likedBy = [];
        if (data['likedBy'] != null) {
          likedBy =
              (data['likedBy'] as List).map((item) => item.toString()).toList();
        }

        // IMPORTANT FIX: Use 'image' field instead of 'imageUrl'
        final imageUrl = data['image'] ?? '';

        posts.add(PsychoeducPost(
          id: doc.id,
          counId: data['counId'] ?? '',
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          tags: List<String>.from(data['tags'] ?? []),
          imageUrl: imageUrl, // Store the image URL here
          currentLikes: data['currentLikes'] ?? 0,
          likedBy: likedBy,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
        ));
      }

      // Shuffle posts to get random suggestions
      posts.shuffle(math.Random());

      setState(() {
        _suggestedPosts = posts.take(6).toList(); // Limit to 6 random posts
        _loadingSuggestions = false;
      });

      // Debug image URLs after loading
      _debugImageUrls();
    } catch (error) {
      print('Error loading random posts: $error');
      setState(() {
        _loadingSuggestions = false;
      });
    }
  }

  Future<void> _debugImageUrls() async {
    try {
      print('Debugging image URLs for suggested posts:');
      for (int i = 0; i < _suggestedPosts.length; i++) {
        final post = _suggestedPosts[i];
        print('Post ${i + 1}: "${post.title}"');
        print('  - Original URL: "${post.imageUrl}"');

        if (post.imageUrl.isNotEmpty) {
          try {
            final validUrl = await widget.getValidImageUrl(post.imageUrl);
            print('  - Valid URL: "$validUrl"');
          } catch (e) {
            print('  - Error getting valid URL: $e');
          }
        } else {
          print('  - No image URL provided');
        }
      }
    } catch (e) {
      print('Error in _debugImageUrls: $e');
    }
  }

  // Navigate to a suggested post
  void _openSuggestedPost(PsychoeducPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailsPage(
          post: post,
          getValidImageUrl: widget.getValidImageUrl,
          userData: widget.userData,
        ),
      ),
    );
  }

  // Check if current user has liked this post
  bool _hasUserLiked() {
    final String? studId = widget.userData?['studId'] as String?;
    return studId != null && _post.likedBy.contains(studId);
  }

  // Toggle like functionality
  Future<void> _toggleLike() async {
    try {
      setState(() => _isLoading = true);

      // Get current user's ID
      final String? studId = widget.userData?['studId'] as String?;
      if (studId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to like: User not logged in')),
        );
        return;
      }

      // Create a new list from _post.likedBy to avoid mutation issues
      final List<String> likedBy = List<String>.from(_post.likedBy);

      // Check if user already liked this post
      if (likedBy.contains(studId)) {
        // User already liked, remove the like
        likedBy.remove(studId);
        await FirebaseFirestore.instance
            .collection('psychoeduc_ads')
            .doc(_post.id)
            .update({
          'likedBy': likedBy,
          'currentLikes': likedBy.length,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Like removed')),
        );
      } else {
        // User hasn't liked, add the like
        likedBy.add(studId);
        await FirebaseFirestore.instance
            .collection('psychoeduc_ads')
            .doc(_post.id)
            .update({
          'likedBy': likedBy,
          'currentLikes': likedBy.length,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post liked!')),
        );
      }

      // Update local post object
      setState(() {
        _post = PsychoeducPost(
          id: _post.id,
          counId: _post.counId,
          title: _post.title,
          description: _post.description,
          tags: _post.tags,
          imageUrl: _post.imageUrl,
          currentLikes: likedBy.length,
          likedBy: likedBy,
          createdAt: _post.createdAt,
        );
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating likes: $error')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat.yMMMd().add_jm().format(_post.createdAt);
    final bool userLiked = _hasUserLiked();

    // Get the screen width for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600 ? 32.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Post Details',
          style: TextStyle(
            color: Colors.green.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.green.shade900),
        elevation: 1,
      ),
      body: Stack(
        children: [
          // Main content with single scroll
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image at the top (if available)
                if (_post.imageUrl.isNotEmpty)
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      // Set max height for very tall images
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: _imageUrl == null
                        ? const Center(child: CircularProgressIndicator())
                        : _imageUrl!.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text(
                                    'Image unavailable',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: _imageUrl!,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) {
                                  return const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.error,
                                            color: Colors.red, size: 40),
                                        SizedBox(height: 8),
                                        Text('Image failed to load'),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),

                // Title and date
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      horizontalPadding, 24, horizontalPadding, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        _post.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth > 600 ? 28 : 24,
                          letterSpacing: -0.5,
                        ),
                      ),

                      // Date
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          formattedDate,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Description
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Text(
                    _post.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),

                const SizedBox(height: 24),

                // Like button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: InkWell(
                    onTap: _toggleLike,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            userLiked ? Icons.favorite : Icons.favorite_border,
                            color: Colors.red,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_post.currentLikes} ${_post.currentLikes == 1 ? 'like' : 'likes'}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Tags section
                if (_post.tags.isNotEmpty)
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tags',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _post.tags.map((tag) {
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
                      ],
                    ),
                  ),

                // Divider before suggested posts
                Padding(
                  padding: EdgeInsets.only(
                      top: 32,
                      bottom: 16,
                      left: horizontalPadding,
                      right: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(thickness: 1),
                      const SizedBox(height: 16),
                      Text(
                        'You might also like',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),

                // Suggested Posts Grid
                _buildSuggestedPostsGrid(horizontalPadding),

                // Add bottom padding
                const SizedBox(height: 32),
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  // Build the suggested posts grid with Pinterest-style layout
  Widget _buildSuggestedPostsGrid(double horizontalPadding) {
    if (_loadingSuggestions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_suggestedPosts.isEmpty) {
      return Padding(
        padding:
            EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
        child: const Center(
          child: Text(
            'No related posts found',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    // Calculate column count based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final columnCount = screenWidth < 600
        ? 2
        : screenWidth < 900
            ? 3
            : 4;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _suggestedPosts.length,
        itemBuilder: (context, index) {
          final post = _suggestedPosts[index];
          return _buildSuggestedPostItem(post);
        },
      ),
    );
  }

  // Build individual suggested post card
  Widget _buildSuggestedPostItem(PsychoeducPost post) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openSuggestedPost(post),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post image thumbnail - taking more space with better error handling
            Expanded(
              child: FutureBuilder<String>(
                future: post.imageUrl.isNotEmpty
                    ? widget.getValidImageUrl(post.imageUrl)
                    : Future.value(''),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  final imageUrl = snapshot.data;

                  if (imageUrl == null || imageUrl.isEmpty) {
                    // Better placeholder for missing images
                    return Container(
                      color: Colors.grey.shade100,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              color: Colors.grey.shade400,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No image',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Better image loading with debugging
                  return CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.green.shade200,
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      // Print error for debugging
                      print('Error loading image $url: $error');
                      return Container(
                        color: Colors.grey.shade100,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade300,
                                size: 36,
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  'Image error',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Post title
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),

            // Like count
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.currentLikes}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
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
