import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/slices/debug/ui/generic/remote_config_overrides_view_model.dart';

/// Debug-only screen (Android) for viewing and editing Remote Config overrides.
///
/// Shows all keys from [RemoteConfigDefaults.all] with their effective values
/// and override status. Only reachable in debug and profile builds — the
/// dashboard AppBar action is gated on `kDebugMode || kProfileMode`.
class RemoteConfigOverridesPageAndroid extends ConsumerWidget {
  const RemoteConfigOverridesPageAndroid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(remoteConfigOverridesViewModelProvider);
    final notifier = ref.read(remoteConfigOverridesViewModelProvider.notifier);
    final hasAnyOverride = entries.any((e) => e.isOverridden);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Config'),
        actions: [
          if (hasAnyOverride)
            TextButton(
              key: const Key('reset-all-button'),
              onPressed: () => _confirmResetAll(context, notifier),
              child: const Text('Reset all'),
            ),
        ],
      ),
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(
            key: Key('rc-entry-${entry.key}'),
            title: Text(
              entry.key,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            subtitle: Text('Value: ${entry.effectiveValue}'),
            trailing: _OverrideBadge(isOverridden: entry.isOverridden),
            onTap: () => _showEditDialog(
              context: context,
              entry: entry,
              onSave: (v) => notifier.setOverride(entry.key, v),
              onClear: () => notifier.clearOverride(entry.key),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmResetAll(
    BuildContext context,
    RemoteConfigOverridesViewModel notifier,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset all overrides'),
        content: const Text('All Remote Config overrides will be cleared and defaults restored.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Reset all',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) await notifier.clearAllOverrides();
  }
}

/// Opens an edit dialog for a single Remote Config key.
Future<void> _showEditDialog({
  required BuildContext context,
  required RemoteConfigEntry entry,
  required Future<void> Function(String value) onSave,
  required Future<void> Function() onClear,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _EditDialogAndroid(entry: entry, onSave: onSave, onClear: onClear),
  );
}

class _EditDialogAndroid extends StatefulWidget {
  const _EditDialogAndroid({
    required this.entry,
    required this.onSave,
    required this.onClear,
  });

  final RemoteConfigEntry entry;
  final Future<void> Function(String value) onSave;
  final Future<void> Function() onClear;

  @override
  State<_EditDialogAndroid> createState() => _EditDialogAndroidState();
}

class _EditDialogAndroidState extends State<_EditDialogAndroid> {
  /// Used only when [RemoteConfigEntry.allowedValues] is `null`.
  late final TextEditingController? _controller;

  /// Used only when [RemoteConfigEntry.allowedValues] is non-`null`.
  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    if (widget.entry.hasAllowedValues) {
      _controller = null;
      final effective = widget.entry.overrideValue ?? widget.entry.effectiveValue;
      _selectedValue =
          (widget.entry.allowedValues!.contains(effective)) ? effective : widget.entry.allowedValues!.first;
    } else {
      _controller = TextEditingController(text: widget.entry.overrideValue ?? '');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry.key),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Default: ${widget.entry.defaultValue}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (widget.entry.hasAllowedValues)
            RadioGroup<String>(
              key: const Key('override-value-picker'),
              groupValue: _selectedValue,
              onChanged: (v) => setState(() => _selectedValue = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final v in widget.entry.allowedValues!)
                    RadioListTile<String>(
                      key: Key('override-option-$v'),
                      title: Text(v),
                      value: v,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            )
          else
            TextField(
              key: const Key('override-value-field'),
              controller: _controller,
              decoration: InputDecoration(hintText: widget.entry.defaultValue),
              autofocus: true,
            ),
        ],
      ),
      actions: [
        if (widget.entry.isOverridden)
          TextButton(
            key: const Key('use-default-action'),
            onPressed: () async {
              Navigator.of(context).pop();
              await widget.onClear();
            },
            child: Text(
              'Use default',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('save-action'),
          onPressed: () async {
            if (widget.entry.hasAllowedValues) {
              final value = _selectedValue;
              Navigator.of(context).pop();
              if (value != null) await widget.onSave(value);
            } else {
              final value = _controller!.text.trim();
              Navigator.of(context).pop();
              if (value.isNotEmpty) await widget.onSave(value);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Small badge indicating whether a key is overridden or using its default.
class _OverrideBadge extends StatelessWidget {
  const _OverrideBadge({required this.isOverridden});

  final bool isOverridden;

  @override
  Widget build(BuildContext context) {
    final color = isOverridden ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant;
    return Container(
      key: Key(isOverridden ? 'override-badge' : 'default-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isOverridden ? 'OVERRIDE' : 'DEFAULT',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color:
              isOverridden ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
