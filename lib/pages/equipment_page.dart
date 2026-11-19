import 'package:dice_reader/main.dart';
import 'package:dice_reader/model/gear.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> {
  bool _showEquipped = true;
  bool _showCarried = true;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final theme = Theme.of(context);
    final equipped = appState.gear.where((item) => item.equipped).toList();
    final carried = appState.gear.where((item) => !item.equipped).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text('Equipped (${equipped.length})'),
                selected: _showEquipped,
                onSelected: (selected) =>
                    setState(() => _showEquipped = selected),
              ),
              FilterChip(
                label: Text('Carried (${carried.length})'),
                selected: _showCarried,
                onSelected: (selected) =>
                    setState(() => _showCarried = selected),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (appState.gear.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                'No gear yet. Add what you are wearing or carrying.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (_showEquipped && equipped.isNotEmpty) ...[
            _sectionHeader(theme, 'Equipped (${equipped.length})'),
            ...equipped.map((item) => _GearTile(item: item)),
          ],
          if (_showCarried && carried.isNotEmpty) ...[
            _sectionHeader(theme, 'Carried (${carried.length})'),
            ...carried.map((item) => _GearTile(item: item)),
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

  Future<void> _showAddItemDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    var equipped = false;
    final appState = context.read<MyAppState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Add equipment'),
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
                        labelText: 'Item name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description (properties, weight, bonuses)',
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
                      title: const Text('Equipped'),
                      subtitle: Text(equipped ? 'Worn or in hand' : 'Carried'),
                      value: equipped,
                      onChanged: (value) =>
                          setDialogState(() => equipped = value),
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
                    final quantity =
                        int.tryParse(quantityController.text.trim()) ?? 1;
                    appState.addGear(
                      name: name,
                      description: descriptionController.text.trim(),
                      quantity: quantity < 1 ? 1 : quantity,
                      equipped: equipped,
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
    quantityController.dispose();
  }

  static Widget _tagChip({
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

class _GearTile extends StatelessWidget {
  const _GearTile({required this.item});

  final GearItem item;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<MyAppState>();
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showGearDetails(context, item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: item.equipped
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                foregroundColor: item.equipped
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                child: Text('${item.quantity}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight:
                            item.equipped ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.equipped
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.equipped ? 'Equipped' : 'Carried',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: item.equipped
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.description,
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
              Switch(
                value: item.equipped,
                onChanged: (_) => appState.toggleGearEquipped(item.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGearDetails(BuildContext context, GearItem initialItem) {
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
            final matches = appState.gear.where((g) => g.id == initialItem.id);
            if (matches.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Item removed.'),
              );
            }
            final liveItem = matches.first;
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
                                liveItem.name,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  ActionChip(
                                    avatar: Icon(
                                      liveItem.equipped
                                          ? Icons.shield
                                          : Icons.backpack,
                                      size: 16,
                                    ),
                                    label: Text(
                                      liveItem.equipped
                                          ? 'Equipped'
                                          : 'Carried',
                                    ),
                                    backgroundColor: liveItem.equipped
                                        ? theme.colorScheme.primaryContainer
                                        : null,
                                    onPressed: () => appState
                                        .toggleGearEquipped(liveItem.id),
                                  ),
                                  Chip(
                                    avatar: const Icon(Icons.numbers, size: 16),
                                    label: Text('Qty: ${liveItem.quantity}'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit item',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            Navigator.of(bottomSheetContext).pop();
                            _showEditItemDialog(context, liveItem);
                          },
                        ),
                        IconButton(
                          tooltip: 'Delete item',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            Navigator.of(bottomSheetContext).pop();
                            _confirmDeleteItem(context, liveItem);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Quantity and Equip quick controls
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
                            const Text(
                              'Quantity',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.remove),
                                  tooltip: 'Decrease quantity',
                                  onPressed: liveItem.quantity > 1
                                      ? () => appState.adjustGearQuantity(
                                          liveItem.id, -1)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${liveItem.quantity}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Increase quantity',
                                  onPressed: () => appState.adjustGearQuantity(
                                      liveItem.id, 1),
                                ),
                              ],
                            ),
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
                      child: liveItem.description.trim().isNotEmpty
                          ? SelectableText(
                              liveItem.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            )
                          : Text(
                              'No description provided for this item. Tap the edit icon above to add details (stats, properties, weight).',
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

  Future<void> _showEditItemDialog(BuildContext context, GearItem item) async {
    final nameController = TextEditingController(text: item.name);
    final descriptionController = TextEditingController(text: item.description);
    final quantityController =
        TextEditingController(text: item.quantity.toString());
    var equipped = item.equipped;
    final appState = context.read<MyAppState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Edit equipment'),
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
                        labelText: 'Item name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
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
                        _EquipmentPageState._tagChip(
                          label: '+ [Aura]',
                          onTap: () => _EquipmentPageState._insertTag(
                            descriptionController,
                            '[Aura: 20ft] ',
                            setDialogState,
                          ),
                        ),
                        _EquipmentPageState._tagChip(
                          label: '+ [Rider]',
                          onTap: () => _EquipmentPageState._insertTag(
                            descriptionController,
                            '[Rider: Spell Cast] ',
                            setDialogState,
                          ),
                        ),
                        _EquipmentPageState._tagChip(
                          label: '+ [Reaction]',
                          onTap: () => _EquipmentPageState._insertTag(
                            descriptionController,
                            '[Reaction: Trigger] ',
                            setDialogState,
                          ),
                        ),
                        _EquipmentPageState._tagChip(
                          label: '+ [Swift]',
                          onTap: () => _EquipmentPageState._insertTag(
                            descriptionController,
                            '[Swift] ',
                            setDialogState,
                          ),
                        ),
                        _EquipmentPageState._tagChip(
                          label: '+ [Counter]',
                          onTap: () => _EquipmentPageState._insertTag(
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
                      title: const Text('Equipped'),
                      subtitle: Text(equipped ? 'Worn or in hand' : 'Carried'),
                      value: equipped,
                      onChanged: (value) =>
                          setDialogState(() => equipped = value),
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
                    final quantity =
                        int.tryParse(quantityController.text.trim()) ??
                            item.quantity;
                    appState.updateGear(
                      id: item.id,
                      name: name,
                      description: descriptionController.text.trim(),
                      quantity: quantity < 1 ? 1 : quantity,
                      equipped: equipped,
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
    quantityController.dispose();
  }

  void _confirmDeleteItem(BuildContext context, GearItem item) {
    final appState = context.read<MyAppState>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete equipment?'),
          content: Text('Are you sure you want to remove "${item.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                appState.removeGear(item.id);
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
