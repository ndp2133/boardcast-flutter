import 'current_conditions.dart';
import 'hourly_data.dart';
import 'daily_data.dart';

class MergedConditions {
  final CurrentConditions current;
  final List<HourlyData> hourly;
  final List<DailyData> daily;
  final bool isStale;
  final DateTime fetchedAt;

  const MergedConditions({
    required this.current,
    required this.hourly,
    required this.daily,
    this.isStale = false,
    required this.fetchedAt,
  });

  MergedConditions copyWith({bool? isStale}) => MergedConditions(
        current: current,
        hourly: hourly,
        daily: daily,
        isStale: isStale ?? this.isStale,
        fetchedAt: fetchedAt,
      );

  factory MergedConditions.fromJson(Map<String, dynamic> json) =>
      MergedConditions(
        current: CurrentConditions.fromJson(
            json['current'] as Map<String, dynamic>? ?? {'timestamp': ''}),
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
        'current': current.toJson(),
        'hourly': hourly.map((e) => e.toJson()).toList(),
        'daily': daily.map((e) => e.toJson()).toList(),
        '_stale': isStale,
        'fetchedAt': fetchedAt.toIso8601String(),
      };
}
