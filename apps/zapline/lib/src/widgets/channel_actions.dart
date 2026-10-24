import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../screens/guide_mapping_screen.dart';
import '../layout.dart';
import '../l10n.dart';
import '../theme.dart';
import 'channel_logo.dart';
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
                            channel.name,
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
                        state.setChannelHidden(channel, true);
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
              channel.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1, color: ZaplineColors.line),
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
              state.setChannelHidden(channel, true);
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
