import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../free_epg.dart';
import '../l10n.dart';
import '../layout.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import '../widgets/free_epg_picker.dart';
import '../widgets/settings_widgets.dart';
import 'filters_screen.dart';
import 'guide_mapping_screen.dart';
import 'manage_source_screen.dart';

/// A source at a glance: how many channels, how much of them has a TV
/// guide, when it was updated and what went wrong, then its settings one
/// tap away and a suggestion when the guide is thin.
class SourceDetailScreen extends StatefulWidget {
  const SourceDetailScreen({
    super.key,
    required this.state,
    required this.sourceId,
  });

  final AppState state;
  final String sourceId;

  @override
  State<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends State<SourceDetailScreen> {
  AppState get _state => widget.state;

  SourceRecord? get _source =>
      _state.sources.where((s) => s.id == widget.sourceId).firstOrNull;

  // A new message replaces the one on screen instead of queueing.
  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _refresh(SourceRecord s) async {
    final l = context.l10n;
    try {
      final r = await _state.refresh(s);
      if (!mounted) return;
      _snack(
        r.guideErrors.isEmpty
            ? l.refreshResult(r.channels, r.guide.programmes)
            : l.refreshGuideFailed(r.guideErrors.join('; ')),
      );
    } catch (e) {
      if (mounted) _snack(l.refreshFailed('$e'));
    }
  }

  Future<void> _addFreeEpg(SourceRecord s) async {
    final l = context.l10n;
    final epg =
        _state.likelyFreeEpg(s.id) ??
        suggestedFreeEpg() ??
        await pickFreeEpg(context);
    if (epg == null || !mounted) return;
    _snack(l.loadingFreeEpg(epg.name));
    try {
      final r = await _state.addFreeEpg(s, epg);
      if (mounted) {
        _snack(
          l.freeEpgAdded(epg.name, r.coverage.matched, r.coverage.channels),
        );
      }
    } catch (e) {
      if (mounted) _snack(l.refreshFailed('$e'));
    }
  }

  Future<void> _remove(SourceRecord s) async {
    final l = context.l10n;
    final ok = await confirmDanger(
      context,
      title: l.removeSourceTitle(s.name),
      message: l.removeSourceMessage,
      confirm: l.removeSource,
      cancel: l.cancel,
    );
    if (!ok || !mounted) return;
    _state.deleteSource(s.id);
    Navigator.of(context).maybePop();
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _state,
    builder: (context, _) {
      final s = _source;
      if (s == null) return const Scaffold();
      final l = context.l10n;
      final cov = _state.coverage(s.id);
      final status = _state.guideStatus(s.id);
      final syncing = _state.syncingSourceId == s.id;
      final hidden = _state.hiddenChannels(s.id).length;
      final groups = _state.groupInfo(s.id);
      final shown = groups.where((g) => !g.hidden).length;
      final free = {for (final u in s.extraGuideUrls) ?FreeEpg.ofUrl(u)?.name};
      final otherGuides = s.extraGuideUrls
          .where((u) => FreeEpg.ofUrl(u) == null)
          .length;
      final missing = cov.channels - cov.matched;

      return AdaptivePage(
        title: s.name,
        children: [
          _Summary(
            state: _state,
            source: s,
            coverage: cov,
            status: status,
            syncing: syncing,
          ),
          if (cov.channels > 0 && cov.ratio < 0.8)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _Suggestion(
                text: l.channelsWithoutGuide(missing),
                actions: [
                  if (!_state.hasFreeEpg(s))
                    (
                      switch (_state.likelyFreeEpg(s.id) ??
                          suggestedFreeEpg()) {
                        final c? => l.addFreeEpgFor(c.name),
                        null => l.addFreeEpg,
                      },
                      () => _addFreeEpg(s),
                    ),
                  (
                    l.matchThem,
                    () => _open(
                      GuideMappingScreen(state: _state, sourceId: s.id),
                    ),
                  ),
                ],
              ),
            ),
          SettingsGroup(
            children: [
              SettingsTile(
                autofocus: !context.isPhone,
                icon: Icons.calendar_month_rounded,
                iconColor: ZaplineColors.focus,
                title: l.sectionGuide,
                subtitle: [
                  l.guideFromSource,
                  if (free.isNotEmpty) l.freeEpgShort(free.join(', ')),
                  if (otherGuides > 0) l.extraGuides(otherGuides),
                  if (s.guideOffset != Duration.zero)
                    l.shiftedBy('${s.guideOffset.inMinutes} min'),
                ].join(' · '),
                onTap: () => _open(
                  ManageSourceScreen(
                    state: _state,
                    sourceId: s.id,
                    section: SourceSection.guide,
                  ),
                ),
              ),
              SettingsTile(
                icon: Icons.filter_alt_outlined,
                iconColor: ZaplineColors.focus,
                title: l.sectionGroups,
                subtitle: [
                  if (_same(s.groupFilter.include, italianTerms))
                    l.italianOnlyTv
                  else if (!s.groupFilter.isEmpty)
                    l.filterOn,
                  l.groupsShown(shown, groups.length),
                  if (hidden > 0) l.hiddenCount(hidden),
                ].join(' · '),
                onTap: () =>
                    _open(FiltersScreen(state: _state, sourceId: s.id)),
              ),
              if (missing > 0)
                SettingsTile(
                  icon: Icons.link_rounded,
                  iconColor: ZaplineColors.focus,
                  title: l.fixTvGuide,
                  subtitle: l.channelsWithoutGuide(missing),
                  onTap: () =>
                      _open(GuideMappingScreen(state: _state, sourceId: s.id)),
                ),
              SettingsTile(
                icon: Icons.edit_outlined,
                iconColor: ZaplineColors.focus,
                title: l.sectionName,
                subtitle: [
                  Uri.tryParse(
                        s.url.contains('://') ? s.url : 'http://${s.url}',
                      )?.host ??
                      s.url,
                  if (s.username.isNotEmpty) s.username,
                ].join(' · '),
                onTap: () => _open(
                  ManageSourceScreen(
                    state: _state,
                    sourceId: s.id,
                    section: SourceSection.name,
                  ),
                ),
              ),
            ],
          ),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.sync_rounded,
                title: syncing ? l.refreshing : l.refreshNow,
                chevron: false,
                onTap: _state.isSyncing ? () {} : () => _refresh(s),
              ),
              SettingsTile(
                icon: Icons.delete_outline_rounded,
                title: l.removeSource,
                danger: true,
                chevron: false,
                onTap: () => _remove(s),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.state,
    required this.source,
    required this.coverage,
    required this.status,
    required this.syncing,
  });

  final AppState state;
  final SourceRecord source;
  final GuideCoverage coverage;
  final GuideStatus? status;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final synced = source.syncedAt?.toLocal();
    final g = status;
    final (statusText, statusColor) = switch (g) {
      _ when syncing => (
        l.syncingProgress('${state.progress ?? ''}'),
        ZaplineColors.focus,
      ),
      final g? when g.errors.isNotEmpty => (
        l.epgFailed(g.errors.join('; ')),
        ZaplineColors.live,
      ),
      final g? when g.programmes == 0 => (
        g.perChannel ? l.epgEmptyPerChannel : l.epgEmpty,
        ZaplineColors.live,
      ),
      _ when synced != null => (
        l.updatedAt(_day(l, synced), state.time(synced.toUtc())),
        ZaplineColors.ok,
      ),
      _ => (l.neverSynced, ZaplineColors.textMuted),
    };
    final ratio = coverage.ratio;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZaplineColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 76,
            child: CustomPaint(
              painter: _Ring(
                ratio,
                ratio >= 0.8 ? ZaplineColors.ok : ZaplineColors.focus,
              ),
              child: Center(
                child: Text(
                  '${(ratio * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.channelCount(coverage.channels),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l.guideFor(coverage.matched)} · '
                  '${source.kind == SourceKind.xtream ? 'Xtream' : 'M3U'}',
                  style: const TextStyle(color: ZaplineColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(statusText, style: TextStyle(color: statusColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _day(AppLocalizations l, DateTime t) {
    final now = DateTime.now();
    final d = DateTime(
      t.year,
      t.month,
      t.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    return switch (d) {
      0 => l.today.toLowerCase(),
      -1 => l.yesterday.toLowerCase(),
      _ => '${t.day}/${t.month}',
    };
  }
}

class _Ring extends CustomPainter {
  _Ring(this.ratio, this.color);

  final double ratio;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 8.0;
    final rect = (Offset.zero & size).deflate(w / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = ZaplineColors.line;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * ratio.clamp(0, 1),
      false,
      base
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Ring old) => old.ratio != ratio || old.color != color;
}

/// A hint with one or two actions, shown when something can be improved.
class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.text, required this.actions});

  final String text;
  final List<(String, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF2B2412),
      border: Border.all(color: const Color(0xFF5A4716)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: ZaplineColors.focus,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, (label, onTap)) in actions.indexed)
              FocusCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                radius: 12,
                selected: i == 0,
                onPressed: onTap,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

bool _same(List<String> a, List<String> b) =>
    a.length == b.length &&
    a.map((e) => e.toLowerCase()).toSet().containsAll(b);
