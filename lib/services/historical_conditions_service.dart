/// Fetches historical marine + weather data from Open-Meteo archive APIs.
/// Groups requests by location and date range for efficient batching.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/hourly_data.dart';
import '../models/location.dart';

/// Max days per Open-Meteo archive request
const _maxDaysPerRequest = 365;

/// Key for the conditions lookup map
typedef ConditionKey = ({String locationId, String dateStr});

class HistoricalConditionsService {
  final http.Client _client;

  HistoricalConditionsService({http.Client? client})
      : _client = client ?? http.Client();

  /// Fetch historical conditions for a batch of (location, date) pairs.
  /// Groups by location, fetches one date range per location (batched),
  /// returns a map keyed by (locationId, dateStr) → HourlyData list for that day.
  Future<Map<ConditionKey, List<HourlyData>>> fetchHistoricalConditions(
    List<({Location location, String date})> requests,
  ) async {
    if (requests.isEmpty) return {};

    // Group by location
    final grouped = <String, List<({Location location, String date})>>{};
    for (final req in requests) {
      grouped.putIfAbsent(req.location.id, () => []).add(req);
    }

    final result = <ConditionKey, List<HourlyData>>{};

    // Fetch per location
    await Future.wait(grouped.entries.map((entry) async {
      final location = entry.value.first.location;
      final dates = entry.value.map((r) => r.date).toList()..sort();

      final startDate = dates.first;
      final endDate = dates.last;

      // Split into chunks of _maxDaysPerRequest
      final chunks = _splitDateRange(startDate, endDate);

      for (final chunk in chunks) {
        try {
          final results = await Future.wait([
            _fetchMarineArchive(location, chunk.start, chunk.end),
            _fetchWeatherArchive(location, chunk.start, chunk.end),
          ]);
          final marineHourly = results[0] as Map<String, List<HourlyData>>;
          final weatherHourly =
              results[1] as Map<String, List<Map<String, dynamic>>>;

          // Merge marine + weather by date
          for (final date in dates) {
            if (date.compareTo(chunk.start) < 0 ||
                date.compareTo(chunk.end) > 0) {
              continue;
            }

            final marineHours = marineHourly[date] ?? [];
            final weatherHours = weatherHourly[date] ?? [];
            final weatherMap = <String, Map<String, dynamic>>{
              for (final wh in weatherHours)
                if (wh['time'] != null) wh['time'] as String: wh,
            };

            final merged = marineHours.map((mh) {
              final wh = weatherMap[mh.time];
              return HourlyData(
                time: mh.time,
                waveHeight: mh.waveHeight,
                wavePeriod: mh.wavePeriod,
                waveDirection: mh.waveDirection,
                swellHeight: mh.swellHeight,
                swellPeriod: mh.swellPeriod,
                swellDirection: mh.swellDirection,
                seaSurfaceTemp: mh.seaSurfaceTemp,
                windSpeed: (wh?['windSpeed'] as num?)?.toDouble(),
                windDirection: (wh?['windDirection'] as num?)?.toDouble(),
                windGusts: (wh?['windGusts'] as num?)?.toDouble(),
                temperature: (wh?['temperature'] as num?)?.toDouble(),
                weatherCode: wh?['weatherCode'] as int?,
              );
            }).toList();

            if (merged.isNotEmpty) {
              result[(locationId: location.id, dateStr: date)] = merged;
            }
          }
        } catch (_) {
          // Silent fail per chunk — partial data is still useful
        }
      }
    }));

    return result;
  }

  /// Fetch marine archive data, returns map of date → hourly data list
  Future<Map<String, List<HourlyData>>> _fetchMarineArchive(
    Location location,
    String startDate,
    String endDate,
  ) async {
    final url = Uri.parse(
      'https://marine-api.open-meteo.com/v1/marine'
      '?latitude=${location.lat}&longitude=${location.lon}'
      '&hourly=wave_height,wave_period,wave_direction,'
      'swell_wave_height,swell_wave_period,swell_wave_direction,'
      'sea_surface_temperature'
      '&start_date=$startDate&end_date=$endDate'
      '&models=era5_ocean'
      '&timezone=${Uri.encodeComponent(location.timezone)}',
    );

    final res = await _client.get(url);
    if (res.statusCode != 200) return {};

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return {};

    final times = (hourly['time'] as List).cast<String>();
    final result = <String, List<HourlyData>>{};

    for (var i = 0; i < times.length; i++) {
      final time = times[i];
      final date = time.split('T')[0];
      final data = HourlyData(
        time: time,
        waveHeight: _numAt(hourly['wave_height'], i),
        wavePeriod: _numAt(hourly['wave_period'], i),
        waveDirection: _numAt(hourly['wave_direction'], i),
        swellHeight: _numAt(hourly['swell_wave_height'], i),
        swellPeriod: _numAt(hourly['swell_wave_period'], i),
        swellDirection: _numAt(hourly['swell_wave_direction'], i),
        seaSurfaceTemp: _numAt(hourly['sea_surface_temperature'], i),
      );
      result.putIfAbsent(date, () => []).add(data);
    }

    return result;
  }

  /// Fetch weather archive data, returns map of date → hourly weather maps
  Future<Map<String, List<Map<String, dynamic>>>> _fetchWeatherArchive(
    Location location,
    String startDate,
    String endDate,
  ) async {
    final url = Uri.parse(
      'https://archive-api.open-meteo.com/v1/archive'
      '?latitude=${location.lat}&longitude=${location.lon}'
      '&hourly=temperature_2m,wind_speed_10m,wind_direction_10m,'
      'wind_gusts_10m,weather_code'
      '&start_date=$startDate&end_date=$endDate'
      '&timezone=${Uri.encodeComponent(location.timezone)}',
    );

    final res = await _client.get(url);
    if (res.statusCode != 200) return {};

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return {};

    final times = (hourly['time'] as List).cast<String>();
    final result = <String, List<Map<String, dynamic>>>{};

    for (var i = 0; i < times.length; i++) {
      final time = times[i];
      final date = time.split('T')[0];
      result.putIfAbsent(date, () => []).add({
        'time': time,
        'temperature': _numAt(hourly['temperature_2m'], i),
        'windSpeed': _numAt(hourly['wind_speed_10m'], i),
        'windDirection': _numAt(hourly['wind_direction_10m'], i),
        'windGusts': _numAt(hourly['wind_gusts_10m'], i),
        'weatherCode':
            (hourly['weather_code'] as List?)?.elementAtOrNull(i) as int?,
      });
    }

    return result;
  }

  /// Split a date range into chunks of max _maxDaysPerRequest days
  List<({String start, String end})> _splitDateRange(
    String startDate,
    String endDate,
  ) {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    final chunks = <({String start, String end})>[];

    var chunkStart = start;
    while (chunkStart.isBefore(end) || chunkStart.isAtSameMomentAs(end)) {
      final chunkEnd =
          chunkStart.add(const Duration(days: _maxDaysPerRequest - 1));
      final actualEnd = chunkEnd.isAfter(end) ? end : chunkEnd;
      chunks.add((
        start: _formatDate(chunkStart),
        end: _formatDate(actualEnd),
      ));
      chunkStart = actualEnd.add(const Duration(days: 1));
    }

    return chunks;
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  double? _numAt(dynamic list, int i) {
    if (list is! List || i >= list.length) return null;
    final val = list[i];
    return val is num ? val.toDouble() : null;
  }
}
