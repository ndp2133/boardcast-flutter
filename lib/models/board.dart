class Board {
  final String id;
  final String name;
  final String type; // matches BoardType.id
  final String? notes;

  const Board({
    required this.id,
    required this.name,
    required this.type,
    this.notes,
  });

  Board copyWith({String? name, String? type, String? notes}) => Board(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        notes: notes ?? this.notes,
      );

  factory Board.fromJson(Map<String, dynamic> json) => Board(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        if (notes != null) 'notes': notes,
      };
}
