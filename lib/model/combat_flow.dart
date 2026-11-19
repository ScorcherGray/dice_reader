enum CombatTiming {
  allyAura,
  actionRider,
  reaction,
  swiftFree,
}

class CombatTriggerItem {
  final String id;
  final String sourceId;
  final String sourceName;
  final String sourceType; // 'gear', 'spell', 'ability'
  final CombatTiming timing;
  final String tagLabel;
  final String parameter;
  final String detail;
  final String? counterKey;
  final String? counterName;
  final int counterValue;

  const CombatTriggerItem({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.sourceType,
    required this.timing,
    required this.tagLabel,
    this.parameter = '',
    required this.detail,
    this.counterKey,
    this.counterName,
    this.counterValue = 0,
  });
}

class CombatFlowParser {
  static final RegExp _timingRegex = RegExp(
    r'\[(Aura|Rider|Reaction|Immediate|Swift|Free)(?::\s*([^\]]+))?\]',
    caseSensitive: false,
  );

  static final RegExp _counterRegex = RegExp(
    r'\[Counter(?::\s*([^\]]+))?\]',
    caseSensitive: false,
  );

  static int compareTriggers(CombatTriggerItem a, CombatTriggerItem b) {
    // 1. Timing category order: Aura -> Action Rider -> Reaction -> Swift/Free
    final timingCmp = a.timing.index.compareTo(b.timing.index);
    if (timingCmp != 0) return timingCmp;

    // 2. Group by parameter / sub-tag (e.g. "Cast Glyph of Warding" vs "Spell Cast")
    final paramA = a.parameter.trim().toLowerCase();
    final paramB = b.parameter.trim().toLowerCase();
    if (paramA.isNotEmpty && paramB.isNotEmpty) {
      final pCmp = paramA.compareTo(paramB);
      if (pCmp != 0) return pCmp;
    } else if (paramA.isNotEmpty) {
      return -1; // Named triggers come first
    } else if (paramB.isNotEmpty) {
      return 1;
    }

    // 3. Group by tagLabel
    final tagCmp = a.tagLabel.toLowerCase().compareTo(b.tagLabel.toLowerCase());
    if (tagCmp != 0) return tagCmp;

    // 4. Stable sort by sourceName
    return a.sourceName.toLowerCase().compareTo(b.sourceName.toLowerCase());
  }

  static List<CombatTriggerItem> parse({
    required String sourceId,
    required String sourceName,
    required String sourceType,
    required String description,
    required Map<String, int> counters,
  }) {
    final results = <CombatTriggerItem>[];
    if (description.trim().isEmpty) return results;

    final matches = _timingRegex.allMatches(description).toList();
    if (matches.isEmpty) return results;

    for (var i = 0; i < matches.length; i++) {
      final currentMatch = matches[i];
      final tagWord = currentMatch.group(1)?.toLowerCase() ?? '';
      final parameter = currentMatch.group(2)?.trim() ?? '';

      CombatTiming timing;
      String tagLabel;

      switch (tagWord) {
        case 'aura':
          timing = CombatTiming.allyAura;
          tagLabel = parameter.isNotEmpty ? 'Aura: $parameter' : 'Ally Aura';
        case 'rider':
          timing = CombatTiming.actionRider;
          tagLabel =
              parameter.isNotEmpty ? 'Rider: $parameter' : 'Action Rider';
        case 'reaction':
        case 'immediate':
          timing = CombatTiming.reaction;
          tagLabel = parameter.isNotEmpty
              ? 'Reaction: $parameter'
              : 'Reaction / Trigger';
        case 'swift':
        case 'free':
          timing = CombatTiming.swiftFree;
          tagLabel = parameter.isNotEmpty
              ? '${tagWord[0].toUpperCase()}${tagWord.substring(1)}: $parameter'
              : (tagWord == 'swift' ? 'Swift Action' : 'Free Action');
        default:
          timing = CombatTiming.actionRider;
          tagLabel = 'Combat Rider';
      }

      // Determine text segment from end of this tag to start of next timing tag (or end of string)
      final startIndex = currentMatch.end;
      final endIndex =
          (i + 1 < matches.length) ? matches[i + 1].start : description.length;
      var rawSegment = description.substring(startIndex, endIndex);

      // Check for counter tag in this segment
      String? counterName;
      String? counterKey;
      int counterValue = 0;

      final counterMatch = _counterRegex.firstMatch(rawSegment);
      if (counterMatch != null) {
        counterName = counterMatch.group(1)?.trim();
        if (counterName == null || counterName.isEmpty) {
          counterName = 'Count';
        }
        counterKey = '${sourceId}_$counterName';
        counterValue = counters[counterKey] ?? 0;

        // Remove counter tag from display text
        rawSegment =
            rawSegment.replaceRange(counterMatch.start, counterMatch.end, '');
      }

      // Clean up detail text
      final detail = rawSegment.trim();
      if (detail.isEmpty && parameter.isEmpty) continue;

      results.add(CombatTriggerItem(
        id: '${sourceId}_${timing.name}_$i',
        sourceId: sourceId,
        sourceName: sourceName,
        sourceType: sourceType,
        timing: timing,
        tagLabel: tagLabel,
        parameter: parameter,
        detail: detail.isNotEmpty ? detail : parameter,
        counterKey: counterKey,
        counterName: counterName,
        counterValue: counterValue,
      ));
    }

    return results;
  }
}
