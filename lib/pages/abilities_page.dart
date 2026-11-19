import 'package:dice_reader/main.dart';
import 'package:dice_reader/model/ability.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const List<String> kAbilityCategories = [
  'Class Feature',
  'Feat',
  'Racial',
  'Boon / Supernatural',
  'Miscellaneous',
];

class AbilitiesPage extends StatefulWidget {
  const AbilitiesPage({super.key});

  @override
  State<AbilitiesPage> createState() => _AbilitiesPageState();
}

class _AbilitiesPageState extends State<AbilitiesPage> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final theme = Theme.of(context);

    final filteredAbilities = _selectedCategory == 'All'
        ? appState.abilities
        : appState.abilities
            .where((a) => a.category == _selectedCategory)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abilities & Boons'),
        actions: [
          if (appState.abilities.any((a) => a.hasLimitedUses))
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Reset all daily uses (Long Rest)',
              onPressed: () {
                appState.resetAllAbilityUses();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All ability uses restored!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAbilityDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add ability'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text('All (${appState.abilities.length})'),
                  selected: _selectedCategory == 'All',
                  onSelected: (_) => setState(() => _selectedCategory = 'All'),
                ),
                const SizedBox(width: 8),
                ...kAbilityCategories.map((category) {
                  final count = appState.abilities
                      .where((a) => a.category == category)
                      .length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('$category ($count)'),
                      selected: _selectedCategory == category,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = category),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (appState.abilities.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                'No abilities or boons recorded yet.\nAdd class features, feats, racial traits, or special granted gifts.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else if (filteredAbilities.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                'No abilities in "$_selectedCategory".',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...filteredAbilities
                .map((ability) => _AbilityCard(ability: ability)),
        ],
      ),
    );
  }

  Future<void> _showAddAbilityDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final usesController = TextEditingController(text: '0');
    var category = 'Class Feature';
    var isActive = true;
    final appState = context.read<MyAppState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Add ability / boon'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: kAbilityCategories.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max uses / day (0 for unlimited / passive)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description & combat triggers',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 3,
                      maxLines: 7,
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
                        _tagChip(
                          label: '+ [Aura]',
                          onTap: () => _insertTag(
                            descriptionController,
                            '[Aura: 20ft] ',
                            setDialogState,
                          ),
                        ),
                        _tagChip(
                          label: '+ [Rider]',
                          onTap: () => _insertTag(
                            descriptionController,
                            '[Rider: Spell Cast] ',
                            setDialogState,
                          ),
                        ),
                        _tagChip(
                          label: '+ [Reaction]',
                          onTap: () => _insertTag(
                            descriptionController,
                            '[Reaction: Trigger] ',
                            setDialogState,
                          ),
                        ),
                        _tagChip(
                          label: '+ [Swift]',
                          onTap: () => _insertTag(
                            descriptionController,
                            '[Swift] ',
                            setDialogState,
                          ),
                        ),
                        _tagChip(
                          label: '+ [Counter]',
                          onTap: () => _insertTag(
                            descriptionController,
                            '[Counter: Charges] ',
                            setDialogState,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active in Combat Flow'),
                      subtitle: Text(
                        isActive
                            ? 'Triggers appear in tactical view'
                            : 'Temporarily disabled',
                      ),
                      value: isActive,
                      onChanged: (val) => setDialogState(() => isActive = val),
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
                    final usesMax =
                        int.tryParse(usesController.text.trim()) ?? 0;
                    appState.addAbility(
                      name: name,
                      description: descriptionController.text.trim(),
                      category: category,
                      usesMax: usesMax < 0 ? 0 : usesMax,
                      isActive: isActive,
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
    usesController.dispose();
  }

  static Widget _tagChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
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

  static void _insertTag(
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

class _AbilityCard extends StatelessWidget {
  const _AbilityCard({required this.ability});

  final AbilityItem ability;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<MyAppState>();
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAbilityDetails(context, ability),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ability.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ability.category,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: ability.isActive,
                    onChanged: (_) => appState.toggleAbilityActive(ability.id),
                  ),
                ],
              ),
              if (ability.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  ability.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (ability.hasLimitedUses) ...[
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Uses: ${ability.usesRemaining} / ${ability.usesMax}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ability.usesRemaining == 0
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.remove, size: 16),
                          tooltip: 'Use 1',
                          onPressed: ability.usesRemaining > 0
                              ? () => appState.adjustAbilityUses(ability.id, -1)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add, size: 16),
                          tooltip: 'Restore 1',
                          onPressed: ability.usesRemaining < ability.usesMax
                              ? () => appState.adjustAbilityUses(ability.id, 1)
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
      ),
    );
  }

  void _showAbilityDetails(BuildContext context, AbilityItem initialAbility) {
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
            final matches =
                appState.abilities.where((a) => a.id == initialAbility.id);
            if (matches.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Ability removed.'),
              );
            }
            final liveAbility = matches.first;
            final theme = Theme.of(context);

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.35,
              maxChildSize: 0.9,
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
                                liveAbility.name,
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
                                    label: Text(liveAbility.category),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  ActionChip(
                                    avatar: Icon(
                                      liveAbility.isActive
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      size: 16,
                                      color: liveAbility.isActive
                                          ? theme.colorScheme.primary
                                          : null,
                                    ),
                                    label: Text(
                                      liveAbility.isActive
                                          ? 'Active in Combat'
                                          : 'Inactive',
                                    ),
                                    onPressed: () => appState
                                        .toggleAbilityActive(liveAbility.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit ability',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            Navigator.of(bottomSheetContext).pop();
                            _showEditAbilityDialog(context, liveAbility);
                          },
                        ),
                        IconButton(
                          tooltip: 'Delete ability',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            Navigator.of(bottomSheetContext).pop();
                            _confirmDeleteAbility(context, liveAbility);
                          },
                        ),
                      ],
                    ),
                    if (liveAbility.hasLimitedUses) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Daily Uses: ${liveAbility.usesRemaining} / ${liveAbility.usesMax}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.remove),
                                    tooltip: 'Use 1',
                                    onPressed: liveAbility.usesRemaining > 0
                                        ? () => appState.adjustAbilityUses(
                                            liveAbility.id, -1)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.add),
                                    tooltip: 'Restore 1',
                                    onPressed: liveAbility.usesRemaining <
                                            liveAbility.usesMax
                                        ? () => appState.adjustAbilityUses(
                                            liveAbility.id, 1)
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                      child: liveAbility.description.trim().isNotEmpty
                          ? SelectableText(
                              liveAbility.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            )
                          : Text(
                              'No description provided.',
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

  Future<void> _showEditAbilityDialog(
      BuildContext context, AbilityItem ability) async {
    final nameController = TextEditingController(text: ability.name);
    final descriptionController =
        TextEditingController(text: ability.description);
    final usesController =
        TextEditingController(text: ability.usesMax.toString());
    var category = ability.category;
    var isActive = ability.isActive;
    final appState = context.read<MyAppState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Edit ability / boon'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: kAbilityCategories.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max uses / day (0 for unlimited)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description & combat triggers',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 3,
                      maxLines: 7,
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
                        _AbilitiesPageState._tagChip(
                          label: '+ [Aura]',
                          onTap: () => _AbilitiesPageState._insertTag(
                            descriptionController,
                            '[Aura: 20ft] ',
                            setDialogState,
                          ),
                        ),
                        _AbilitiesPageState._tagChip(
                          label: '+ [Rider]',
                          onTap: () => _AbilitiesPageState._insertTag(
                            descriptionController,
                            '[Rider: Spell Cast] ',
                            setDialogState,
                          ),
                        ),
                        _AbilitiesPageState._tagChip(
                          label: '+ [Reaction]',
                          onTap: () => _AbilitiesPageState._insertTag(
                            descriptionController,
                            '[Reaction: Trigger] ',
                            setDialogState,
                          ),
                        ),
                        _AbilitiesPageState._tagChip(
                          label: '+ [Swift]',
                          onTap: () => _AbilitiesPageState._insertTag(
                            descriptionController,
                            '[Swift] ',
                            setDialogState,
                          ),
                        ),
                        _AbilitiesPageState._tagChip(
                          label: '+ [Counter]',
                          onTap: () => _AbilitiesPageState._insertTag(
                            descriptionController,
                            '[Counter: Charges] ',
                            setDialogState,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active in Combat Flow'),
                      value: isActive,
                      onChanged: (val) => setDialogState(() => isActive = val),
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
                    final usesMax =
                        int.tryParse(usesController.text.trim()) ?? 0;
                    appState.updateAbility(
                      id: ability.id,
                      name: name,
                      description: descriptionController.text.trim(),
                      category: category,
                      usesMax: usesMax < 0 ? 0 : usesMax,
                      usesRemaining: usesMax < ability.usesRemaining
                          ? usesMax
                          : ability.usesRemaining,
                      isActive: isActive,
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
    usesController.dispose();
  }

  void _confirmDeleteAbility(BuildContext context, AbilityItem ability) {
    final appState = context.read<MyAppState>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete ability?'),
          content: Text('Are you sure you want to remove "${ability.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                appState.removeAbility(ability.id);
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
