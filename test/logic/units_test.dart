import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/units.dart';

void main() {
  group('metersToFeet', () {
    test('converts 1 meter to ~3.28 feet', () {
      expect(metersToFeet(1.0), closeTo(3.28084, 0.001));
    });

    test('converts 0 meters to 0 feet', () {
      expect(metersToFeet(0.0), 0.0);
    });

    test('converts 0.5 meters', () {
      expect(metersToFeet(0.5), closeTo(1.64042, 0.001));
    });
  });

  group('kmhToMph', () {
    test('converts 1 km/h to ~0.62 mph', () {
      expect(kmhToMph(1.0), closeTo(0.621371, 0.001));
    });

    test('converts 10 km/h', () {
      expect(kmhToMph(10.0), closeTo(6.21371, 0.01));
    });
  });

  group('celsiusToFahrenheit', () {
    test('converts 0C to 32F', () {
      expect(celsiusToFahrenheit(0.0), 32.0);
    });

    test('converts 100C to 212F', () {
      expect(celsiusToFahrenheit(100.0), 212.0);
    });

    test('converts 20C to 68F', () {
      expect(celsiusToFahrenheit(20.0), 68.0);
    });
  });

  group('degreesToCardinal', () {
    test('0 degrees is N', () {
      expect(degreesToCardinal(0), 'N');
    });

    test('90 degrees is E', () {
      expect(degreesToCardinal(90), 'E');
    });

    test('180 degrees is S', () {
      expect(degreesToCardinal(180), 'S');
    });

    test('270 degrees is W', () {
      expect(degreesToCardinal(270), 'W');
    });

    test('45 degrees is NE', () {
      expect(degreesToCardinal(45), 'NE');
    });

    test('360 degrees wraps to N', () {
      expect(degreesToCardinal(360), 'N');
    });
  });

  group('formatWaveHeight', () {
    test('null returns --', () {
      expect(formatWaveHeight(null), '--');
    });

    test('1m imperial returns ~3.3', () {
      expect(formatWaveHeight(1.0), '3.3');
    });

    test('1m metric returns 1.0', () {
      expect(formatWaveHeight(1.0, imperial: false), '1.0');
    });
  });

  group('formatWindSpeed', () {
    test('null returns --', () {
      expect(formatWindSpeed(null), '--');
    });

    test('10 km/h imperial rounds correctly', () {
      expect(formatWindSpeed(10.0), '6');
    });

    test('10 km/h metric returns 10', () {
      expect(formatWindSpeed(10.0, imperial: false), '10');
    });
  });

  group('formatTemp', () {
    test('null returns --', () {
      expect(formatTemp(null), '--');
    });

    test('20C imperial returns 68', () {
      expect(formatTemp(20.0), '68');
    });

    test('20C metric returns 20', () {
      expect(formatTemp(20.0, imperial: false), '20');
    });
  });

  group('unit labels', () {
    test('waveUnit imperial', () => expect(waveUnit(), 'ft'));
    test('waveUnit metric', () => expect(waveUnit(imperial: false), 'm'));
    test('windUnit imperial', () => expect(windUnit(), 'mph'));
    test('windUnit metric', () => expect(windUnit(imperial: false), 'km/h'));
    test('tempUnit imperial', () => expect(tempUnit(), 'F'));
    test('tempUnit metric', () => expect(tempUnit(imperial: false), 'C'));
  });
}
