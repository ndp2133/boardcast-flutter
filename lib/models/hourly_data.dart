class HourlyData {
  final String time;
  final double? waveHeight;
  final double? wavePeriod;
  final double? waveDirection;
  final double? swellHeight;
  final double? swellPeriod;
  final double? swellDirection;
  final double? windSpeed;
  final double? windDirection;
  final double? windGusts;
  final double? temperature;
  final double? seaSurfaceTemp;
  final int? weatherCode;
  final double? tideHeight;

  const HourlyData({
    required this.time,
    this.waveHeight,
    this.wavePeriod,
    this.waveDirection,
    this.swellHeight,
    this.swellPeriod,
    this.swellDirection,
    this.windSpeed,
    this.windDirection,
    this.windGusts,
    this.temperature,
    this.seaSurfaceTemp,
    this.weatherCode,
    this.tideHeight,
  });

  factory HourlyData.fromJson(Map<String, dynamic> json) => HourlyData(
        time: json['time'] as String,
        waveHeight: (json['waveHeight'] as num?)?.toDouble(),
        wavePeriod: (json['wavePeriod'] as num?)?.toDouble(),
        waveDirection: (json['waveDirection'] as num?)?.toDouble(),
        swellHeight: (json['swellHeight'] as num?)?.toDouble(),
        swellPeriod: (json['swellPeriod'] as num?)?.toDouble(),
        swellDirection: (json['swellDirection'] as num?)?.toDouble(),
        windSpeed: (json['windSpeed'] as num?)?.toDouble(),
        windDirection: (json['windDirection'] as num?)?.toDouble(),
        windGusts: (json['windGusts'] as num?)?.toDouble(),
        temperature: (json['temperature'] as num?)?.toDouble(),
        seaSurfaceTemp: (json['seaSurfaceTemp'] as num?)?.toDouble(),
        weatherCode: json['weatherCode'] as int?,
        tideHeight: (json['tideHeight'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'time': time,
        if (waveHeight != null) 'waveHeight': waveHeight,
        if (wavePeriod != null) 'wavePeriod': wavePeriod,
        if (waveDirection != null) 'waveDirection': waveDirection,
        if (swellHeight != null) 'swellHeight': swellHeight,
        if (swellPeriod != null) 'swellPeriod': swellPeriod,
        if (swellDirection != null) 'swellDirection': swellDirection,
        if (windSpeed != null) 'windSpeed': windSpeed,
        if (windDirection != null) 'windDirection': windDirection,
        if (windGusts != null) 'windGusts': windGusts,
        if (temperature != null) 'temperature': temperature,
        if (seaSurfaceTemp != null) 'seaSurfaceTemp': seaSurfaceTemp,
        if (weatherCode != null) 'weatherCode': weatherCode,
        if (tideHeight != null) 'tideHeight': tideHeight,
      };
}
