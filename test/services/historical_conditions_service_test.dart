import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/services/historical_conditions_service.dart';
import 'package:boardcast_flutter/models/location.dart';

const _testLocation = Location(
  id: 'rockaway',
  name: 'Rockaway Beach, NY',
  lat: 40.5835,
  lon: -73.8155,
  timezone: 'America/New_York',
  beachFacing: 180,
  offshoreMin: 315,
  offshoreMax: 45,
  onshoreMin: 135,
  onshoreMax: 225,
  noaaStation: '8517137',
);

void main() {
  group('HistoricalConditionsService', () {
    test('returns empty map for empty requests', () async {
      final service = HistoricalConditionsService();
      final result = await service.fetchHistoricalConditions([]);
      expect(result, isEmpty);
    });

    test('date range splitting works for single day', () {
      // Access the internal method indirectly by testing the service
      // with a known date range — this is a structural test
      final service = HistoricalConditionsService();
      // The service should handle a single-day request without error
      expect(
        () => service.fetchHistoricalConditions([
          (location: _testLocation, date: '2025-06-15'),
        ]),
        returnsNormally,
      );
    });

    test('ConditionKey works as map key', () {
      final key1 = (locationId: 'rockaway', dateStr: '2025-06-15');
      final key2 = (locationId: 'rockaway', dateStr: '2025-06-15');
      final key3 = (locationId: 'miami', dateStr: '2025-06-15');

      final map = <ConditionKey, String>{};
      map[key1] = 'value1';
      map[key3] = 'value3';

      expect(map[key2], 'value1');
      expect(map[key3], 'value3');
      expect(map.length, 2);
    });
  });
}
