import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/services/notification_service.dart';

const _kWatchedProducts = 'back_in_stock_watched_v1';

/// SharedPreferences-backed implementation of the back-in-stock alert
/// port defined beside [NotificationService] (consumer-side port — the
/// shared layer never imports this file). The storefront wishlist and
/// details pages expose the per-product toggle.
final class PrefsBackInStockAlertStore implements BackInStockAlertStore {
  PrefsBackInStockAlertStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Set<String> get watchedProductIds =>
      (_prefs.getStringList(_kWatchedProducts) ?? const []).toSet();

  @override
  bool isWatched(String productId) => watchedProductIds.contains(productId);

  @override
  void setWatched(String productId, bool enabled) {
    final next = watchedProductIds;
    enabled ? next.add(productId) : next.remove(productId);
    _prefs.setStringList(_kWatchedProducts, next.toList());
  }
}
