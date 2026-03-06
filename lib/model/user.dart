class RollBonuses {
  final int attackBonus;
  final int fortBonus;
  final int reflexBonus;
  final int willBonus;
  final int casterLevel;

  // D&D ability scores: score and modifier for each
  final int maxHp;
  final int maxTempHp;
  final int strScore;
  final int strMod;
  final int conScore;
  final int conMod;
  final int dexScore;
  final int dexMod;
  final int intScore;
  final int intMod;
  final int wisScore;
  final int wisMod;
  final int chaScore;
  final int chaMod;

  const RollBonuses({
    this.attackBonus = 0,
    this.fortBonus = 0,
    this.reflexBonus = 0,
    this.willBonus = 0,
    this.casterLevel = 0,
    this.maxHp = 0,
    this.maxTempHp = 0,
    this.strScore = 0,
    this.strMod = 0,
    this.conScore = 0,
    this.conMod = 0,
    this.dexScore = 0,
    this.dexMod = 0,
    this.intScore = 0,
    this.intMod = 0,
    this.wisScore = 0,
    this.wisMod = 0,
    this.chaScore = 0,
    this.chaMod = 0,
  });

  factory RollBonuses.fromJson(Map<String, dynamic> json) {
    int parseIntField(dynamic value, String field) {
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

    int parseFirstOfKeys(List<String> keys, String fieldNameForLogs) {
      for (final key in keys) {
        if (json.containsKey(key)) {
          return parseIntField(json[key], '$fieldNameForLogs ($key)');
        }
      }
      return 0;
    }

    return RollBonuses(
      attackBonus: parseIntField(json['attackBonus'], 'attackBonus'),
      fortBonus: parseIntField(json['fortBonus'], 'fortBonus'),
      reflexBonus: parseIntField(json['reflexBonus'], 'reflexBonus'),
      willBonus: parseIntField(json['willBonus'], 'willBonus'),
      casterLevel: parseIntField(json['casterLevel'], 'casterLevel'),
      maxHp: parseFirstOfKeys(['maxHp', 'hpMax', 'hp'], 'maxHp'),
      maxTempHp: parseFirstOfKeys(['maxTempHp', 'tempHpMax', 'tempHp'], 'maxTempHp'),
      strScore: parseIntField(json['strScore'], 'strScore'),
      strMod: parseIntField(json['strMod'], 'strMod'),
      conScore: parseIntField(json['conScore'], 'conScore'),
      conMod: parseIntField(json['conMod'], 'conMod'),
      dexScore: parseIntField(json['dexScore'], 'dexScore'),
      dexMod: parseIntField(json['dexMod'], 'dexMod'),
      intScore: parseIntField(json['intScore'], 'intScore'),
      intMod: parseIntField(json['intMod'], 'intMod'),
      wisScore: parseIntField(json['wisScore'], 'wisScore'),
      wisMod: parseIntField(json['wisMod'], 'wisMod'),
      chaScore: parseIntField(json['chaScore'], 'chaScore'),
      chaMod: parseIntField(json['chaMod'], 'chaMod'),
    );
  }

  bool get hasAnyBonus =>
      attackBonus != 0 ||
      fortBonus != 0 ||
      reflexBonus != 0 ||
      willBonus != 0;
}
