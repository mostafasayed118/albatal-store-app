import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/coupon_discount.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/coupons_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/checkout_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/checkout/coupon_card.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/checkout/shipping_address_card.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/extensions/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _selectedAddress = Address(
  id: 'addr-1',
  recipient: 'Sara Ahmed',
  phone: '01012345678',
  line: '45 Nile Corniche',
  city: 'Cairo',
  country: 'Egypt',
);

const _otherAddress = Address(
  id: 'addr-2',
  recipient: 'Omar Hassan',
  phone: '01098765432',
  line: '7 Pyramid Road',
  city: 'Giza',
  country: 'Egypt',
);

const _phoneLessAddress = Address(
  id: 'legacy-1',
  recipient: 'Legacy Customer',
  line: '12 Nile Street',
  city: 'Giza',
  country: 'Egypt',
);

/// The cards never place an order in these tests; the stub only satisfies
/// the cubit's constructor.
final class _NoopCheckoutRepository implements CheckoutRepository {
  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required Address? address,
    String? couponCode,
    String? idempotencyKey,
  }) async =>
      throw UnimplementedError('not used');
}

final class _ScriptedCoupons implements CouponsRepository {
  _ScriptedCoupons(this.result);

  final Result<CouponDiscount> result;

  @override
  Future<Result<CouponDiscount>> validate(String code) async => result;
}

final class _RecordingAddressRepository implements AddressRepository {
  _RecordingAddressRepository(this._addresses);

  List<Address> _addresses;
  final List<List<Address>> writes = [];

  @override
  Future<Result<List<Address>>> read() async => Success(List.of(_addresses));

  @override
  Future<Result<void>> save(List<Address> addresses) async {
    writes.add(List.of(addresses));
    _addresses = List.of(addresses);
    return const Success(null);
  }
}

Widget _harness({
  required Widget child,
  required CheckoutCubit checkout,
  required AddressesCubit addresses,
}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: checkout),
          BlocProvider.value(value: addresses),
        ],
        child: Builder(
          builder: (context) => Scaffold(body: child),
        ),
      ),
    );

Widget _couponCard(CheckoutCubit checkout, AddressesCubit addresses) =>
    _harness(
      checkout: checkout,
      addresses: addresses,
      child: Builder(
        builder: (context) => CheckoutCouponCard(l10n: context.l10n),
      ),
    );

Widget _shippingCard({
  required CheckoutCubit checkout,
  required AddressesCubit addresses,
  required Address? selected,
  bool hasError = false,
  bool needsPhone = false,
}) =>
    _harness(
      checkout: checkout,
      addresses: addresses,
      child: Builder(
        builder: (context) => CheckoutShippingAddressCard(
          l10n: context.l10n,
          scheme: Theme.of(context).colorScheme,
          selectedAddress: selected,
          hasError: hasError,
          needsPhone: needsPhone,
        ),
      ),
    );

const _kAppliedText =
    'Coupon applied — the discount is confirmed by the server when you place '
    'the order.';

