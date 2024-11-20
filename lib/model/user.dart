class RollBonuses {
  final int attackBonus;
  final int fortBonus;
  final int reflexBonus;
  final int willBonus;

  const RollBonuses({
    this.attackBonus = 0,
    this.fortBonus = 0,
    this.reflexBonus = 0,
    this.willBonus = 0,
  });

  factory RollBonuses.fromJson(Map<String, dynamic> json) {
    int parseBonus(dynamic value, String field) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        try {
          return int.parse(value);
        } catch (e) {
          print('Error parsing $field: $value');
          return 0;
        }
      }
      return 0;
    }

    return RollBonuses(
      attackBonus: parseBonus(json['attackBonus'], 'attackBonus'),
      fortBonus: parseBonus(json['fortBonus'], 'fortBonus'),
      reflexBonus: parseBonus(json['reflexBonus'], 'reflexBonus'),
      willBonus: parseBonus(json['willBonus'], 'willBonus'),
    );
  }

  bool get hasAnyBonus => 
    attackBonus != 0 || 
    fortBonus != 0 || 
    reflexBonus != 0 || 
    willBonus != 0;
}
