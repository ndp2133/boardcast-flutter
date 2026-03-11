class UserPrefs {
  final double? minWaveHeight; // meters
  final double? maxWaveHeight; // meters
  final double? maxWindSpeed; // km/h
  final String? preferredTide; // 'low', 'mid', 'high', 'any'
  final String? skillLevel; // 'beginner', 'intermediate', 'advanced'
  final Map<String, double>? weights; // scoring weight overrides: height, swellDir, swellQuality
  final String? surfStyle; // performance, longboard, casual, allround

  const UserPrefs({
    this.minWaveHeight,
    this.maxWaveHeight,
    this.maxWindSpeed,
    this.preferredTide,
    this.skillLevel,
    this.weights,
    this.surfStyle,
  });

  static const defaultPrefs = UserPrefs(
    minWaveHeight: 0.3,
    maxWaveHeight: 2.0,
    maxWindSpeed: 25.0,
    preferredTide: 'any',
    skillLevel: 'intermediate',
  );

  bool get hasCustomWeights => weights != null && weights!.isNotEmpty;

  UserPrefs copyWith({
    double? minWaveHeight,
    double? maxWaveHeight,
    double? maxWindSpeed,
    String? preferredTide,
    String? skillLevel,
    Map<String, double>? weights,
    String? surfStyle,
  }) =>
      UserPrefs(
        minWaveHeight: minWaveHeight ?? this.minWaveHeight,
        maxWaveHeight: maxWaveHeight ?? this.maxWaveHeight,
        maxWindSpeed: maxWindSpeed ?? this.maxWindSpeed,
        preferredTide: preferredTide ?? this.preferredTide,
        skillLevel: skillLevel ?? this.skillLevel,
        weights: weights ?? this.weights,
        surfStyle: surfStyle ?? this.surfStyle,
      );

  factory UserPrefs.fromJson(Map<String, dynamic> json) => UserPrefs(
        minWaveHeight: (json['minWaveHeight'] as num?)?.toDouble(),
        maxWaveHeight: (json['maxWaveHeight'] as num?)?.toDouble(),
        maxWindSpeed: (json['maxWindSpeed'] as num?)?.toDouble(),
        preferredTide: json['preferredTide'] as String?,
        skillLevel: json['skillLevel'] as String?,
        weights: json['weights'] != null
            ? (json['weights'] as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, (v as num).toDouble()))
            : null,
        surfStyle: json['surfStyle'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (minWaveHeight != null) 'minWaveHeight': minWaveHeight,
        if (maxWaveHeight != null) 'maxWaveHeight': maxWaveHeight,
        if (maxWindSpeed != null) 'maxWindSpeed': maxWindSpeed,
        if (preferredTide != null) 'preferredTide': preferredTide,
        if (skillLevel != null) 'skillLevel': skillLevel,
        if (weights != null) 'weights': weights,
        if (surfStyle != null) 'surfStyle': surfStyle,
      };
}
