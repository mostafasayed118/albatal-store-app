import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the client ↔ database contract for the admin low-stock RPC.
///
/// `AdminMappers.lowStockVariantFromRow` requires every
/// `get_low_stock_products` row to carry the variant id
/// (`product_variants.id`) — it is what the Inventory page feeds back
/// into `updateStock()`, and rows without it are skipped as unmappable.
///
/// Migration 043 added the missing `id UUID` column (before it, every
/// row was dropped and the Inventory page always claimed "All stock
/// levels are healthy"). This test fails if a future migration
/// redefines the function and silently drops the column again.
///
/// Assumes the `NNNN_` zero-padded migration naming convention, so
/// lexicographic file order equals application order and the LAST
/// definition of the function across migrations is the deployed shape.
void main() {
  test(
      'get_low_stock_products (latest definition) returns the variant id column',
      () {
    final migrationsDir = Directory('supabase/migrations');
    expect(migrationsDir.existsSync(), isTrue,
        reason:
            'supabase/migrations/ not found — contract tests must run from the repo root');

    const marker = 'CREATE OR REPLACE FUNCTION get_low_stock_products';
    String? latestDefinition;
    String? latestFile;

    final files = migrationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final text = file.readAsStringSync();
      final start = text.indexOf(marker);
      if (start != -1) {
        latestDefinition = text.substring(start);
        latestFile = file.path;
      }
    }

    expect(latestDefinition, isNotNull,
        reason:
            'get_low_stock_products not found in any migration under supabase/migrations/');

    // The contract: the RETURNS TABLE clause (up to the function body)
    // must declare the variant id column.
    final returnsStart = latestDefinition!.indexOf('RETURNS TABLE');
    expect(returnsStart, isNot(-1),
        reason: 'get_low_stock_products lost its RETURNS TABLE clause');

    final bodyStart = latestDefinition.indexOf('AS \$\$');
    expect(bodyStart, greaterThan(returnsStart),
        reason: 'Malformed function definition in $latestFile');

    final returnsClause = latestDefinition.substring(returnsStart, bodyStart);
    expect(returnsClause, contains('id UUID'),
        reason: 'The latest get_low_stock_products definition '
            '(in $latestFile) no longer RETURNS `id UUID`. '
            'AdminMappers.lowStockVariantFromRow drops id-less rows, so the '
            'admin Inventory page would silently render "All stock levels are '
            'healthy" again. See migration 043 for the contract.');
  });

  test(
      'product_variants.price_override is CHECK-guarded (latest migration state)',
      () {
    final migrationsDir = Directory('supabase/migrations');
    expect(migrationsDir.existsSync(), isTrue,
        reason:
            'supabase/migrations/ not found — contract tests must run from the repo root');

    const constraint = 'product_variants_price_override_check';

    final files = migrationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    // Track the constraint's lifecycle in application order: the last
    // operation must be an ADD. A later file that only DROPs the
    // constraint (without re-adding it) fails here, not in production.
    String? latestAddFile;
    String? latestDropFile;
    for (final file in files) {
      final text = file.readAsStringSync();
      if (text.contains('ADD CONSTRAINT') && text.contains(constraint)) {
        latestAddFile = file.path;
      } else if (text.contains('DROP CONSTRAINT') &&
          text.contains(constraint)) {
        latestDropFile = file.path;
      }
    }

    expect(latestAddFile, isNotNull,
        reason: 'product_variants_price_override_check not found in any '
            'migration — the price_override column is unguarded.');
    expect(latestDropFile, isNull,
        reason: 'product_variants_price_override_check was dropped in '
            '$latestDropFile and never re-added. Negative and zero override '
            'prices would persist again and win over base_price at display '
            'time. See migration 044 for the contract.');

    // The contract: the constraint must reject everything but NULL and
    // strictly positive prices (mirrors products.base_price from 001).
    final addText = File(latestAddFile!).readAsStringSync();
    final addStart = addText.indexOf('ADD CONSTRAINT $constraint');
    final statementEnd = addText.indexOf(';', addStart);
    expect(statementEnd, greaterThan(addStart),
        reason: 'Malformed constraint statement in $latestAddFile');
    final checkExpression = addText.substring(addStart, statementEnd);
    expect(checkExpression,
        contains('price_override IS NULL OR price_override > 0'),
        reason: 'The product_variants_price_override_check defined in '
            '$latestAddFile no longer rejects negative and zero override '
            'prices. admin_upsert_variant would persist them again — they '
            'win over base_price at display time. See migration 044.');
  });

  test('customer-side numeric CHECKs survive migration rewrites', () {
    final migrationsDir = Directory('supabase/migrations');
    expect(migrationsDir.existsSync(), isTrue,
        reason:
            'supabase/migrations/ not found — contract tests must run from the repo root');

    // constraint name → the bound it must enforce.
    const contracts = <String, String>{
      'shipping_zones_estimated_days_min_check': 'estimated_days_min >= 1',
      'shipping_zones_estimated_days_max_check':
          'estimated_days_max >= estimated_days_min',
      'products_review_count_check':
          'review_count IS NULL OR review_count >= 0',
    };

    final files = migrationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    contracts.forEach((constraint, expression) {
      // The last operation per constraint must be an ADD; a later file
      // that only DROPs it (without re-adding) fails here.
      String? latestAddFile;
      String? latestDropFile;
      for (final file in files) {
        final text = file.readAsStringSync();
        if (text.contains('ADD CONSTRAINT') && text.contains(constraint)) {
          latestAddFile = file.path;
        } else if (text.contains('DROP CONSTRAINT') &&
            text.contains(constraint)) {
          latestDropFile = file.path;
        }
      }

      expect(latestAddFile, isNotNull,
          reason: '$constraint not found in any migration — the numeric it '
              'guards is unguarded.');
      expect(latestDropFile, isNull,
          reason: '$constraint was dropped in $latestDropFile and never '
              're-added. The bound `$expression` would stop holding at the '
              'database layer. See migration 045 for the contract.');

      final addText = File(latestAddFile!).readAsStringSync();
      final addStart = addText.indexOf('ADD CONSTRAINT $constraint');
      final statementEnd = addText.indexOf(';', addStart);
      expect(statementEnd, greaterThan(addStart),
          reason: 'Malformed constraint statement in $latestAddFile');

      expect(addText.substring(addStart, statementEnd), contains(expression),
          reason: 'The $constraint defined in $latestAddFile no longer '
              'enforces `$expression`. See migration 045 for the contract.');
    });
  });
}
