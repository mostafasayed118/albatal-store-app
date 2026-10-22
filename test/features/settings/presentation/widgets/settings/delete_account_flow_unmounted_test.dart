import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/settings/domain/account_deletion_port.dart';
import 'package:al_batal_elite/features/settings/presentation/widgets/settings/delete_account_flow.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Port implements AccountDeletionPort {
  @override
  bool get isAuthenticated => true;

  @override
  Future<Result<void>> deleteAccount({required String email}) async =>
      const Success(null);

  @override
  void clearGuestData() {}
}

void main() {
  testWidgets('a context unmounted before the settled frame disposes safely',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (c) {
        context = c;
        return const Scaffold(body: SizedBox.shrink());
      }),
    ));

    final pending = confirmDeleteAccount(context, _Port());

    // Unmount the page before `endOfFrame` resumes the dialog flow: the
    // function must dispose its controllers and return without touching a
    // dead context or showing a dialog.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    await pending;

    expect(find.byType(AlertDialog), findsNothing);
  });
}
