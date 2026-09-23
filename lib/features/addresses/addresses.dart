/// Public API of the addresses feature for other features.
///
/// The audit's cross-feature rule (2026-09-21, P2): features never reach
/// into another feature's internals — they import this barrel. Exports
/// are limited to what is actually consumed across features today.
library;
export 'domain/repositories/address_repository.dart';
export 'presentation/cubit/addresses_cubit.dart';
