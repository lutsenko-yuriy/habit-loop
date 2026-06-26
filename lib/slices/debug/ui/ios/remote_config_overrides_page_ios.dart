import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, Material, MaterialType, Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/notifications/data/test_notification_helper.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/slices/debug/ui/generic/debug_seed_data_view_model.dart';
import 'package:habit_loop/slices/debug/ui/generic/override_badge.dart';
import 'package:habit_loop/slices/debug/ui/generic/rc_entry_edit_state.dart';
import 'package:habit_loop/slices/debug/ui/generic/remote_config_overrides_scroll_view.dart';
import 'package:habit_loop/slices/debug/ui/generic/remote_config_overrides_view_model.dart';
import 'package:habit_loop/slices/debug/ui/generic/restart_required_banner.dart';

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
          child: RemoteConfigOverridesScrollView(
            entries: entries,
            showBackendRestartBanner: showBackendRestartBanner,
            seedState: seedState,
            hasFakeBackend: seedNotifier.hasFakeBackend,
            onSeedLocal: () => _showSeedPercentDialog(context, seedNotifier.seedLocalPacts),
            onSeedRemote: () => _showSeedPercentDialog(context, seedNotifier.seedRemotePacts),
            onEntryTap: (entry) => _showEditDialog(
              context: context,
              entry: entry,
              onSave: (v) => notifier.setOverride(entry.key, v),
              onClear: () => notifier.clearOverride(entry.key),
            ),
            slots: (
              buildTopSection: (ctx) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: CupertinoColors.tertiarySystemFill.resolveFrom(ctx),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CupertinoButton(
                      key: const Key('test-notification-button'),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      onPressed: () => scheduleTestNotification(ref.read(notificationServiceProvider)),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.bell),
                          SizedBox(width: 10),
                          Text('Fire test notification'),
                        ],
                      ),
                    ),
                  ),
              buildEntryTile: (ctx, entry, onTap) => _RcEntryRow(
                    key: Key('rc-entry-${entry.key}'),
                    entry: entry,
                    onTap: onTap,
                  ),
              buildEntrySeparator: (ctx) => const SizedBox(height: 8),
              buildSectionDivider: (ctx) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [SizedBox(height: 8), Divider(), SizedBox(height: 8)],
                  ),
              buildSectionHeader: (ctx, title) => Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemGrey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              buildRestartBanner: (ctx) => RestartRequiredBanner(
                    key: const Key('debug-backend-restart-banner'),
                    color: CupertinoColors.systemYellow.resolveFrom(ctx),
                    icon: CupertinoIcons.exclamationmark_triangle_fill,
                  ),
              seedSlots: (
                buildHeader: (ctx) => const Padding(
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
                buildButton: (ctx, key, label, isBusy, onPressed) => CupertinoButton(
                      key: key,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      onPressed: isBusy ? null : onPressed,
                      child: Align(alignment: Alignment.centerLeft, child: Text(label)),
                    ),
                buildButtonContainer: (ctx, buttons) => Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: CupertinoColors.tertiarySystemFill.resolveFrom(ctx),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: buttons),
                    ),
                buildStatusText: (ctx, key, message, status) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        message,
                        key: key,
                        style: TextStyle(
                          fontSize: 12,
                          color: switch (status) {
                            DebugSeedState.error => CupertinoColors.systemRed.resolveFrom(ctx),
                            DebugSeedState.done => CupertinoColors.systemGreen.resolveFrom(ctx),
                            _ => CupertinoColors.systemGrey.resolveFrom(ctx),
                          },
                        ),
                      ),
                    ),
              ),
              wrapSeedSection: (ctx, child) => child,
              listPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
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
            OverrideBadge(isOverridden: entry.isOverridden),
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
  late RcEntryEditState _editState;

  @override
  void initState() {
    super.initState();
    _editState = RcEntryEditState.fromEntry(widget.entry);
  }

  @override
  void dispose() {
    if (_editState case RcEntryEditFreeText(:final controller)) {
      controller.dispose();
    }
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
          switch (_editState) {
            RcEntryEditAllowedValues(:final selected) => CupertinoSlidingSegmentedControl<String>(
                key: const Key('override-value-picker'),
                groupValue: selected,
                children: {for (final v in widget.entry.allowedValues!) v: Text(v)},
                onValueChanged: (v) =>
                    setState(() => _editState = (_editState as RcEntryEditAllowedValues).withSelected(v)),
              ),
            RcEntryEditIntRange(:final sliderValue) => Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${sliderValue.round()}',
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
                        value: sliderValue,
                        min: widget.entry.intRange!.min.toDouble(),
                        max: widget.entry.intRange!.max.toDouble(),
                        onChanged: (v) =>
                            setState(() => _editState = (_editState as RcEntryEditIntRange).withSliderValue(v)),
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
                ],
              ),
            RcEntryEditFreeText(:final controller) => CupertinoTextField(
                key: const Key('override-value-field'),
                controller: controller,
                placeholder: widget.entry.defaultValue,
                autofocus: true,
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
          },
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
            final value = _editState.computeSaveValue();
            Navigator.of(context).pop();
            if (value != null) await widget.onSave(value);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<void> _showSeedPercentDialog(
  BuildContext context,
  Future<void> Function({int successPercent}) onSeed,
) async {
  await showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _SeedPercentDialogIos(onSeed: onSeed),
  );
}

class _SeedPercentDialogIos extends StatefulWidget {
  const _SeedPercentDialogIos({required this.onSeed});

  final Future<void> Function({int successPercent}) onSeed;

  @override
  State<_SeedPercentDialogIos> createState() => _SeedPercentDialogIosState();
}

class _SeedPercentDialogIosState extends State<_SeedPercentDialogIos> {
  double _percent = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Success rate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(
            '${_percent.round()}% done',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          CupertinoSlider(
            value: _percent,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) => setState(() => _percent = v),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%', style: TextStyle(fontSize: 11, color: CupertinoColors.secondaryLabel)),
              Text('100%', style: TextStyle(fontSize: 11, color: CupertinoColors.secondaryLabel)),
            ],
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () async {
            Navigator.of(context).pop();
            await widget.onSeed(successPercent: _percent.round());
          },
          child: const Text('Seed'),
        ),
      ],
    );
  }
}
