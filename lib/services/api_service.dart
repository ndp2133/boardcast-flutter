/// Open-Meteo + NOAA API fetching, normalization, and merging
/// Direct port of js/api.js
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Raw normalized marine data (intermediate, before merge)
class _MarineNormalized {
  final Map<String, double?> current;
  final List<HourlyData> hourly;
  final List<DailyData> daily;
  _MarineNormalized(this.current, this.hourly, this.daily);
}

/// Raw normalized weather data (intermediate, before merge)
class _WeatherNormalized {
  final Map<String, dynamic> current;
  final List<Map<String, dynamic>> hourly;
  final List<Map<String, dynamic>> daily;
  _WeatherNormalized(this.current, this.hourly, this.daily);
}

/// Raw normalized tide data (intermediate, before merge)
class _TideNormalized {
  final double? currentHeight;
  final String tideTrend;
  final List<({String time, double height})> hourly;
  _TideNormalized(this.currentHeight, this.tideTrend, this.hourly);
}

// ---------------------------------------------------------------------------
// Fetch functions
// ---------------------------------------------------------------------------

Future<Map<String, dynamic>> fetchMarineData(
  Location location, {
  int forecastDays = 14,
  http.Client? client,
}) async {
  final url = Uri.parse(
    'https://marine-api.open-meteo.com/v1/marine?'
    'latitude=${location.lat}&longitude=${location.lon}'
    '&current=wave_height,wave_period,wave_direction,'
    'swell_wave_height,swell_wave_period,swell_wave_direction,'
    'sea_surface_temperature'
    '&hourly=wave_height,wave_direction,wave_period,'
    'swell_wave_height,swell_wave_period,swell_wave_direction,'
    'sea_surface_temperature'
    '&daily=wave_height_max,wave_period_max,wave_direction_dominant'
    '&timezone=${location.timezone}'
    '&forecast_days=$forecastDays',
  );

  final c = client ?? http.Client();
  try {
    final res = await c.get(url);
    if (res.statusCode != 200) {
      throw ApiException('Marine API error: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  } finally {
    if (client == null) c.close();
  }
}

Future<Map<String, dynamic>> fetchWeatherData(
  Location location, {
  int forecastDays = 14,
  http.Client? client,
}) async {
  final url = Uri.parse(
    'https://api.open-meteo.com/v1/forecast?'
    'latitude=${location.lat}&longitude=${location.lon}'
    '&current=temperature_2m,apparent_temperature,'
    'wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code'
    '&hourly=temperature_2m,wind_speed_10m,wind_direction_10m,'
    'wind_gusts_10m,weather_code'
    '&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset'
    '&timezone=${location.timezone}'
    '&forecast_days=$forecastDays',
  );

  final c = client ?? http.Client();
  try {
    final res = await c.get(url);
    if (res.statusCode != 200) {
      throw ApiException('Weather API error: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  } finally {
    if (client == null) c.close();
  }
}

Future<Map<String, dynamic>?> fetchTideData(
  Location location, {
  int forecastDays = 14,
  http.Client? client,
}) async {
  if (location.noaaStation.isEmpty) return null;

  final now = DateTime.now();
  final end = now.add(Duration(days: forecastDays));

  String fmt(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  final url = Uri.parse(
    'https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?'
    'station=${location.noaaStation}'
    '&product=predictions'
    '&datum=MLLW'
    '&units=english'
    '&time_zone=lst_ldt'
    '&interval=h'
    '&format=json'
    '&begin_date=${fmt(now)}'
    '&end_date=${fmt(end)}',
  );

  final c = client ?? http.Client();
  try {
    final res = await c.get(url);
    if (res.statusCode != 200) {
      throw ApiException('NOAA API error: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  } finally {
    if (client == null) c.close();
  }
}

// ---------------------------------------------------------------------------
// Normalization functions (public for testing)
// ---------------------------------------------------------------------------

_MarineNormalized normalizeMarineData(Map<String, dynamic> data) {
  final cur = data['current'] as Map<String, dynamic>? ?? {};

  final current = <String, double?>{
    'waveHeight': (cur['wave_height'] as num?)?.toDouble(),
    'wavePeriod': (cur['wave_period'] as num?)?.toDouble(),
    'waveDirection': (cur['wave_direction'] as num?)?.toDouble(),
    'swellHeight': (cur['swell_wave_height'] as num?)?.toDouble(),
    'swellPeriod': (cur['swell_wave_period'] as num?)?.toDouble(),
    'swellDirection': (cur['swell_wave_direction'] as num?)?.toDouble(),
    'waterTemp': (cur['sea_surface_temperature'] as num?)?.toDouble(),
  };

  final hourlyRaw = data['hourly'] as Map<String, dynamic>? ?? {};
  final times = (hourlyRaw['time'] as List?)?.cast<String>() ?? [];

  final hourly = List.generate(times.length, (i) {
    return HourlyData(
      time: times[i],
      waveHeight: _numAt(hourlyRaw['wave_height'], i),
      waveDirection: _numAt(hourlyRaw['wave_direction'], i),
      wavePeriod: _numAt(hourlyRaw['wave_period'], i),
      swellHeight: _numAt(hourlyRaw['swell_wave_height'], i),
      swellPeriod: _numAt(hourlyRaw['swell_wave_period'], i),
      swellDirection: _numAt(hourlyRaw['swell_wave_direction'], i),
      seaSurfaceTemp: _numAt(hourlyRaw['sea_surface_temperature'], i),
    );
  });

  final dailyRaw = data['daily'] as Map<String, dynamic>? ?? {};
  final dailyTimes = (dailyRaw['time'] as List?)?.cast<String>() ?? [];

  final daily = List.generate(dailyTimes.length, (i) {
    return DailyData(
      date: dailyTimes[i],
      waveHeightMax: _numAt(dailyRaw['wave_height_max'], i),
      wavePeriodMax: _numAt(dailyRaw['wave_period_max'], i),
      waveDirectionDominant: _numAt(dailyRaw['wave_direction_dominant'], i),
    );
  });

  return _MarineNormalized(current, hourly, daily);
}

_WeatherNormalized normalizeWeatherData(Map<String, dynamic> data) {
  final cur = data['current'] as Map<String, dynamic>? ?? {};

  final current = <String, dynamic>{
    'temperature': (cur['temperature_2m'] as num?)?.toDouble(),
    'feelsLike': (cur['apparent_temperature'] as num?)?.toDouble(),
    'windSpeed': (cur['wind_speed_10m'] as num?)?.toDouble(),
    'windDirection': (cur['wind_direction_10m'] as num?)?.toDouble(),
    'windGusts': (cur['wind_gusts_10m'] as num?)?.toDouble(),
    'weatherCode': cur['weather_code'] as int?,
  };

  final hourlyRaw = data['hourly'] as Map<String, dynamic>? ?? {};
  final times = (hourlyRaw['time'] as List?)?.cast<String>() ?? [];

  final hourly = List.generate(times.length, (i) {
    return <String, dynamic>{
      'time': times[i],
      'temperature': _numAt(hourlyRaw['temperature_2m'], i),
      'windSpeed': _numAt(hourlyRaw['wind_speed_10m'], i),
      'windDirection': _numAt(hourlyRaw['wind_direction_10m'], i),
      'windGusts': _numAt(hourlyRaw['wind_gusts_10m'], i),
      'weatherCode': (hourlyRaw['weather_code'] as List?)?[i] as int?,
    };
  });

  final dailyRaw = data['daily'] as Map<String, dynamic>? ?? {};
  final dailyTimes = (dailyRaw['time'] as List?)?.cast<String>() ?? [];

  final daily = List.generate(dailyTimes.length, (i) {
    return <String, dynamic>{
      'date': dailyTimes[i],
      'tempMax': _numAt(dailyRaw['temperature_2m_max'], i),
      'tempMin': _numAt(dailyRaw['temperature_2m_min'], i),
      'sunrise': (dailyRaw['sunrise'] as List?)?[i] as String?,
      'sunset': (dailyRaw['sunset'] as List?)?[i] as String?,
    };
  });

  return _WeatherNormalized(current, hourly, daily);
}

_TideNormalized? normalizeTideData(Map<String, dynamic>? data) {
  if (data == null) return null;
  final predictions = data['predictions'] as List?;
  if (predictions == null || predictions.isEmpty) return null;

  final hourly = predictions.map((p) {
    final m = p as Map<String, dynamic>;
    return (
      time: (m['t'] as String).replaceFirst(' ', 'T'),
      height: double.tryParse(m['v'] as String? ?? '') ?? 0.0,
    );
  }).toList();

  // Find current hour's prediction
  final now = DateTime.now();
  final currentHourStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}T'
      '${now.hour.toString().padLeft(2, '0')}:00';

  var currentIdx = hourly.indexWhere((p) => p.time.compareTo(currentHourStr) >= 0);
  if (currentIdx < 0) currentIdx = 0;

  final currentPred = hourly[currentIdx];
  final nextIdx = currentIdx + 1;
  final nextPred = nextIdx < hourly.length ? hourly[nextIdx] : currentPred;

  String tideTrend = 'Slack';
  final diff = nextPred.height - currentPred.height;
  if (diff > 0.05) {
    tideTrend = 'Rising';
  } else if (diff < -0.05) {
    tideTrend = 'Falling';
  }

  return _TideNormalized(currentPred.height, tideTrend, hourly);
}

// ---------------------------------------------------------------------------
// Merge
// ---------------------------------------------------------------------------

/// Merge marine, weather, and tide data into a single MergedConditions.
/// Filters out daily entries with null waveHeightMax (the PWA bug fix).
MergedConditions mergeConditions(
  Map<String, dynamic> marineRaw,
  Map<String, dynamic> weatherRaw,
  Map<String, dynamic>? tideRaw,
) {
  final marine = normalizeMarineData(marineRaw);
  final weather = normalizeWeatherData(weatherRaw);
  final tide = normalizeTideData(tideRaw);

  // Build current
  final current = CurrentConditions(
    waveHeight: marine.current['waveHeight'],
    wavePeriod: marine.current['wavePeriod'],
    waveDirection: marine.current['waveDirection'],
    swellHeight: marine.current['swellHeight'],
    swellPeriod: marine.current['swellPeriod'],
    swellDirection: marine.current['swellDirection'],
    waterTemp: marine.current['waterTemp'],
    temperature: weather.current['temperature'] as double?,
    feelsLike: weather.current['feelsLike'] as double?,
    windSpeed: weather.current['windSpeed'] as double?,
    windDirection: weather.current['windDirection'] as double?,
    windGusts: weather.current['windGusts'] as double?,
    weatherCode: weather.current['weatherCode'] as int?,
    tideHeight: tide?.currentHeight,
    tideTrend: tide?.tideTrend,
    timestamp: DateTime.now().toIso8601String(),
  );

  // Merge hourly — marine is the base, weather + tide join on time
  final weatherHourlyMap = <String, Map<String, dynamic>>{};
  for (final wh in weather.hourly) {
    weatherHourlyMap[wh['time'] as String] = wh;
  }
  final tideHourlyMap = <String, double>{};
  if (tide != null) {
    for (final th in tide.hourly) {
      tideHourlyMap[th.time] = th.height;
    }
  }

  final hourly = marine.hourly.map((mh) {
    final wh = weatherHourlyMap[mh.time];
    final tideH = tideHourlyMap[mh.time];
    return HourlyData(
      time: mh.time,
      waveHeight: mh.waveHeight,
      wavePeriod: mh.wavePeriod,
      waveDirection: mh.waveDirection,
      swellHeight: mh.swellHeight,
      swellPeriod: mh.swellPeriod,
      swellDirection: mh.swellDirection,
      seaSurfaceTemp: mh.seaSurfaceTemp,
      temperature: wh?['temperature'] as double?,
      windSpeed: wh?['windSpeed'] as double?,
      windDirection: wh?['windDirection'] as double?,
      windGusts: wh?['windGusts'] as double?,
      weatherCode: wh?['weatherCode'] as int?,
      tideHeight: tideH,
    );
  }).toList();

  // Merge daily — marine base, weather joins on date
  final weatherDailyMap = <String, Map<String, dynamic>>{};
  for (final wd in weather.daily) {
    weatherDailyMap[wd['date'] as String] = wd;
  }

  final daily = marine.daily
      .where((md) => md.waveHeightMax != null) // filter empty marine days
      .map((md) {
    final wd = weatherDailyMap[md.date];
    return DailyData(
      date: md.date,
      waveHeightMax: md.waveHeightMax,
      wavePeriodMax: md.wavePeriodMax,
      waveDirectionDominant: md.waveDirectionDominant,
      tempMax: wd?['tempMax'] as double?,
      tempMin: wd?['tempMin'] as double?,
      sunrise: wd?['sunrise'] as String?,
      sunset: wd?['sunset'] as String?,
    );
  }).toList();

  return MergedConditions(
    current: current,
    hourly: hourly,
    daily: daily,
    fetchedAt: DateTime.now(),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double? _numAt(dynamic list, int i) {
  if (list is! List || i >= list.length) return null;
  final v = list[i];
  return (v as num?)?.toDouble();
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}
