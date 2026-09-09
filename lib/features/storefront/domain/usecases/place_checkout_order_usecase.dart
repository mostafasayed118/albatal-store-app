import '../../../../core/data/address_codec.dart';
import '../../../../core/entities/address.dart';
import '../../../../core/entities/product.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../payments/domain/entities/payment.dart';
import '../entities/pending_order.dart';
import '../repositories/checkout_repository.dart';
import '../repositories/idempotency_store.dart';

/// Outcome of [PlaceCheckoutOrderUseCase].
///
/// Unlike `Result<PendingOrder>`, the outcome ALWAYS carries the
/// idempotency key the attempt settled on — including failures — so the
/// cubit can keep it in state (retry stability), exactly like the legacy
/// cubit which emitted the key before the repository call.
final class PlaceCheckoutOrderOutcome {
  const PlaceCheckoutOrderOutcome.success({
    required this.pending,
    required this.idempotencyKey,
  }) : error = null;

  const PlaceCheckoutOrderOutcome.failure({
    required this.error,
    required this.idempotencyKey,
  }) : pending = null;

  final PendingOrder? pending;
  final AppError? error;
  final String idempotencyKey;

  bool get isSuccess => pending != null;
}

/// Server-side checkout orchestration, extracted from [CheckoutCubit].
///
/// Owns everything the cubit used to do inline: idempotency-key reuse
/// (in-session key first, then a fresh persisted key inside the TTL,
/// otherwise a generated one), address-snapshot building, and the
/// non-pending retry policy (a restored key that resurrects a dead order
/// is discarded and the attempt is retried ONCE with a fresh key so
/// checkout never gets stuck on an unpayable order).
///
/// The cubit stays thin: it emits loading, awaits this use-case, and
/// emits the result. [clock] is injectable for deterministic TTL tests.
class PlaceCheckoutOrderUseCase {
  PlaceCheckoutOrderUseCase({
    required CheckoutRepository checkoutRepository,
    required IdempotencyStore idempotencyStore,
    DateTime Function()? clock,
  })  : _checkoutRepository = checkoutRepository,
        _idempotencyStore = idempotencyStore,
        _clock = clock ?? DateTime.now;

  /// How long a persisted key survives an app restart (crash
  /// mid-checkout) before it is treated as expired.
  static const idempotencyTtl = Duration(hours: 24);

  final CheckoutRepository _checkoutRepository;
  final IdempotencyStore _idempotencyStore;
  final DateTime Function() _clock;

  int _attemptCounter = 0;
  static int _instanceCounter = 0;
  final int _instanceId = ++_instanceCounter;

  Future<PlaceCheckoutOrderOutcome> call({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    Address? address,
    String? inSessionKey,
  }) async {
    final key = inSessionKey ?? _restoredKey() ?? _generateIdempotencyKey();
    await _idempotencyStore.saveKey(key, _clock().millisecondsSinceEpoch);
    final snapshot = address != null
        ? AddressCodec.toSnapshotJson(address)
        : <String, dynamic>{};

    final first = await _checkoutRepository.placeOrder(
      items: items,
      paymentMethod: paymentMethod,
      addressSnapshot: snapshot,
      idempotencyKey: key,
    );
    switch (first) {
      case Success<PendingOrder>(:final value):
        if (value.status == 'pending') {
          return PlaceCheckoutOrderOutcome.success(
              pending: value, idempotencyKey: key);
        }
        // A restored key resurrected a dead (non-pending) order: discard
        // it and retry ONCE with a fresh key.
        await _idempotencyStore.clear();
        final fresh = _generateIdempotencyKey();
        await _idempotencyStore.saveKey(fresh, _clock().millisecondsSinceEpoch);
        final second = await _checkoutRepository.placeOrder(
          items: items,
          paymentMethod: paymentMethod,
          addressSnapshot: snapshot,
          idempotencyKey: fresh,
        );
        return switch (second) {
          Success<PendingOrder>(:final value) =>
            PlaceCheckoutOrderOutcome.success(
                pending: value, idempotencyKey: fresh),
          Failure<PendingOrder>(:final error) =>
            PlaceCheckoutOrderOutcome.failure(
                error: error, idempotencyKey: fresh),
        };
      case Failure<PendingOrder>(:final error):
        // No retry on a hard failure, but the key stays persisted AND is
        // returned so the user can retry the same attempt with it.
        return PlaceCheckoutOrderOutcome.failure(
            error: error, idempotencyKey: key);
    }
  }

  /// Discards the persisted key (new attempt / order completed).
  Future<void> clearPersistedKey() => _idempotencyStore.clear();

  /// Returns the persisted key when it exists and is younger than the
  /// TTL, otherwise null.
  String? _restoredKey() {
    final key = _idempotencyStore.loadKey();
    final ts = _idempotencyStore.loadTimestampMs();
    if (key == null || ts == null) return null;
    final age = _clock().millisecondsSinceEpoch - ts;
    if (age > idempotencyTtl.inMilliseconds) return null;
    return key;
  }

  String _generateIdempotencyKey() {
    _attemptCounter++;
    return 'cko-${_clock().millisecondsSinceEpoch}-$_attemptCounter-$_instanceId';
  }
}
