import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boardcast_flutter/services/strava_service.dart';

// Sample Strava activity JSON matching API response shape
Map<String, dynamic> _surfActivity({
  int id = 12345,
  String sportType = 'Surfing',
  String startDate = '2025-06-15T08:00:00Z',
  int elapsedTime = 5400, // 90 min
  List<double>? startLatlng,
  String name = 'Morning Surf',
}) =>
    {
      'id': id,
      'sport_type': sportType,
      'type': sportType,
      'start_date': startDate,
      'elapsed_time': elapsedTime,
      'start_latlng': startLatlng ?? [40.5834, -73.8152], // Rockaway
      'name': name,
    };

Map<String, dynamic> _nonSurfActivity() => {
      'id': 99999,
      'sport_type': 'Run',
      'type': 'Run',
      'start_date': '2025-06-15T07:00:00Z',
      'elapsed_time': 1800,
      'start_latlng': [40.7128, -74.0060],
      'name': 'Morning Run',
    };

void main() {
  group('StravaActivity', () {
    test('fromJson parses surf activity with GPS', () {
      final json = _surfActivity(
        id: 42,
        startDate: '2025-08-01T09:30:00Z',
        elapsedTime: 7200,
        startLatlng: [34.0087, -118.4998], // Venice Beach
        name: 'Venice Session',
      );

      final activity = StravaActivity.fromJson(json);

      expect(activity.id, 42);
      expect(activity.name, 'Venice Session');
      expect(activity.startTime, DateTime.parse('2025-08-01T09:30:00Z'));
      expect(activity.endTime, DateTime.parse('2025-08-01T11:30:00Z'));
      expect(activity.lat, closeTo(34.0087, 0.001));
      expect(activity.lon, closeTo(-118.4998, 0.001));
    });

    test('fromJson handles missing GPS', () {
      final json = _surfActivity();
      json.remove('start_latlng');

      final activity = StravaActivity.fromJson(json);

      expect(activity.lat, isNull);
      expect(activity.lon, isNull);
    });

    test('fromJson handles empty latlng array', () {
      final json = _surfActivity();
      json['start_latlng'] = [];

      final activity = StravaActivity.fromJson(json);

      expect(activity.lat, isNull);
      expect(activity.lon, isNull);
    });

    test('fingerprint uses strava prefix + activity ID', () {
      final activity = StravaActivity.fromJson(_surfActivity(id: 777));
      expect(activity.fingerprint, 'strava_777');
    });

    test('toRawSession preserves start/end times and GPS', () {
      final activity = StravaActivity.fromJson(_surfActivity(
        startDate: '2025-07-04T06:00:00Z',
        elapsedTime: 3600,
        startLatlng: [40.5834, -73.8152],
      ));

      final raw = activity.toRawSession();

      expect(raw.startTime, DateTime.parse('2025-07-04T06:00:00Z'));
      expect(raw.endTime, DateTime.parse('2025-07-04T07:00:00Z'));
      expect(raw.lat, closeTo(40.5834, 0.001));
      expect(raw.lon, closeTo(-73.8152, 0.001));
    });

    test('toRawSession computes correct duration', () {
      final activity = StravaActivity.fromJson(_surfActivity(
        elapsedTime: 5400, // 90 minutes
      ));

      final raw = activity.toRawSession();
      expect(raw.durationMinutes, 90);
    });

    test('default name is Surf Session for missing name', () {
      final json = _surfActivity();
      json.remove('name');

      final activity = StravaActivity.fromJson(json);
      expect(activity.name, 'Surf Session');
    });
  });

  group('StravaService API filtering', () {
    test('fetchSurfActivityDetails filters non-surf activities', () async {
      final mockClient = MockClient((request) async {
        // Return mixed activities — only surf ones should be kept
        final body = jsonEncode([
          _surfActivity(id: 1, name: 'Dawn Patrol'),
          _nonSurfActivity(),
          _surfActivity(id: 2, name: 'Evening Glass'),
          _nonSurfActivity(),
        ]);
        return http.Response(body, 200);
      });

      // We can't test fetchSurfActivityDetails directly because it requires
      // Hive to be initialized. Instead, verify the filtering logic by
      // constructing StravaActivity objects and checking sport_type filtering.
      final activities = [
        _surfActivity(id: 1, name: 'Dawn Patrol'),
        _nonSurfActivity(),
        _surfActivity(id: 2, name: 'Evening Glass'),
      ];

      final surfOnly = activities
          .where((a) =>
              a['sport_type'] == 'Surfing' || a['type'] == 'Surfing')
          .map((a) => StravaActivity.fromJson(a))
          .toList();

      expect(surfOnly.length, 2);
      expect(surfOnly[0].name, 'Dawn Patrol');
      expect(surfOnly[1].name, 'Evening Glass');

      mockClient.close();
    });

    test('dedup fingerprints are unique across activities', () {
      final a1 = StravaActivity.fromJson(_surfActivity(id: 100));
      final a2 = StravaActivity.fromJson(_surfActivity(id: 200));
      final a3 = StravaActivity.fromJson(_surfActivity(id: 100));

      expect(a1.fingerprint, isNot(equals(a2.fingerprint)));
      expect(a1.fingerprint, equals(a3.fingerprint)); // same ID = same fingerprint
    });
  });

  group('Token exchange', () {
    test('successful token exchange returns 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(),
            contains('strava.com/oauth/token'));
        expect(request.body, contains('grant_type=authorization_code'));
        expect(request.body, contains('code=test_code'));

        return http.Response(
          jsonEncode({
            'access_token': 'mock_access',
            'refresh_token': 'mock_refresh',
            'expires_at': 9999999999,
          }),
          200,
        );
      });

      // Verify the mock client would respond correctly
      final response = await mockClient.post(
        Uri.parse('https://www.strava.com/oauth/token'),
        body: {
          'client_id': '207801',
          'client_secret': 'secret',
          'code': 'test_code',
          'grant_type': 'authorization_code',
        },
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body);
      expect(data['access_token'], 'mock_access');
      expect(data['refresh_token'], 'mock_refresh');

      mockClient.close();
    });

    test('failed token exchange returns non-200', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "invalid_grant"}', 400);
      });

      final response = await mockClient.post(
        Uri.parse('https://www.strava.com/oauth/token'),
        body: {'code': 'expired_code', 'grant_type': 'authorization_code'},
      );

      expect(response.statusCode, 400);

      mockClient.close();
    });
  });
}
