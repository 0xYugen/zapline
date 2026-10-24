import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../theme.dart';
import 'channel_logo.dart';
import 'focus_card.dart';

/// A channel in a list: logo, number, name, what is on now with progress,
/// and catch-up / favourite markers. Hold OK to toggle the favourite.
class ChannelTile extends StatelessWidget {
  const ChannelTile({
    super.key,
    required this.state,
    required this.channel,
    required this.fallbackNumber,
    required this.onPressed,
    required this.onLongPress,
    this.focusNode,
  });

  final AppState state;
  final Channel channel;
  final int fallbackNumber;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = channel;
    // One indexed query per visible row; rows are built lazily.
    final (now, _) = state.nowNext(c);
    return FocusCard(
      focusNode: focusNode,
      onPressed: onPressed,
      onLongPress: onLongPress,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          ChannelLogo(channel: c),
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            child: Text(
              '${c.number ?? fallbackNumber}',
              style: const TextStyle(
                fontSize: 16,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (now != null)
                  // Builder: read the text colour FocusCard sets for its
                  // child (dark on the focused amber), not this row's.
                  Builder(
                    builder: (context) => Text(
                      now.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: DefaultTextStyle.of(context).style.color
                            ?.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (now != null)
            SizedBox(width: 90, child: _Progress(programme: now)),
          if (c.catchup != null)
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Icon(Icons.history, size: 20),
            ),
          if (state.isFavourite(c))
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(Icons.star_rounded, size: 22),
            ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.programme});

  final Programme programme;

  @override
  Widget build(BuildContext context) {
    final total = programme.stop.difference(programme.start).inSeconds;
    final done = DateTime.now().toUtc().difference(programme.start).inSeconds;
    final v = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final fg = DefaultTextStyle.of(context).style.color ?? ZaplineColors.text;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: v,
        minHeight: 5,
        color: fg,
        backgroundColor: fg.withValues(alpha: 0.2),
      ),
    );
  }
}
