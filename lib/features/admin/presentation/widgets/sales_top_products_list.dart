import 'package:flutter/material.dart';

import '../../domain/entities/admin_sales.dart';

/// Best-sellers panel for the admin sales dashboard (#12): top products
/// by units sold, best first (the data layer caps the list at 5).
class SalesTopProductsCard extends StatelessWidget {
  const SalesTopProductsCard({super.key, required this.products});

  final List<AdminTopProduct> products;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child:
                Text('Best sellers — units sold', style: textTheme.titleMedium),
          ),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child:
                  Text('No sales in this window', style: textTheme.bodySmall),
            )
          else
            for (var i = 0; i < products.length; i++)
              ListTile(
                leading: CircleAvatar(
                  child: Text('${i + 1}'),
                ),
                title: Text(products[i].productName),
                trailing: Text('${products[i].unitsSold} u'),
              ),
        ],
      ),
    );
  }
}
