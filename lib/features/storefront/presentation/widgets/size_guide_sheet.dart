import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';

/// Shows size guide bottom sheet with width/length/best-for table.
Future<void> showSizeGuide(BuildContext context) {
  final l = context.l10n;
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l.sizeGuide, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Table(
            border: TableBorder.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: .3)),
            columnWidths: const {
              0: FlexColumnWidth(1.5),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2.5),
            },
            children: [
              _tableHeader(l.length, l.width, l.bestFor, context),
              _tableRow('1m', '110 cm', l.sizeGuide1m, context),
              _tableRow('2m', '110 cm', l.sizeGuide2m, context),
              _tableRow('5m', '110 cm', l.sizeGuide5m, context),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.gotIt),
            ),
          ),
        ],
      ),
    ),
  );
}

TableRow _tableHeader(String c1, String c2, String c3, BuildContext ctx) =>
    TableRow(
      decoration: BoxDecoration(
          color:
              Theme.of(ctx).colorScheme.primaryContainer.withValues(alpha: .3)),
      children: [
        _cell(c1, bold: true),
        _cell(c2, bold: true),
        _cell(c3, bold: true)
      ],
    );

TableRow _tableRow(String c1, String c2, String c3, BuildContext ctx) =>
    TableRow(children: [_cell(c1), _cell(c2), _cell(c3)]);

Widget _cell(String text, {bool bold = false}) => Padding(
      padding: const EdgeInsets.all(10),
      child: Text(text,
          style: TextStyle(
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
    );
