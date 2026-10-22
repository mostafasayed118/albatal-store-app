import 'package:al_batal_elite/features/storefront/presentation/cubit/reviews_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/reviews/review_submit_sheet.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

/// A picker that blows up (web/tests, permission denied) must degrade to a
/// text-only review instead of taking the sheet down with it.
Future<XFile?> _throwingPicker() async => throw Exception('picker unavailable');

void main() {
  testWidgets('a picker that throws keeps the sheet usable', (tester) async {
    final cubit = ReviewsCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(
            body: ReviewSubmitSheet(pickImage: _throwingPicker),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Photo attached'), findsNothing);
    expect(find.text('Add photo'), findsOneWidget);
    // The form is still alive — the submit action is reachable.
    expect(find.text('Submit'), findsOneWidget);
  });
}
