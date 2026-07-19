import 'package:supabase_flutter/supabase_flutter.dart';

/// Shipping calculation service.
class ShippingService {
  ShippingService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Calculate shipping fee for a given governorate and subtotal.
  Future<int> calculateFee(String governorate, int subtotal) async {
    try {
      final response = await _client.rpc('calculate_shipping_fee', params: {
        'p_governorate': governorate,
        'p_subtotal': subtotal,
      });
      return response as int;
    } catch (e) {
      // Default fee on error
      return 7500;
    }
  }

  /// Get all active shipping zones.
  Future<List<Map<String, dynamic>>> getZones() async {
    final response = await _client
        .from('shipping_zones')
        .select()
        .eq('is_active', true)
        .order('name');
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Get estimated delivery days for a governorate.
  Future<Map<String, int>> getEstimatedDays(String governorate) async {
    final response = await _client
        .from('shipping_zones')
        .select('estimated_days_min, estimated_days_max')
        .eq('is_active', true);

    for (final zone in (response as List)) {
      final governorates = await _client
          .from('shipping_zones')
          .select('governorates')
          .eq('id', zone['id'])
          .single();
      if ((governorates['governorates'] as List).contains(governorate)) {
        return {
          'min': zone['estimated_days_min'] as int,
          'max': zone['estimated_days_max'] as int,
        };
      }
    }

    return {'min': 1, 'max': 3}; // Default
  }
}
