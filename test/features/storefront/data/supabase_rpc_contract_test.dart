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

  test('membership tier is server-managed (migration 046 contract)', () {
    final migrationsDir = Directory('supabase/migrations');
    expect(migrationsDir.existsSync(), isTrue,
        reason:
            'supabase/migrations/ not found — contract tests must run from the repo root');

    final files = migrationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final sql46 = files.map((f) => (f.path, f.readAsStringSync())).firstWhere(
          (e) => e.$2.contains('admin_set_membership_tier'),
          orElse: () => ('', ''),
        );

    expect(sql46.$2, isNotEmpty,
        reason: 'No migration defines admin_set_membership_tier — the '
            'Premium badge would have no data source and no admin write path.');

    // 1. The tier value guard must exist and must be the last definition.
    const tierCheck = 'profiles_membership_tier_check';
    String? latestAddFile;
    String? latestDropFile;
    for (final file in files) {
      final text = file.readAsStringSync();
      if (text.contains('ADD CONSTRAINT') && text.contains(tierCheck)) {
        latestAddFile = file.path;
      } else if (text.contains('DROP CONSTRAINT') && text.contains(tierCheck)) {
        latestDropFile = file.path;
      }
    }
    expect(latestAddFile, isNotNull,
        reason: '$tierCheck not found — the tier column accepts any string.');
    expect(latestDropFile, isNull,
        reason: '$tierCheck was dropped in $latestDropFile and never '
            're-added. Arbitrary tier values would persist.');
    final addText = File(latestAddFile!).readAsStringSync();
    final addStart = addText.indexOf('ADD CONSTRAINT $tierCheck');
    final stmtEnd = addText.indexOf(';', addStart);
    expect(addText.substring(addStart, stmtEnd),
        contains("membership_tier IN ('standard', 'premium')"),
        reason: 'The tier CHECK in $latestAddFile no longer pins the '
            'value set the client maps against.');

    // 2. Self-service UPDATE must pin BOTH privileged columns (a policy
    // that only guards is_admin would let customers self-promote to
    // premium). The LAST definition of the policy wins.
    String? latestUpdatePolicyFile;
    for (final file in files) {
      final text = file.readAsStringSync();
      if (text.contains('CREATE POLICY "profiles_update_own_safe"')) {
        latestUpdatePolicyFile = file.path;
      }
    }
    expect(latestUpdatePolicyFile, isNotNull,
        reason: 'profiles_update_own_safe not found — profile updates are '
            'unprotected.');
    final policyText = File(latestUpdatePolicyFile!).readAsStringSync();
    final policyStart =
        policyText.indexOf('CREATE POLICY "profiles_update_own_safe"');
    final policyBody =
        policyText.substring(policyStart, policyText.indexOf(';', policyStart));
    expect(policyBody, contains('membership_tier ='),
        reason: 'The profiles_update_own_safe policy in '
            '$latestUpdatePolicyFile no longer pins membership_tier to the '
            'existing row — customers could self-promote to premium via a '
            'plain profile UPDATE. See migration 046.');
    expect(policyBody, contains('is_admin ='),
        reason: 'The profiles_update_own_safe policy in '
            '$latestUpdatePolicyFile dropped the 003 is_admin guard.');

    // 3. Self-service INSERT must start unprivileged.
    String? latestInsertPolicyFile;
    for (final file in files) {
      final text = file.readAsStringSync();
      if (text.contains('CREATE POLICY "profiles_insert_own_safe"')) {
        latestInsertPolicyFile = file.path;
      }
    }
    expect(latestInsertPolicyFile, isNotNull,
        reason: 'profiles_insert_own_safe not found — a customer could '
            'INSERT their own profile row with is_admin=true.');
    final insertText = File(latestInsertPolicyFile!).readAsStringSync();
    final insertStart =
        insertText.indexOf('CREATE POLICY "profiles_insert_own_safe"');
    final insertBody =
        insertText.substring(insertStart, insertText.indexOf(';', insertStart));
    expect(insertBody, contains("membership_tier = 'standard'"),
        reason: 'The profiles_insert_own_safe policy in '
            '$latestInsertPolicyFile no longer forces new profiles to start '
            'at standard tier.');

    // 4. The RPC must be admin-gated and revoked from PUBLIC/anon.
    final rpcStart = sql46.$2
        .indexOf('CREATE OR REPLACE FUNCTION admin_set_membership_tier');
    final rpcBody = sql46.$2.substring(
        rpcStart,
        sql46.$2
            .indexOf('GRANT EXECUTE ON FUNCTION admin_set_membership_tier'));
    expect(rpcBody, contains('SECURITY DEFINER'),
        reason: 'admin_set_membership_tier must be SECURITY DEFINER to '
            'bypass RLS for admins only.');
    expect(rpcBody, contains('assert_admin()'),
        reason: 'admin_set_membership_tier must gate on assert_admin() — '
            'without it any authenticated user could re-tier anyone.');
    expect(
        rpcBody,
        contains(
            'REVOKE EXECUTE ON FUNCTION admin_set_membership_tier(UUID, TEXT) FROM PUBLIC, anon'),
        reason: 'admin_set_membership_tier must be revoked from PUBLIC and '
            'anon like every admin RPC.');
  });

  test('premium free-shipping perk is server-side (migration 047 contract)',
      () {
    final migrationsDir = Directory('supabase/migrations');
    expect(migrationsDir.existsSync(), isTrue);

    final files = migrationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    // The LAST definition of create_checkout_order wins on the server, so
    // the perk must live in the newest file defining it — and in every
    // future one.
    String? latestFile;
    for (final file in files) {
      if (file
          .readAsStringSync()
          .contains('CREATE OR REPLACE FUNCTION create_checkout_order')) {
        latestFile = file.path;
      }
    }
    expect(latestFile, isNotNull,
        reason: 'No migration defines create_checkout_order.');
    expect(latestFile!.replaceAll('\\', '/'),
        'supabase/migrations/047_premium_free_shipping.sql',
        reason: '047 must remain the newest definition of '
            'create_checkout_order — a later migration rewriting the RPC '
            'without the perk silently strips the premium benefit.');

    final body = File(latestFile).readAsStringSync();

    // The perk reads the tier from the profile row, never from the
    // request — a tampered client must not be able to claim premium.
    final perkStart = body.indexOf('Premium perk: free shipping');
    expect(perkStart, greaterThan(0),
        reason: 'The 047 perk block is missing from the checkout RPC.');
    final perkBody =
        body.substring(perkStart, body.indexOf('v_total', perkStart));
    expect(perkBody, contains('FROM profiles WHERE id = v_user_id'),
        reason: 'The perk must read membership_tier from the profile row, '
            'not from any request parameter.');
    expect(perkBody, contains("'premium'"),
        reason: 'The perk must gate on the premium tier value.');
    expect(perkBody, contains('v_shipping := 0'),
        reason: 'The perk must zero shipping before the total is computed.');

    // Applied after the zone calculation, so standard users keep the
    // 024 shipping-zone logic untouched.
    final zoneLine = body.indexOf('v_shipping := calculate_shipping_fee');
    expect(zoneLine, greaterThan(0));
    expect(perkStart, greaterThan(zoneLine),
        reason: 'The perk must apply AFTER the zone calculation.');

    // Posture unchanged: authenticated-only execution.
    expect(
        body,
        contains(
            'GRANT EXECUTE ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) TO authenticated'),
        reason: 'The rewrite must preserve the 019/024 grant posture.');
  });
}
