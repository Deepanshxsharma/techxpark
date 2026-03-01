import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String bookingId;
  final String parkingId;
  final int rating;
  final String reviewText;
  final List<String> tags;
  final DateTime? createdAt;

  const ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.bookingId,
    required this.parkingId,
    required this.rating,
    this.reviewText = '',
    this.tags = const [],
    this.createdAt,
  });

  factory ReviewModel.fromMap(String id, Map<String, dynamic> m) {
    return ReviewModel(
      id: id,
      userId: m['userId'] ?? '',
      userName: m['userName'] ?? '',
      bookingId: m['bookingId'] ?? '',
      parkingId: m['parkingId'] ?? '',
      rating: (m['rating'] as num?)?.toInt() ?? 0,
      reviewText: m['reviewText'] ?? '',
      tags: List<String>.from(m['tags'] ?? []),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'bookingId': bookingId,
        'parkingId': parkingId,
        'rating': rating,
        'reviewText': reviewText,
        'tags': tags,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
