/// Shared extension for [DateTime] formatting.
extension DateTimeX on DateTime {
  /// Formats as "12 Jul 2026".
  String get formatted => '$day ${_month(month)} $year';

  String _month(int m) => switch (m) {
        1 => 'Jan',
        2 => 'Feb',
        3 => 'Mar',
        4 => 'Apr',
        5 => 'May',
        6 => 'Jun',
        7 => 'Jul',
        8 => 'Aug',
        9 => 'Sep',
        10 => 'Oct',
        11 => 'Nov',
        12 => 'Dec',
        _ => '',
      };
}
