import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Theme;
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
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
        child: Material(
          type: MaterialType.transparency,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              for (final entry in entries) ...[
                _RcEntryRow(
                  key: Key('rc-entry-${entry.key}'),
                  entry: entry,
                  onTap: () => _showEditDialog(
                    context: context,
                    entry: entry,
                    onSave: (v) => notifier.setOverride(entry.key, v),
                    onClear: () => notifier.clearOverride(entry.key),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
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

/// A single Remote Config entry row matching the app's iOS row style.
class _RcEntryRow extends StatelessWidget {
  const _RcEntryRow({super.key, required this.entry, required this.onTap});

  final RemoteConfigEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Value: ${entry.effectiveValue}',
                    style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _OverrideBadge(isOverridden: entry.isOverridden),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: CupertinoColors.systemGrey.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
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
  /// Used only when [RemoteConfigEntry.allowedValues] is `null` and
  /// [RemoteConfigEntry.intRange] is also `null` (plain free-text key).
  late final TextEditingController? _controller;

  /// Used only when [RemoteConfigEntry.allowedValues] is non-`null`.
  String? _selectedValue;

  /// Used only when [RemoteConfigEntry.hasIntRange] is `true`.
  double? _sliderValue;

  @override
  void initState() {
    super.initState();
    if (widget.entry.hasAllowedValues) {
      _controller = null;
      final effective = widget.entry.overrideValue ?? widget.entry.effectiveValue;
      _selectedValue =
          (widget.entry.allowedValues!.contains(effective)) ? effective : widget.entry.allowedValues!.first;
    } else if (widget.entry.hasIntRange) {
      _controller = null;
      final range = widget.entry.intRange!;
      final raw = int.tryParse(widget.entry.overrideValue ?? widget.entry.effectiveValue) ?? range.min;
      _sliderValue = raw.clamp(range.min, range.max).toDouble();
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
          if (widget.entry.hasValueHint) ...[
            const SizedBox(height: 4),
            Text(
              widget.entry.valueHint!,
              style: const TextStyle(fontSize: 11, color: CupertinoColors.secondaryLabel),
            ),
          ],
          const SizedBox(height: 8),
          if (widget.entry.hasAllowedValues)
            CupertinoSlidingSegmentedControl<String>(
              key: const Key('override-value-picker'),
              groupValue: _selectedValue,
              children: {for (final v in widget.entry.allowedValues!) v: Text(v)},
              onValueChanged: (v) => setState(() => _selectedValue = v),
            )
          else if (widget.entry.hasIntRange) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_sliderValue!.round()}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            // IntrinsicHeight + OverflowBox expand the slider so its track
            // exactly spans the dialog's content area, aligning the min/max
            // thumb positions with the "0" / "max" labels below.
            //
            // CupertinoSlider has a built-in track inset of
            //   _kPadding (8) + _thumbRadius (11) = 19 pt per side.
            // The dialog content padding is 16 pt per side.
            // To make the track reach the content edges:
            //   maxWidth = 270 (dialog) + 2 × (19 − 16) = 276 pt.
            // The slider overflows the dialog border by 3 pt on each side;
            // CupertinoAlertDialog clips this invisibly via ClipRRect.
            //
            // Why not LayoutBuilder? CupertinoAlertDialog probes intrinsic
            // dimensions of its content during sizing; LayoutBuilder throws
            // in that context. OverflowBox supports intrinsic queries natively.
            // IntrinsicHeight tightens the vertical constraint so OverflowBox
            // doesn't receive an unbounded height from the parent Column.
            IntrinsicHeight(
              child: OverflowBox(
                maxWidth: 276.0, // dialog width + 2×(slider inset − content padding)
                alignment: Alignment.center,
                child: CupertinoSlider(
                  key: const Key('override-value-slider'),
                  value: _sliderValue!,
                  min: widget.entry.intRange!.min.toDouble(),
                  max: widget.entry.intRange!.max.toDouble(),
                  onChanged: (v) => setState(() => _sliderValue = v),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.entry.intRange!.min}',
                  style: const TextStyle(fontSize: 11, color: CupertinoColors.secondaryLabel),
                ),
                Text(
                  '${widget.entry.intRange!.max}',
                  style: const TextStyle(fontSize: 11, color: CupertinoColors.secondaryLabel),
                ),
              ],
            ),
          ] else
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
            } else if (widget.entry.hasIntRange) {
              final value = _sliderValue!.round().toString();
              Navigator.of(context).pop();
              await widget.onSave(value);
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
