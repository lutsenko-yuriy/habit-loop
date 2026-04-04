import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/features/pact/domain/pact_list_state.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_detail_screen.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

class PactsSummaryBar extends ConsumerStatefulWidget {
  final AsyncCallback onCreatePact;

  const PactsSummaryBar({super.key, required this.onCreatePact});

  @override
  ConsumerState<PactsSummaryBar> createState() => _PactsSummaryBarState();
}

class _PactsSummaryBarState extends ConsumerState<PactsSummaryBar> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(pactListViewModelProvider.notifier).load();
    });
  }

  Future<void> _showSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => _PactListSheet(
          scrollController: scrollController,
          onCreatePact: widget.onCreatePact,
        ),
      ),
    );
    if (mounted) ref.read(pactListViewModelProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pactListViewModelProvider);
    final l10n = AppLocalizations.of(context)!;

    if (state.activeCount == 0 && state.doneCount == 0 && state.cancelledCount == 0) {
      return const SizedBox.shrink();
    }

    final lines = <String>[
      if (state.activeCount > 0) l10n.pactsActive(state.activeCount),
      if (state.doneCount > 0) l10n.pactsDone(state.doneCount),
      if (state.cancelledCount > 0) l10n.pactsCancelled(state.cancelledCount),
    ];

    return GestureDetector(
      onTap: () => _showSheet(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lines.join('\n'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Icon(Icons.keyboard_arrow_up, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Sheet content ────────────────────────────────────────────────────────────

class _PactListSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final AsyncCallback onCreatePact;

  const _PactListSheet({
    required this.scrollController,
    required this.onCreatePact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pactListViewModelProvider);
    final l10n = AppLocalizations.of(context)!;

    void navigateToPact(PactListEntry entry) {
      final nav = Navigator.of(context);
      nav.pop();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        nav.push(CupertinoPageRoute<void>(
          builder: (_) => PactDetailScreen(pactId: entry.pact.id),
        ));
      } else {
        nav.push(MaterialPageRoute<void>(
          builder: (_) => PactDetailScreen(pactId: entry.pact.id),
        ));
      }
    }

    Future<void> addPact() async {
      Navigator.of(context).pop();
      await onCreatePact();
    }

    return Column(
      children: [
        // Drag handle
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.pactListTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: addPact,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addPact),
              ),
            ],
          ),
        ),
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _FilterChip(
                label: l10n.filterActive,
                selected: state.activeFilters.contains(PactStatus.active),
                onTap: () => ref
                    .read(pactListViewModelProvider.notifier)
                    .toggleFilter(PactStatus.active),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: l10n.filterDone,
                selected: state.activeFilters.contains(PactStatus.completed),
                onTap: () => ref
                    .read(pactListViewModelProvider.notifier)
                    .toggleFilter(PactStatus.completed),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: l10n.filterCancelled,
                selected: state.activeFilters.contains(PactStatus.stopped),
                onTap: () => ref
                    .read(pactListViewModelProvider.notifier)
                    .toggleFilter(PactStatus.stopped),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        // Pact list
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.filteredEntries.isEmpty
                  ? Center(child: Text(l10n.noPactsYet))
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: state.filteredEntries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                      itemBuilder: (context, index) {
                        final entry = state.filteredEntries[index];
                        return _PactTile(
                          entry: entry,
                          onTap: () => navigateToPact(entry),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _PactTile extends StatelessWidget {
  final PactListEntry entry;
  final VoidCallback onTap;

  const _PactTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMd(locale);
    final pact = entry.pact;

    final String subtitle;
    if (pact.status == PactStatus.active) {
      final next = entry.nextShowupAt;
      subtitle = next != null
          ? l10n.pactNextShowup(dateFormat.format(next))
          : '';
    } else if (pact.status == PactStatus.completed) {
      subtitle = l10n.pactEndedOn(dateFormat.format(pact.endDate));
    } else {
      subtitle = l10n.pactCancelledOn(dateFormat.format(pact.endDate));
    }

    return ListTile(
      onTap: onTap,
      title: Text(pact.habitName),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
