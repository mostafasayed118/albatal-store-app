import 'package:al_batal_elite/features/payments/presentation/widgets/instapay_proof_form.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

InstapayProofForm _form({
  required TextEditingController controller,
  bool hasAttachment = false,
  String? attachedFileName,
  bool submitted = false,
  bool submitting = false,
  VoidCallback? onPickScreenshot,
  VoidCallback? onSubmitProof,
}) =>
    InstapayProofForm(
      referenceController: controller,
      maxReferenceLength: 64,
      hasAttachment: hasAttachment,
      attachedFileName: attachedFileName,
      submitted: submitted,
      submitting: submitting,
      onPickScreenshot: onPickScreenshot ?? () {},
      onSubmitProof: onSubmitProof ?? () {},
    );

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  testWidgets('initial state renders the reference field and a disabled submit',
      (tester) async {
    await tester.pumpWidget(_wrap(_form(controller: controller)));

    expect(find.text('Transfer reference (optional)'), findsOneWidget);
    expect(find.text('Attach transfer screenshot'), findsOneWidget);
    expect(find.byIcon(Icons.upload_file), findsOneWidget);
    expect(find.text('Submit proof for review'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, 64);
    expect(field.controller, same(controller));

    final submit = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(submit.onPressed, isNull);
  });

  testWidgets('typing into the reference field updates the shared controller',
      (tester) async {
    await tester.pumpWidget(_wrap(_form(controller: controller)));

    await tester.enterText(find.byType(TextField), 'op-1234');
    await tester.pump();

    expect(controller.text, 'op-1234');
  });

  testWidgets(
      'attached state shows the check icon, file name and enables submit',
      (tester) async {
    var submitted = 0;
    await tester.pumpWidget(_wrap(_form(
      controller: controller,
      hasAttachment: true,
      attachedFileName: 'proof.png',
      onSubmitProof: () => submitted++,
    )));

    expect(find.text('Screenshot attached'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('proof.png'), findsOneWidget);

    final submit = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(submit.onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    expect(submitted, 1);
  });

  testWidgets('tapping the attach button invokes its callback', (tester) async {
    var picked = 0;
    await tester.pumpWidget(_wrap(_form(
      controller: controller,
      onPickScreenshot: () => picked++,
    )));

    await tester.tap(find.text('Attach transfer screenshot'));
    expect(picked, 1);
  });

  testWidgets('submitting state shows a spinner and disables submit',
      (tester) async {
    await tester.pumpWidget(_wrap(_form(
      controller: controller,
      hasAttachment: true,
      submitting: true,
    )));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final submit = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(submit.onPressed, isNull);
  });

  testWidgets('submitted state shows the pending-review note only',
      (tester) async {
    await tester.pumpWidget(_wrap(_form(
      controller: controller,
      hasAttachment: true,
      attachedFileName: 'proof.png',
      submitted: true,
    )));

    expect(
      find.text(
        'Your payment stays pending until we review the proof. You can safely '
        'leave this page — the status appears in your orders.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);

    final attach = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(attach.onPressed, isNull);
  });
}
