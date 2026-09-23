import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/checkout_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/checkout/shipping_address_card.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/extensions/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX-003 closure for rows saved before the phone field existed: a COD order
/// needs a callable number, so the checkout must not let a phone-less
/// address through silently — it says why and offers the fix in place.
const _phoneLess = Address(
  id: 'legacy-1',
  recipient: 'Legacy Customer',
  line: '12 Nile Street',
  city: 'Giza',
  country: 'Egypt',
);

const _complete = Address(
  id: 'addr-2',
  recipient: 'Sara Ahmed',
  phone: '01012345678',
  line: '45 Nile Corniche',
  city: 'Cairo',
  country: 'Egypt',
);

class _StubAddressRepository implements AddressRepository {
  _StubAddressRepository(this._addresses);
  final List<Address> _addresses;
  @override
  Future<Result<List<Address>>> read() async => Success(_addresses);
  @override
  Future<Result<void>> save(List<Address> addresses) async =>
      const Success(null);
}

/// The card never places an order in these tests; the stub only satisfies
/// the cubit's constructor.
class _StubCheckoutRepository implements CheckoutRepository {
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

Widget _harness({
  required Address? selected,
  required bool needsPhone,
  List<Address> book = const [],
}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
              create: (_) =>
                  AddressesCubit(_StubAddressRepository(book))..load()),
          BlocProvider(create: (_) => CheckoutCubit(_StubCheckoutRepository())),
        ],
        child: Builder(
          builder: (context) => Scaffold(
            body: CheckoutShippingAddressCard(
              l10n: context.l10n,
              scheme: Theme.of(context).colorScheme,
              selectedAddress: selected,
              hasError: false,
              needsPhone: needsPhone,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a phone-less selected address is flagged with a fix action',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        _harness(selected: _phoneLess, needsPhone: true, book: [_phoneLess]));
    await tester.pumpAndSettle();

    expect(find.text('Add a phone number so the courier can reach you'),
        findsOneWidget);
    expect(find.text('Add phone number'), findsOneWidget);
  });

  testWidgets('a complete address shows no warning',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        _harness(selected: _complete, needsPhone: false, book: [_complete]));
    await tester.pumpAndSettle();

    expect(find.text('Add a phone number so the courier can reach you'),
        findsNothing);
    expect(find.text('Add phone number'), findsNothing);
  });

  testWidgets('the fix action opens the shared form, prefilled, in edit mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        _harness(selected: _phoneLess, needsPhone: true, book: [_phoneLess]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add phone number'));
    await tester.pumpAndSettle();

    // Same form as the address book, in edit mode: the identity is carried,
    // so completing the phone updates the existing row instead of adding a
    // duplicate address.
    expect(find.text('Edit address'), findsOneWidget);
    expect(find.text('Legacy Customer'), findsWidgets);
    expect(find.text('Save'), findsOneWidget);
  });
}
