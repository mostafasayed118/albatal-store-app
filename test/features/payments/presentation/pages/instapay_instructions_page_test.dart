import 'dart:async';
import 'dart:typed_data';

import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:al_batal_elite/features/payments/presentation/pages/instapay_instructions_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../../../helpers/instapay_stub.dart';
import '../../../../helpers/proof_image_picker_platform_fake.dart';

Widget _routerHarness(GoRouter router) => MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );

GoRouter _singlePageRouter(Widget page) => GoRouter(
      initialLocation: '/test',
      routes: [GoRoute(path: '/test', builder: (_, __) => page)],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InstapayStub stub;
  late ImagePickerPlatform originalPlatform;
  late ProofImagePickerPlatformFake pickerPlatform;

  setUp(() {
    stub = InstapayStub(
      initiation: const InstapayReady(instructions: readyInstructions),
    );
    originalPlatform = ImagePickerPlatform.instance;
    pickerPlatform = ProofImagePickerPlatformFake();
    ImagePickerPlatform.instance = pickerPlatform;
  });

  tearDown(() async {
    ImagePickerPlatform.instance = originalPlatform;
    await stub.watchController.close();
  });

  Future<PaymentCubit> readyCubit() async {
    final cubit = buildReadyCubit(stub);
    await cubit.processPayment(customerEmail: 'a@b.c');
    expect(cubit.state.status, PaymentStatus.awaitingProof);
    return cubit;
  }

  Future<void> pumpPage(WidgetTester tester, PaymentCubit cubit) async {
    final router = _singlePageRouter(InstapayInstructionsPage(cubit: cubit));
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerHarness(router));
    await tester.pump();
  }

  Future<GoRouter> pumpPushedPage(
      WidgetTester tester, PaymentCubit cubit) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/instapay',
          builder: (_, __) => InstapayInstructionsPage(cubit: cubit),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerHarness(router));
    unawaited(router.push('/instapay'));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('copy button copies the server address and shows a snackbar',
      (tester) async {
    final cubit = await readyCubit();
    await pumpPage(tester, cubit);

    expect(find.text('instapay@merchant'), findsOneWidget);

    await tester.tap(find.byTooltip('Copy'));
    await tester.pump();

    expect(find.text('InstaPay address copied'), findsOneWidget);
    cubit.cancel();
  });

  testWidgets('cancelled pick leaves the submit button disabled',
      (tester) async {
    final cubit = await readyCubit();
    await pumpPage(tester, cubit);
    pickerPlatform.file = null;

    await tester.ensureVisible(find.text('Attach transfer screenshot'));
    await tester.tap(find.text('Attach transfer screenshot'));
    await tester.pumpAndSettle();

    expect(find.text('Screenshot attached'), findsNothing);
    final submit = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(submit.onPressed, isNull);
    expect(pickerPlatform.calls, 1);
    cubit.cancel();
  });

  testWidgets('a reference longer than 64 characters is rejected locally',
      (tester) async {
    final cubit = await readyCubit();
    await pumpPage(tester, cubit);
    pickerPlatform.file = XFile.fromData(
      Uint8List.fromList(const [1]),
      path: 'proof.png',
    );

    await tester.ensureVisible(find.text('Attach transfer screenshot'));
    await tester.tap(find.text('Attach transfer screenshot'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.text = 'x' * 65;
    await tester.ensureVisible(find.text('Submit proof for review'));
    await tester.tap(find.text('Submit proof for review'));
    await tester.pump();

    expect(
      find.text(
          'The reference is too long. Please keep it under 64 characters.'),
      findsOneWidget,
    );
    expect(stub.proofCalls, isEmpty);
    cubit.cancel();
  });

  testWidgets('picked screenshot attaches and a valid submit is recorded',
      (tester) async {
    final cubit = await readyCubit();
    await pumpPage(tester, cubit);
    pickerPlatform.file = XFile.fromData(
      Uint8List.fromList(const [1, 2, 3, 4]),
      path: 'proof.png',
    );

    await tester.ensureVisible(find.text('Attach transfer screenshot'));
    await tester.tap(find.text('Attach transfer screenshot'));
    await tester.pumpAndSettle();

    expect(find.text('Screenshot attached'), findsOneWidget);
    expect(find.text('proof.png'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.text = '  TX-1  ';
    await tester.ensureVisible(find.text('Submit proof for review'));
    await tester.tap(find.text('Submit proof for review'));
    await tester.pumpAndSettle();

    expect(stub.proofCalls, hasLength(1));
    expect(stub.proofCalls.single['order_id'], 'ord-1');
    expect(stub.proofCalls.single['file_ext'], 'png');
    expect(stub.proofCalls.single['bytes'], const [1, 2, 3, 4]);
    expect(stub.proofCalls.single['reference'], 'TX-1');
    expect(find.text('Proof submitted — we will review it shortly'),
        findsOneWidget);
    expect(
      find.text(
        'Your payment stays pending until we review the proof. You can safely '
        'leave this page — the status appears in your orders.',
      ),
      findsOneWidget,
    );

    cubit.cancel();
  });

  testWidgets(
      'a failed proof submission pops the page for the parent to report',
      (tester) async {
    final cubit = await readyCubit();
    await pumpPushedPage(tester, cubit);
    pickerPlatform.file = XFile.fromData(
      Uint8List.fromList(const [1]),
      path: 'proof.jpg',
    );
    stub.proofResult = const PaymentFailed(message: 'x', code: 'proof_missing');

    await tester.ensureVisible(find.text('Attach transfer screenshot'));
    await tester.tap(find.text('Attach transfer screenshot'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit proof for review'));
    await tester.tap(find.text('Submit proof for review'));
    await tester.pumpAndSettle();

    expect(find.byType(InstapayInstructionsPage), findsNothing);
    expect(find.text('home'), findsOneWidget);
    cubit.cancel();
  });

  for (final status in const [
    PaymentStatus.expired,
    PaymentStatus.timedOut,
    PaymentStatus.selectingMethod,
  ]) {
    testWidgets('terminal status $status pops the page', (tester) async {
      final cubit = await readyCubit();
      await pumpPushedPage(tester, cubit);

      cubit.emitState(cubit.state.copyWith(status: status));
      await tester.pumpAndSettle();

      expect(find.byType(InstapayInstructionsPage), findsNothing);
      expect(find.text('home'), findsOneWidget);
      cubit.cancel();
    });
  }
}
