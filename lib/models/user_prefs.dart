class UserPrefs {
  final double? minWaveHeight; // meters
  final double? maxWaveHeight; // meters
  final double? maxWindSpeed; // km/h
  final String? preferredWindDir; // 'offshore', 'onshore', 'any'
  final String? preferredTide; // 'low', 'mid', 'high', 'any'
  final String? skillLevel; // 'beginner', 'intermediate', 'advanced'

  const UserPrefs({
    this.minWaveHeight,
    this.maxWaveHeight,
    this.maxWindSpeed,
    this.preferredWindDir,
    this.preferredTide,
    this.skillLevel,
  });

  static const defaultPrefs = UserPrefs(
    minWaveHeight: 0.3,
    maxWaveHeight: 2.0,
    maxWindSpeed: 25.0,
    preferredWindDir: 'offshore',
    preferredTide: 'any',
    skillLevel: 'intermediate',
  );

  UserPrefs copyWith({
    double? minWaveHeight,
    double? maxWaveHeight,
    double? maxWindSpeed,
    String? preferredWindDir,
    String? preferredTide,
    String? skillLevel,
  }) =>
      UserPrefs(
        minWaveHeight: minWaveHeight ?? this.minWaveHeight,
        maxWaveHeight: maxWaveHeight ?? this.maxWaveHeight,
        maxWindSpeed: maxWindSpeed ?? this.maxWindSpeed,
        preferredWindDir: preferredWindDir ?? this.preferredWindDir,
        preferredTide: preferredTide ?? this.preferredTide,
        skillLevel: skillLevel ?? this.skillLevel,
      );

  factory UserPrefs.fromJson(Map<String, dynamic> json) => UserPrefs(
        minWaveHeight: (json['minWaveHeight'] as num?)?.toDouble(),
        maxWaveHeight: (json['maxWaveHeight'] as num?)?.toDouble(),
        maxWindSpeed: (json['maxWindSpeed'] as num?)?.toDouble(),
        preferredWindDir: json['preferredWindDir'] as String?,
        preferredTide: json['preferredTide'] as String?,
        skillLevel: json['skillLevel'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (minWaveHeight != null) 'minWaveHeight': minWaveHeight,
        if (maxWaveHeight != null) 'maxWaveHeight': maxWaveHeight,
        if (maxWindSpeed != null) 'maxWindSpeed': maxWindSpeed,
        if (preferredWindDir != null) 'preferredWindDir': preferredWindDir,
        if (preferredTide != null) 'preferredTide': preferredTide,
        if (skillLevel != null) 'skillLevel': skillLevel,
      };
}
