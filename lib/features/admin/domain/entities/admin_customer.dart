import 'package:equatable/equatable.dart';

/// Admin-facing customer row (feature-batch §14).
final class AdminCustomer extends Equatable {
  const AdminCustomer({
    required this.id,
    required this.name,
    required this.email,
    required this.tier,
    required this.isBlocked,
  });

  final String id;
  final String name;
  final String email;
  final String tier;

  /// Suspended customer flag (read-only display in this batch).
  final bool isBlocked;

  @override
  List<Object?> get props => [id, name, email, tier, isBlocked];
}
