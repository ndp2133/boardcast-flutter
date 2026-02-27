import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/locations.dart';

void main() {
  group('locations', () {
    test('has 11 locations', () {
      expect(locations.length, 11);
    });

    test('all have required fields', () {
      for (final loc in locations) {
        expect(loc.id, isNotEmpty);
        expect(loc.name, isNotEmpty);
        expect(loc.noaaStation, isNotEmpty);
        expect(loc.lat, isNonZero);
        expect(loc.lon, isNonZero);
      }
    });

    test('regions are represented', () {
      final ids = locations.map((l) => l.id).toSet();
      // NY/NJ
      expect(ids.contains('rockaway'), true);
      expect(ids.contains('longbeach'), true);
      expect(ids.contains('asbury'), true);
      expect(ids.contains('belmar'), true);
      // CA
      expect(ids.contains('huntington'), true);
      expect(ids.contains('santacruz'), true);
      expect(ids.contains('oceanbeach'), true);
      // FL
      expect(ids.contains('clearwater'), true);
      expect(ids.contains('cocoa'), true);
      expect(ids.contains('jacksonville'), true);
      expect(ids.contains('miami'), true);
    });
  });

  group('getLocationById', () {
    test('finds rockaway', () {
      final loc = getLocationById('rockaway');
      expect(loc.name, 'Rockaway Beach, NY');
    });

    test('returns default for unknown id', () {
      final loc = getLocationById('nonexistent');
      expect(loc.id, 'rockaway'); // first location
    });
  });

  group('getDefaultLocation', () {
    test('returns rockaway', () {
      expect(getDefaultLocation().id, 'rockaway');
    });
  });

  group('haversine', () {
    test('same point returns 0', () {
      expect(haversine(40.0, -74.0, 40.0, -74.0), 0);
    });

    test('NYC to LA is roughly 3940km', () {
      final dist = haversine(40.7128, -74.0060, 34.0522, -118.2437);
      expect(dist, closeTo(3940, 50));
    });
  });

  group('findNearestLocation', () {
    test('near Rockaway returns Rockaway', () {
      final loc = findNearestLocation(40.58, -73.82);
      expect(loc.id, 'rockaway');
    });

    test('near Miami returns Miami', () {
      final loc = findNearestLocation(25.79, -80.13);
      expect(loc.id, 'miami');
    });

    test('near Huntington returns Huntington', () {
      final loc = findNearestLocation(33.65, -118.0);
      expect(loc.id, 'huntington');
    });
  });
}
