class GearItem {
  GearItem({
    required this.id,
    required this.name,
    this.description = '',
    this.quantity = 1,
    this.equipped = false,
  });

  final String id;
  String name;
  String description;
  int quantity;
  bool equipped;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'quantity': quantity,
        'equipped': equipped,
      };

  factory GearItem.fromJson(Map<String, dynamic> json) => GearItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 1,
        equipped: json['equipped'] as bool? ?? false,
      );
}
