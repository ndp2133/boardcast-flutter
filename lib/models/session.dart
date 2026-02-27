class SessionConditions {
  final double? matchScore;
  final double? waveHeight;
  final double? windSpeed;
  final double? windDirection;
  final double? swellDirection;
  final double? swellPeriod;

  const SessionConditions({
    this.matchScore,
    this.waveHeight,
    this.windSpeed,
    this.windDirection,
    this.swellDirection,
    this.swellPeriod,
  });

  factory SessionConditions.fromJson(Map<String, dynamic> json) =>
      SessionConditions(
        matchScore: (json['matchScore'] as num?)?.toDouble(),
        waveHeight: (json['waveHeight'] as num?)?.toDouble(),
        windSpeed: (json['windSpeed'] as num?)?.toDouble(),
        windDirection: (json['windDirection'] as num?)?.toDouble(),
        swellDirection: (json['swellDirection'] as num?)?.toDouble(),
        swellPeriod: (json['swellPeriod'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        if (matchScore != null) 'matchScore': matchScore,
        if (waveHeight != null) 'waveHeight': waveHeight,
        if (windSpeed != null) 'windSpeed': windSpeed,
        if (windDirection != null) 'windDirection': windDirection,
        if (swellDirection != null) 'swellDirection': swellDirection,
        if (swellPeriod != null) 'swellPeriod': swellPeriod,
      };
}

class Session {
  final String id;
  final String? userId;
  final String locationId;
  final String date;
  final String status; // 'planned', 'completed'
  final List<int>? selectedHours;
  final int? rating;
  final int? calibration; // -1, 0, 1
  final String? boardId;
  final List<String>? tags;
  final String? notes;
  final SessionConditions? conditions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Session({
    required this.id,
    this.userId,
    required this.locationId,
    required this.date,
    required this.status,
    this.selectedHours,
    this.rating,
    this.calibration,
    this.boardId,
    this.tags,
    this.notes,
    this.conditions,
    required this.createdAt,
    required this.updatedAt,
  });

  Session copyWith({
    String? status,
    int? rating,
    int? calibration,
    String? boardId,
    List<String>? tags,
    String? notes,
    SessionConditions? conditions,
    List<int>? selectedHours,
  }) =>
      Session(
        id: id,
        userId: userId,
        locationId: locationId,
        date: date,
        status: status ?? this.status,
        selectedHours: selectedHours ?? this.selectedHours,
        rating: rating ?? this.rating,
        calibration: calibration ?? this.calibration,
        boardId: boardId ?? this.boardId,
        tags: tags ?? this.tags,
        notes: notes ?? this.notes,
        conditions: conditions ?? this.conditions,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as String,
        userId: json['userId'] as String?,
        locationId: json['locationId'] as String,
        date: json['date'] as String,
        status: json['status'] as String,
        selectedHours: (json['selectedHours'] as List?)?.cast<int>(),
        rating: json['rating'] as int?,
        calibration: json['calibration'] as int?,
        boardId: json['boardId'] as String?,
        tags: (json['tags'] as List?)?.cast<String>(),
        notes: json['notes'] as String?,
        conditions: json['conditions'] != null
            ? SessionConditions.fromJson(
                json['conditions'] as Map<String, dynamic>)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (userId != null) 'userId': userId,
        'locationId': locationId,
        'date': date,
        'status': status,
        if (selectedHours != null) 'selectedHours': selectedHours,
        if (rating != null) 'rating': rating,
        if (calibration != null) 'calibration': calibration,
        if (boardId != null) 'boardId': boardId,
        if (tags != null) 'tags': tags,
        if (notes != null) 'notes': notes,
        if (conditions != null) 'conditions': conditions!.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
