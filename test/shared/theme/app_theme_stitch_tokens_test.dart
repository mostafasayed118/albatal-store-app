import 'package:flutter_test/flutter_test.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';

void main() {
  test('light scaffold is Stitch #f9f9f9 and primary #003527', () {
    final t = AppTheme.light();
    // Use toARGB32() (non-deprecated) to avoid analyze info; equivalent to .value
    expect(t.scaffoldBackgroundColor.toARGB32(), 0xFFF9F9F9);
    expect(t.colorScheme.primary.toARGB32(), 0xFF003527);
    expect(t.colorScheme.secondaryContainer.toARGB32(), 0xFFFE932C);
  });
}
