import 'package:cloud_firestore/cloud_firestore.dart';

class PsychoeducPost {
  final String id;
  final String counId;
  final String title;
  final String description;
  final List<String> tags;
  final List<String> likedBy;
  final String imageUrl;
  final int currentLikes;
  final DateTime createdAt;

  PsychoeducPost({
    required this.id,
    required this.counId,
    required this.title,
    required this.description,
    required this.tags,
    required this.imageUrl,
    required this.currentLikes,
    required this.createdAt,
    required this.likedBy,
  });

  // Create from Firestore document
  factory PsychoeducPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Handle nullable timestamp (important for testing or new documents)
    DateTime createdAt;
    try {
      final timestamp = data['createdAt'];
      createdAt = timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
    } catch (e) {
      createdAt = DateTime.now();
    }
    
    return PsychoeducPost(
      id: doc.id,
      counId: data['counId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      imageUrl: data['image'] ?? '',
      currentLikes: data['currentLikes'] ?? 0,
      createdAt: createdAt,
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'counId': counId,
      'title': title,
      'description': description,
      'tags': tags,
      'image': imageUrl,
      'currentLikes': currentLikes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}