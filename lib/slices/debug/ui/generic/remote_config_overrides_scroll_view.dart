import 'package:flutter/widgets.dart';
import 'package:habit_loop/slices/debug/ui/generic/debug_seed_data_view_model.dart';
import 'package:habit_loop/slices/debug/ui/generic/remote_config_overrides_view_model.dart';
import 'package:habit_loop/slices/debug/ui/generic/seed_section.dart';
import 'package:habit_loop/theme/spacing.dart';

typedef RemoteConfigOverridesSlots = ({
  /// Optional builder for a section rendered above seed data.
  /// Null means no top section is rendered.
  Widget Function(BuildContext context)? buildTopSection,
  Widget Function(BuildContext context, RemoteConfigEntry entry, VoidCallback onTap) buildEntryTile,
  Widget Function(BuildContext context) buildEntrySeparator,
  Widget Function(BuildContext context) buildSectionDivider,
  Widget Function(BuildContext context, String title) buildSectionHeader,
  Widget Function(BuildContext context) buildRestartBanner,
  SeedSectionSlots seedSlots,
  Widget Function(BuildContext context, Widget seedSection) wrapSeedSection,
  EdgeInsets listPadding,
});

/// Shared scrollable body for the debug RC overrides page.
///
/// Section order: top (notification) → seed data → RC entries (with banner).
class RemoteConfigOverridesScrollView extends StatelessWidget {
  const RemoteConfigOverridesScrollView({
    super.key,
    required this.entries,
    required this.showBackendRestartBanner,
    required this.seedState,
    required this.hasFakeBackend,
    required this.onSeedLocal,
    required this.onSeedRemote,
    required this.onEntryTap,
    required this.slots,
  });

  final List<RemoteConfigEntry> entries;
  final bool showBackendRestartBanner;
  final DebugSeedDataState seedState;
  final bool hasFakeBackend;
  final VoidCallback onSeedLocal;
  final VoidCallback onSeedRemote;
  final void Function(RemoteConfigEntry entry) onEntryTap;
  final RemoteConfigOverridesSlots slots;

  @override
  Widget build(BuildContext context) {
    final topSection = slots.buildTopSection?.call(context);
    final seedSection = slots.wrapSeedSection(
      context,
      SeedSection(
        state: seedState,
        hasFakeBackend: hasFakeBackend,
        onSeedLocal: onSeedLocal,
        onSeedRemote: onSeedRemote,
        slots: slots.seedSlots,
      ),
    );

    final toggleEntries = entries.where((e) => e.isFeatureToggle).toList();
    final experimentEntries = entries.where((e) => !e.isFeatureToggle).toList();

    return ListView(
      padding: slots.listPadding,
      children: [
        if (topSection != null) ...[
          topSection,
          slots.buildSectionDivider(context),
        ],
        seedSection,
        slots.buildSectionDivider(context),
        if (showBackendRestartBanner) ...[
          slots.buildRestartBanner(context),
          const SizedBox(height: AppSpacing.s8),
        ],
        if (toggleEntries.isNotEmpty) ...[
          slots.buildSectionHeader(context, 'FEATURE TOGGLES'),
          const SizedBox(height: AppSpacing.s8),
          for (final entry in toggleEntries) ...[
            slots.buildEntryTile(context, entry, () => onEntryTap(entry)),
            slots.buildEntrySeparator(context),
          ],
        ],
        if (toggleEntries.isNotEmpty && experimentEntries.isNotEmpty) ...[
          slots.buildSectionDivider(context),
        ],
        if (experimentEntries.isNotEmpty) ...[
          slots.buildSectionHeader(context, 'A/B TESTS'),
          const SizedBox(height: AppSpacing.s8),
          for (final entry in experimentEntries) ...[
            slots.buildEntryTile(context, entry, () => onEntryTap(entry)),
            slots.buildEntrySeparator(context),
          ],
        ],
        const SizedBox(height: AppSpacing.s16),
      ],
    );
  }
}
