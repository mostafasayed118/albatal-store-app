// ignore_for_file: depend_on_referenced_packages
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_order_detail_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_only_admin_repository.dart';

const _printChannel = MethodChannel('net.nfet.printing');

AdminOrder _order({
  String id = 'order-1',
  AdminOrderStatus status = AdminOrderStatus.paid,
  List<AdminOrderItem> items = const [],
}) =>
    AdminOrder(
      id: id,
      status: status,
      total: const Money.egp(120),
      placedAt: DateTime(2026),
      customerName: 'Sara Ali',
      items: items,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestOnlyAdminRepository repo;
  late List<MethodCall> printCalls;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    repo = TestOnlyAdminRepository();
    printCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_printChannel, (call) async {
      printCalls.add(call);
      return 1;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_printChannel, null);
  });

  Widget harness(String orderId) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: AdminCubit(repo),
          child: AdminOrderDetailPage(orderId: orderId),
        ),
      );

  void tallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('a loaded order with items shares a branded invoice PDF',
      (tester) async {
    repo.orderDetailsResult = Success(_order(items: const [
      AdminOrderItem(
        productName: 'Royal Silk',
        size: '2m',
        color: 'Emerald',
        quantity: 2,
        unitPrice: Money.egp(60),
      ),
    ]));

    await tester.pumpWidget(harness('order-1'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.picture_as_pdf_outlined));
    await tester.pump();
    // InvoicePdfBuilder builds off the main isolate; give that real async
    // work a chance to finish before checking the share call.
    await tester.runAsync(() async {
      for (var i = 0; i < 200 && printCalls.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(printCalls, hasLength(1));
    final params = printCalls.single.arguments as Map<Object?, Object?>;
    expect(params['name'], 'invoice-order-1.pdf');
    expect(params['doc'], isA<Uint8List>());
    expect((params['doc']! as Uint8List), isNotEmpty);
  });

  testWidgets('unknown order retry reloads the detail into a rendered page',
      (tester) async {
    tallViewport(tester);
    repo.orderDetailsResult = const Success(null);

    await tester.pumpWidget(harness('missing'));
    await tester.pumpAndSettle();

    expect(find.text('Order not found'), findsOneWidget);

    repo.orderDetailsResult = Success(_order(id: 'missing'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Order not found'), findsNothing);
    expect(find.text('Sara Ali'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
  });

  testWidgets('cancelling the tracking dialog closes it without a write',
      (tester) async {
    tallViewport(tester);
    repo.orderDetailsResult =
        Success(_order(status: AdminOrderStatus.processing));

    await tester.pumpWidget(harness('order-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark as Shipped'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Add Tracking Details'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Add Tracking Details'), findsNothing);
    expect(find.text('Order status updated to shipped'), findsNothing);
  });
}
