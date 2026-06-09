import 'package:flutter/material.dart' show Divider;
import 'package:flutter/widgets.dart';
import 'package:habit_loop/slices/debug/ui/generic/debug_seed_data_view_model.dart';

typedef SeedSectionSlots = ({
  Widget Function(BuildContext context) buildHeader,
  Widget Function(BuildContext context, Key key, String label, bool isBusy, VoidCallback onPressed) buildButton,
  Widget Function(BuildContext context, List<Widget> buttons) buildButtonContainer,
  Widget Function(BuildContext context, Key key, String message, DebugSeedState status) buildStatusText,
});

class SeedSection extends StatelessWidget {
  const SeedSection({
    super.key,
    required this.state,
    required this.hasFakeBackend,
    required this.onSeedLocal,
    required this.onSeedRemote,
    required this.slots,
  });

  final DebugSeedDataState state;
  final bool hasFakeBackend;
  final VoidCallback onSeedLocal;
  final VoidCallback onSeedRemote;
  final SeedSectionSlots slots;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      slots.buildButton(
        context,
        const Key('seed-local-button'),
        'Regenerate local pacts',
        state.isBusy,
        onSeedLocal,
      ),
      if (hasFakeBackend) ...[
        const Divider(height: 1),
        slots.buildButton(
          context,
          const Key('seed-remote-button'),
          'Regenerate remote pacts',
          state.isBusy,
          onSeedRemote,
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        slots.buildHeader(context),
        slots.buildButtonContainer(context, buttons),
        if (state.status != DebugSeedState.idle) ...[
          const SizedBox(height: 8),
          slots.buildStatusText(context, const Key('seed-status-text'), state.message ?? '', state.status),
        ],
      ],
    );
  }
}
