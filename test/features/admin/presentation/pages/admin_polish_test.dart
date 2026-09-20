import 'dart:typed_data';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_coupon.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_coupons_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_image_manager_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_inventory_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_order_detail_page.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_orders_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/app_button.dart';
import 'package:al_batal_elite/shared/components/app_image.dart';
import 'package:al_batal_elite/shared/components/feedback_view.dart';
import 'package:al_batal_elite/shared/services/image_compressor.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';
import 'package:al_batal_elite/shared/services/share_service.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdminRepository extends Mock implements AdminRepository {}

/// Minimal fake that avoids Supabase client init (mirrors
/// admin_catalog_navigation_test.dart).
class _FakeStorageService extends StorageService {
  _FakeStorageService() : super(client: null);

  @override
  String getProductImageUrl(String storagePath) =>
      'https://example.com/$storagePath';
}

/// Records upload file names without touching Supabase.
class _UploadingStorageService extends _FakeStorageService {
  _UploadingStorageService(this.uploadedFileNames);

  final List<String> uploadedFileNames;

  @override
  Future<String> uploadProductImage(String productId, List<int> bytes,
      String fileName, String contentType) async {
    uploadedFileNames.add(fileName);
    return 'product-images/pid/$fileName';
  }
}

/// Always re-encodes to a small payload so the compression pass is
/// observably on the upload path.
class _ShrinkCompressor implements ImageCompressor {
  @override
  Future<Uint8List> compress(Uint8List bytes) async =>
      Uint8List.sublistView(bytes, 0, 1024);
}

/// Captures what the CSV export actually hands the share sheet, so the
/// assertions can read the real payload instead of trusting the call.
class _RecordingShareService implements ShareService {
  final List<String> shared = [];
  final List<({String fileName, String content, String mimeType})> files = [];

  @override
  Future<void> shareText(String message) async => shared.add(message);

  @override
  Future<void> shareFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) async =>
      files.add((fileName: fileName, content: content, mimeType: mimeType));
}

