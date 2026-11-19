import 'package:dice_reader/main.dart';
import 'package:dice_reader/model/combat_flow.dart';
import 'package:dice_reader/pages/abilities_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CombatFlowPage extends StatefulWidget {
  const CombatFlowPage({super.key});

  @override
  State<CombatFlowPage> createState() => _CombatFlowPageState();
}

class _CombatFlowPageState extends State<CombatFlowPage> {
  CombatTiming? _selectedTiming; // null means All

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final theme = Theme.of(context);
    final allTriggers = appState.activeCombatTriggers;

    final auras =
        allTriggers.where((t) => t.timing == CombatTiming.allyAura).toList();
    final riders =
        allTriggers.where((t) => t.timing == CombatTiming.actionRider).toList();
    final reactions =
        allTriggers.where((t) => t.timing == CombatTiming.reaction).toList();
    final swiftFree =
        allTriggers.where((t) => t.timing == CombatTiming.swiftFree).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Combat Flow'),
        actions: [
          if (appState.combatCounters.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset combat counters (End Encounter)',
              onPressed: () {
                appState.resetAllCombatCounters();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Combat counters reset!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Abilities & Boons',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const AbilitiesPage(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'reset_order') {
                appState.resetTriggerOrderToGrouped();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Order reset to automatic tag grouping!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else if (value == 'backup_data') {
                _showBackupDialog(context, appState);
              }
            },
            itemBuilder: (context) => [
              if (appState.customTriggerOrder.isNotEmpty)
                const PopupMenuItem(
                  value: 'reset_order',
                  child: Row(
                    children: [
                      Icon(Icons.sort, size: 18),
                      SizedBox(width: 8),
                      Text('Auto-Group by Tag (Reset Order)'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'backup_data',
                child: Row(
                  children: [
                    Icon(Icons.save_alt, size: 18),
                    SizedBox(width: 8),
                    Text('Backup / Export Data'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text('All (${allTriggers.length})'),
                  selected: _selectedTiming == null,
                  onSelected: (_) => setState(() => _selectedTiming = null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.people_outline, size: 16),
                  label: Text('Allies (${auras.length})'),
                  selected: _selectedTiming == CombatTiming.allyAura,
                  onSelected: (_) => setState(() => _selectedTiming =
                      _selectedTiming == CombatTiming.allyAura
                          ? null
                          : CombatTiming.allyAura),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.bolt, size: 16),
                  label: Text('Action Riders (${riders.length})'),
                  selected: _selectedTiming == CombatTiming.actionRider,
                  onSelected: (_) => setState(() => _selectedTiming =
                      _selectedTiming == CombatTiming.actionRider
                          ? null
                          : CombatTiming.actionRider),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                  label: Text('Reactions (${reactions.length})'),
                  selected: _selectedTiming == CombatTiming.reaction,
                  onSelected: (_) => setState(() => _selectedTiming =
                      _selectedTiming == CombatTiming.reaction
                          ? null
                          : CombatTiming.reaction),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.timer_outlined, size: 16),
                  label: Text('Swift / Free (${swiftFree.length})'),
                  selected: _selectedTiming == CombatTiming.swiftFree,
                  onSelected: (_) => setState(() => _selectedTiming =
                      _selectedTiming == CombatTiming.swiftFree
                          ? null
                          : CombatTiming.swiftFree),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (allTriggers.isEmpty)
            _buildEmptyState(context, theme)
          else ...[
            if (_selectedTiming == null ||
                _selectedTiming == CombatTiming.allyAura)
              _buildSection(
                context,
                appState,
                theme,
                '👥 Ally Auras & Team Reminders',
                'Auras, proximity effects, and reminders to announce for your party.',
                theme.colorScheme.primary,
                auras,
              ),
            if (_selectedTiming == null ||
                _selectedTiming == CombatTiming.actionRider)
              _buildSection(
                context,
                appState,
                theme,
                '⚡ Action Riders (When Acting / Casting)',
                'Triggers that piggyback on your attacks, spellcasts, or actions.',
                Colors.amber.shade700,
                riders,
              ),
            if (_selectedTiming == null ||
                _selectedTiming == CombatTiming.reaction)
              _buildSection(
                context,
                appState,
                theme,
                '🚨 Off-Turn Reactions & Triggers',
                'Immediate actions and triggers to watch for when it is not your turn.',
                Colors.deepOrange.shade600,
                reactions,
              ),
            if (_selectedTiming == null ||
                _selectedTiming == CombatTiming.swiftFree)
              _buildSection(
                context,
                appState,
                theme,
                '⏱️ Swift & Free Actions',
                'Action economy options to remember on your turn.',
                Colors.teal.shade600,
                swiftFree,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    MyAppState appState,
    ThemeData theme,
    String title,
    String subtitle,
    Color accentColor,
    List<CombatTriggerItem> sectionList,
  ) {
    if (sectionList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, title, subtitle, accentColor),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: sectionList.length,
          onReorder: (oldIndex, newIndex) {
            appState.reorderCombatTriggers(oldIndex, newIndex, sectionList);
          },
          itemBuilder: (context, index) {
            final trigger = sectionList[index];
            return _TriggerCard(
              key: ValueKey(trigger.id),
              trigger: trigger,
              dragIndex: index,
            );
          },
        ),
      ],
    );
  }

  Widget _sectionHeader(
    ThemeData theme,
    String title,
    String subtitle,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.bolt_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No Combat Triggers Found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Combat Flow scans your equipped gear, prepared spells, and active abilities for trigger tags in their descriptions:\n\n'
              '• [Aura: 20ft] Allies gain +2d6 damage\n'
              '• [Rider: Spell Cast] Deals damage to nearby enemies\n'
              '• [Reaction: Ally enters dying] Activates emergency ward\n'
              '• [Swift] Teleport 10ft\n'
              '• [Counter: Casts] Bonus per cast',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const AbilitiesPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Manage Abilities & Boons'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupDialog(BuildContext context, MyAppState appState) {
    final jsonExport = appState.exportAllDataAsJson();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Backup & Export Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'All your entered gear, spells, abilities, and combat counters are saved permanently on this device. You can copy this JSON backup anytime:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonExport,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonExport));
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Backup JSON copied to clipboard!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy to Clipboard'),
            ),
          ],
        );
      },
    );
  }
}

class _TriggerCard extends StatelessWidget {
  const _TriggerCard({
    super.key,
    required this.trigger,
    required this.dragIndex,
  });

