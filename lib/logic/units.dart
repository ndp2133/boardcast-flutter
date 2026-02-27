/// Unit conversion utilities — direct port of utils/units.js

double metersToFeet(double m) => m * 3.28084;

double kmhToMph(double kmh) => kmh * 0.621371;

double celsiusToFahrenheit(double c) => (c * 9 / 5) + 32;

String degreesToCardinal(double deg) {
  const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final index = (deg / 45).round() % 8;
  return directions[index];
}

String formatWaveHeight(double? meters, {bool imperial = true}) {
  if (meters == null) return '--';
  final val = imperial ? metersToFeet(meters) : meters;
  return val.toStringAsFixed(1);
}

String formatWindSpeed(double? kmh, {bool imperial = true}) {
  if (kmh == null) return '--';
  final val = imperial ? kmhToMph(kmh) : kmh;
  return val.round().toString();
}

String formatTemp(double? celsius, {bool imperial = true}) {
  if (celsius == null) return '--';
  final val = imperial ? celsiusToFahrenheit(celsius) : celsius;
  return val.round().toString();
}

String waveUnit({bool imperial = true}) => imperial ? 'ft' : 'm';

String windUnit({bool imperial = true}) => imperial ? 'mph' : 'km/h';

String tempUnit({bool imperial = true}) => imperial ? 'F' : 'C';
