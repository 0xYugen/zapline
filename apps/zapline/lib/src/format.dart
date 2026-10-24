/// Local clock time, honouring the 24-hour setting.
String formatTime(DateTime t, {bool h24 = true}) {
  final l = t.toLocal();
  final m = l.minute.toString().padLeft(2, '0');
  if (h24) return '${l.hour.toString().padLeft(2, '0')}:$m';
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$h:$m ${l.hour < 12 ? 'AM' : 'PM'}';
}

/// "+1:30", "-0:30" for a time shift.
String formatShift(Duration d) {
  final sign = d.isNegative ? '-' : '+';
  final m = d.inMinutes.abs();
  return '$sign${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
}
