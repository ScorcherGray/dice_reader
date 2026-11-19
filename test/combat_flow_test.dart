import 'package:dice_reader/model/combat_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CombatFlowParser Tests', () {
    test('parses Gloves aura tag correctly', () {
      const desc = 'Heavy leather gloves stitched with radiant thread.\n'
          '[Aura: 20ft] Allies in range gain +2d6 damage to their attacks.';

      final triggers = CombatFlowParser.parse(
        sourceId: 'gloves_1',
        sourceName: 'Gloves of the Dawn',
        sourceType: 'gear',
        description: desc,
        counters: {},
      );

      expect(triggers.length, 1);
      expect(triggers[0].timing, CombatTiming.allyAura);
      expect(triggers[0].tagLabel, 'Aura: 20ft');
      expect(triggers[0].parameter, '20ft');
      expect(triggers[0].detail,
          'Allies in range gain +2d6 damage to their attacks.');
      expect(triggers[0].sourceName, 'Gloves of the Dawn');
    });

    test('parses Mask rider tag correctly', () {
      const desc = 'A porcelain visage carved with arcane runes.\n'
          '[Rider: Spell Cast] Deals 2d6 energy damage to all nearby enemies when an effect is active.';

      final triggers = CombatFlowParser.parse(
        sourceId: 'mask_1',
        sourceName: 'Mask of the Pyre',
        sourceType: 'gear',
        description: desc,
        counters: {},
      );

      expect(triggers.length, 1);
      expect(triggers[0].timing, CombatTiming.actionRider);
      expect(triggers[0].tagLabel, 'Rider: Spell Cast');
      expect(triggers[0].parameter, 'Spell Cast');
      expect(triggers[0].detail,
          'Deals 2d6 energy damage to all nearby enemies when an effect is active.');
    });

    test('parses Ring with reaction, rider, and counter correctly', () {
      const desc = 'An ancient band attuned to the thread of life.\n'
          '[Reaction: Ally enters dying] Activates emergency ward to stabilize ally.\n'
          '[Rider: Spell Cast] [Counter: Spell Casts] Adds +1 bonus per spell cast this encounter.';

      final counters = {'ring_1_Spell Casts': 3};
      final triggers = CombatFlowParser.parse(
        sourceId: 'ring_1',
        sourceName: 'Ring of Arcane Echoes',
        sourceType: 'gear',
        description: desc,
        counters: counters,
      );

      expect(triggers.length, 2);

      // Trigger 1: Reaction
      expect(triggers[0].timing, CombatTiming.reaction);
      expect(triggers[0].tagLabel, 'Reaction: Ally enters dying');
      expect(triggers[0].parameter, 'Ally enters dying');
      expect(triggers[0].detail, 'Activates emergency ward to stabilize ally.');
      expect(triggers[0].counterKey, isNull);

      // Trigger 2: Action Rider with Counter
      expect(triggers[1].timing, CombatTiming.actionRider);
      expect(triggers[1].tagLabel, 'Rider: Spell Cast');
      expect(triggers[1].parameter, 'Spell Cast');
      expect(
          triggers[1].detail, 'Adds +1 bonus per spell cast this encounter.');
      expect(triggers[1].counterKey, 'ring_1_Spell Casts');
      expect(triggers[1].counterName, 'Spell Casts');
      expect(triggers[1].counterValue, 3);
    });

    test('ignores items without combat tags', () {
      const desc = 'Standard 50ft hempen rope. Nothing special.';
      final triggers = CombatFlowParser.parse(
        sourceId: 'rope_1',
        sourceName: 'Rope',
        sourceType: 'gear',
        description: desc,
        counters: {},
      );
      expect(triggers, isEmpty);
    });

    test('automatically groups cards with the same tag parameter together', () {
      final item1 = CombatTriggerItem(
        id: '1',
        sourceId: 'gear_1',
        sourceName: 'Amulet of Runes',
        sourceType: 'gear',
        timing: CombatTiming.actionRider,
        tagLabel: 'Rider: Cast Glyph of Warding',
        parameter: 'Cast Glyph of Warding',
        detail: 'Detonates with extra force',
      );

      final item2 = CombatTriggerItem(
        id: '2',
        sourceId: 'gear_2',
        sourceName: 'Staff of the Magi',
        sourceType: 'gear',
        timing: CombatTiming.actionRider,
        tagLabel: 'Rider: Spell Cast',
        parameter: 'Spell Cast',
        detail: 'Gains 1 charge',
      );

      final item3 = CombatTriggerItem(
        id: '3',
        sourceId: 'ability_1',
        sourceName: 'Warding Mastery Boon',
        sourceType: 'ability',
        timing: CombatTiming.actionRider,
        tagLabel: 'Rider: Cast Glyph of Warding',
        parameter: 'Cast Glyph of Warding',
        detail: 'Reduces casting time to standard action',
      );

      final list = [item1, item2, item3];
      list.sort(CombatFlowParser.compareTriggers);

      // Both "Cast Glyph of Warding" should be first and adjacent!
      expect(list[0].parameter, 'Cast Glyph of Warding');
      expect(list[1].parameter, 'Cast Glyph of Warding');
      expect(list[2].parameter, 'Spell Cast');
      expect(list[0].sourceName, 'Amulet of Runes');
      expect(list[1].sourceName, 'Warding Mastery Boon');
    });
  });
}
