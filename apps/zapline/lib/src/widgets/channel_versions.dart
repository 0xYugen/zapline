import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import 'channel_logo.dart';
import 'channel_name.dart';

/// Lets the user pick which version of a channel to watch (4K, Full HD,
/// HD…). Returns the version and whether to keep it for this channel.
Future<({Channel channel, bool remember})?> pickChannelVersion(
  BuildContext context,
  AppState state,
  Channel current, {
  bool rememberByDefault = false,
}) => showModalBottomSheet<({Channel channel, bool remember})>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => _VersionSheet(
    state: state,
    current: current,
    remember: rememberByDefault,
  ),
);

class _VersionSheet extends StatefulWidget {
  const _VersionSheet({
    required this.state,
    required this.current,
    required this.remember,
  });

  final AppState state;
  final Channel current;
  final bool remember;

  @override
  State<_VersionSheet> createState() => _VersionSheetState();
}

class _VersionSheetState extends State<_VersionSheet> {
  late bool _remember = widget.remember;

  String _describe(AppLocalizations l, Channel v) =>
      switch (ChannelVariant.parse(v.name).quality) {
        VideoQuality.uhd => l.versionUhd,
        VideoQuality.fhd => l.versionFhd,
        VideoQuality.hd => l.versionHd,
        VideoQuality.sd => l.versionSd,
        VideoQuality.unknown => l.versionOther,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = widget.state;
    final versions = state.versionsOf(widget.current);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ChannelLogo(channel: widget.current, width: 56, height: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.displayName(widget.current),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l.versionCount(versions.length),
                      style: const TextStyle(
                        fontSize: 13,
                        color: ZaplineColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: ZaplineColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, v) in versions.indexed) ...[
                  if (i > 0)
                    const Divider(height: 1, color: ZaplineColors.line),
                  ListTile(
                    autofocus: v.id == widget.current.id,
                    onTap: () =>
                        Navigator.of(context)
                            .pop((channel: v, remember: _remember)),
                    leading: SizedBox(
                      width: 44,
                      child: Center(
                        child: QualityBadge(state.qualityOf(v) ?? '·'),
                      ),
                    ),
                    title: Text(
                      _describe(l, v),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      v.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: v.id == widget.current.id
                        ? const Icon(
                            Icons.check_rounded,
                            color: ZaplineColors.focus,
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            value: _remember,
            onChanged: (v) => setState(() => _remember = v),
            title: Text(
              l.rememberVersion,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              state.settings.saveData
                  ? l.rememberVersionHintSaver
                  : l.rememberVersionHintBest,
            ),
          ),
        ],
      ),
    );
  }
}
