import 'package:al_batal_elite/features/storefront/presentation/widgets/quantity_stepper.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_ar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit 2026-09-19, sweep part 32 (Tier 2): the stepper's *visible* tooltips were
/// localized while its `CustomSemanticsAction` labels were hardcoded English, so
/// screen-reader users heard "Increase"/"Decrease" in an Arabic session.
///
/// The pin reads the labels off the semantics tree rather than off the widget's
/// source, because that is the copy assistive tech actually announces.
Widget _harness(
        {Locale? locale, int quantity = 2, int min = 1, int max = 99}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: QuantityStepper(
            quantity: quantity,
            min: min,
            max: max,
            onChanged: (_) {},
          ),
        ),
      ),
    );

/// The labels of the custom actions exposed on the stepper's semantics node.
List<String> _spokenActions(WidgetTester tester) {
  final data =
      tester.getSemantics(find.byType(QuantityStepper)).getSemanticsData();
  return (data.customSemanticsActionIds ?? const <int>[])
      .map((id) => CustomSemanticsAction.getAction(id)!.label!)
      .toList();
}

void main() {
  testWidgets('spoken actions are English copy in EN', (tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('en')));

    expect(_spokenActions(tester),
        containsAll(<String>[_en.increaseQuantity, _en.decreaseQuantity]));
  });

  testWidgets('spoken actions are Arabic copy in AR, not English',
      (tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('ar')));

    final spoken = _spokenActions(tester);
    expect(spoken,
        containsAll(<String>[_ar.increaseQuantity, _ar.decreaseQuantity]));
    // The assertion that encodes the defect: nothing announced stays English.
    expect(spoken, isNot(contains(_en.increaseQuantity)));
    expect(spoken, isNot(contains(_en.decreaseQuantity)));
  });

  testWidgets('an unavailable action is not announced at either bound',
      (tester) async {
    // At min=max=2 there is nowhere to go, so the stepper must expose no actions
    // — a localized label on an impossible action would still be a bug.
    await tester.pumpWidget(
        _harness(locale: const Locale('ar'), quantity: 2, min: 2, max: 2));
    expect(_spokenActions(tester), isEmpty);

    // At the lower bound only "increase" remains reachable.
    await tester.pumpWidget(_harness(locale: const Locale('ar'), quantity: 1));
    expect(_spokenActions(tester), <String>[_ar.increaseQuantity]);
  });
}

final _en = AppLocalizationsEn();
final _ar = AppLocalizationsAr();
