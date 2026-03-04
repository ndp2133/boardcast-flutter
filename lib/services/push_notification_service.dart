import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase automatically shows notification on Android when app is in background
  // No additional handling needed
}

class PushNotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  SupabaseClient? _supabase;
  String? Function()? _getUserId;
  bool Function()? _isGuest;
  String Function()? _getLocationId;

  bool _initialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  void configure({
    required SupabaseClient supabase,
    required String? Function() getUserId,
    required bool Function() isGuest,
    required String Function() getLocationId,
  }) {
    _supabase = supabase;
    _getUserId = getUserId;
    _isGuest = isGuest;
    _getLocationId = getLocationId;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Set up background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize local notifications for foreground display
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      'surf_alerts',
      'Surf Alerts',
      description: 'Morning surf condition alerts',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Request iOS provisional permission (silent, no prompt)
    if (Platform.isIOS) {
      await FirebaseMessaging.instance.requestPermission(
        alert: false,
        badge: false,
        sound: false,
        provisional: true,
      );
    }
  }

  /// Request full notification permission and subscribe
  Future<bool> subscribe() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }

    // Get FCM token
    _fcmToken = await FirebaseMessaging.instance.getToken();
    if (_fcmToken == null) return false;

    // Save to Supabase
    await _saveToken(_fcmToken!);

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

    return true;
  }

  /// Unsubscribe from push notifications
  Future<void> unsubscribe() async {
    if (_fcmToken != null) {
      await _deleteToken(_fcmToken!);
    }
    await FirebaseMessaging.instance.deleteToken();
    _fcmToken = null;
  }

  /// Re-subscribe silently if token exists (call on app start)
  Future<void> refreshToken() async {
    _fcmToken = await FirebaseMessaging.instance.getToken();
    if (_fcmToken != null) {
      await _saveToken(_fcmToken!);
    }
  }

  /// Update location for push notifications
  Future<void> updateLocation(String locationId) async {
    if (_fcmToken == null) return;
    final userId = _getUserId?.call();
    if (userId == null) return;

    await _supabase?.from('device_tokens').update({
      'location_id': locationId,
    }).eq('user_id', userId).eq('fcm_token', _fcmToken!);
  }

  /// Get current permission status
  Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus;
  }

  Future<void> _saveToken(String token) async {
    final userId = _getUserId?.call();
    if (userId == null || (_isGuest?.call() ?? true)) return;

    final locationId = _getLocationId?.call() ?? 'rockaway';
    final platform = Platform.isIOS ? 'ios' : 'android';

    await _supabase?.from('device_tokens').upsert({
      'user_id': userId,
      'fcm_token': token,
      'platform': platform,
      'location_id': locationId,
    }, onConflict: 'user_id,fcm_token');
  }

  Future<void> _deleteToken(String token) async {
    final userId = _getUserId?.call();
    if (userId == null) return;

    await _supabase
        ?.from('device_tokens')
        .delete()
        .eq('user_id', userId)
        .eq('fcm_token', token);
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Boardcast',
      notification.body ?? 'Check the surf!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'surf_alerts',
          'Surf Alerts',
          channelDescription: 'Morning surf condition alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
