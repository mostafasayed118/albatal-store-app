import 'entities/admin_order.dart';

/// Pure CSV builder for the admin orders export (feature-batch §14).
///
/// Security: every cell passes the formula-injection guard — values
/// starting with `=`, `+`, `-`, `@`, TAB or CR are prefixed with a
/// single quote so spreadsheet apps treat them as text.
String buildOrdersCsv(List<AdminOrder> orders) {
  final buffer = StringBuffer(
      'order_id,placed_at,status,items,total_minor,customer_name\n');
  for (final o in orders) {
    final cells = [
      _cell(o.id),
      _cell(o.placedAt.toUtc().toIso8601String()),
      _cell(o.status.name),
      _cell((o.itemCount ?? 0).toString()),
      _cell(o.total.minorUnits.toString()),
      _cell(o.customerName ?? ''),
    ];
    buffer.write(cells.join(','));
    buffer.write('\r\n');
  }
  return buffer.toString();
}

String _cell(String raw) {
  final safe = _formulaGuard(raw);
  if (safe.contains('"') || safe.contains(',') || safe.contains('\n')) {
    return '"${safe.replaceAll('"', '""')}"';
  }
  return safe;
}

String _formulaGuard(String value) {
  if (value.isEmpty) return value;
  const dangerous = {'=', '+', '-', '@', '\t', '\r'};
  if (dangerous.contains(value[0])) return "'$value";
  return value;
}
