import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../theme.dart';

/// A channel's name and, when the provider lists it in several qualities,
/// the quality playing ("4K") and how many other versions there are ("+2").
class ChannelName extends StatelessWidget {
  const ChannelName({
    super.key,
    required this.state,
    required this.channel,
    required this.style,
  });

  final AppState state;
  final Channel channel;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final others = state.versionsOf(channel).length - 1;
    final quality = others > 0 ? state.qualityOf(channel) : null;
    // Muted text follows the colour around (dark on a focused TV card).
    final muted = DefaultTextStyle.of(context).style.color
        ?.withValues(alpha: 0.7);
    return Row(
      children: [
        Flexible(
          child: Text(
            state.displayName(channel),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (quality != null) ...[
          const SizedBox(width: 6),
          QualityBadge(quality),
        ],
        if (others > 0) ...[
          const SizedBox(width: 4),
          Text(
            '+$others',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: muted ?? ZaplineColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// "4K", "FHD", "HD" or "SD" in a small outlined box; 4K stands out.
class QualityBadge extends StatelessWidget {
  const QualityBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = DefaultTextStyle.of(context).style.color;
    // Dark text means a light (focused, amber) card: amber would vanish.
    final onLight = text != null && text.computeLuminance() < 0.2;
    final color = label == '4K' && !onLight
        ? ZaplineColors.focus
        : text?.withValues(alpha: onLight ? 0.9 : 0.75) ??
              ZaplineColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}
