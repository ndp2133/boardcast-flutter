import 'hourly_data.dart';
import 'daily_data.dart';

class MergedConditions {
  final List<HourlyData> hourly;
  final List<DailyData> daily;
  final bool isStale;
  final DateTime fetchedAt;

  const MergedConditions({
    required this.hourly,
    required this.daily,
    this.isStale = false,
    required this.fetchedAt,
  });

  factory MergedConditions.fromJson(Map<String, dynamic> json) =>
      MergedConditions(
        hourly: (json['hourly'] as List)
            .map((e) => HourlyData.fromJson(e as Map<String, dynamic>))
            .toList(),
        daily: (json['daily'] as List)
            .map((e) => DailyData.fromJson(e as Map<String, dynamic>))
            .toList(),
        isStale: json['_stale'] as bool? ?? false,
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'hourly': hourly.map((e) => e.toJson()).toList(),
        'daily': daily.map((e) => e.toJson()).toList(),
        '_stale': isStale,
        'fetchedAt': fetchedAt.toIso8601String(),
      };
}
