/// Business days follow the phone's local calendar, not a fixed 24-hour timer.
String businessDayKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

bool isBusinessDayClosed(String? closedDay, DateTime now) =>
    closedDay == businessDayKey(now);

List<Map<String, dynamic>> transactionsForDay(
        List<Map<String, dynamic>> sales, DateTime day) =>
    sales
        .where((sale) =>
            businessDayKey(DateTime.parse(sale['date'] as String)) ==
            businessDayKey(day))
        .toList();