AdminOrder _order(String id, AdminOrderStatus status) => AdminOrder(
      id: id,
      status: status,
      total: const Money.egp(100),
      placedAt: DateTime(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAdminRepository repo;
  late _FakeStorageService storage;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    repo = _MockAdminRepository();
  });

  void registerRepoInGetIt() {
    if (getIt.isRegistered<AdminRepository>()) {
      getIt.unregister<AdminRepository>();
    }
    getIt.registerSingleton<AdminRepository>(repo);
  }

  Widget harness(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(value: AdminCubit(repo), child: child),
      );

  tearDown(() {
    if (getIt.isRegistered<AdminRepository>()) {
      getIt.unregister<AdminRepository>();
    }
    if (getIt.isRegistered<StorageService>()) {
      getIt.unregister<StorageService>();
    }
  });

  group('AdminDashboardPage', () {
    testWidgets('loads its own data on entry (no permanently-empty stats)',
        (tester) async {
      when(() => repo.getAllOrders(status: any(named: 'status')))
          .thenAnswer((_) async => const Success([]));
      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => const Success([]));
      when(() => repo.isCurrentUserAdmin()).thenAnswer((_) async => true);

      await tester.pumpWidget(harness(const AdminDashboardPage()));
      // First pump runs the post-frame loaders, later pumps settle them.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Total Orders'), findsOneWidget);
      expect(find.text('Low Stock'), findsOneWidget);
      verify(() => repo.getAllOrders(status: any(named: 'status'))).called(1);
      verify(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .called(1);
    });

    testWidgets('the Coupons tile reaches the coupon manager', (tester) async {
      when(() => repo.getAllOrders(status: any(named: 'status')))
          .thenAnswer((_) async => const Success([]));
      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => const Success([]));
      when(() => repo.isCurrentUserAdmin()).thenAnswer((_) async => true);
      when(() => repo.fetchCoupons())
          .thenAnswer((_) async => const Success(<AdminCoupon>[]));

      // Tall viewport: the tile sits below the stat cards and the other
      // quick actions, so the default 800x600 window never lays it out.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The tile is the ONLY way an admin reaches coupon management: §8
      // shipped the page, cubit and repository methods with no destination,
      // so a coupon could be redeemed at checkout but never created.
      final router = GoRouter(
        initialLocation: '/admin',
        routes: [
          GoRoute(
              path: '/admin', builder: (_, __) => const AdminDashboardPage()),
          GoRoute(
              path: '/admin/coupons',
              builder: (_, __) => AdminCouponsPage(repository: repo)),
        ],
      );
      addTearDown(router.dispose);
      final adminCubit = AdminCubit(repo);
      addTearDown(adminCubit.close);

      // The cubit sits above the router, as it does in the app (the routed
      // pages read it from the root providers).
      await tester.pumpWidget(BlocProvider.value(
        value: adminCubit,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Coupons'), findsOneWidget);

      await tester.tap(find.text('Coupons'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AdminCouponsPage), findsOneWidget,
          reason: 'the tile must land on the coupon manager, not a 404');
      verify(() => repo.fetchCoupons()).called(1);
    });

    testWidgets('error state offers a retry that actually reloads',
        (tester) async {
      // Both loaders fail so the last emitted state is the error.
      when(() => repo.getAllOrders(status: any(named: 'status')))
          .thenAnswer((_) async => const Failure(AppError('offline')));
      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => const Failure(AppError('offline')));
      when(() => repo.isCurrentUserAdmin()).thenAnswer((_) async => true);

      await tester.pumpWidget(harness(const AdminDashboardPage()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);

      when(() => repo.getAllOrders(status: any(named: 'status')))
          .thenAnswer((_) async => const Success([]));
      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => const Success([]));
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Something went wrong'), findsNothing,
          reason: 'retry reloads the stats instead of only clearing the flag');
      expect(find.text('Total Orders'), findsOneWidget);
    });
  });

  group('AdminOrdersPage', () {
    testWidgets('empty queue renders the inviting empty state', (tester) async {
      when(() => repo.getAllOrders(status: any(named: 'status')))
          .thenAnswer((_) async => const Success([]));

      await tester.pumpWidget(harness(const AdminOrdersPage()));
      await tester.pump();
      await tester.pump();

      expect(find.byType(FeedbackView), findsOneWidget);
      expect(find.text('No orders found'), findsOneWidget);
      expect(find.text('New orders will appear here as customers check out.'),
          findsOneWidget);
    });

    testWidgets('failed load renders an error, not a fake empty queue',
        (tester) async {
      when(() => repo.getAllOrders(status: any(named: 'status')))
          .thenAnswer((_) async => const Failure(AppError('offline')));

      await tester.pumpWidget(harness(const AdminOrdersPage()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('offline'), findsOneWidget);
      expect(find.text('No orders found'), findsNothing);
    });
    testWidgets('CSV export attaches the loaded queue as a real .csv file',
        (tester) async {
      final share = _RecordingShareService();
      when(() => repo.getAllOrders(status: any(named: 'status')))
          .thenAnswer((_) async => Success([
                _order('ORD-1', AdminOrderStatus.placed),
                _order('ORD-2', AdminOrderStatus.shipped),
              ]));

      await tester.pumpWidget(harness(AdminOrdersPage(shareService: share)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byTooltip('Export orders as CSV'));
      await tester.pump();

      expect(share.files, hasLength(1),
          reason: 'the export action must actually reach the share sheet');
      expect(share.shared, isEmpty,
          reason: 'a CSV is an attachment, not share-sheet body text');
      final file = share.files.single;
      expect(
          file.content,
          startsWith(
              'order_id,placed_at,status,items,total_minor,customer_name'));
      expect(file.content, contains('ORD-1'));
      expect(file.content, contains('ORD-2'));
      expect(file.fileName, endsWith('.csv'));
      expect(file.mimeType, 'text/csv',
          reason: 'spreadsheet apps pick the handler off the mime type');
    });

    testWidgets('CSV export follows the status filter, not the whole queue',
        (tester) async {
      final share = _RecordingShareService();
      when(() => repo.getAllOrders(status: any(named: 'status')))
          .thenAnswer((_) async => Success([
                _order('ORD-1', AdminOrderStatus.placed),
                _order('ORD-2', AdminOrderStatus.shipped),
              ]));

      await tester.pumpWidget(harness(AdminOrdersPage(shareService: share)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Placed'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byTooltip('Export orders as CSV'));
      await tester.pump();

      expect(share.files.single.content, contains('ORD-1'));
      expect(share.files.single.content, isNot(contains('ORD-2')),
          reason: 'the CSV must mirror the queue on screen');
    });

    testWidgets('CSV export is unavailable while the queue is empty',
        (tester) async {
      final share = _RecordingShareService();
      when(() => repo.getAllOrders(status: any(named: 'status')))
          .thenAnswer((_) async => const Success([]));

      await tester.pumpWidget(harness(AdminOrdersPage(shareService: share)));
      await tester.pump();
      await tester.pump();

      final button = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.share_outlined));
      expect(button.onPressed, isNull,
          reason: 'a header-only CSV is not worth offering');
      expect(share.files, isEmpty);
    });
  });

  group('AdminOrderDetailPage', () {
    testWidgets(
        'confirm acknowledges with a verified snackbar once the repository agrees',
        (tester) async {
      const orderId = 'order-0001-uuid';
      when(() => repo.getOrderDetails(orderId)).thenAnswer(
          (_) async => Success(_order(orderId, AdminOrderStatus.paid)));
      when(() => repo.updateOrderStatus(
            orderId,
            AdminOrderStatus.processing,
            trackingNumber: any(named: 'trackingNumber'),
          )).thenAnswer((_) async => const Success(null));
      when(() => repo.getAllOrders(status: any(named: 'status'))).thenAnswer(
          (_) async => Success([_order(orderId, AdminOrderStatus.processing)]));

      // Tall viewport: the customer card sits between the status card and
      // the fulfillment actions, so the default viewport hides Confirm.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(
        const AdminOrderDetailPage(orderId: orderId),
      ));
      await tester.pump();
      await tester.pump();

      // Was 'PAID' — the raw enum name shouted. The chip now renders the
      // localized label (admin_order_status_label.dart, owner decision part 34).
      expect(find.text('Paid'), findsOneWidget);

      await tester.tap(find.text('Confirm Order'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Order status updated to processing'), findsOneWidget,
          reason: 'the ack is earned by the repository result');
      expect(find.text('Processing'), findsOneWidget,
          reason: 'the status card reflects the transition immediately');
    });

    testWidgets('failed transition surfaces an error, never a success ack',
        (tester) async {
      const orderId = 'order-0002-uuid';
      when(() => repo.getOrderDetails(orderId)).thenAnswer(
          (_) async => Success(_order(orderId, AdminOrderStatus.paid)));
      when(() => repo.updateOrderStatus(
                orderId,
                AdminOrderStatus.processing,
                trackingNumber: any(named: 'trackingNumber'),
              ))
          .thenAnswer(
              (_) async => const Failure(AppError('transition rejected')));

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(
        const AdminOrderDetailPage(orderId: orderId),
      ));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Confirm Order'));
      await tester.pump();
      await tester.pump();

      expect(find.text('transition rejected'), findsOneWidget);
      expect(find.text('Order status updated to processing'), findsNothing);
    });

    testWidgets('shipping via dialog confirms with tracking number',
        (tester) async {
      const orderId = 'order-0003-uuid';
      when(() => repo.getOrderDetails(orderId)).thenAnswer(
          (_) async => Success(_order(orderId, AdminOrderStatus.processing)));
      when(() => repo.updateOrderStatus(
            orderId,
            AdminOrderStatus.shipped,
            trackingNumber: any(named: 'trackingNumber'),
          )).thenAnswer((_) async => const Success(null));
      when(() => repo.getAllOrders(status: any(named: 'status'))).thenAnswer(
          (_) async => Success([_order(orderId, AdminOrderStatus.shipped)]));

      // Tall viewport so the whole detail page fits without scrolling
      // (the project pattern used by experience_polish_test.dart).
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(
        const AdminOrderDetailPage(orderId: orderId),
      ));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Mark as Shipped'));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Tracking Number'),
        'EG-123',
      );
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump();

      verify(() => repo.updateOrderStatus(
            orderId,
            AdminOrderStatus.shipped,
            trackingNumber: 'EG-123',
          )).called(1);
      expect(find.text('Order status updated to shipped'), findsOneWidget);
    });

    testWidgets(
        'empty tracking number is rejected and typing clears the inline error',
        (tester) async {
      const orderId = 'order-0004-uuid';
      when(() => repo.getOrderDetails(orderId)).thenAnswer(
          (_) async => Success(_order(orderId, AdminOrderStatus.processing)));

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(
        const AdminOrderDetailPage(orderId: orderId),
      ));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Mark as Shipped'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Confirm with nothing typed: the shipment must be refused.
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump();

      expect(find.text('This field is required'), findsOneWidget,
          reason: 'the rejection is visible on the field, not silent');
      expect(find.text('Add Tracking Details'), findsOneWidget,
          reason: 'the dialog stays open instead of shipping a blank number');
      verifyNever(() => repo.updateOrderStatus(
            orderId,
            AdminOrderStatus.shipped,
            trackingNumber: any(named: 'trackingNumber'),
          ));

      // First keystroke clears the error; Confirm now ships.
      await tester.enterText(
        find.widgetWithText(TextField, 'Tracking Number'),
        '  EG-456  ',
      );
      await tester.pump();

      expect(find.text('This field is required'), findsNothing);

      when(() => repo.updateOrderStatus(
            orderId,
            AdminOrderStatus.shipped,
            trackingNumber: any(named: 'trackingNumber'),
          )).thenAnswer((_) async => const Success(null));
      when(() => repo.getAllOrders(status: any(named: 'status'))).thenAnswer(
          (_) async => Success([_order(orderId, AdminOrderStatus.shipped)]));

      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump();

      verify(() => repo.updateOrderStatus(
            orderId,
            AdminOrderStatus.shipped,
            trackingNumber: 'EG-456',
          )).called(1);
      expect(find.text('Order status updated to shipped'), findsOneWidget);
    });

    testWidgets('whitespace-only tracking number is also rejected',
        (tester) async {
      const orderId = 'order-0005-uuid';
      when(() => repo.getOrderDetails(orderId)).thenAnswer(
          (_) async => Success(_order(orderId, AdminOrderStatus.processing)));

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(
        const AdminOrderDetailPage(orderId: orderId),
      ));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Mark as Shipped'));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Tracking Number'),
        '   ',
      );
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump();

      expect(find.text('This field is required'), findsOneWidget,
          reason: 'blank-looking input must not ship either');
      expect(find.text('Add Tracking Details'), findsOneWidget);
      verifyNever(() => repo.updateOrderStatus(
            orderId,
            AdminOrderStatus.shipped,
            trackingNumber: any(named: 'trackingNumber'),
          ));
    });

    testWidgets('unknown order id offers a retry instead of dead-ending',
        (tester) async {
      const orderId = 'missing-0001';
      when(() => repo.getOrderDetails(orderId))
          .thenAnswer((_) async => const Success(null));

      await tester.pumpWidget(harness(
        const AdminOrderDetailPage(orderId: orderId),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Order not found'), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget,
          reason: 'a stale deep link must offer a way forward');
    });
  });

  group('AdminInventoryPage', () {
    const variant = LowStockVariant(
      variantId: 'v1',
      productName: 'Silk',
      size: '1m',
      color: 'Emerald',
      stock: 2,
    );

    testWidgets('stock update confirms only after the repository result lands',
        (tester) async {
      // The post-update reload must change the list (stock 7 is no longer
      // low) — an equal state would never reach the BlocListener.
      var lowStock = <LowStockVariant>[variant];
      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => Success(lowStock));
      when(() => repo.updateStock('v1', 7)).thenAnswer((_) async {
        lowStock = const [];
        return const Success(null);
      });

      await tester.pumpWidget(harness(const AdminInventoryPage()));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '7');
      await tester.tap(find.text('Update'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Stock updated'), findsOneWidget);
    });

    testWidgets('failed stock update reports the repository error',
        (tester) async {
      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => const Success([variant]));
      when(() => repo.updateStock('v1', 7))
          .thenAnswer((_) async => const Failure(AppError('write failed')));

      await tester.pumpWidget(harness(const AdminInventoryPage()));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '7');
      await tester.tap(find.text('Update'));
      await tester.pump();
      await tester.pump();

      // The error renders both as a full-screen state and as the
      // floating error snackbar.
      expect(find.text('write failed'), findsWidgets);
      expect(find.text('Stock updated'), findsNothing);
    });

    testWidgets('blank stock entry is rejected and a valid entry then commits',
        (tester) async {
      // The post-update reload must change the list (stock 7 is no longer
      // low) — an equal state never reaches the verified-ack listener.
      var lowStock = <LowStockVariant>[variant];
      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => Success(lowStock));
      when(() => repo.updateStock('v1', 7)).thenAnswer((_) async {
        lowStock = const [];
        return const Success(null);
      });

      await tester.pumpWidget(harness(const AdminInventoryPage()));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.pumpAndSettle();

      // Clear the prefilled "2" and commit the blank: refused, dialog open.
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Update'));
      await tester.pump();
      await tester.pump();

      expect(find.text('This field is required'), findsOneWidget,
          reason: 'a blank entry must be visible, never silently stock 0');
      expect(find.text('Update Stock'), findsOneWidget);
      verifyNever(() => repo.updateStock('v1', any()));

      // Typing a valid number clears the error and commits.
      await tester.enterText(find.byType(TextField), '7');
      await tester.pump();

      expect(find.text('This field is required'), findsNothing);

      await tester.tap(find.text('Update'));
      await tester.pump();
      await tester.pumpAndSettle();

      verify(() => repo.updateStock('v1', 7)).called(1);
      expect(find.text('Stock updated'), findsOneWidget);
      expect(find.text('Update Stock'), findsNothing,
          reason: 'a valid entry closes the dialog');
    });

    testWidgets(
        'non-numeric, whitespace-only, and negative stock entries are rejected',
        (tester) async {
      when(() => repo.getLowStockProducts(threshold: any(named: 'threshold')))
          .thenAnswer((_) async => const Success([variant]));

      await tester.pumpWidget(harness(const AdminInventoryPage()));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.pumpAndSettle();

      // enterText bypasses the numeric keyboard, which is exactly the
      // garbage path the parse guard exists for.
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.tap(find.text('Update'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Enter a valid number'), findsOneWidget);
      expect(find.text('Update Stock'), findsOneWidget);
      verifyNever(() => repo.updateStock('v1', any()));

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Update'));
      await tester.pump();
      await tester.pump();

      expect(find.text('This field is required'), findsOneWidget,
          reason: 'blank-looking input is treated as empty, not 0');
      verifyNever(() => repo.updateStock('v1', any()));

      // Negatives parse fine — the guard gives an immediate inline error
      // instead of a failed write against the DB's stock >= 0 CHECK.
      await tester.enterText(find.byType(TextField), '-3');
      await tester.tap(find.text('Update'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Stock cannot be negative'), findsOneWidget);
      verifyNever(() => repo.updateStock('v1', any()));
    });
  });

  group('AdminImageManagerPage', () {
    setUp(() {
      // Dependencies are constructor-injected now (audit P1); the getIt
      // registrations stay only for other locator-resolving widgets in
      // this harness.
      registerRepoInGetIt();
      if (getIt.isRegistered<StorageService>()) {
        getIt.unregister<StorageService>();
      }
      storage = _FakeStorageService();
      getIt.registerSingleton<StorageService>(storage);
    });

    testWidgets('empty gallery renders an inviting upload state',
        (tester) async {
      when(() => repo.getProductImagePaths('pid'))
          .thenAnswer((_) async => const Success([]));

      await tester.pumpWidget(harness(
        AdminImageManagerPage(
            productId: 'pid', repository: repo, storage: storage),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(FeedbackView), findsOneWidget);
      expect(find.text('No images yet'), findsOneWidget);
      expect(
        find.text(
            'Upload the first image so the product has a gallery on the store.'),
        findsOneWidget,
      );
    });

    testWidgets('load failure offers a retry that re-reads the gallery',
        (tester) async {
      when(() => repo.getProductImagePaths('pid'))
          .thenAnswer((_) async => const Failure(AppError('offline')));

      await tester.pumpWidget(harness(
        AdminImageManagerPage(
            productId: 'pid', repository: repo, storage: storage),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(FeedbackView), findsOneWidget);
      expect(find.text('offline'), findsOneWidget);

      // The retry must go back to the repository, not merely clear the
      // message: the second read has to land as a rendered tile.
      when(() => repo.getProductImagePaths('pid'))
          .thenAnswer((_) async => const Success(['product-images/pid/a.jpg']));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      verify(() => repo.getProductImagePaths('pid')).called(2);
      expect(find.byType(AppImage), findsOneWidget,
          reason: 'the retry re-reads the gallery instead of only clearing it');
      expect(find.text('offline'), findsNothing);
    });

    testWidgets('deleting an image confirms first, then confirms the outcome',
        (tester) async {
      when(() => repo.getProductImagePaths('pid'))
          .thenAnswer((_) async => const Success(['product-images/pid/a.jpg']));
      when(() => repo.adminSetProductImages('pid', any()))
          .thenAnswer((_) async => const Success(null));

      await tester.pumpWidget(harness(
        AdminImageManagerPage(
            productId: 'pid', repository: repo, storage: storage),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AppImage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pump();
      await tester.pumpAndSettle();

      // The single tap must not delete: the confirm dialog is up.
      expect(find.text('Delete image?'), findsOneWidget);
      verifyNever(() => repo.adminSetProductImages('pid', any()));

      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump();

      verify(() => repo.adminSetProductImages('pid', any())).called(1);
      expect(find.text('Image removed'), findsOneWidget);
      expect(find.byType(AppImage), findsNothing);
    });

    testWidgets('uploading picks, compresses, stores, and saves the gallery',
        (tester) async {
      // Audit 2026-09-13: the upload is real now — no dummy-bytes stub.
      when(() => repo.getProductImagePaths('pid'))
          .thenAnswer((_) async => const Success([]));
      when(() => repo.adminSetProductImages('pid', any()))
          .thenAnswer((_) async => const Success(null));
      final uploadedFileNames = <String>[];
      final uploadStorage = _UploadingStorageService(uploadedFileNames);

      await tester.pumpWidget(harness(
        AdminImageManagerPage(
          productId: 'pid',
          repository: repo,
          storage: uploadStorage,
          pickImage: (_) async => XFile.fromData(
            Uint8List.fromList(List.filled(300 * 1024, 1)),
            name: 'fabric.jpg',
            mimeType: 'image/jpeg',
          ),
          imageCompressor: _ShrinkCompressor(),
        ),
      ));
      await tester.pump();
      await tester.pump();

      // Two AppButtons render on the empty gallery (page upload +
      // FeedbackView action); the page's own upload button is first.
      await tester.tap(find.byType(AppButton).first);
      await tester.pump();
      await tester.pump();

      expect(uploadedFileNames, hasLength(1));
      expect(uploadedFileNames.single, endsWith('.jpg'));
      verify(() => repo.adminSetProductImages('pid', any())).called(1);
      expect(find.text('Image uploaded'), findsOneWidget);
    });
  });

  group('AdminOrderDetailPage membership tier control', () {
    // Detail row carrying the joined profile the tier control operates on.
    AdminOrder orderWithCustomer(String profileId, String tier) => AdminOrder(
          id: 'order-tier-1',
          status: AdminOrderStatus.paid,
          total: const Money.egp(100),
          placedAt: DateTime(2026),
          customerName: 'Sara Ali',
          customerId: profileId,
          customerTier: tier,
        );

    void registerTierStubs(String profileId) {
      when(() => repo.getOrderDetails('order-tier-1')).thenAnswer(
          (_) async => Success(orderWithCustomer(profileId, 'standard')));
      when(() => repo.setMembershipTier(profileId, 'premium'))
          .thenAnswer((_) async => const Success(null));
    }

    testWidgets('premium customer renders the gold badge and Change control',
        (tester) async {
      when(() => repo.getOrderDetails('order-tier-1')).thenAnswer(
          (_) async => Success(orderWithCustomer('profile-9', 'premium')));

      await tester.pumpWidget(
        harness(const AdminOrderDetailPage(orderId: 'order-tier-1')),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Sara Ali'), findsOneWidget);
      expect(find.text('Premium Member'), findsOneWidget);
      expect(find.text('Standard Member'), findsNothing);
      expect(find.byIcon(Icons.workspace_premium), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets(
        'changing to premium updates the card and confirms after repository success',
        (tester) async {
      registerTierStubs('profile-9');

      await tester.pumpWidget(
        harness(const AdminOrderDetailPage(orderId: 'order-tier-1')),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      // The radio lives in the dialog; a plain text find would also match
      // the card badge underneath. (byType(RadioListTile) would miss:
      // runtimeType is RadioListTile<String>, and byType is exact.)
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Premium Member'),
      ));
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      // Settle the dialog's exit animation fully so the badge is asserted
      // without the (still-animating) dialog duplicating its text.
      await tester.pumpAndSettle();

      verify(() => repo.setMembershipTier('profile-9', 'premium')).called(1);
      expect(find.text('Premium Member'), findsOneWidget);
      expect(find.text('Membership tier updated'), findsOneWidget,
          reason: 'the ack is earned by the repository result');
    });

    testWidgets('failed tier change surfaces an error, never a success ack',
        (tester) async {
      registerTierStubs('profile-9');
      when(() => repo.setMembershipTier('profile-9', 'premium')).thenAnswer(
          (_) async => const Failure(AppError('tier change rejected')));

      await tester.pumpWidget(
        harness(const AdminOrderDetailPage(orderId: 'order-tier-1')),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Premium Member'));
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump();

      expect(find.text('tier change rejected'), findsOneWidget);
      expect(find.text('Membership tier updated'), findsNothing);
    });

    testWidgets('no Change control without a joined profile id',
        (tester) async {
      when(() => repo.getOrderDetails('order-tier-1'))
          .thenAnswer((_) async => Success(AdminOrder(
                id: 'order-tier-1',
                status: AdminOrderStatus.paid,
                total: const Money.egp(100),
                placedAt: DateTime(2026),
                customerName: 'Name Only',
              )));

      await tester.pumpWidget(
        harness(const AdminOrderDetailPage(orderId: 'order-tier-1')),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Change'), findsNothing,
          reason: 'the RPC would have nothing to address');
    });
  });
}
