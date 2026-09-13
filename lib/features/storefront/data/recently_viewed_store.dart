import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../domain/repositories/recently_viewed_store.dart';

const kRecentlyViewedKey = 'recently_viewed_v1';
const kRecentlyViewedMax = 10;

/// SharedPreferences-backed recently-viewed snapshots.
///
/// Each entry is a minimal JSON map (id/name/category/price/image) —
/// enough to render the home strip without a network fetch, and stable
/// across catalog changes. Decode follows the total-decode contract
/// (audit 2026-09-13): malformed or id-less entries are skipped, never
/// thrown past the store.
final class PrefsRecentlyViewedStore implements RecentlyViewedStore {
  PrefsRecentlyViewedStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  List<Product> load() {
    final raw = _prefs.getStringList(kRecentlyViewedKey) ?? const [];
    return raw.map(_decode).whereType<Product>().toList();
  }

  @override
  void record(Product product) {
    if (product.id.isEmpty) return;
    final current = load();
    current.removeWhere((existing) => existing.id == product.id);
    current.insert(0, product);
    final encoded = current.take(kRecentlyViewedMax).map(_encode).toList();
    _prefs.setStringList(kRecentlyViewedKey, encoded);
  }

  @override
  void clear() => _prefs.remove(kRecentlyViewedKey);

  String _encode(Product p) => jsonEncode({
        'id': p.id,
        'name': p.name,
        'category': p.category,
        'price_minor': p.price.minorUnits,
        'image_color': p.imageColor,
        if (p.oldPrice != null) 'old_price_minor': p.oldPrice!.minorUnits,
        if (p.imageAsset != null) 'image_asset': p.imageAsset,
        'rating': p.rating,
        'review_count': p.reviewCount,
      });

  Product? _decode(String entry) {
    try {
      final map = jsonDecode(entry);
      if (map is! Map<String, dynamic>) return null;
      final id = map['id'];
      final name = map['name'];
      final category = map['category'];
      final priceMinor = map['price_minor'];
      if (id is! String ||
          id.isEmpty ||
          name is! String ||
          category is! String ||
          priceMinor is! int) {
        return null;
      }
      final oldPriceMinor = map['old_price_minor'];
      final imageAsset = map['image_asset'];
      final rating = map['rating'];
      final reviewCount = map['review_count'];
      return Product(
        id: id,
        name: name,
        category: category,
        price: Money(priceMinor),
        imageColor: map['image_color'] is int ? map['image_color'] as int : 0,
        oldPrice: oldPriceMinor is int ? Money(oldPriceMinor) : null,
        imageAsset: imageAsset is String ? imageAsset : null,
        rating: rating is num ? rating.toDouble() : 0.0,
        reviewCount: reviewCount is int ? reviewCount : 0,
      );
    } on FormatException {
      return null;
    }
  }
}
