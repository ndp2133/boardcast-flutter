/// Analytics provider — exposes AnalyticsService to the widget tree.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_service.dart';

final analyticsProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});
