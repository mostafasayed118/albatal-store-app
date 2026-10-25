import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/admin/domain/entities/instapay_proof.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InstapayProof.tryFromRow', () {
    test('maps the RPC row with integer minor units and a trimmed reference',
        () {
      final proof = InstapayProof.tryFromRow({
        'proof_id': 'proof-1',
        'payment_id': 'pay-1',
        'order_id': 'abcdefgh-1234',
        'order_total': 150000,
        'customer_name': '  Mona Hassan  ',
        'reference': '  TRX-9911  ',
        'storage_path': 'proofs/p1.jpg',
        'created_at': '2026-10-25T11:30:00Z',
      });

      expect(proof, isNotNull);
      expect(proof!.proofId, 'proof-1');
      expect(proof.paymentId, 'pay-1');
      expect(proof.orderId, 'abcdefgh-1234');
      expect(proof.total, const Money(150000),
          reason: 'order_total is already minor units — no /100 conversion');
      expect(proof.total.minorUnits, 150000);
      expect(proof.customerName, 'Mona Hassan');
      expect(proof.reference, 'TRX-9911');
      expect(proof.storagePath, 'proofs/p1.jpg');
      expect(proof.createdAt, DateTime.utc(2026, 10, 25, 11, 30));
      expect(proof.hasProofFile, isTrue);
      expect(proof.shortOrderId, 'abcdefgh');
    });

    test('a blank customer name falls back to the short order handle', () {
      final proof = InstapayProof.tryFromRow({
        'proof_id': 'proof-1',
        'order_id': '0123456789abcdef',
        'order_total': 100,
        'customer_name': '   ',
        'storage_path': '',
        'created_at': '2026-10-25T11:30:00Z',
      });

      expect(proof, isNotNull);
      expect(proof!.customerName, '01234567');
      expect(proof.shortOrderId, '01234567');
      expect(proof.hasProofFile, isFalse);
    });

    test('missing/blank optional fields degrade instead of throwing', () {
      final proof = InstapayProof.tryFromRow({
        'proof_id': 'proof-1',
        'order_id': 'short',
        'order_total': 99875,
        'customer_name': 42,
        'reference': '   ',
        'storage_path': null,
        'created_at': '2026-10-25T11:30:00Z',
      });

      expect(proof, isNotNull);
      expect(proof!.customerName, 'short',
          reason: 'a mistyped name is absent, so the order handle shows');
      expect(proof.reference, isNull,
          reason: 'spaces-only references are absent, not empty strings');
      expect(proof.storagePath, '');
      expect(proof.total, const Money(99875),
          reason: 'fractional piasters are preserved');
    });

    test('a numeric string for the total is malformed, not coerced', () {
      final proof = InstapayProof.tryFromRow({
        'proof_id': 'proof-1',
        'order_id': 'order-1',
        'order_total': '150000',
        'created_at': '2026-10-25T11:30:00Z',
      });

      expect(proof, isNull,
          reason: 'a mistyped total cannot be trusted as the amount to verify');
    });

    test('rows that cannot be reviewed are rejected', () {
      final base = <String, dynamic>{
        'proof_id': 'proof-1',
        'order_id': 'order-1',
        'order_total': 100,
        'created_at': '2026-10-25T11:30:00Z',
      };

      for (final missing in ['proof_id', 'order_id', 'order_total']) {
        final row = Map<String, dynamic>.from(base)..remove(missing);
        expect(InstapayProof.tryFromRow(row), isNull,
            reason: 'a row without $missing cannot be reviewed or read');
      }

      expect(
        InstapayProof.tryFromRow(
            Map<String, dynamic>.from(base)..['order_total'] = -1),
        isNull,
        reason: 'Money asserts non-negative minor units',
      );
      expect(
        InstapayProof.tryFromRow(
            Map<String, dynamic>.from(base)..['created_at'] = 'not a date'),
        isNull,
        reason: 'an epoch fallback would lie about when the proof arrived',
      );
    });
  });
}
