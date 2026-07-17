import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/catalog_cubit.dart';
import '../cubit/products_data.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Fabric Categories')),
        body: GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length - 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.15,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (_, i) {
            final c = categories[i + 1];
            final p = products.firstWhere((x) => x.category == c);
            return InkWell(
              onTap: () {
                context.read<CatalogCubit>().select(c);
                context.go('/home');
              },
              child: Container(
                decoration: BoxDecoration(color: Color(p.imageColor), borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.texture, color: Colors.white, size: 36),
                    const Spacer(),
                    Text(c, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('${products.where((x) => x.category == c).length} curated fabrics', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            );
          },
        ),
      );
}
