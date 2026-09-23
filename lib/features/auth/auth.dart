/// Public API of the auth feature for other features.
///
/// The audit's cross-feature rule (2026-09-21, P2): features never reach
/// into another feature's internals — they import this barrel. Exports
/// are limited to what is actually consumed across features today.
library;

export 'domain/repositories/order_snapshot_port.dart';
export 'presentation/cubit/auth_cubit.dart';
