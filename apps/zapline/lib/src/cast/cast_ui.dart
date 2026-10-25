import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../screens/player_screen.dart';
import '../theme.dart';
import '../widgets/channel_logo.dart';
import 'cast_link.dart';

/// What a player sends to the TV: a channel, or a film or episode with the
/// position to resume from.
Map<String, Object?>? castRequestFor(
  AppState state, {
  Channel? channel,
  String? vodKey,
  Duration position = Duration.zero,
}) {
  String? fingerprint(String sourceId) {
    final s = state.sources.where((s) => s.id == sourceId).firstOrNull;
    return s == null ? null : sourceFingerprint(s);
  }

  if (channel != null) {
    final fp = fingerprint(channel.sourceId);
    if (fp == null) return null;
    return {'source': fp, 'kind': 'live', 'channel': channel.id};
  }
  // "movie:<source>/<id>" or "episode:<source>/<show>/<episode>".
  final key = vodKey;
  if (key == null) return null;
  final colon = key.indexOf(':');
  final parts = key.substring(colon + 1).split('/');
  final fp = parts.isEmpty ? null : fingerprint(parts.first);
  if (fp == null) return null;
  return switch (key.substring(0, colon)) {
    'movie' when parts.length == 2 => {
      'source': fp,
      'kind': 'movie',
      'movie': parts[1],
      'position': position.inMilliseconds,
    },
    'episode' when parts.length >= 3 => {
      'source': fp,
      'kind': 'episode',
      'show': parts.sublist(1, parts.length - 1).join('/'),
      'episode': parts.last,
      'position': position.inMilliseconds,
    },
    _ => null,
  };
}

/// Lets the user pick a TV or PC running Zapline and moves playback there.
/// [stopHere] stops this device's player once the TV has taken over.
Future<void> sendToTv(
  BuildContext context,
  AppState state, {
  required Map<String, Object?> request,
  required String title,
  required VoidCallback stopHere,
  List<Channel>? channels,
  int index = 0,
}) async {
  final device = await showModalBottomSheet<CastDevice>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _CastSheet(title: title, ownPort: state.castPort),
  );
  if (device == null || !context.mounted) return;
  final l = context.l10n;
  String? error;
  try {
    error = await CastClient.play(device, request);
  } catch (_) {
    error = 'unreachable';
  }
  if (!context.mounted) return;
  if (error != null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (error) {
            'unknown-source' => l.castNoList(device.name),
            'unreachable' => l.castUnreachable(device.name),
            _ => l.castFailed(device.name),
          }),
        ),
      );
    return;
  }
  HapticFeedback.mediumImpact();
  final navigator = Navigator.of(context);
  stopHere();
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => CastRemoteScreen(
        state: state,
        device: device,
        channels: channels,
        index: index,
      ),
    ),
  );
}

class _CastSheet extends StatefulWidget {
  const _CastSheet({required this.title, required this.ownPort});

  final String title;
  final int? ownPort;

