import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/presentation/widgets/product_edit_form.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<TextEditingController> controllers;
  late GlobalKey<FormState> formKey;

  String? categorySelection;

  setUp(() {
    formKey = GlobalKey<FormState>();
    categorySelection = null;
    controllers = List<TextEditingController>.generate(
      10,
      (_) => TextEditingController(),
    );
  });

  tearDown(() {
    for (final controller in controllers) {
      controller.dispose();
    }
  });

  Widget harness({
    bool sellByLength = false,
    bool loadingCategories = false,
    List<AdminCategory> categories = const [],
    bool submitting = false,
    bool loadingProduct = false,
  }) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: AdminProductEditForm(
                nameCtrl: controllers[0],
                slugCtrl: controllers[1],
                descriptionCtrl: controllers[2],
                compositionCtrl: controllers[3],
                careCtrl: controllers[4],
                originCtrl: controllers[5],
                widthCtrl: controllers[6],
                gsmCtrl: controllers[7],
                priceCtrl: controllers[8],
                minCutCtrl: controllers[9],
                loadingCategories: loadingCategories,
                categories: categories,
                selectedCategoryId: categorySelection,
                onCategoryChanged: (value) => categorySelection = value,
                sellByLength: sellByLength,
                onSellByLengthChanged: (_) {},
                isActive: true,
                onActiveChanged: (_) {},
                submitting: submitting,
                loadingProduct: loadingProduct,
                isCreate: true,
                onSubmit: () {},
              ),
            ),
          ),
        ),
      );

  testWidgets('empty name, slug, category, and malformed price fail validation',
      (tester) async {
    controllers[8].text = 'abc';
    await tester.pumpWidget(harness());

    final valid = formKey.currentState!.validate();
    await tester.pump();

    expect(valid, isFalse);
    expect(find.text('Required'), findsNWidgets(3));
    expect(find.text('Invalid number'), findsOneWidget);
  });

  testWidgets('an empty price fails with the required copy', (tester) async {
    await tester.pumpWidget(harness());

    final valid = formKey.currentState!.validate();
    await tester.pump();

    expect(valid, isFalse);
    expect(find.text('Required'), findsNWidgets(4));
    expect(find.text('Invalid number'), findsNothing);
  });

  testWidgets('the category spinner replaces the dropdown while loading',
      (tester) async {
    await tester.pumpWidget(harness(loadingCategories: true));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('sell-by-length reveals the minimum-cut field', (tester) async {
    await tester.pumpWidget(harness(
      sellByLength: true,
      categories: const [
        AdminCategory(id: 'c-1', name: 'Silk', isActive: true),
      ],
    ));

    expect(find.text('Minimum cut (meters)'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(10));
  });

  testWidgets('submitting or loading the product replaces the save button',
      (tester) async {
    await tester.pumpWidget(harness(submitting: true));
    expect(find.text('Create Product'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpWidget(harness(loadingProduct: true));
    expect(find.text('Create Product'), findsNothing);
  });
}
