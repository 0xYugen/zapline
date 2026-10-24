import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../screens/guide_mapping_screen.dart';
import '../layout.dart';
import '../l10n.dart';
import '../theme.dart';
import '../screens/player_screen.dart';
import 'channel_logo.dart';
import 'channel_versions.dart';
import 'focus_card.dart';

/// Menu opened by holding OK on a channel (or the Menu key, a long tap, a
/// right click): favourite, hide, fix its guide.
Future<void> showChannelActions(
  BuildContext context,
  AppState state,
  Channel channel,
) => context.isPhone
    ? (HapticFeedback.mediumImpact(), _showSheet(context, state, channel)).$2
    : showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (dialogContext) {
          final favourite = state.isFavourite(channel);
          void done() => Navigator.of(dialogContext).pop();

          Widget action(
            IconData icon,
            String label,
            VoidCallback onPressed, {
            bool autofocus = false,
          }) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FocusCard(
              autofocus: autofocus,
              onPressed: onPressed,
              child: Row(
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          return Dialog(
            backgroundColor: ZaplineColors.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ChannelLogo(channel: channel),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            state.displayName(channel),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (state.versionsOf(channel).length > 1)
                      action(
                        Icons.hd_outlined,
                        _versionLabel(context, state, channel),
                        () {
                          done();
                          _pickVersion(context, state, channel);
                        },
                      ),
                    action(
                      favourite
                          ? Icons.star_outline_rounded
                          : Icons.star_rounded,
                      favourite
                          ? context.l10n.removeFromFavourites
                          : context.l10n.addToFavourites,
                      () {
                        state.toggleFavourite(channel);
                        done();
                      },
                      autofocus: true,
                    ),
                    action(
                      Icons.visibility_off_outlined,
                      context.l10n.hideChannel,
                      () {
                        _hideAll(state, channel);
                        done();
                      },
                    ),
                    action(
                      Icons.event_note_outlined,
                      context.l10n.fixItsGuide,
                      () {
                        done();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => GuideMappingScreen(
                              state: state,
                              sourceId: channel.sourceId,
                              only: channel,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.hiddenHint,
                      style: TextStyle(
                        fontSize: 13,
                        color: ZaplineColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

void _fixGuide(BuildContext context, AppState state, Channel channel) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuideMappingScreen(
          state: state,
          sourceId: channel.sourceId,
          only: channel,
        ),
      ),
    );

Future<void> _showSheet(
  BuildContext context,
  AppState state,
  Channel channel,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (sheetContext) {
    final favourite = state.isFavourite(channel);
    void done() => Navigator.of(sheetContext).pop();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: ChannelLogo(channel: channel, width: 48, height: 34),
            title: Text(
              state.displayName(channel),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1, color: ZaplineColors.line),
          if (state.versionsOf(channel).length > 1)
            ListTile(
              leading: const Icon(Icons.hd_outlined),
              title: Text(_versionLabel(context, state, channel)),
              subtitle: Text(
                context.l10n.versionCount(state.versionsOf(channel).length),
              ),
              onTap: () {
                done();
                _pickVersion(context, state, channel);
              },
            ),
          ListTile(
            leading: Icon(
              favourite ? Icons.star_outline_rounded : Icons.star_rounded,
            ),
            title: Text(
              favourite
                  ? context.l10n.removeFromFavourites
                  : context.l10n.addToFavourites,
            ),
            onTap: () {
              state.toggleFavourite(channel);
              done();
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: Text(context.l10n.hideChannel),
            subtitle: Text(context.l10n.hiddenHint),
            onTap: () {
              _hideAll(state, channel);
              done();
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: Text(context.l10n.fixItsGuide),
            onTap: () {
              done();
              _fixGuide(context, state, channel);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  },
);

void _hideAll(AppState state, Channel channel) {
  for (final v in state.versionsOf(channel)) {
    state.setChannelHidden(v, true);
  }
}

String _versionLabel(BuildContext context, AppState state, Channel c) =>
    context.l10n.versionPlaying(state.qualityOf(c) ?? state.displayName(c));

/// From the channel list: the picked version becomes the channel's, or
/// plays once when not to be remembered.
Future<void> _pickVersion(
  BuildContext context,
  AppState state,
  Channel channel,
) async {
  final picked = await pickChannelVersion(
    context,
    state,
    channel,
    rememberByDefault: true,
  );
  if (picked == null || !context.mounted) return;
  if (picked.remember) {
    state.preferVersion(picked.channel);
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(
        state: state,
        channels: [picked.channel],
        initialIndex: 0,
      ),
    ),
  );
}
