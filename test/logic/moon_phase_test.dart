import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/moon_phase.dart';

void main() {
  group('getMoonPhase', () {
    test('reference new moon date returns New Moon', () {
      final result = getMoonPhase('2025-01-29');
      expect(result.name, 'New Moon');
      expect(result.phase, 0);
    });

    test('~7.4 days after new moon is First Quarter', () {
      // 2025-01-29 + 7 days = 2025-02-05
      final result = getMoonPhase('2025-02-05');
      expect(result.name, 'First Quarter');
      expect(result.phase, 2);
    });

    test('~14.8 days after new moon is Full Moon', () {
      // 2025-01-29 + 15 days = 2025-02-13
      final result = getMoonPhase('2025-02-13');
      expect(result.name, 'Full Moon');
      expect(result.phase, 4);
    });

    test('~22 days after new moon is Last Quarter', () {
      // 2025-01-29 + 22 days = 2025-02-20
      final result = getMoonPhase('2025-02-20');
      expect(result.name, 'Last Quarter');
      expect(result.phase, 6);
    });

    test('one full cycle returns New Moon', () {
      // 2025-01-29 + 30 days = 2025-02-28 (close to next new moon)
      final result = getMoonPhase('2025-02-28');
      expect(result.name, 'New Moon');
    });

    test('emojis are present', () {
      final result = getMoonPhase('2025-01-29');
      expect(result.emoji, isNotEmpty);
    });
  });
}
