// Strava OAuth + API service for importing surf sessions.
// Handles auth flow, token management, and activity fetching.
// Token exchange is done server-side via Supabase Edge Function (client secret never ships in app).
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'health_import_service.dart';

const _clientId = '207801';
const _redirectUri = 'com.boardcast.app://strava-callback';
const _authUrl = 'https://www.strava.com/oauth/mobile/authorize';
const _apiBase = 'https://www.strava.com/api/v3';
const _revokeUrl = 'https://www.strava.com/oauth/deauthorize';

/// Secure storage keys for tokens
const _kAccessToken = 'strava_access_token';
const _kRefreshToken = 'strava_refresh_token';
const _kTokenExpiry = 'strava_token_expiry';
const _kOAuthState = 'strava_oauth_state';

const _secureStorage = FlutterSecureStorage();

class StravaService {
  final http.Client _client;

  StravaService({http.Client? client}) : _client = client ?? http.Client();

  /// Generate a cryptographic random state parameter for CSRF protection
  static String _generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Open Strava authorization page in browser
  Future<bool> startAuth() async {
    final state = _generateState();
    await _secureStorage.write(key: _kOAuthState, value: state);

    final uri = Uri.parse(_authUrl).replace(queryParameters: {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'approval_prompt': 'auto',
      'scope': 'activity:read_all',
      'state': state,
    });
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Exchange authorization code for tokens via server-side Edge Function.
  /// The client secret lives in the Edge Function, never in the app binary.
  Future<bool> exchangeCode(String code, {String? state}) async {
    // Verify state parameter to prevent CSRF
    if (state != null) {
      final savedState = await _secureStorage.read(key: _kOAuthState);
      if (savedState == null || savedState != state) {
        return false; // CSRF protection: state mismatch
      }
      await _secureStorage.delete(key: _kOAuthState);
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'strava-token-exchange',
        body: {'code': code, 'grant_type': 'authorization_code'},
      );

      if (response.status != 200) return false;

      final data = response.data as Map<String, dynamic>;
      await _saveTokens(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Refresh expired access token via server-side Edge Function
  Future<bool> _refreshToken() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'strava-token-exchange',
        body: {
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.status != 200) return false;

      final data = response.data as Map<String, dynamic>;
      await _saveTokens(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get a valid access token, refreshing if needed
  Future<String?> _getValidToken() async {
    final expiry = await _secureStorage.read(key: _kTokenExpiry);
    final token = await _secureStorage.read(key: _kAccessToken);

    if (token == null) return null;

    // Refresh if expired or expiring within 60s
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expiry != null && now >= int.parse(expiry) - 60) {
      final refreshed = await _refreshToken();
      if (!refreshed) return null;
      return _secureStorage.read(key: _kAccessToken);
    }

    return token;
  }

  /// Whether the user has connected Strava
  Future<bool> get isConnected async {
    final token = await _secureStorage.read(key: _kAccessToken);
    return token != null;
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

    await _secureStorage.delete(key: _kAccessToken);
    await _secureStorage.delete(key: _kRefreshToken);
    await _secureStorage.delete(key: _kTokenExpiry);
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    await _secureStorage.write(
        key: _kAccessToken, value: data['access_token'] as String);
    await _secureStorage.write(
        key: _kRefreshToken, value: data['refresh_token'] as String);
    await _secureStorage.write(
        key: _kTokenExpiry, value: '${data['expires_at']}');
  }

  Future<String?> _getRefreshToken() async {
    return _secureStorage.read(key: _kRefreshToken);
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