void main() {
  late _RecordingAddressRepository addressRepo;
  late AddressesCubit addresses;

  setUp(() {
    addressRepo = _RecordingAddressRepository(const []);
    addresses = AddressesCubit(addressRepo);
  });

  tearDown(() async => addresses.close());

  group('CheckoutCouponCard', () {
    testWidgets('applies a coupon, then removes it and re-enables the field',
        (tester) async {
      final checkout = CheckoutCubit(
        _NoopCheckoutRepository(),
        coupons: _ScriptedCoupons(
          const Success(CouponDiscount(code: 'SILK10', discountMinor: 500)),
        ),
      );
      addTearDown(checkout.close);

      await tester.pumpWidget(_couponCard(checkout, addresses));

      await tester.enterText(find.byType(TextField), 'silk10');
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(checkout.state.appliedCoupon?.code, 'SILK10');
      expect(find.text(_kAppliedText), findsOneWidget);
      // The entry field locks while a coupon is attached.
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await tester.tap(find.byTooltip('Remove coupon'));
      await tester.pump();

      expect(checkout.state.appliedCoupon, isNull);
      expect(find.text(_kAppliedText), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
    });

    testWidgets('an invalid code renders the localized rejection',
        (tester) async {
      final checkout = CheckoutCubit(
        _NoopCheckoutRepository(),
        coupons: _ScriptedCoupons(const Failure(AppError(kCouponInvalid))),
      );
      addTearDown(checkout.close);

      await tester.pumpWidget(_couponCard(checkout, addresses));
      await tester.enterText(find.byType(TextField), 'NOPE');
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(find.text('This coupon code is not valid.'), findsOneWidget);
    });

    testWidgets('an unavailable backend renders the unavailable copy',
        (tester) async {
      final checkout = CheckoutCubit(
        _NoopCheckoutRepository(),
        coupons: _ScriptedCoupons(const Failure(AppError(kCouponUnavailable))),
      );
      addTearDown(checkout.close);

      await tester.pumpWidget(_couponCard(checkout, addresses));
      await tester.enterText(find.byType(TextField), 'SILK10');
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(find.text('Coupons are unavailable right now.'), findsOneWidget);
    });

    testWidgets('an unknown outcome code falls back to the applied copy',
        (tester) async {
      final checkout = CheckoutCubit(
        _NoopCheckoutRepository(),
        coupons: _ScriptedCoupons(const Failure(AppError('coupon_other'))),
      );
      addTearDown(checkout.close);

      await tester.pumpWidget(_couponCard(checkout, addresses));
      await tester.enterText(find.byType(TextField), 'SILK10');
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(find.text(_kAppliedText), findsOneWidget);
    });
  });

  group('CheckoutShippingAddressCard', () {
    testWidgets('a validation error explains the missing address',
        (tester) async {
      final checkout = CheckoutCubit(_NoopCheckoutRepository());
      addTearDown(checkout.close);

      await tester.pumpWidget(_shippingCard(
        checkout: checkout,
        addresses: addresses,
        selected: null,
        hasError: true,
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Please select a shipping address'), findsOneWidget);
    });

    testWidgets('picking a saved address selects it in the checkout cubit',
        (tester) async {
      addressRepo =
          _RecordingAddressRepository(const [_selectedAddress, _otherAddress]);
      await addresses.close();
      addresses = AddressesCubit(addressRepo);
      await addresses.load();

      final checkout = CheckoutCubit(_NoopCheckoutRepository());
      addTearDown(checkout.close);

      await tester.pumpWidget(_shippingCard(
        checkout: checkout,
        addresses: addresses,
        selected: null,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Omar Hassan'));
      await tester.pump();

      expect(checkout.state.selectedAddress?.id, 'addr-2');
    });

    testWidgets('adding a new address selects it and persists it',
        (tester) async {
      final checkout = CheckoutCubit(_NoopCheckoutRepository());
      addTearDown(checkout.close);

      await tester.pumpWidget(_shippingCard(
        checkout: checkout,
        addresses: addresses,
        selected: null,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Address'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Full Name'), 'Nour Adel');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Phone number'), '01011112222');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Street address'), '10 Tahrir Sq');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'City'), 'Cairo');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Country'), 'Egypt');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(checkout.state.selectedAddress?.recipient, 'Nour Adel');
      expect(
        addresses.state.addresses.map((a) => a.recipient),
        contains('Nour Adel'),
      );
      expect(addressRepo.writes, isNotEmpty);
    });

    testWidgets('completing the missing phone updates the selection and book',
        (tester) async {
      addressRepo = _RecordingAddressRepository(const [_phoneLessAddress]);
      await addresses.close();
      addresses = AddressesCubit(addressRepo);
      await addresses.load();

      final checkout = CheckoutCubit(_NoopCheckoutRepository());
      addTearDown(checkout.close);

      await tester.pumpWidget(_shippingCard(
        checkout: checkout,
        addresses: addresses,
        selected: _phoneLessAddress,
        needsPhone: true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add phone number'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Phone number'), '01012345678');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(checkout.state.selectedAddress?.phone, '01012345678');
      final saved = addresses.state.addresses
          .firstWhere((a) => a.id == _phoneLessAddress.id);
      expect(saved.phone, '01012345678');
      // Editing keeps the identity — no duplicate row is minted.
      expect(addresses.state.addresses, hasLength(1));
      expect(addressRepo.writes, isNotEmpty);
    });
  });
}
