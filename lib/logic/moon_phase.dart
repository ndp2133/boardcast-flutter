/// Moon phase calculator — direct port of utils/moon.js

const _synodicPeriod = 29.53059;
final _referenceNewMoon = DateTime.utc(2025, 1, 29, 12);

class MoonPhaseResult {
  final int phase;
  final String name;
  final String emoji;

  const MoonPhaseResult({
    required this.phase,
    required this.name,
    required this.emoji,
  });
}

const _phases = [
  MoonPhaseResult(phase: 0, name: 'New Moon', emoji: '\u{1F311}'),
  MoonPhaseResult(phase: 1, name: 'Waxing Crescent', emoji: '\u{1F312}'),
  MoonPhaseResult(phase: 2, name: 'First Quarter', emoji: '\u{1F313}'),
  MoonPhaseResult(phase: 3, name: 'Waxing Gibbous', emoji: '\u{1F314}'),
  MoonPhaseResult(phase: 4, name: 'Full Moon', emoji: '\u{1F315}'),
  MoonPhaseResult(phase: 5, name: 'Waning Gibbous', emoji: '\u{1F316}'),
  MoonPhaseResult(phase: 6, name: 'Last Quarter', emoji: '\u{1F317}'),
  MoonPhaseResult(phase: 7, name: 'Waning Crescent', emoji: '\u{1F318}'),
];

MoonPhaseResult getMoonPhase(String dateStr) {
  final date = DateTime.parse('${dateStr}T12:00:00Z');
  final diffMs = date.difference(_referenceNewMoon).inMilliseconds;
  final diffDays = diffMs / (1000 * 60 * 60 * 24);
  final cyclePosition =
      ((diffDays % _synodicPeriod) + _synodicPeriod) % _synodicPeriod;
  final phase = (cyclePosition / _synodicPeriod * 8).round() % 8;
  return _phases[phase];
}
