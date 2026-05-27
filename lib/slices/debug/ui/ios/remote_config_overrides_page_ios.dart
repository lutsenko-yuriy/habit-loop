import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/slices/debug/ui/generic/remote_config_overrides_view_model.dart';

/// Debug-only screen (iOS) for viewing and editing Remote Config overrides.
///
/// Shows all keys from [RemoteConfigDefaults.all] with their effective values
/// and override status. Only reachable in debug and profile builds — the
/// dashboard nav bar button is gated on `kDebugMode || kProfileMode`.
class RemoteConfigOverridesPageIos extends ConsumerWidget {
  const RemoteConfigOverridesPageIos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(remoteConfigOverridesViewModelProvider);
    final notifier = ref.read(remoteConfigOverridesViewModelProvider.notifier);
    final hasAnyOverride = entries.any((e) => e.isOverridden);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Remote Config'),
        trailing: CupertinoButton(
          key: const Key('reset-all-button'),
          padding: EdgeInsets.zero,
          onPressed: hasAnyOverride ? () => _confirmResetAll(context, notifier) : null,
          child: Text(
            'Reset all',
            style: hasAnyOverride ? null : const TextStyle(color: CupertinoColors.inactiveGray),
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 8),
            CupertinoListSection.insetGrouped(
              children: [
                for (final entry in entries)
                  CupertinoListTile.notched(
                    key: Key('rc-entry-${entry.key}'),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 13),
                    ),
                    subtitle: Text('Value: ${entry.effectiveValue}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _OverrideBadge(isOverridden: entry.isOverridden),
                        const SizedBox(width: 4),
                        const CupertinoListTileChevron(),
                      ],
                    ),
                    onTap: () => _showEditDialog(
                      context: context,
                      entry: entry,
                      onSave: (v) => notifier.setOverride(entry.key, v),
                      onClear: () => notifier.clearOverride(entry.key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResetAll(
    BuildContext context,
    RemoteConfigOverridesViewModel notifier,
  ) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Reset all overrides'),
        content: const Text('All Remote Config overrides will be cleared and defaults restored.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset all'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
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
  await showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _EditDialogIos(entry: entry, onSave: onSave, onClear: onClear),
  );
}

class _EditDialogIos extends StatefulWidget {
  const _EditDialogIos({
    required this.entry,
    required this.onSave,
    required this.onClear,
  });

  final RemoteConfigEntry entry;
  final Future<void> Function(String value) onSave;
  final Future<void> Function() onClear;

  @override
  State<_EditDialogIos> createState() => _EditDialogIosState();
}

class _EditDialogIosState extends State<_EditDialogIos> {
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
    return CupertinoAlertDialog(
      title: Text(widget.entry.key),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Default: ${widget.entry.defaultValue}',
            style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel),
          ),
          const SizedBox(height: 8),
          if (widget.entry.hasAllowedValues)
            CupertinoSlidingSegmentedControl<String>(
              key: const Key('override-value-picker'),
              groupValue: _selectedValue,
              children: {for (final v in widget.entry.allowedValues!) v: Text(v)},
              onValueChanged: (v) => setState(() => _selectedValue = v),
            )
          else
            CupertinoTextField(
              key: const Key('override-value-field'),
              controller: _controller,
              placeholder: widget.entry.defaultValue,
              autofocus: true,
              clearButtonMode: OverlayVisibilityMode.editing,
            ),
        ],
      ),
      actions: [
        if (widget.entry.isOverridden)
          CupertinoDialogAction(
            key: const Key('use-default-action'),
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop();
              await widget.onClear();
            },
            child: const Text('Use default'),
          ),
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          key: const Key('save-action'),
          isDefaultAction: true,
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
    final cs = Theme.of(context).colorScheme;
    final bgColor = isOverridden ? cs.primary : cs.outlineVariant;
    final textColor = isOverridden ? cs.onPrimary : cs.onSurfaceVariant;

    return Container(
      key: Key(isOverridden ? 'override-badge' : 'default-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isOverridden ? 'OVERRIDE' : 'DEFAULT',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
