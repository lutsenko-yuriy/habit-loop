import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/slices/debug/ui/generic/debug_seed_data_view_model.dart';
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
    final seedState = ref.watch(debugSeedDataViewModelProvider);
    final seedNotifier = ref.read(debugSeedDataViewModelProvider.notifier);

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
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final entry in entries) ...[
            ListTile(
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
            ),
            const Divider(height: 1),
          ],
          const SizedBox(height: 8),
          _SeedSection(state: seedState, notifier: seedNotifier),
        ],
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
          if (widget.entry.hasValueHint) ...[
            const SizedBox(height: 4),
            Text(
              widget.entry.valueHint!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
          else if (widget.entry.hasIntRange) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_sliderValue!.round()}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            // IntrinsicHeight + OverflowBox expand the slider to the full
            // dialog width, cancelling out AlertDialog's 24 pt horizontal
            // content padding so the track runs edge-to-edge.
            //
            // Why not LayoutBuilder? AlertDialog probes intrinsic dimensions
            // of its content during sizing; LayoutBuilder throws in that
            // context. OverflowBox supports intrinsic queries natively.
            // IntrinsicHeight is needed because a Column gives OverflowBox an
            // unbounded vertical size; IntrinsicHeight fixes that by tightening
            // the height to the slider's natural height before layout runs.
            // Builder (not LayoutBuilder) accesses MediaQuery for dialog width.
            // AlertDialog has 40 pt margin on each side, constrained to 280–560 pt.
            IntrinsicHeight(
              child: Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final dialogWidth = (screenWidth - 80.0).clamp(280.0, 560.0);
                  return OverflowBox(
                    maxWidth: dialogWidth,
                    alignment: Alignment.center,
                    child: Slider(
                      key: const Key('override-value-slider'),
                      value: _sliderValue!,
                      min: widget.entry.intRange!.min.toDouble(),
                      max: widget.entry.intRange!.max.toDouble(),
                      onChanged: (v) => setState(() => _sliderValue = v),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.entry.intRange!.min}', style: Theme.of(context).textTheme.bodySmall),
                Text('${widget.entry.intRange!.max}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ] else
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

/// Seed-data section shown at the bottom of the RC overrides screen.
///
/// "Regenerate local pacts" is always visible.
/// "Regenerate remote pacts" is visible only when a [FakeFirestoreClient] is
/// wired (i.e. `debug_backend = local`).
class _SeedSection extends StatelessWidget {
  const _SeedSection({required this.state, required this.notifier});

  final DebugSeedDataState state;
  final DebugSeedDataViewModel notifier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SEED DATA',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SeedButton(
                  key: const Key('seed-local-button'),
                  label: 'Regenerate local pacts',
                  isBusy: state.isBusy,
                  onPressed: notifier.seedLocalPacts,
                ),
                if (notifier.hasFakeBackend) ...[
                  const Divider(height: 1),
                  _SeedButton(
                    key: const Key('seed-remote-button'),
                    label: 'Regenerate remote pacts',
                    isBusy: state.isBusy,
                    onPressed: notifier.seedRemotePacts,
                  ),
                ],
              ],
            ),
          ),
          if (state.status != DebugSeedState.idle) ...[
            const SizedBox(height: 8),
            Text(
              state.message ?? '',
              key: const Key('seed-status-text'),
              style: TextStyle(
                fontSize: 12,
                color: switch (state.status) {
                  DebugSeedState.error => Theme.of(context).colorScheme.error,
                  DebugSeedState.done => Colors.green,
                  _ => Theme.of(context).colorScheme.onSurfaceVariant,
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeedButton extends StatelessWidget {
  const _SeedButton({
    super.key,
    required this.label,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      onTap: isBusy ? null : onPressed,
      enabled: !isBusy,
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