  @override
  State<_CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends State<_CastSheet> {
  List<CastDevice>? _devices;

  @override
  void initState() {
    super.initState();
    _find();
  }

  Future<void> _find() async {
    setState(() => _devices = null);
    final found = await CastClient.discover(ownPort: widget.ownPort);
    if (mounted) setState(() => _devices = found);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final devices = _devices;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.castTo(widget.title),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (devices == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ZaplineColors.focus,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(l.castSearching),
                ],
              ),
            )
          else if (devices.isEmpty) ...[
            Text(
              l.castNoneFound,
              style: const TextStyle(
                color: ZaplineColors.textMuted,
                height: 1.45,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _find,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.retry),
              ),
            ),
          ] else
            Material(
              color: ZaplineColors.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, d) in devices.indexed) ...[
                    if (i > 0)
                      const Divider(height: 1, color: ZaplineColors.line),
                    ListTile(
                      leading: const Icon(
                        Icons.tv_rounded,
                        color: ZaplineColors.focus,
                      ),
                      title: Text(
                        d.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(l.castZaplineDevice),
                      onTap: () => Navigator.of(context).pop(d),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: ZaplineColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.castOneStream,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ZaplineColors.textMuted,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The phone while the TV plays: what's on, channel up/down or pause, the
/// channel list, back to the phone, stop.
class CastRemoteScreen extends StatefulWidget {
  const CastRemoteScreen({
    super.key,
    required this.state,
    required this.device,
    this.channels,
    this.index = 0,
  });

  final AppState state;
  final CastDevice device;

  /// The list the channel came from; `null` for films and episodes.
  final List<Channel>? channels;
  final int index;

  @override
  State<CastRemoteScreen> createState() => _CastRemoteScreenState();
}

class _CastRemoteScreenState extends State<CastRemoteScreen> {
  late int _index = widget.index;
  CastStatus? _status;
  Timer? _poll;
  bool _lost = false;

  List<Channel>? get _channels => widget.channels;
  bool get _live => _channels != null;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final s = await CastClient.status(widget.device);
      if (mounted) {
        setState(() {
          _status = s;
          _lost = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _lost = true);
    }
  }

  Future<void> _key(String key) async {
    HapticFeedback.selectionClick();
    final list = _channels;
    if (list != null && (key == 'up' || key == 'down')) {
      setState(
        () => _index =
            (_index + (key == 'up' ? -1 : 1) + list.length) % list.length,
      );
    }
    try {
      await CastClient.key(widget.device, key);
    } catch (_) {}
    Future<void>.delayed(const Duration(milliseconds: 600), _refresh);
  }

  Future<void> _pickChannel() async {
    final list = _channels!;
    final picked = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (context, scroll) => ListView.builder(
          controller: scroll,
          itemCount: list.length,
          itemBuilder: (context, i) => ListTile(
            selected: i == _index,
            selectedColor: ZaplineColors.focus,
            leading: ChannelLogo(channel: list[i], width: 48, height: 34),
            title: Text(widget.state.displayName(list[i])),
            onTap: () => Navigator.of(sheet).pop(i),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final request = castRequestFor(widget.state, channel: list[picked]);
    if (request == null) return;
    setState(() => _index = picked);
    try {
      await CastClient.play(widget.device, request);
    } catch (_) {}
    _refresh();
  }

  Future<void> _watchHere() async {
    try {
      await CastClient.stop(widget.device);
    } catch (_) {}
    if (!mounted) return;
    final list = _channels;
    final navigator = Navigator.of(context);
    if (list == null) {
      navigator.pop();
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          state: widget.state,
          channels: list,
          initialIndex: _index,
        ),
      ),
    );
  }

  Future<void> _stop() async {
    try {
      await CastClient.stop(widget.device);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final list = _channels;
    final channel = list == null ? null : list[_index];
    final status = _status;
    Widget round(
      IconData icon,
      String tip,
      VoidCallback onTap, {
      bool main = false,
    }) => Material(
      color: main ? ZaplineColors.focus : ZaplineColors.surfaceHigh,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tip,
        iconSize: main ? 34 : 28,
        padding: EdgeInsets.all(main ? 22 : 16),
        color: main ? ZaplineColors.onFocus : ZaplineColors.text,
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.back,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.tv_rounded, size: 18, color: ZaplineColors.focus),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l.castOnAir(widget.device.name),
                style: const TextStyle(
                  fontSize: 15,
                  color: ZaplineColors.focus,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            if (channel != null)
              ChannelLogo(channel: channel, width: 160, height: 100),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                channel != null
                    ? widget.state.displayName(channel)
                    : status?.title ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _lost
                    ? l.castLost
                    : status == null
                    ? l.castStopped
                    : status.subtitle ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: _lost ? ZaplineColors.live : ZaplineColors.textMuted,
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _live
                  ? [
                      round(
                        Icons.keyboard_arrow_up_rounded,
                        l.previousChannel,
                        () => _key('up'),
                      ),
                      const SizedBox(width: 26),
                      round(
                        Icons.format_list_bulleted_rounded,
                        l.channelList,
                        _pickChannel,
                        main: true,
                      ),
                      const SizedBox(width: 26),
                      round(
                        Icons.keyboard_arrow_down_rounded,
                        l.nextChannel,
                        () => _key('down'),
                      ),
                    ]
                  : [
                      round(
                        Icons.play_arrow_rounded,
                        l.pause,
                        () => _key('toggle'),
                        main: true,
                      ),
                    ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                children: [
                  if (_live) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _watchHere,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: ZaplineColors.text,
                          side: const BorderSide(color: ZaplineColors.line),
                        ),
                        child: Text(l.castWatchHere),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _stop,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: const Color(0xFF2B1A17),
                        foregroundColor: ZaplineColors.live,
                      ),
                      child: Text(l.castStop),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
