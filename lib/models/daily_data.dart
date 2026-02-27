class DailyData {
  final String date;
  final double? waveHeightMax;
  final double? wavePeriodMax;
  final double? swellPeriodMax;
  final double? swellDirectionDominant;
  final double? windSpeedMax;
  final double? windGustsMax;
  final double? tempMax;
  final double? tempMin;
  final int? weatherCode;

  const DailyData({
    required this.date,
    this.waveHeightMax,
    this.wavePeriodMax,
    this.swellPeriodMax,
    this.swellDirectionDominant,
    this.windSpeedMax,
    this.windGustsMax,
    this.tempMax,
    this.tempMin,
    this.weatherCode,
  });

  factory DailyData.fromJson(Map<String, dynamic> json) => DailyData(
        date: json['date'] as String,
        waveHeightMax: (json['waveHeightMax'] as num?)?.toDouble(),
        wavePeriodMax: (json['wavePeriodMax'] as num?)?.toDouble(),
        swellPeriodMax: (json['swellPeriodMax'] as num?)?.toDouble(),
        swellDirectionDominant:
            (json['swellDirectionDominant'] as num?)?.toDouble(),
        windSpeedMax: (json['windSpeedMax'] as num?)?.toDouble(),
        windGustsMax: (json['windGustsMax'] as num?)?.toDouble(),
        tempMax: (json['tempMax'] as num?)?.toDouble(),
        tempMin: (json['tempMin'] as num?)?.toDouble(),
        weatherCode: json['weatherCode'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        if (waveHeightMax != null) 'waveHeightMax': waveHeightMax,
        if (wavePeriodMax != null) 'wavePeriodMax': wavePeriodMax,
        if (swellPeriodMax != null) 'swellPeriodMax': swellPeriodMax,
        if (swellDirectionDominant != null)
          'swellDirectionDominant': swellDirectionDominant,
        if (windSpeedMax != null) 'windSpeedMax': windSpeedMax,
        if (windGustsMax != null) 'windGustsMax': windGustsMax,
        if (tempMax != null) 'tempMax': tempMax,
        if (tempMin != null) 'tempMin': tempMin,
        if (weatherCode != null) 'weatherCode': weatherCode,
      };
}
