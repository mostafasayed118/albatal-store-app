import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/presentation/catalog_constants.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/categories_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/color_swatches.dart';
import 'package:al_batal_elite/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result.guard (audit P5)', () {
    test('maps a success to Success with the value', () async {
      final result = await Result.guard(() async => 42, 'Failed to load cart');
      expect(result, isA<Success<int>>());
      expect((result as Success<int>).value, 42);
    });

    test('maps a throw to Failure with the byte-identical message', () async {
      final boom = StateError('disk full');
      final result = await Result.guard<int>(
        () => throw boom,
        'Failed to load cart',
      );
      expect(result, isA<Failure<int>>());
      final error = (result as Failure<int>).error;
      expect(error.message, 'Failed to load cart');
      expect(identical(error.cause, boom), isTrue);
    });

    test('supports void actions (write-style boundaries)', () async {
      var ran = false;
      final result = await Result.guard<void>(() async {
        ran = true;
      }, 'Failed to save cart');
      expect(ran, isTrue);
      expect(result, isA<Success<void>>());
    });

    test('void failure keeps the save message byte-identical', () async {
      final result = await Result.guard<void>(
        () => throw const FormatException('bad json'),
        'Unable to save app preferences.',
      );
      final error = (result as Failure<void>).error;
      expect(error.message, 'Unable to save app preferences.');
      expect(error.cause, isA<FormatException>());
    });

    test('local messages stay byte-identical through guard', () async {
      const messages = [
        'Failed to load cart',
        'Failed to save cart',
        'Failed to load wishlist',
        'Failed to save wishlist',
        'Failed to load orders',
        'Unable to read saved addresses.',
        'Unable to save saved addresses.',
        'Unable to clear saved addresses.',
        'Unable to read app preferences.',
        'Unable to save app preferences.',
        'Unable to read onboarding state.',
        'Unable to save onboarding state.',
      ];
      for (final message in messages) {
        final result = await Result.guard(() => throw StateError('x'), message);
        expect(
          (result as Failure).error.message,
          message,
          reason: 'guard message for "$message"',
        );
      }
    });
  });

  group('AppColors gold tokens (audit P5)', () {
    test('hero gradient stops match the mockup-exact hex', () {
      expect(AppColors.goldDeep, const Color(0xFFB8860B));
      expect(AppColors.goldPale, const Color(0xFFFFFAF0));
    });

    test('legacy gold alias is unchanged', () {
      expect(AppColors.gold, const Color(0xFFD97706));
    });
  });

  group('CatalogConstants (audit P5)', () {
    test('defaults match the previous inline lists byte-for-byte', () {
      expect(
        CatalogConstants.defaults,
        const ['Silk', 'Cotton', 'Velvet', 'Linen', 'Wool'],
      );
    });

    test('accent map keeps the curated family tints', () {
      expect(
          CatalogConstants.categoryAccents['Velvet'], const Color(0xFF6E1423));
      expect(CatalogConstants.categoryAccents['Silk'], const Color(0xFFB08A2E));
      expect(CatalogConstants.accentFor('Velvet'), const Color(0xFF6E1423));
    });

    test('swatch table keeps the curated fabric hues', () {
      expect(
          CatalogConstants.curatedSwatches['emerald'], const Color(0xFF0B7A4D));
      expect(CatalogConstants.swatchFor('Emerald'), const Color(0xFF0B7A4D));
      expect(CatalogConstants.swatchFor('  emerald '),
          CatalogConstants.swatchFor('EMERALD'));
    });

    test('deprecated aliases delegate identically', () {
      // ignore: deprecated_member_use_from_same_package
      expect(categoryAccent('Wool'), CatalogConstants.accentFor('Wool'));
      // ignore: deprecated_member_use_from_same_package
      expect(visibleCategoryChips([]), CatalogConstants.chipsFor([]));
      // ignore: deprecated_member_use_from_same_package
      expect(visibleCategoryChips(['All', 'Wool', 'Silk']), ['Wool', 'Silk']);
      // ignore: deprecated_member_use_from_same_package
      expect(swatchColorFor('gold'), CatalogConstants.swatchFor('gold'));
      // ignore: deprecated_member_use_from_same_package
      expect(deterministicTint('Zanzibar'),
          CatalogConstants.deterministicTint('Zanzibar'));
    });

    test('deterministic tint is stable and case-insensitive', () {
      expect(CatalogConstants.deterministicTint('Zanzibar Weave'),
          CatalogConstants.deterministicTint('zanzibar weave'.toUpperCase()));
      expect(
        CatalogConstants.deterministicTint('Zanzibar'),
        isNot(CatalogConstants.deterministicTint('Kashmir')),
      );
    });
  });
}
