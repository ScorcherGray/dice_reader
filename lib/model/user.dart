
class RollBonuses {
  int attackBonus;
  int fortBonus;
  int reflexBonus;
  int willBonus;

  RollBonuses(
      {this.attackBonus=0,
      this.fortBonus=0,
      this.reflexBonus=0,
      this.willBonus=0});

  factory RollBonuses.fromJson(dynamic json){
    return RollBonuses(
      attackBonus: json['attackBonus'],
      fortBonus: json['fortBonus'],
      reflexBonus: json['reflexBonus'],
      willBonus: json['willBonus'],
    );
  }

  Map toJson() => {
    "attackBonus": attackBonus,
    "fortBonus": fortBonus,
    "reflexBonus": reflexBonus,
    "willBonus": willBonus,
  };
}
