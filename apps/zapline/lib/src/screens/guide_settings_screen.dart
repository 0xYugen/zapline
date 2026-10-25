import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../countries.dart';
import '../free_epg.dart';
import '../l10n.dart';
import '../layout.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import '../widgets/free_epg_picker.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/tv_text_field.dart';
import 'guide_mapping_screen.dart';

/// A source's TV guide: how much of it is covered, the guides in use, and
/// the fixes for when something is off (times, a refresh).
class GuideSettingsScreen extends StatefulWidget {
  const GuideSettingsScreen({
    super.key,
    required this.state,
    required this.sourceId,
  });

  final AppState state;
  final String sourceId;

  @override
  State<GuideSettingsScreen> createState() => _GuideSettingsScreenState();
}

/// A guide as listed: a free EPG country covers several links.
typedef _Guide = ({String title, String subtitle, List<String> urls});

class _GuideSettingsScreenState extends State<GuideSettingsScreen> {
  AppState get _state => widget.state;
  SourceRecord get _source =>
      _state.sources.firstWhere((s) => s.id == widget.sourceId);

  void _snack(String text, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text), action: action));

  Future<void> _refresh() async {
    final l = context.l10n;
    _snack(l.refreshing);
    try {
      final r = await _state.refresh(_source);
      if (!mounted) return;
      _snack(
        r.guideErrors.isEmpty
            ? l.refreshResult(r.channels, r.guide.programmes)
            : l.refreshGuideFailed(r.guideErrors.join('; ')),
      );
    } catch (e) {
      if (mounted) _snack(l.refreshFailed(redactSecrets('$e')));
    }
  }

  String _countryOf(FreeEpg epg) {
    final lang = Localizations.localeOf(context).languageCode;
    final code = epg.code == 'gb' ? 'uk' : epg.code;
    return countryNames.containsKey(code) ? countryName(code, lang) : epg.name;
  }

  List<_Guide> _guides(AppLocalizations l, SourceRecord s) {
    final free = <String, List<String>>{};
    final out = <_Guide>[];
    for (final url in s.extraGuideUrls) {
      final epg = FreeEpg.ofUrl(url);
      if (epg != null) {
        (free[epg.code] ??= []).add(url);
      } else {
        out.add((
          title: Uri.tryParse(url)?.host ?? url,
          subtitle: l.guideLink,
          urls: [url],
        ));
      }
    }
    return [
      for (final MapEntry(:key, :value) in free.entries)
        (
          title: l.freeGuideOf(
            _countryOf(FreeEpg.countries.firstWhere((c) => c.code == key)),
          ),
          subtitle: l.freeGuideHint,
          urls: value,
        ),
      ...out,
    ];
  }

  void _remove(_Guide g) {
    final l = context.l10n;
    final before = _source.extraGuideUrls;
    _state.updateSource(
      _source.copyWith(
        extraGuideUrls: [
          for (final u in before)
            if (!g.urls.contains(u)) u,
        ],
      ),
    );
    _snack(
      l.guideRemovedNamed(g.title),
      action: SnackBarAction(
        label: l.undo,
        onPressed: () =>
            _state.updateSource(_source.copyWith(extraGuideUrls: before)),
      ),
    );
  }

  Future<void> _add() async {
    final l = context.l10n;
    final choice = await showChoice<int>(
      context,
      title: l.addGuide,
      options: {0: l.addFreeGuide, 1: l.addGuideLink},
      current: -1,
    );
    if (choice == null || !mounted) return;
    if (choice.value == 0) {
      final epg = await pickFreeEpg(
        context,
        first: _state.likelyFreeEpg(widget.sourceId),
      );
      if (epg == null || !mounted) return;
      _snack(l.loadingFreeEpg(_countryOf(epg)));
      try {
        final r = await _state.addFreeEpg(_source, epg);
        if (mounted) {
          _snack(
            l.freeEpgAdded(
              _countryOf(epg),
              r.coverage.matched,
              r.coverage.channels,
            ),
          );
        }
      } catch (e) {
        if (mounted) _snack(l.refreshFailed(redactSecrets('$e')));
      }
      return;
    }
    final url = await _askLink();
    if (url == null || !mounted) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _snack(l.enterFullLink);
      return;
    }
    if (_source.extraGuideUrls.contains(url)) return;
    _state.updateSource(
      _source.copyWith(extraGuideUrls: [..._source.extraGuideUrls, url]),
    );
    await _refresh();
  }

  Future<String?> _askLink() {
    final controller = TextEditingController();
    final l = context.l10n;
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.addGuideLink),
        content: TvTextField(
          builder: (readOnly) => TextField(
            readOnly: readOnly,
            controller: controller,
            autofocus: true,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: l.addEpgLink),
            onSubmitted: (v) => Navigator.of(dialog).pop(v.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(controller.text.trim()),
            child: Text(l.add),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  /// Tapping an added guide: shift its times or remove it.
  Future<void> _guideMenu(_Guide g) async {
    final l = context.l10n;
    final choice = await showChoice<int>(
      context,
      title: g.title,
      options: {0: l.shiftTimes, 1: l.remove},
      current: -1,
    );
    if (choice == null || !mounted) return;
    if (choice.value == 0) {
      await _shift([g]);
    } else {
      _remove(g);
    }
  }

  /// "The times are wrong": picks the guide when there are several, then
  /// the shift.
  Future<void> _shiftWhich() async {
    final l = context.l10n;
    final guides = _guides(l, _source);
    if (guides.isEmpty) return _shift(const []);
    String label(String title, Duration d) =>
        '$title · ${d == Duration.zero ? l.noShift : _shiftText(d)}';
    final picked = await showChoice<int>(
      context,
      title: l.whichGuideToShift,
      options: {
        -1: l.allGuides,
        0: label(l.providerGuide, _source.guideOffset),
        for (final (i, g) in guides.indexed)
          i + 1: label(g.title, _source.shiftOf(g.urls.first)),
      },
      current: -2,
    );
    if (picked == null || !mounted) return;
    await switch (picked.value) {
      -1 => _shift(guides, provider: true),
      0 => _shift(const []),
      final i => _shift([guides[i - 1]], provider: false),
    };
  }

  /// Shifts the provider's guide (when [provider]) and [guides].
  Future<void> _shift(List<_Guide> guides, {bool? provider}) async {
    final l = context.l10n;
    final withProvider = provider ?? guides.isEmpty;
    final s = _source;
    final current = withProvider
        ? s.guideOffset
        : s.shiftOf(guides.first.urls.first);
    final options = {
      for (var m = -180; m <= 180; m += 30)
        m: m == 0 ? l.noShift : _shiftText(Duration(minutes: m)),
    };
    final picked = await showChoice<int>(
      context,
      title: l.shiftBy,
      options: options,
      current: current.inMinutes,
    );
    if (picked == null || !mounted) return;
    final d = Duration(minutes: picked.value);
    _state.updateSource(
      s.copyWith(
        guideOffset: withProvider ? d : null,
        guideShifts: {
          ...s.guideShifts,
          for (final g in guides)
            for (final u in g.urls) u: d,
        },
      ),
    );
    await _refresh();
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

  static String _shiftText(Duration d) {
    final m = d.inMinutes;
    final sign = m < 0 ? '−' : '+';
    return '$sign${m.abs() ~/ 60}:${(m.abs() % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _state,
    builder: (context, _) {
      final l = context.l10n;
      final s = _source;
      final cov = _state.coverage(s.id);
      final status = _state.guideStatus(s.id);
      final missing = _state.channelsNeedingGuide(s.id).length;
      final guides = _guides(l, s);
      final syncing = _state.syncingSourceId == s.id;
      return AdaptivePage(
        title: l.sectionGuide,
        children: [
          const SizedBox(height: 4),
          _Coverage(
            ratio: cov.ratio,
            title: l.guideCoverage(cov.matched, cov.channels),
            subtitle: syncing
                ? l.refreshing
                : s.syncedAt == null
                ? l.neverSynced
                : l.updatedAt(
                    _day(l, s.syncedAt!.toLocal()),
                    _state.time(s.syncedAt!.toUtc()),
                  ),
            errors: status?.errors ?? const [],
          ),
          if (missing > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FocusCard(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        GuideMappingScreen(state: _state, sourceId: s.id),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, color: ZaplineColors.focus),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.channelsWithoutGuide(missing),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            l.matchOneByOne,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          SettingsGroup(
            title: l.guidesInUse,
            children: [
              SettingsTile(
                leading: const Icon(
                  Icons.check_circle_rounded,
                  color: ZaplineColors.ok,
                ),
                title: l.providerGuide,
                subtitle: status?.perChannel ?? false
                    ? l.providerGuidePerChannel
                    : l.providerGuideHint,
                value: s.guideOffset == Duration.zero
                    ? null
                    : _shiftText(s.guideOffset),
                onTap: () => _shift(const []),
              ),
              for (final g in guides)
                SettingsTile(
                  leading: const Icon(
                    Icons.check_circle_rounded,
                    color: ZaplineColors.ok,
                  ),
                  title: g.title,
                  subtitle: g.subtitle,
                  value: s.shiftOf(g.urls.first) == Duration.zero
                      ? null
                      : _shiftText(s.shiftOf(g.urls.first)),
                  onTap: () => _guideMenu(g),
                ),
              SettingsTile(
                icon: Icons.add_rounded,
                iconColor: ZaplineColors.focus,
                title: l.addGuide,
                accent: true,
                chevron: false,
                onTap: _state.isSyncing ? () {} : _add,
              ),
            ],
          ),
          SettingsGroup(
            title: l.ifSomethingsOff,
            children: [
              SettingsTile(
                title: l.timesWrong,
                subtitle: l.timesWrongHint,
                onTap: _shiftWhich,
              ),
              SettingsTile(
                icon: Icons.sync_rounded,
                title: syncing ? l.refreshing : l.refreshGuideNow,
                subtitle: l.refreshGuideHint,
                chevron: false,
                onTap: _state.isSyncing ? () {} : _refresh,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      );
    },
  );
}

class _Coverage extends StatelessWidget {
  const _Coverage({
    required this.ratio,
    required this.title,
    required this.subtitle,
    required this.errors,
  });

  final double ratio;
  final String title;
  final String subtitle;
  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    final color = ratio >= 0.8
        ? ZaplineColors.ok
        : ratio >= 0.4
        ? ZaplineColors.focus
        : ZaplineColors.live;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZaplineColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 6,
                      color: color,
                      backgroundColor: ZaplineColors.line,
                    ),
                    Center(
                      child: Text(
                        '${(ratio * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
          for (final e in errors)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                context.l10n.guideFailedLine(e),
                style: const TextStyle(fontSize: 13, color: ZaplineColors.live),
              ),
            ),
        ],
      ),
    );
  }
}
