import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result.guard', () {
    test('wraps the action value in Success', () async {
      final result = await Result.guard(() async => 42, 'fallback');
      expect(result, isA<Success<int>>());
      expect((result as Success<int>).value, 42);
    });

    test('maps a throw into Failure with the fixed message', () async {
      final result = await Result.guard<int>(
        () async => throw Exception('boom'),
        'fallback',
      );
      expect(result, isA<Failure<int>>());
      final error = (result as Failure<int>).error;
      expect(error.message, 'fallback');
      expect(error.cause, isA<Exception>());
      expect(error.stackTrace, isNotNull);
      expect(error.code, isNull);
    });

    test('onError fully owns the AppError construction', () async {
      const mapped = AppError('mapped text', code: 'mapped_code');
      final result = await Result.guard<int>(
        () async => throw StateError('raw'),
        'fallback',
        onError: (e, st) => mapped,
      );
      expect((result as Failure<int>).error, same(mapped));
    });

    test('captures Errors (TypeError) too, not just Exceptions', () async {
      final result = await Result.guard<List<int>>(
        // Unchecked dynamic cast → throws TypeError (an Error) at runtime.
        () async => <dynamic>['not-an-int'] as List<int>,
        'fallback',
      );
      expect(result, isA<Failure<List<int>>>());
      expect((result as Failure<List<int>>).error.cause, isA<TypeError>());
    });
  });
}
