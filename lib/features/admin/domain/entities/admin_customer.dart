import 'package:equatable/equatable.dart';

/// Admin-facing customer row (feature-batch §14).
final class AdminCustomer extends Equatable {
  const AdminCustomer({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    required this.tier,
    required this.isBlocked,
  });

  final String id;
  final String name;

  /// Customer email. Empty in the current schema: `public.profiles` has no
  /// `email` column (the address lives in `auth.users`, which PostgREST does
  /// not expose). Kept on the entity so a future profile-view/RPC can
  /// populate it without a breaking change — see [contact].
  final String email;

  /// Customer phone. `profiles.phone` EXISTS today, so this is the contact
  /// column the directory actually renders.
  final String phone;

  final String tier;

  /// Suspended customer flag (read-only display in this batch).
  final bool isBlocked;

  /// Contact value to display: the email when one is available, otherwise
  /// the phone. Empty when neither exists (the UI hides the row rather than
  /// rendering a blank subtitle).
  String get contact => email.isNotEmpty ? email : phone;

  /// Narrow copy holding [tier] — the one field the directory can change
  /// (matches [AdminCoupon.copyWith]). Used by [AdminCustomersCubit] to
  /// reflect a confirmed tier write without reloading the whole page.
  AdminCustomer copyWith({String? tier}) => AdminCustomer(
        id: id,
        name: name,
        email: email,
        phone: phone,
        tier: tier ?? this.tier,
        isBlocked: isBlocked,
      );

  @override
  List<Object?> get props => [id, name, email, phone, tier, isBlocked];
}
