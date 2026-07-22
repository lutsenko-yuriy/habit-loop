import 'package:flutter/material.dart';
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
import 'package:habit_loop/theme/colors.dart';
import 'package:habit_loop/theme/spacing.dart';

class RemoteConfigOverridesPageAndroid extends ConsumerWidget {
  const RemoteConfigOverridesPageAndroid({super.key});

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

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
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
      body: Column(
        children: [
          Container(height: 0.5, color: Theme.of(context).dividerColor),
          Expanded(
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
                buildTopSection: (ctx) => ListTile(
                      key: const Key('test-notification-button'),
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('Fire test notification'),
                      onTap: () => scheduleTestNotification(
                        ref.read(notificationServiceProvider),
                        ref.read(pactRepositoryProvider),
                        ref.read(showupRepositoryProvider),
                      ),
                    ),
                buildEntryTile: (ctx, entry, onTap) => ListTile(
                      key: Key('rc-entry-${entry.key}'),
                      title: Text(
                        entry.key,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                      subtitle: Text('Value: ${entry.effectiveValue}'),
                      trailing: OverrideBadge(isOverridden: entry.isOverridden),
                      onTap: onTap,
                    ),
                buildEntrySeparator: (ctx) => const Divider(height: 1),
                buildSectionDivider: (ctx) => const SizedBox(height: AppSpacing.s8),
                buildSectionHeader: (ctx, title) => Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.s4, bottom: AppSpacing.s6, top: AppSpacing.s4),
                      child: Text(
                        title,
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ),
                buildRestartBanner: (ctx) => const Padding(
                      padding: EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s0),
                      child: RestartRequiredBanner(
                        key: Key('debug-backend-restart-banner'),
                        color: HabitLoopColors.sunrise,
                      ),
                    ),
                seedSlots: (
                  buildHeader: (ctx) => Text(
                        'SEED DATA',
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                      ),
                  buildButton: (ctx, key, label, isBusy, onPressed) => ListTile(
                        key: key,
                        title: Text(label),
                        onTap: isBusy ? null : onPressed,
                        enabled: !isBusy,
                      ),
                  buildButtonContainer: (ctx, buttons) => Card(
                        margin: EdgeInsets.zero,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: buttons),
                      ),
                  buildStatusText: (ctx, key, message, status) => Text(
                        message,
                        key: key,
                        style: TextStyle(
                          fontSize: 12,
                          color: switch (status) {
                            DebugSeedState.error => Theme.of(ctx).colorScheme.error,
                            DebugSeedState.done => HabitLoopColors.success,
                            _ => Theme.of(ctx).colorScheme.onSurfaceVariant,
                          },
                        ),
                      ),
                ),
                wrapSeedSection: (ctx, child) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                      child: child,
                    ),
                listPadding: EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s8 + bottomInset),
              ),
            ),
          ),
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
            const SizedBox(height: AppSpacing.s4),
            Text(
              widget.entry.valueHint!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.s8),
          switch (_editState) {
            RcEntryEditAllowedValues(:final selected) => RadioGroup<String>(
                key: const Key('override-value-picker'),
                groupValue: selected,
                onChanged: (v) => setState(() => _editState = (_editState as RcEntryEditAllowedValues).withSelected(v)),
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
              ),
            RcEntryEditIntRange(:final sliderValue) => Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${sliderValue.round()}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  // OverflowBox cancels AlertDialog's 24 pt content padding so track runs edge-to-edge.
                  // LayoutBuilder can't be used — AlertDialog probes intrinsic dimensions and it throws.
                  // IntrinsicHeight prevents OverflowBox from receiving unbounded height from Column.
                  // dialogWidth = (screenWidth - 80).clamp(280, 560) — AlertDialog 40 pt margin per side.
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
                            value: sliderValue,
                            min: widget.entry.intRange!.min.toDouble(),
                            max: widget.entry.intRange!.max.toDouble(),
                            onChanged: (v) =>
                                setState(() => _editState = (_editState as RcEntryEditIntRange).withSliderValue(v)),
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
                ],
              ),
            RcEntryEditFreeText(:final controller) => TextField(
                key: const Key('override-value-field'),
                controller: controller,
                decoration: InputDecoration(hintText: widget.entry.defaultValue),
                autofocus: true,
              ),
          },
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
  await showDialog<void>(
    context: context,
    builder: (_) => _SeedPercentDialogAndroid(onSeed: onSeed),
  );
}

class _SeedPercentDialogAndroid extends StatefulWidget {
  const _SeedPercentDialogAndroid({required this.onSeed});

  final Future<void> Function({int successPercent}) onSeed;

  @override
  State<_SeedPercentDialogAndroid> createState() => _SeedPercentDialogAndroidState();
}

class _SeedPercentDialogAndroidState extends State<_SeedPercentDialogAndroid> {
  double _percent = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Success rate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_percent.round()}% done',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Slider(
            value: _percent,
            min: 0,
            max: 100,
            divisions: 100,
            label: '${_percent.round()}%',
            onChanged: (v) => setState(() => _percent = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%', style: Theme.of(context).textTheme.labelSmall),
              Text('100%', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
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
