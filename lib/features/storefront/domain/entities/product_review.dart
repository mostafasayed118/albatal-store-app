import 'package:equatable/equatable.dart';

/// A customer product review (feature-batch §9).
final class ProductReview extends Equatable {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.authorName,
    required this.rating,
    required this.text,
    required this.createdAt,
    this.photoUrl,
  });

  final String id;
  final String productId;

  /// Display name from the author's profile (never an email).
  final String authorName;
  final int rating; // 1..5
  final String text;
  final DateTime createdAt;

  /// Public URL of the approved customer photo, when present.
  final String? photoUrl;

  @override
  List<Object?> get props =>
      [id, productId, authorName, rating, text, createdAt, photoUrl];
}

/// A pending moderation row in the admin queue.
final class AdminReview extends Equatable {
  const AdminReview({
    required this.id,
    required this.productId,
    required this.authorName,
    required this.rating,
    required this.text,
    required this.status,
    this.photoUrl,
  });

  final String id;
  final String productId;
  final String authorName;
  final int rating;
  final String text;

  /// `pending` | `approved` | `rejected`
  final String status;
  final String? photoUrl;

  @override
  List<Object?> get props =>
      [id, productId, authorName, rating, text, status, photoUrl];
}
