/// Current conditions snapshot — merged from marine + weather + tide APIs
class CurrentConditions {
  // Marine
  final double? waveHeight;
  final double? wavePeriod;
  final double? waveDirection;
  final double? swellHeight;
  final double? swellPeriod;
  final double? swellDirection;
  final double? waterTemp;

  // Weather
  final double? temperature;
  final double? feelsLike;
  final double? windSpeed;
  final double? windDirection;
  final double? windGusts;
  final int? weatherCode;

  // Tide
  final double? tideHeight;
  final String? tideTrend; // 'Rising', 'Falling', 'Slack'

  final String timestamp;

  const CurrentConditions({
    this.waveHeight,
    this.wavePeriod,
    this.waveDirection,
    this.swellHeight,
    this.swellPeriod,
    this.swellDirection,
    this.waterTemp,
    this.temperature,
    this.feelsLike,
    this.windSpeed,
    this.windDirection,
    this.windGusts,
    this.weatherCode,
    this.tideHeight,
    this.tideTrend,
    required this.timestamp,
  });

  factory CurrentConditions.fromJson(Map<String, dynamic> json) =>
      CurrentConditions(
        waveHeight: (json['waveHeight'] as num?)?.toDouble(),
        wavePeriod: (json['wavePeriod'] as num?)?.toDouble(),
        waveDirection: (json['waveDirection'] as num?)?.toDouble(),
        swellHeight: (json['swellHeight'] as num?)?.toDouble(),
        swellPeriod: (json['swellPeriod'] as num?)?.toDouble(),
        swellDirection: (json['swellDirection'] as num?)?.toDouble(),
        waterTemp: (json['waterTemp'] as num?)?.toDouble(),
        temperature: (json['temperature'] as num?)?.toDouble(),
        feelsLike: (json['feelsLike'] as num?)?.toDouble(),
        windSpeed: (json['windSpeed'] as num?)?.toDouble(),
        windDirection: (json['windDirection'] as num?)?.toDouble(),
        windGusts: (json['windGusts'] as num?)?.toDouble(),
        weatherCode: json['weatherCode'] as int?,
        tideHeight: (json['tideHeight'] as num?)?.toDouble(),
        tideTrend: json['tideTrend'] as String?,
        timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        if (waveHeight != null) 'waveHeight': waveHeight,
        if (wavePeriod != null) 'wavePeriod': wavePeriod,
        if (waveDirection != null) 'waveDirection': waveDirection,
        if (swellHeight != null) 'swellHeight': swellHeight,
        if (swellPeriod != null) 'swellPeriod': swellPeriod,
        if (swellDirection != null) 'swellDirection': swellDirection,
        if (waterTemp != null) 'waterTemp': waterTemp,
        if (temperature != null) 'temperature': temperature,
        if (feelsLike != null) 'feelsLike': feelsLike,
        if (windSpeed != null) 'windSpeed': windSpeed,
        if (windDirection != null) 'windDirection': windDirection,
        if (windGusts != null) 'windGusts': windGusts,
        if (weatherCode != null) 'weatherCode': weatherCode,
        if (tideHeight != null) 'tideHeight': tideHeight,
        if (tideTrend != null) 'tideTrend': tideTrend,
        'timestamp': timestamp,
      };
}
