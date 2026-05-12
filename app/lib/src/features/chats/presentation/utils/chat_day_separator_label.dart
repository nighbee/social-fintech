/// Подписи к разделителям дня в ленте сообщений (локальная дата [messageDay]).
String chatDaySeparatorLabel(DateTime messageDayLocal, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final d = DateTime(
    messageDayLocal.year,
    messageDayLocal.month,
    messageDayLocal.day,
  );
  if (d == today) {
    return 'Today';
  }
  if (d == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final m = months[d.month - 1];
  return '${d.day} $m ${d.year}';
}
