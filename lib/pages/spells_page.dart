import 'package:dice_reader/main.dart';
import 'package:dice_reader/model/spell.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SpellsPage extends StatefulWidget {
  const SpellsPage({super.key});

  @override
  State<SpellsPage> createState() => _SpellsPageState();

  static Widget tagChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  static void insertTag(
    TextEditingController controller,
    String tag,
    StateSetter setDialogState,
  ) {
    final text = controller.text;
    final selection = controller.selection;
    if (selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, tag);
      controller.value = TextEditingValue(
        text: newText,
        selection:
            TextSelection.collapsed(offset: selection.start + tag.length),
      );
    } else {
      controller.text = text.isEmpty ? tag : '$text\n$tag';
      controller.selection =
          TextSelection.collapsed(offset: controller.text.length);
    }
    setDialogState(() {});
  }
}

class _SpellsPageState extends State<SpellsPage> {
  bool _showPrepared = true;
  bool _showUnprepared = true;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final theme = Theme.of(context);
    final prepared = appState.spells.where((spell) => spell.prepared).toList();
    final unprepared =
        appState.spells.where((spell) => !spell.prepared).toList();
    final totalPreparedSlots =
        appState.spells.fold(0, (sum, s) => sum + s.preparedCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spells'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSpellDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add spell'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text(
                  totalPreparedSlots > 0
                      ? 'Prepared (${prepared.length} • $totalPreparedSlots slots)'
                      : 'Prepared (${prepared.length})',
                ),
                selected: _showPrepared,
                onSelected: (selected) =>
                    setState(() => _showPrepared = selected),
              ),
              FilterChip(
                label: Text('Unprepared (${unprepared.length})'),
                selected: _showUnprepared,
                onSelected: (selected) =>
                    setState(() => _showUnprepared = selected),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (appState.spells.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                'No spells yet. Add spells you know or can prepare.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (_showPrepared && prepared.isNotEmpty) ...[
            _sectionHeader(
              theme,
              'Prepared (${prepared.length} spells • $totalPreparedSlots slots)',
            ),
            ...prepared.map((spell) => _SpellTile(spell: spell)),
          ],
          if (_showUnprepared && unprepared.isNotEmpty) ...[
            _sectionHeader(theme, 'Unprepared (${unprepared.length})'),
            ...unprepared.map((spell) => _SpellTile(spell: spell)),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _showAddSpellDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final levelController = TextEditingController(text: '0');
    var preparedCount = 0;
    final appState = context.read<MyAppState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Add spell'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Spell name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: levelController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Spell level (0 for Cantrip)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description (school, range, effect, etc.)',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 3,
                      maxLines: 6,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Insert Combat Flow Tag:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        SpellsPage.tagChip(
                          label: '+ [Aura]',
                          onTap: () => SpellsPage.insertTag(
                            descriptionController,
                            '[Aura: 20ft] ',
                            setDialogState,
                          ),
                        ),
                        SpellsPage.tagChip(
                          label: '+ [Rider]',
                          onTap: () => SpellsPage.insertTag(
                            descriptionController,
                            '[Rider: Spell Cast] ',
                            setDialogState,
                          ),
                        ),
                        SpellsPage.tagChip(
                          label: '+ [Reaction]',
                          onTap: () => SpellsPage.insertTag(
                            descriptionController,
                            '[Reaction: Trigger] ',
                            setDialogState,
                          ),
                        ),
                        SpellsPage.tagChip(
                          label: '+ [Swift]',
                          onTap: () => SpellsPage.insertTag(
                            descriptionController,
                            '[Swift] ',
                            setDialogState,
                          ),
                        ),
                        SpellsPage.tagChip(
                          label: '+ [Counter]',
                          onTap: () => SpellsPage.insertTag(
                            descriptionController,
                            '[Counter: Charges] ',
                            setDialogState,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Slots Prepared (3.5e)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                preparedCount > 0
                                    ? '$preparedCount copy(ies) ready'
                                    : 'Not prepared',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: preparedCount > 0
                                    ? () =>
                                        setDialogState(() => preparedCount--)
                                    : null,
                              ),
                              Text(
                                '$preparedCount',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () =>
                                    setDialogState(() => preparedCount++),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final level =
                        int.tryParse(levelController.text.trim()) ?? 0;
                    appState.addSpell(
                      name: name,
                      description: descriptionController.text.trim(),
                      level: level,
                      preparedCount: preparedCount,
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    levelController.dispose();
  }
}

class _SpellTile extends StatelessWidget {
  const _SpellTile({required this.spell});

  final SpellItem spell;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<MyAppState>();
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSpellDetails(context, spell),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: spell.prepared
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                foregroundColor: spell.prepared
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                child: Text('${spell.level}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spell.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: spell.prepared
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: spell.prepared
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            spell.prepared
                                ? 'Prep x${spell.preparedCount}'
                                : 'Unprepared',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: spell.prepared
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (spell.description.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              spell.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Expend / Unprepare slot',
                    onPressed: spell.preparedCount > 0
                        ? () => appState.decrementSpellPrepared(spell.id)
                        : null,
                  ),
                  Text(
                    '${spell.preparedCount}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Prepare slot',
                    onPressed: () => appState.incrementSpellPrepared(spell.id),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpellDetails(BuildContext context, SpellItem initialSpell) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return Consumer<MyAppState>(
          builder: (context, appState, child) {
            // Find live spell from state
            final spellMatches =
                appState.spells.where((s) => s.id == initialSpell.id);
            if (spellMatches.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Spell removed.'),
              );
            }
            final liveSpell = spellMatches.first;
            final theme = Theme.of(context);

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                liveSpell.name,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Chip(
                                    avatar: const Icon(Icons.stars, size: 16),
                                    label: Text(
                                      liveSpell.level == 0
                                          ? 'Cantrip (Level 0)'
                                          : 'Level ${liveSpell.level}',
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Chip(
                                    avatar:
                                        const Icon(Icons.bookmark, size: 16),
                                    label: Text(
                                      liveSpell.preparedCount > 0
                                          ? '${liveSpell.preparedCount} Prepared'
                                          : 'Unprepared',
                                    ),
                                    backgroundColor: liveSpell.preparedCount > 0
                                        ? theme.colorScheme.primaryContainer
                                        : null,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit spell',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            Navigator.of(bottomSheetContext).pop();
                            _showEditSpellDialog(context, liveSpell);
                          },
                        ),
                        IconButton(
                          tooltip: 'Delete spell',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            Navigator.of(bottomSheetContext).pop();
                            _confirmDeleteSpell(context, liveSpell);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // D&D 3.5e Preparation Card
                    Card(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Prepared Slots (D&D 3.5e)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      liveSpell.preparedCount > 0
                                          ? '${liveSpell.preparedCount} slot(s) ready to cast'
                                          : 'None prepared',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton.filledTonal(
                                      icon: const Icon(Icons.remove),
                                      tooltip: 'Unprepare 1 slot',
                                      onPressed: liveSpell.preparedCount > 0
                                          ? () =>
                                              appState.decrementSpellPrepared(
                                                  liveSpell.id)
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${liveSpell.preparedCount}',
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      icon: const Icon(Icons.add),
                                      tooltip: 'Prepare 1 slot',
                                      onPressed: () => appState
                                          .incrementSpellPrepared(liveSpell.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (liveSpell.preparedCount > 0) ...[
                              const Divider(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.auto_awesome),
                                  label: const Text('Cast Spell (Expends 1)'),
                                  onPressed: () {
                                    appState
                                        .decrementSpellPrepared(liveSpell.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Cast ${liveSpell.name}! (${liveSpell.preparedCount - 1} slot(s) left)',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: liveSpell.description.trim().isNotEmpty
                          ? SelectableText(
                              liveSpell.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            )
                          : Text(
                              'No description provided for this spell. Tap the edit icon above to add details (school, range, saving throw, effect).',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showEditSpellDialog(
      BuildContext context, SpellItem spell) async {
    final nameController = TextEditingController(text: spell.name);
    final descriptionController =
        TextEditingController(text: spell.description);
    final levelController = TextEditingController(text: spell.level.toString());
    var preparedCount = spell.preparedCount;
    final appState = context.read<MyAppState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Edit spell'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Spell name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: levelController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Spell level (0 for Cantrip)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 3,
                      maxLines: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Insert Combat Flow Tag:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        SpellsPage.tagChip(
                          label: '+ [Aura]',
                          onTap: () => SpellsPage.insertTag(
                            descriptionController,
                            '[Aura: 20ft] ',
                            setDialogState,
                          ),
                        ),
                        SpellsPage.tagChip(
                          label: '+ [Rider]',
                          onTap: () => SpellsPage.insertTag(
                            descriptionController,
                            '[Rider: Spell Cast] ',
                            setDialogState,
                          ),
                        ),
                        SpellsPage.tagChip(
                          label: '+ [Reaction]',
                          onTap: () => SpellsPage.insertTag(
                            descriptionController,
                            '[Reaction: Trigger] ',
                            setDialogState,
                          ),
                        ),
                        SpellsPage.tagChip(
                          label: '+ [Swift]',
                          onTap: () => SpellsPage.insertTag(
                            descriptionController,
                            '[Swift] ',
                            setDialogState,
                          ),
                        ),
                        SpellsPage.tagChip(
                          label: '+ [Counter]',
                          onTap: () => SpellsPage.insertTag(
                            descriptionController,
                            '[Counter: Charges] ',
                            setDialogState,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Slots Prepared (3.5e)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                preparedCount > 0
                                    ? '$preparedCount copy(ies) ready'
                                    : 'Not prepared',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: preparedCount > 0
                                    ? () =>
                                        setDialogState(() => preparedCount--)
                                    : null,
                              ),
                              Text(
                                '$preparedCount',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () =>
                                    setDialogState(() => preparedCount++),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final level = int.tryParse(levelController.text.trim()) ??
                        spell.level;
                    appState.updateSpell(
                      id: spell.id,
                      name: name,
                      description: descriptionController.text.trim(),
                      level: level,
                      preparedCount: preparedCount,
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    levelController.dispose();
  }

  void _confirmDeleteSpell(BuildContext context, SpellItem spell) {
    final appState = context.read<MyAppState>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete spell?'),
          content: Text('Are you sure you want to remove "${spell.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                appState.removeSpell(spell.id);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
