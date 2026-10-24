import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../layout.dart';
import '../theme.dart';
import '../widgets/channel_logo.dart';
import '../widgets/focus_card.dart';
import '../widgets/tv_text_field.dart';

/// Gives channels the automatic matcher missed a TV guide, one channel at a
/// time: the likely guides are shown with what they air now, so the right
/// one is recognised by its programme rather than by a code. Sure matches
/// can be taken all at once. Choices survive re-syncs.
class GuideMappingScreen extends StatefulWidget {
  const GuideMappingScreen({
    super.key,
    required this.state,
    required this.sourceId,
    this.only,
  });

  final AppState state;
  final String sourceId;

  /// Fix just this channel (from its menu), even if it already has a guide.
  final Channel? only;

  @override
  State<GuideMappingScreen> createState() => _GuideMappingScreenState();
}

/// A suggestion at least this good is taken as sure.
const _sure = 0.9;

class _GuideMappingScreenState extends State<GuideMappingScreen> {
  AppState get _state => widget.state;

  late List<Channel> _queue = _load();
  late final int _total = _queue.length;
  int _done = 0;
  bool _searching = false;
  final _query = TextEditingController();

  List<Channel> _load() => widget.only != null
      ? [widget.only!]
      : _state.channelsNeedingGuide(widget.sourceId);

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Channel? get _current => _queue.firstOrNull;

  void _next({required bool done}) {
    HapticFeedback.selectionClick();
    setState(() {
      final c = _queue.removeAt(0);
      if (done) {
        _done++;
      } else {
        // Skipped: asked again at the end.
        _queue.add(c);
      }
      _searching = false;
      _query.clear();
    });
  }

  void _assign(Channel c, XmltvChannel g) {
    _state.assignGuide(c, g.id);
    _snack(context.l10n.guideLinked(_state.displayName(c), g.displayName));
    _next(done: true);
  }

  void _noGuide(Channel c) {
    _state.markNoGuide(c);
    _next(done: true);
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );

  /// Channels whose best suggestion is all but certain; worked out once,
  /// ranking every channel against every guide is slow.
  late final List<(Channel, XmltvChannel)> _allSure = widget.only != null
      ? const []
      : _sureMatches();

  List<(Channel, XmltvChannel)> _sureMatches() => [
    for (final c in _queue)
      if (_state.guideSuggestions(c).firstOrNull case (final g, final score)
          when score >= _sure)
        (c, g),
  ];

  void _takeSure(List<(Channel, XmltvChannel)> sure) {
    _state.assignGuides([for (final (c, g) in sure) (c, g.id)]);
    final taken = {for (final (c, _) in sure) c};
    setState(() {
      _queue = [
        for (final c in _queue)
          if (!taken.contains(c)) c,
      ];
      _done += taken.length;
    });
    _snack(context.l10n.sureMatchesTaken(taken.length));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final phone = context.isPhone;
    final c = _current;
    final sure = [
      for (final e in _allSure)
        if (_queue.contains(e.$1)) e,
    ];
    final body = c == null
        ? _finished(l)
        : ListView(
            padding: phone
                ? const EdgeInsets.fromLTRB(16, 4, 16, 24)
                : const EdgeInsets.fromLTRB(56, 40, 56, 32),
            children: [
              if (!phone)
                Text(
                  l.fixTvGuide,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (_total > 1) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.matchProgress(_done + 1, _total),
                          style: const TextStyle(
                            color: ZaplineColors.textMuted,
                          ),
                        ),
                      ),
                      Text(
                        '${(_done * 100 / _total).round()}%',
                        style: const TextStyle(color: ZaplineColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _done / _total,
                      minHeight: 4,
                      color: ZaplineColors.focus,
                      backgroundColor: ZaplineColors.line,
                    ),
                  ),
                ),
              ],
              if (sure.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _SureBanner(
                    count: sure.length,
                    onTake: () => _takeSure(sure),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _ChannelCard(
                  key: ValueKey(c),
                  state: _state,
                  channel: c,
                  searching: _searching,
                  query: _query,
                  onSearch: () => setState(() => _searching = true),
                  onPick: (g) => _assign(c, g),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _noGuide(c),
                      style: _buttonStyle(outlined: true),
                      child: Text(l.noGuideForIt),
                    ),
                  ),
                  if (_queue.length > 1) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => _next(done: false),
                        style: _buttonStyle(outlined: false),
                        child: Text(l.skipForNow),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
    return Scaffold(
      appBar: phone ? AppBar(title: Text(l.fixTvGuide)) : null,
      body: body,
    );
  }

