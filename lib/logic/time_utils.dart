/// Time formatting utilities — direct port of utils/time.js

String formatHour(String isoString) {
  final date = DateTime.parse(isoString);
  final h = date.hour;
  final ampm = h >= 12 ? 'PM' : 'AM';
  final hour = h % 12 == 0 ? 12 : h % 12;
  return '$hour$ampm';
}

String formatDate(String isoString) {
  final date = DateTime.parse(isoString);
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}

String formatDayShort(String isoDateString) {
  final date = DateTime.parse('${isoDateString}T00:00:00');
  const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return weekdays[date.weekday - 1];
}

int formatDayNum(String isoDateString) {
  final date = DateTime.parse('${isoDateString}T00:00:00');
  return date.day;
}

String formatDayFull(String isoDateString) {
  final date = DateTime.parse('${isoDateString}T00:00:00');
  const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}

int getCurrentHourIndex(List<String> hourlyTimes) {
  final now = DateTime.now();
  final currentHour =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}T'
      '${now.hour.toString().padLeft(2, '0')}:00';
  return hourlyTimes.indexOf(currentHour);
}

bool isToday(String isoDateString) {
  final today = DateTime.now();
  final date = DateTime.parse('${isoDateString}T00:00:00');
  return date.day == today.day &&
      date.month == today.month &&
      date.year == today.year;
}

String getRelativeTime(String isoString) {
  final target = DateTime.parse(isoString);
  final now = DateTime.now();
  final diffMs = target.difference(now).inMilliseconds;
  final diffHrs = (diffMs / (1000 * 60 * 60)).round();

  if (diffHrs < 0) return 'past';
  if (diffHrs == 0) return 'now';
  if (diffHrs < 24) return 'in ${diffHrs}h';
  final days = (diffHrs / 24).round();
  return 'in ${days}d';
}

List<T> getNextNHours<T>(List<T> hourlyData, int currentIndex, [int n = 12]) {
  final start = currentIndex < 0 ? 0 : currentIndex;
  final end = (start + n).clamp(0, hourlyData.length);
  return hourlyData.sublist(start, end);
}
