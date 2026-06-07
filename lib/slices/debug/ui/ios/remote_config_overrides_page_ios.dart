import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, Material, MaterialType, Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/slices/debug/ui/generic/debug_seed_data_view_model.dart';
import 'package:habit_loop/slices/debug/ui/generic/remote_config_overrides_view_model.dart';

class RemoteConfigOverridesPageIos extends ConsumerWidget {
  const RemoteConfigOverridesPageIos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(remoteConfigOverridesViewModelProvider);
    final notifier = ref.read(remoteConfigOverridesViewModelProvider.notifier);
    final hasAnyOverride = entries.any((e) => e.isOverridden);
    final seedState = ref.watch(debugSeedDataViewModelProvider);
    final seedNotifier = ref.read(debugSeedDataViewModelProvider.notifier);

    // Banner only when pending debug_backend differs from the value running at startup.
    final startupBackend = ref.watch(debugBackendAtStartupProvider);
    final showBackendRestartBanner = entries.any((e) {
      if (e.key != 'debug_backend') return false;
      final pendingValue = e.overrideValue ?? RemoteConfigDefaults.debugBackend;
      return pendingValue != startupBackend;
    });

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
              if (showBackendRestartBanner) ...[
                const _RestartRequiredBanner(
                  key: Key('debug-backend-restart-banner'),
                ),
                const SizedBox(height: 8),
              ],
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
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _SeedSection(state: seedState, notifier: seedNotifier),
              const SizedBox(height: 16),
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
  late final TextEditingController? _controller;
  String? _selectedValue;
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
            // OverflowBox expands track to dialog edges. LayoutBuilder can't be used —
            // CupertinoAlertDialog probes intrinsic dimensions and LayoutBuilder throws there.
            // IntrinsicHeight prevents OverflowBox from receiving unbounded height.
            // maxWidth = 270 (dialog) + 2×(slider inset 19 − content padding 16) = 276 pt.
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

class _SeedSection extends StatelessWidget {
  const _SeedSection({required this.state, required this.notifier});

  final DebugSeedDataState state;
  final DebugSeedDataViewModel notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'SEED DATA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemGrey,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
          ),
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
                const Divider(height: 1, indent: 16),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              state.message ?? '',
              key: const Key('seed-status-text'),
              style: TextStyle(
                fontSize: 12,
                color: switch (state.status) {
                  DebugSeedState.error => CupertinoColors.systemRed.resolveFrom(context),
                  DebugSeedState.done => CupertinoColors.systemGreen.resolveFrom(context),
                  _ => CupertinoColors.systemGrey.resolveFrom(context),
                },
              ),
            ),
          ),
        ],
      ],
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
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onPressed: isBusy ? null : onPressed,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label),
      ),
    );
  }
}

// debug_backend takes effect only after a restart — banner makes that visible.
class _RestartRequiredBanner extends StatelessWidget {
  const _RestartRequiredBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemYellow.resolveFrom(context).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.systemYellow.resolveFrom(context),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 16,
            color: CupertinoColors.systemYellow.resolveFrom(context),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'debug_backend changed — restart the app to apply',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

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
