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
      };
}
