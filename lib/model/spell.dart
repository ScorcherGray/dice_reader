class SpellItem {
  SpellItem({
    required this.id,
    required this.name,
    this.description = '',
    this.level = 0,
    int preparedCount = 0,
    bool? prepared,
  }) : preparedCount =
            preparedCount > 0 ? preparedCount : ((prepared ?? false) ? 1 : 0);

  final String id;
  String name;
  String description;
  int level;
  int preparedCount;

  bool get prepared => preparedCount > 0;
  set prepared(bool value) {
    if (value && preparedCount == 0) {
      preparedCount = 1;
    } else if (!value) {
      preparedCount = 0;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'level': level,
        'preparedCount': preparedCount,
        'prepared': prepared,
      };

  factory SpellItem.fromJson(Map<String, dynamic> json) {
    final legacyPrepared = json['prepared'] as bool? ?? false;
    final count = json['preparedCount'] as int? ?? (legacyPrepared ? 1 : 0);
    return SpellItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      level: json['level'] as int? ?? 0,
      preparedCount: count < 0 ? 0 : count,
    );
  }
}
