import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/time_utils.dart';

void main() {
  group('formatHour', () {
    test('midnight is 12AM', () {
      expect(formatHour('2025-01-15T00:00'), '12AM');
    });

    test('6am is 6AM', () {
      expect(formatHour('2025-01-15T06:00'), '6AM');
    });

    test('noon is 12PM', () {
      expect(formatHour('2025-01-15T12:00'), '12PM');
    });

    test('3pm is 3PM', () {
      expect(formatHour('2025-01-15T15:00'), '3PM');
    });

    test('11pm is 11PM', () {
      expect(formatHour('2025-01-15T23:00'), '11PM');
    });
  });

  group('formatDate', () {
    test('formats correctly', () {
      // Jan 15 2025 is a Wednesday
      expect(formatDate('2025-01-15T12:00'), 'Wed, Jan 15');
    });
  });

  group('formatDayShort', () {
    test('returns uppercase short day', () {
      // Jan 15 2025 is a Wednesday
      expect(formatDayShort('2025-01-15'), 'WED');
    });
  });

  group('formatDayNum', () {
    test('returns day number', () {
      expect(formatDayNum('2025-01-15'), 15);
    });

    test('returns day 1', () {
      expect(formatDayNum('2025-02-01'), 1);
    });
  });

  group('formatDayFull', () {
    test('returns full day format', () {
      expect(formatDayFull('2025-01-15'), 'Wednesday, Jan 15');
    });
  });

  group('isToday', () {
    test('today returns true', () {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      expect(isToday(todayStr), true);
    });

    test('yesterday returns false', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final str =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      expect(isToday(str), false);
    });
  });

  group('getRelativeTime', () {
    test('past time returns past', () {
      final pastTime =
          DateTime.now().subtract(const Duration(hours: 2)).toIso8601String();
      expect(getRelativeTime(pastTime), 'past');
    });

    test('far future returns days', () {
      final future =
          DateTime.now().add(const Duration(days: 3)).toIso8601String();
      expect(getRelativeTime(future), 'in 3d');
    });
  });

  group('getNextNHours', () {
    test('returns correct slice', () {
      final data = List.generate(24, (i) => 'hour_$i');
      final result = getNextNHours(data, 5, 3);
      expect(result, ['hour_5', 'hour_6', 'hour_7']);
    });

    test('negative index starts from 0', () {
      final data = List.generate(10, (i) => i);
      final result = getNextNHours(data, -1, 3);
      expect(result, [0, 1, 2]);
    });

    test('clamps to list length', () {
      final data = List.generate(5, (i) => i);
      final result = getNextNHours(data, 3, 10);
      expect(result, [3, 4]);
    });
  });

  group('getCurrentHourIndex', () {
    test('returns -1 for empty list', () {
      expect(getCurrentHourIndex([]), -1);
    });

    test('finds matching hour', () {
      final now = DateTime.now();
      final currentHour =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}T'
          '${now.hour.toString().padLeft(2, '0')}:00';
      expect(getCurrentHourIndex([currentHour]), 0);
    });
  });
}
