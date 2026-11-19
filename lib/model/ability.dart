class AbilityItem {
  AbilityItem({
    required this.id,
    required this.name,
    this.description = '',
    this.category = 'Class Feature',
    this.usesMax = 0,
    this.usesRemaining = 0,
    this.isActive = true,
  });

  final String id;
  String name;
  String description;
  String category;
  int usesMax;
  int usesRemaining;
  bool isActive;

  bool get hasLimitedUses => usesMax > 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'usesMax': usesMax,
        'usesRemaining': usesRemaining,
        'isActive': isActive,
      };

  factory AbilityItem.fromJson(Map<String, dynamic> json) => AbilityItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'Class Feature',
        usesMax: json['usesMax'] as int? ?? 0,
        usesRemaining:
            json['usesRemaining'] as int? ?? (json['usesMax'] as int? ?? 0),
        isActive: json['isActive'] as bool? ?? true,
      );
}
