import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../widgets/category_grid.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.fabricCategories)),
      body: CategoryGrid(l10n: l),
    );
  }
}
