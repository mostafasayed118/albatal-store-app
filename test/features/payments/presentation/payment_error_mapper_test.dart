import 'package:al_batal_elite/features/payments/presentation/payment_error_mapper.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known codes map, unknown falls back', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(paymentMessageForCode(l10n, 'payment_not_pending', 'RAW'), isNot('RAW'));
    expect(paymentMessageForCode(l10n, null, 'RAW'), 'RAW');
    expect(paymentMessageForCode(l10n, 'no_such_code', 'RAW'), 'RAW');
  });
}
