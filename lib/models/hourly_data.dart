class HourlyData {
  final String time;
  final double? waveHeight;
  final double? wavePeriod;
  final double? waveDirection;
  final double? swellHeight;
  final double? swellPeriod;
  final double? swellPeakPeriod;
  final double? swellDirection;
  final double? secondarySwellHeight;
  final double? secondarySwellPeriod;
  final double? secondarySwellDirection;
  final double? secondarySwellPeakPeriod;
  final double? windSpeed;
  final double? windDirection;
  final double? windGusts;
  final double? temperature;
  final double? seaSurfaceTemp;
  final int? weatherCode;
  final double? tideHeight;
  final double? oceanCurrentVelocity;
  final double? oceanCurrentDirection;

  const HourlyData({
    required this.time,
    this.waveHeight,
    this.wavePeriod,
    this.waveDirection,
    this.swellHeight,
    this.swellPeriod,
    this.swellPeakPeriod,
    this.swellDirection,
    this.secondarySwellHeight,
    this.secondarySwellPeriod,
    this.secondarySwellDirection,
    this.secondarySwellPeakPeriod,
    this.windSpeed,
    this.windDirection,
    this.windGusts,
    this.temperature,
    this.seaSurfaceTemp,
    this.weatherCode,
    this.tideHeight,
    this.oceanCurrentVelocity,
    this.oceanCurrentDirection,
  });

  factory HourlyData.fromJson(Map<String, dynamic> json) => HourlyData(
        time: json['time'] as String,
        waveHeight: (json['waveHeight'] as num?)?.toDouble(),
        wavePeriod: (json['wavePeriod'] as num?)?.toDouble(),
        waveDirection: (json['waveDirection'] as num?)?.toDouble(),
        swellHeight: (json['swellHeight'] as num?)?.toDouble(),
        swellPeriod: (json['swellPeriod'] as num?)?.toDouble(),
        swellPeakPeriod: (json['swellPeakPeriod'] as num?)?.toDouble(),
        swellDirection: (json['swellDirection'] as num?)?.toDouble(),
        secondarySwellHeight: (json['secondarySwellHeight'] as num?)?.toDouble(),
        secondarySwellPeriod: (json['secondarySwellPeriod'] as num?)?.toDouble(),
        secondarySwellDirection: (json['secondarySwellDirection'] as num?)?.toDouble(),
        secondarySwellPeakPeriod: (json['secondarySwellPeakPeriod'] as num?)?.toDouble(),
        windSpeed: (json['windSpeed'] as num?)?.toDouble(),
        windDirection: (json['windDirection'] as num?)?.toDouble(),
        windGusts: (json['windGusts'] as num?)?.toDouble(),
        temperature: (json['temperature'] as num?)?.toDouble(),
        seaSurfaceTemp: (json['seaSurfaceTemp'] as num?)?.toDouble(),
        weatherCode: json['weatherCode'] as int?,
        tideHeight: (json['tideHeight'] as num?)?.toDouble(),
        oceanCurrentVelocity: (json['oceanCurrentVelocity'] as num?)?.toDouble(),
        oceanCurrentDirection: (json['oceanCurrentDirection'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'time': time,
        if (waveHeight != null) 'waveHeight': waveHeight,
        if (wavePeriod != null) 'wavePeriod': wavePeriod,
        if (waveDirection != null) 'waveDirection': waveDirection,
        if (swellHeight != null) 'swellHeight': swellHeight,
        if (swellPeriod != null) 'swellPeriod': swellPeriod,
        if (swellPeakPeriod != null) 'swellPeakPeriod': swellPeakPeriod,
        if (swellDirection != null) 'swellDirection': swellDirection,
        if (secondarySwellHeight != null) 'secondarySwellHeight': secondarySwellHeight,
        if (secondarySwellPeriod != null) 'secondarySwellPeriod': secondarySwellPeriod,
        if (secondarySwellDirection != null) 'secondarySwellDirection': secondarySwellDirection,
        if (secondarySwellPeakPeriod != null) 'secondarySwellPeakPeriod': secondarySwellPeakPeriod,
        if (windSpeed != null) 'windSpeed': windSpeed,
        if (windDirection != null) 'windDirection': windDirection,
        if (windGusts != null) 'windGusts': windGusts,
        if (temperature != null) 'temperature': temperature,
        if (seaSurfaceTemp != null) 'seaSurfaceTemp': seaSurfaceTemp,
        if (weatherCode != null) 'weatherCode': weatherCode,
        if (tideHeight != null) 'tideHeight': tideHeight,
        if (oceanCurrentVelocity != null) 'oceanCurrentVelocity': oceanCurrentVelocity,
        if (oceanCurrentDirection != null) 'oceanCurrentDirection': oceanCurrentDirection,
      };
}