  final CombatTriggerItem trigger;
  final int dragIndex;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<MyAppState>();
    final theme = Theme.of(context);

    IconData sourceIcon;
    switch (trigger.sourceType) {
      case 'gear':
        sourceIcon = Icons.shield_outlined;
      case 'spell':
        sourceIcon = Icons.auto_awesome_outlined;
      default:
        sourceIcon = Icons.stars_outlined;
    }

    Color badgeColor;
    switch (trigger.timing) {
      case CombatTiming.allyAura:
        badgeColor = theme.colorScheme.primary;
      case CombatTiming.actionRider:
        badgeColor = Colors.amber.shade800;
      case CombatTiming.reaction:
        badgeColor = Colors.deepOrange.shade700;
      case CombatTiming.swiftFree:
        badgeColor = Colors.teal.shade700;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    trigger.tagLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  sourceIcon,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  trigger.sourceName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                ReorderableDragStartListener(
                  index: dragIndex,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              trigger.detail,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            if (trigger.counterKey != null) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${trigger.counterName}: ${trigger.counterValue}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove, size: 16),
                        tooltip: 'Decrease count',
                        onPressed: trigger.counterValue > 0
                            ? () => appState.adjustCombatCounter(
                                trigger.counterKey!, -1)
                            : null,
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add, size: 16),
                        tooltip: 'Increase count',
                        onPressed: () => appState.adjustCombatCounter(
                            trigger.counterKey!, 1),
                      ),
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        icon: const Icon(Icons.refresh, size: 16),
                        tooltip: 'Reset count to 0',
                        onPressed: trigger.counterValue > 0
                            ? () =>
                                appState.resetCombatCounter(trigger.counterKey!)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
