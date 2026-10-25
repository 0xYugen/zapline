import 'package:flutter/material.dart';
import 'package:zapline_data/zapline_data.dart';

import '../l10n.dart';
import '../theme.dart';

/// A source loading, in three steps: login, channels, TV guide.
class SyncSteps extends StatelessWidget {
  const SyncSteps(this.p, {super.key, this.title});

  /// Shown above the steps; "Connecting…" when not given.
  final String? title;

  final SyncProgress? p;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stage = p?.stage;
    final count = p?.count ?? 0;
    final step = switch (stage) {
      null => 0,
      SyncStage.channels => count == 0 ? 0 : 1,
      SyncStage.guide => 2,
      SyncStage.linking || SyncStage.done => 3,
    };
    final steps = [
      (l.stepLogin, step > 0),
      (step >= 1 ? l.stepChannelsCount(count) : l.stepChannels, step > 1),
      (
        stage == SyncStage.guide
            ? l.stepGuideCount(count)
            : stage == SyncStage.linking
            ? l.stepMatching
            : l.stepGuide,
        step > 2,
      ),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZaplineColors.surface,
        border: Border.all(color: ZaplineColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title ?? l.connecting,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final (i, (label, done)) in steps.indexed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      done
                          ? Icons.check_circle_rounded
                          : i == step
                          ? Icons.downloading_rounded
                          : Icons.circle_outlined,
                      size: 16,
                      color: done
                          ? ZaplineColors.ok
                          : i == step
                          ? ZaplineColors.focus
                          : ZaplineColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: done || i == step
                            ? ZaplineColors.text
                            : ZaplineColors.textMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (step + 0.5) / 4,
              minHeight: 6,
              color: ZaplineColors.focus,
              backgroundColor: ZaplineColors.line,
            ),
          ),
        ],
      ),
    );
  }
}
