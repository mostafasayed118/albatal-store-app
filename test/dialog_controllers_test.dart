import 'package:al_batal_elite/features/admin/presentation/widgets/dialog_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host extends StatefulWidget {
  const _Host({required this.onReady});

  final ValueChanged<TextEditingController> onReady;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with DialogControllers {
  @override
  void initState() {
    super.initState();
    widget.onReady(newDialogController('seed'));
  }

  @override
  void dispose() {
    disposeDialogControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('DialogControllers (audit P5)', () {
    testWidgets('disposes registered controllers with the page',
        (tester) async {
      late TextEditingController controller;
      await tester.pumpWidget(
        MaterialApp(home: _Host(onReady: (c) => controller = c)),
      );
      expect(controller.text, 'seed');

      // Unmount the page: controllers must be freed, not leak.
      // Attaching a listener to a disposed controller throws.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(() => controller.addListener(() {}), throwsFlutterError);
    });

    testWidgets('supports seeded text for edit dialogs', (tester) async {
      late TextEditingController controller;
      await tester.pumpWidget(
        MaterialApp(home: _Host(onReady: (c) => controller = c)),
      );
      expect(controller.text, 'seed');
    });
  });
}
