class Location {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final String timezone;
  final double beachFacing;
  final double offshoreMin;
  final double offshoreMax;
  final double onshoreMin;
  final double onshoreMax;
  final String noaaStation;
  final String breakType; // 'beach', 'point', 'reef'
  final String? description; // Spot knowledge for AI coach
  // Per-spot scoring overrides (null = use break-type defaults)
  final double? swellWindowWidth;
  final double? tideSensitivity;
  final double? windExposure;
  final double? minWaveEnergy;

  const Location({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.timezone,
    required this.beachFacing,
    required this.offshoreMin,
    required this.offshoreMax,
    required this.onshoreMin,
    required this.onshoreMax,
    required this.noaaStation,
    this.breakType = 'beach',
    this.description,
    this.swellWindowWidth,
    this.tideSensitivity,
    this.windExposure,
    this.minWaveEnergy,
  });

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        id: json['id'] as String,
        name: json['name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        timezone: json['timezone'] as String,
        beachFacing: (json['beachFacing'] as num).toDouble(),
        offshoreMin: (json['offshoreMin'] as num).toDouble(),
        offshoreMax: (json['offshoreMax'] as num).toDouble(),
        onshoreMin: (json['onshoreMin'] as num).toDouble(),
        onshoreMax: (json['onshoreMax'] as num).toDouble(),
        noaaStation: json['noaaStation'] as String,
        breakType: json['breakType'] as String? ?? 'beach',
        description: json['description'] as String?,
        swellWindowWidth: (json['swellWindowWidth'] as num?)?.toDouble(),
        tideSensitivity: (json['tideSensitivity'] as num?)?.toDouble(),
        windExposure: (json['windExposure'] as num?)?.toDouble(),
        minWaveEnergy: (json['minWaveEnergy'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lon': lon,
        'timezone': timezone,
        'beachFacing': beachFacing,
        'offshoreMin': offshoreMin,
        'offshoreMax': offshoreMax,
        'onshoreMin': onshoreMin,
        'onshoreMax': onshoreMax,
        'noaaStation': noaaStation,
        'breakType': breakType,
        if (description != null) 'description': description,
        if (swellWindowWidth != null) 'swellWindowWidth': swellWindowWidth,
        if (tideSensitivity != null) 'tideSensitivity': tideSensitivity,
        if (windExposure != null) 'windExposure': windExposure,
        if (minWaveEnergy != null) 'minWaveEnergy': minWaveEnergy,
      };
}
