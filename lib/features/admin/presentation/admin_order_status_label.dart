import '../../../generated/l10n/app_localizations.dart';
import '../domain/entities/admin_order.dart';

/// The one place an [AdminOrderStatus] becomes shopper-visible copy.
///
/// Why this exists: two admin surfaces rendered the raw DB enum name — the order
/// detail card printed `status.name.toUpperCase()` and the sales panel hand-
/// capitalized it — so an Arabic admin read "SHIPPED" / "Shipped" next to
/// localized chrome. The order queue's filter chips already mapped statuses to
/// ARB keys, so this gives the other two surfaces that same mapping instead of a
/// third and fourth spelling of it (owner decision, part 34: the admin console
/// is localized like the storefront).
///
/// Not a `l10n` extension on the enum: the enum lives in the admin domain layer,
/// which must not know about presentation copy.
String adminOrderStatusLabel(AppLocalizations l, AdminOrderStatus status) =>
    switch (status) {
      AdminOrderStatus.pending => l.pending,
      AdminOrderStatus.placed => l.placed,
      AdminOrderStatus.paid => l.paid,
      AdminOrderStatus.processing => l.processing,
      AdminOrderStatus.shipped => l.shipped,
      AdminOrderStatus.delivered => l.delivered,
      AdminOrderStatus.cancelled => l.cancelled,
      AdminOrderStatus.refunded => l.refunded,
      AdminOrderStatus.unknown => l.unknown,
    };
