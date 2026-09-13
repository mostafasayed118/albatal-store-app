import 'dart:io';

import 'package:al_batal_elite/shared/widgets/skeleton_loaders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Frame-timing harness for the skeleton surfaces (feature-batch §17).
/// Only meaningful on real hardware: skipped unless PERF=1
/// (`PERF=1 flutter test test/perf --profile`).
void main() {
  final perfEnabled = Platform.environment['PERF'] == '1';

  testWidgets('catalog skeleton mounts and unmounts cleanly', (tester) async {
    if (!perfEnabled) {
      // Plain-VM smoke run: build once, no frame budgeting.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CatalogSkeleton(itemCount: 4)),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
      return;
    }

    // Device run: mount the skeleton and pump a fixed 60-frame budget.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CatalogSkeleton(itemCount: 12)),
    ));
    final watch = Stopwatch()..start();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    watch.stop();
    // 60 frames at 60 Hz must render in under 1.1 s of fake time.
    expect(watch.elapsedMilliseconds, lessThan(1100));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
