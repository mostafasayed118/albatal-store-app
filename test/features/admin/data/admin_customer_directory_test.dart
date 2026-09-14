import 'dart:async';

import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/data/supabase_admin_repository.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_customer.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regression guards for the admin data layer.
///
/// The customer directory previously requested `email` from `profiles`, a
/// column that does not exist (the address lives in `auth.users`, which
/// PostgREST does not expose). PostgREST answered 42703, the repository
/// mapped it to `Failure`, and the Customers screen could never list anyone.
/// It stayed invisible because every existing test drove the page through a
/// STUB repository — the real `SupabaseAdminRepository` had no test at all.
///
/// `getOrderDetails` is covered for the same reason: its embedded
/// `profiles(...)` join is subject to the viewer's RLS, so it now goes through
/// the admin-checked `get_order_details` RPC instead.

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

/// Awaitable terminal builder (the repository `await`s the chain).
class FakeTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  FakeTransformBuilder(this._value);

  final T _value;

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) =>
      this;

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) =>
      this;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
          {Function? onError}) =>
      Future.value(_value).then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) =>
      Future.value(_value).catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      Future.value(_value).whenComplete(action);

  @override
  Stream<T> asStream() => Future.value(_value).asStream();

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      Future.value(_value).timeout(timeLimit, onTimeout: onTimeout);
}

/// `select()` returns a `PostgrestFilterBuilder`, which is NOT a subtype of
/// the transform builder, so it needs its own fake that hands back one.
class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  FakeFilterBuilder(this._rows);

  final List<Map<String, dynamic>> _rows;

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) =>
      FakeTransformBuilder<T>(_rows as T);

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) =>
      FakeTransformBuilder<T>(_rows as T);

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
          {Function? onError}) =>
      Future.value(_rows as T).then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) =>
      Future.value(_rows as T).catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      Future.value(_rows as T).whenComplete(action);

  @override
  Stream<T> asStream() => Future.value(_rows as T).asStream();

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      Future.value(_rows as T).timeout(timeLimit, onTimeout: onTimeout);
}