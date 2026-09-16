import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_coupon.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_coupons_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_coupons_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/app_button.dart';
import 'package:al_batal_elite/shared/components/feedback_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdminRepository extends Mock implements AdminRepository {}

Widget _harness(AdminCouponsCubit cubit) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminCouponsPage(cubit: cubit),
    );

void main() {
  testWidgets('error state offers a retry that reloads the coupon list',
      (WidgetTester tester) async {
    final repo = _MockAdminRepository();
    when(() => repo.fetchCoupons())
        .thenAnswer((_) async => const Failure(AppError('offline')));

    await tester.pumpWidget(_harness(AdminCouponsCubit(repository: repo)));
    await tester.pump();
    await tester.pump();

    expect(find.byType(FeedbackView), findsOneWidget,
        reason: 'a failed load renders the shared status view');
    expect(find.text('offline'), findsOneWidget);

    // The retry must go back through the repository, not merely clear the
    // message: the second read has to land as rendered rows.
    when(() => repo.fetchCoupons()).thenAnswer((_) async => const Success([
          AdminCoupon(
              id: 'c1', code: 'EID25', discountMinor: 1000, active: true),
        ]));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    verify(() => repo.fetchCoupons()).called(2);
    expect(find.text('EID25'), findsOneWidget);
    expect(find.text('offline'), findsNothing);
  });

  testWidgets('empty list renders the empty state without a second add control',
      (WidgetTester tester) async {
    final repo = _MockAdminRepository();
    when(() => repo.fetchCoupons()).thenAnswer((_) async => const Success([]));

    await tester.pumpWidget(_harness(AdminCouponsCubit(repository: repo)));
    await tester.pump();
    await tester.pump();

    expect(find.byType(FeedbackView), findsOneWidget);
    expect(
      tester.widget<FeedbackView>(find.byType(FeedbackView)).type,
      FeedbackViewType.empty,
    );
    expect(find.byType(AppButton), findsNothing,
        reason:
            'the create-coupon FAB owns the action, so no CTA duplicates it');
  });
}
