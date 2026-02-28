/// Store service provider — singleton for Hive-backed persistence
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/store_service.dart';

/// The store service singleton. Must be initialized before use.
final storeServiceProvider = Provider<StoreService>((ref) {
  return StoreService();
});
