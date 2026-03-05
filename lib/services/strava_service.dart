// Strava OAuth + API service for importing surf sessions.
// Handles auth flow, token management, and activity fetching.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:hive/hive.dart';
import 'health_import_service.dart';

const _clientId = '207801';
const _clientSecret = '827b5d0f127bbab7369221221b4b21ed44058aec';
const _redirectUri = 'com.boardcast.app://strava-callback';
const _authUrl = 'https://www.strava.com/oauth/mobile/authorize';
const _tokenUrl = 'https://www.strava.com/oauth/token';
const _apiBase = 'https://www.strava.com/api/v3';
const _revokeUrl = 'https://www.strava.com/oauth/deauthorize';

/// Hive keys for token storage
const _kAccessToken = 'strava_access_token';
const _kRefreshToken = 'strava_refresh_token';
const _kTokenExpiry = 'strava_token_expiry';

class StravaService {
  final http.Client _client;

  StravaService({http.Client? client}) : _client = client ?? http.Client();

  /// Open Strava authorization page in browser
  Future<bool> startAuth() async {
    final uri = Uri.parse(_authUrl).replace(queryParameters: {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'approval_prompt': 'auto',
      'scope': 'activity:read_all',
    });
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Exchange authorization code for tokens
  Future<bool> exchangeCode(String code) async {
    try {
      final response = await _client.post(
        Uri.parse(_tokenUrl),
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _saveTokens(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Refresh expired access token
  Future<bool> _refreshToken() async {
    final refreshToken = _getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _client.post(
        Uri.parse(_tokenUrl),
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _saveTokens(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get a valid access token, refreshing if needed
  Future<String?> _getValidToken() async {
    final box = Hive.box('settings');
    final expiry = box.get(_kTokenExpiry) as int?;
    final token = box.get(_kAccessToken) as String?;

    if (token == null) return null;

    // Refresh if expired or expiring within 60s
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expiry != null && now >= expiry - 60) {
      final refreshed = await _refreshToken();
      if (!refreshed) return null;
      return Hive.box('settings').get(_kAccessToken) as String?;
    }

    return token;
  }

  /// Whether the user has connected Strava
  bool get isConnected {
    final box = Hive.box('settings');
    return box.get(_kAccessToken) != null;
  }

  /// Fetch surf activities with IDs for fingerprinting and dedup
  Future<List<StravaActivity>> fetchSurfActivityDetails() async {
    final token = await _getValidToken();
    if (token == null) return [];

    final activities = <StravaActivity>[];
    var page = 1;
    const perPage = 100;
    final threeYearsAgo =
        DateTime.now().subtract(const Duration(days: 365 * 3));
    final afterEpoch = threeYearsAgo.millisecondsSinceEpoch ~/ 1000;

    while (true) {
      try {
        final uri = Uri.parse('$_apiBase/athlete/activities').replace(
          queryParameters: {
            'after': afterEpoch.toString(),
            'per_page': perPage.toString(),
            'page': page.toString(),
          },
        );

        final response = await _client.get(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode != 200) break;

        final data = jsonDecode(response.body) as List;
        if (data.isEmpty) break;

        for (final activity in data) {
          final sportType = activity['sport_type'] as String?;
          final type = activity['type'] as String?;
          if (sportType != 'Surfing' && type != 'Surfing') continue;

          activities.add(StravaActivity.fromJson(activity));
        }

        if (data.length < perPage) break;
        page++;
        if (page > 20) break;
      } catch (_) {
        break;
      }
    }

    return activities;
  }

  /// Disconnect Strava — revoke token and clear storage
  Future<void> disconnect() async {
    final token = await _getValidToken();
    if (token != null) {
      try {
        await _client.post(
          Uri.parse(_revokeUrl),
          body: {'access_token': token},
        );
      } catch (_) {
        // Best-effort revocation
      }
    }

    final box = Hive.box('settings');
    await box.delete(_kAccessToken);
    await box.delete(_kRefreshToken);
    await box.delete(_kTokenExpiry);
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final box = Hive.box('settings');
    await box.put(_kAccessToken, data['access_token'] as String);
    await box.put(_kRefreshToken, data['refresh_token'] as String);
    await box.put(_kTokenExpiry, data['expires_at'] as int);
  }

  String? _getRefreshToken() {
    final box = Hive.box('settings');
    return box.get(_kRefreshToken) as String?;
  }
}

/// Strava activity with ID for fingerprinting
class StravaActivity {
  final int id;
  final DateTime startTime;
  final DateTime endTime;
  final double? lat;
  final double? lon;
  final String name;

  const StravaActivity({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.lat,
    this.lon,
    required this.name,
  });

  /// Create a RawHealthSession for the import pipeline
  RawHealthSession toRawSession() => RawHealthSession(
        startTime: startTime,
        endTime: endTime,
        lat: lat,
        lon: lon,
      );

  /// Dedup fingerprint using Strava activity ID
  String get fingerprint => 'strava_$id';

  factory StravaActivity.fromJson(Map<String, dynamic> json) {
    final startDate = DateTime.parse(json['start_date'] as String);
    final elapsedSeconds = json['elapsed_time'] as int? ?? 0;
    final endDate = startDate.add(Duration(seconds: elapsedSeconds));

    double? lat, lon;
    final startLatlng = json['start_latlng'] as List?;
    if (startLatlng != null && startLatlng.length >= 2) {
      lat = (startLatlng[0] as num).toDouble();
      lon = (startLatlng[1] as num).toDouble();
    }

    return StravaActivity(
      id: json['id'] as int,
      startTime: startDate,
      endTime: endDate,
      lat: lat,
      lon: lon,
      name: json['name'] as String? ?? 'Surf Session',
    );
  }
}
