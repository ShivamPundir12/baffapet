String formatForSite(DateTime dt) {
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  final yyyy = dt.year.toString();
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final min = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return "$mm/$dd/$yyyy, $hour12:$min $ampm";
}
