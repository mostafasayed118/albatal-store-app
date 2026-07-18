import 'package:equatable/equatable.dart';

/// Customer profile entity.
final class Profile extends Equatable {
  const Profile({
    required this.id,
    this.fullName = '',
    this.phone,
    this.avatarUrl,
    this.isAdmin = false,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final bool isAdmin;

  Profile copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    bool? isAdmin,
  }) =>
      Profile(
        id: id,
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isAdmin: isAdmin ?? this.isAdmin,
      );

  @override
  List<Object?> get props => [id, fullName, phone, avatarUrl, isAdmin];
}