  static ButtonStyle _buttonStyle({required bool outlined}) =>
      (outlined ? OutlinedButton.styleFrom : FilledButton.styleFrom)(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: ZaplineColors.text,
        backgroundColor: outlined ? null : ZaplineColors.surfaceHigh,
        side: outlined ? const BorderSide(color: ZaplineColors.line) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      );

  Widget _finished(AppLocalizations l) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 56,
            color: ZaplineColors.ok,
          ),
          const SizedBox(height: 16),
          Text(
            widget.only != null ? l.fixDone : l.fixAllMatched,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          FocusCard(
            autofocus: true,
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l.back),
          ),
        ],
      ),
    ),
  );
}

class _SureBanner extends StatelessWidget {
  const _SureBanner({required this.count, required this.onTake});

  final int count;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2412),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5A4716)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: ZaplineColors.focus),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.sureMatches(count),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(l.sureMatchesHint, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FocusCard(
            onPressed: onTake,
            selected: true,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              l.takeAll,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// The channel to match, its likely guides with what they air now, and a
/// search over every guide channel.
class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    super.key,
    required this.state,
    required this.channel,
    required this.searching,
    required this.query,
    required this.onSearch,
    required this.onPick,
  });

  final AppState state;
  final Channel channel;
  final bool searching;
  final TextEditingController query;
  final VoidCallback onSearch;
  final ValueChanged<XmltvChannel> onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = query.text.trim();
    final suggestions = state.guideSuggestions(channel);
    final options = searching && q.isNotEmpty
        ? [for (final g in state.searchGuide(q, limit: 12)) (g, 0.0)]
        : suggestions.take(searching ? 8 : 3).toList();
    // Outlined, so the guide choices inside stand out as buttons.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZaplineColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ChannelLogo(channel: channel, width: 64, height: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.displayName(channel),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (channel.groupTitle case final g? when g.isNotEmpty)
                      Text(
                        l.inGroupNoGuide(g),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 14),
          Text(
            suggestions.isEmpty && !searching ? l.noSuggestions : l.whichGuide,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          if (searching)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TvTextField(
                builder: (readOnly) => TextField(
                  readOnly: readOnly,
                  controller: query,
                  autofocus: true,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l.searchTheGuide,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          for (final (i, (g, score)) in options.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GuideOption(
                autofocus: i == 0 && !searching,
                name: g.displayName,
                airing: state.airingOn(g.id),
                likely: i == 0 && score >= _sure && !searching,
                onPressed: () => onPick(g),
              ),
            ),
          if (searching && q.isNotEmpty && options.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l.nothingFoundTryAnother,
                style: const TextStyle(color: ZaplineColors.textMuted),
              ),
            ),
          if (!searching)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onSearch,
                style: TextButton.styleFrom(
                  foregroundColor: ZaplineColors.focus,
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.search_rounded),
                label: Text(l.searchAnotherGuide),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideOption extends StatelessWidget {
  const _GuideOption({
    required this.name,
    required this.airing,
    required this.likely,
    required this.onPressed,
    this.autofocus = false,
  });

  final String name;
  final Programme? airing;
  final bool likely;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = airing;
    final local = MaterialLocalizations.of(context);
    String hm(DateTime t) => local.formatTimeOfDay(
      TimeOfDay.fromDateTime(t.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return FocusCard(
      autofocus: autofocus,
      onPressed: onPressed,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (likely)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17352A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    l.veryLikely,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ZaplineColors.ok,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Builder(
            builder: (context) => Text(
              a == null ? l.nothingAiringNow : l.airingNow(a.title, hm(a.stop)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: DefaultTextStyle.of(context).style.color
                    ?.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
