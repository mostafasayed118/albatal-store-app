import 'package:al_batal_elite/shared/services/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the structured logging entry points and the debug-only render
/// path. The release-only branches (`kReleaseMode` breadcrumb + safe error
/// summary) cannot execute in a test build, which always runs in debug.
void main() {
  late DebugPrintCallback originalDebugPrint;
  late List<String> lines;

  setUp(() {
    originalDebugPrint = debugPrint;
    lines = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    Log.setLevel(LogLevel.debug);
    Log.includeTimestamp = true;
    Log.includeCategory = true;
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    Log.setLevel(LogLevel.debug);
    Log.includeTimestamp = true;
    Log.includeCategory = true;
  });

  test('setLevel filters below the configured minimum', () {
    Log.setLevel(LogLevel.warning);

    Log.d('debug hidden');
    Log.i('info hidden');
    Log.w('warning shown');

    expect(lines, hasLength(1));
    expect(lines.single, contains('warning shown'));
  });

  test('all four levels render a distinct icon and category', () {
    Log.d('debug line', category: LogCategory.app);
    Log.i('info line', category: LogCategory.network);
    Log.w('warning line', category: LogCategory.payment);
    Log.e('error line');

    expect(lines[0], contains('🔍'));
    expect(lines[0], contains('[APP]'));
    expect(lines[1], contains('ℹ️'));
    expect(lines[1], contains('[NETWORK]'));
    expect(lines[2], contains('⚠️'));
    expect(lines[3], contains('🔴'));
    expect(lines[3], contains('[ERROR]'));
  });

  test('auth, nav, cubit and payment helpers tag their category', () {
    Log.auth('signed in');
    Log.nav('go to /cart');
    Log.cubit('CartCubit', 'loaded', level: LogLevel.info);
    Log.payment('charge initiated');

    expect(lines[0], contains('[AUTH]'));
    expect(lines[1], contains('[NAVIGATION]'));
    expect(lines[2], contains('[CUBIT]'));
    expect(lines[2], contains('[CartCubit] loaded'));
    expect(lines[3], contains('[PAYMENT]'));
  });

  test('includeTimestamp and includeCategory can be disabled', () {
    Log.includeTimestamp = false;
    Log.includeCategory = false;

    Log.i('bare message');

    expect(lines.single, isNot(contains('[APP]')));
    expect(lines.single, endsWith('bare message'));
    expect(lines.single, isNot(matches(RegExp(r'^\d{2}:\d{2}:\d{2}\.'))));
  });

  test('warning/error append the error summary', () {
    Log.w('flaky', error: StateError('offline'));
    Log.e('crashed', error: StateError('boom'), stackTrace: StackTrace.current);

    expect(lines[0], contains('flaky'));
    expect(lines[1], contains('  Error: Bad state: offline'));
    expect(lines[2], contains('crashed'));
    expect(lines[3], contains('  Error: Bad state: boom'));
    expect(lines[4], contains('  Stack:'));
  });
}
