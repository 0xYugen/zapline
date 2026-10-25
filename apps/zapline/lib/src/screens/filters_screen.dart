import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../countries.dart';
import '../l10n.dart';
import '../layout.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/tv_text_field.dart';

/// What a source shows, in plain choices: Italian only, everything, or
/// countries and groups picked by hand; adult content off with one switch;
/// keywords for the few who want them. Changes apply at once, with Undo.
class FiltersScreen extends StatefulWidget {
  const FiltersScreen({super.key, required this.state, required this.sourceId});

  final AppState state;
  final String sourceId;

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

/// Terms of "Italian only" and "Hide adult content".
const italianTerms = ['it', 'ita', 'ital*'];
const adultTerms = ['xxx', 'adult*', '18+', 'porn*'];

enum _Mode { italian, all, custom }

class _FiltersScreenState extends State<FiltersScreen> {
  ContentKind _kind = ContentKind.tv;
  final _undo = UndoBar();

  AppState get _state => widget.state;
  SourceRecord get _source =>
      _state.sources.firstWhere((s) => s.id == widget.sourceId);

  @override
  void dispose() {
    _undo.dispose();
    super.dispose();
  }

  static bool _same(List<String> a, List<String> b) =>
      a.map((e) => e.toLowerCase()).toSet().containsAll(b) &&
      b.length == a.length;

  _Mode _modeOf(GroupFilter f, List<CategoryInfo> all) {
    if (_same(f.include, italianTerms)) return _Mode.italian;
    if (f.include.isNotEmpty || all.any((c) => c.explicit != null)) {
      return _Mode.custom;
    }
    return _Mode.all;
  }

  bool _adultHidden(GroupFilter f) => adultTerms.every(
    (t) => f.exclude.map((e) => e.toLowerCase()).contains(t),
  );

  /// What [filter] alone would show: (categories, items).
  (int, int) _tally(List<CategoryInfo> all, GroupFilter filter) {
    var groups = 0, items = 0;
    for (final c in all) {
      if (filter.hides(c.title.isEmpty ? null : c.title)) continue;
      groups++;
      items += c.count;
    }
    return (groups, items);
  }

  void _change(String message, VoidCallback apply) {
    HapticFeedback.selectionClick();
    final before = _state.snapshot(widget.sourceId, _kind);
    apply();
    _undo.show(message, () => _state.restore(before));
  }

  void _setMode(_Mode mode, GroupFilter current, List<CategoryInfo> all) {
    final l = context.l10n;
    final exclude = current.exclude;
    switch (mode) {
      case _Mode.italian:
        _change(l.filterSaved, () {
          _state.setFilter(
            _source,
            _kind,
            GroupFilter(include: italianTerms, exclude: exclude),
            resetChoices: true,
          );
        });
      case _Mode.all:
        _change(l.filterSaved, () {
          _state.setFilter(
            _source,
            _kind,
            GroupFilter(exclude: exclude),
            resetChoices: true,
          );
        });
      case _Mode.custom:
        // Starts from what shows now, each group then switched by hand.
        _change(l.filterSaved, () {
          final hidden = [
            for (final c in all)
              if (c.hidden) c.title,
          ];
          final shown = [
            for (final c in all)
              if (!c.hidden) c.title,
          ];
          _state.setFilter(_source, _kind, GroupFilter(exclude: exclude));
          _state.setCategoriesHidden(widget.sourceId, _kind, hidden, true);
          _state.setCategoriesHidden(widget.sourceId, _kind, shown, false);
        });
    }
  }

  void _setAdult(GroupFilter f, bool hide) {
    final exclude = [
      for (final t in f.exclude)
        if (!adultTerms.contains(t.toLowerCase())) t,
      if (hide) ...adultTerms,
    ];
    _change(
      context.l10n.filterSaved,
      () => _state.setFilter(
        _source,
        _kind,
        GroupFilter(include: f.include, exclude: exclude),
      ),
    );
  }

  String _tallyText(AppLocalizations l, int groups, int items) =>
      switch (_kind) {
        ContentKind.tv => l.tallyTv(groups, items),
        ContentKind.movies => l.tallyMovies(groups, items),
        ContentKind.shows => l.tallyShows(groups, items),
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _state,
    builder: (context, _) {
      final l = context.l10n;
      final s = _source;
      final kinds = [
        ContentKind.tv,
        if (_state.db.movieCount(sourceId: s.id) > 0) ContentKind.movies,
        if (_state.db.showCount(sourceId: s.id) > 0) ContentKind.shows,
      ];
      if (!kinds.contains(_kind)) _kind = ContentKind.tv;
      final all = _state.categoriesOf(s.id, _kind);
      final filter = _state.filterOf(s, _kind);
      final mode = _modeOf(filter, all);
      final adult = _adultHidden(filter);
      final shown = all.where((c) => !c.hidden).toList();
      final (itGroups, itItems) = _tally(
        all,
        GroupFilter(include: italianTerms, exclude: filter.exclude),
      );
      final (allGroups, allItems) = _tally(
        all,
        GroupFilter(exclude: filter.exclude),
      );
      final adultCount = all
          .where(
            (c) =>
                GroupFilter(exclude: adultTerms).hides(c.title) &&
                c.title.isNotEmpty,
          )
          .length;

      // Groups by country, the most watched first.
      final byCountry = <String?, List<CategoryInfo>>{};
      for (final c in all) {
        (byCountry[groupCountry(c.title)] ??= []).add(c);
      }
      final countries = byCountry.keys.whereType<String>().toList()
        ..sort((a, b) {
          int visible(String k) => byCountry[k]!.where((c) => !c.hidden).length;
          final v = visible(b).compareTo(visible(a));
          return v != 0
              ? v
              : byCountry[b]!.length.compareTo(byCountry[a]!.length);
        });
      final lang = Localizations.localeOf(context).languageCode;
      final hiddenChannels = _kind == ContentKind.tv
          ? _state.hiddenChannels(s.id)
          : const <Channel>[];

      Widget modeTile(_Mode m, String title, String subtitle) => SettingsTile(
        leading: Icon(
          m == mode
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_off_rounded,
          color: m == mode ? ZaplineColors.focus : ZaplineColors.textMuted,
        ),
        title: title,
        subtitle: subtitle,
        chevron: false,
        accent: m == mode,
        onTap: () => m == mode ? null : _setMode(m, filter, all),
      );

      final children = <Widget>[
        if (kinds.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: KindTabs(
              kinds: kinds,
              selected: _kind,
              onSelected: (k) => setState(() => _kind = k),
            ),
          ),
        SettingsGroup(
          title: l.whatToSee,
          children: [
            modeTile(_Mode.italian, switch (_kind) {
              ContentKind.tv => l.italianOnlyTv,
              ContentKind.movies => l.italianOnlyMovies,
              ContentKind.shows => l.italianOnlyShows,
            }, _tallyText(l, itGroups, itItems)),
            modeTile(
              _Mode.all,
              l.everything,
              _tallyText(l, allGroups, allItems),
            ),
            modeTile(
              _Mode.custom,
              l.pickByHand,
              filter.include.isNotEmpty && mode == _Mode.custom
                  ? l.keywordFilterOn
                  : l.pickByHandHint,
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsSwitchTile(
              title: l.hideAdult,
              subtitle: adult && adultCount > 0
                  ? l.hiddenNumber(adultCount)
                  : null,
              value: adult,
              onChanged: (v) => _setAdult(filter, v),
            ),
          ],
        ),
        SettingsGroup(
          title: l.byCountry,
          children: [
            for (final code in [
              ...countries,
              if (byCountry[null] != null) null,
            ])
              _CountryTile(
                name: code == null ? l.otherGroups : countryName(code, lang),
                code: code,
                groups: byCountry[code]!,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FilterCountryScreen(
                      state: _state,
                      sourceId: s.id,
                      kind: _kind,
                      country: code,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (hiddenChannels.isNotEmpty)
          SettingsGroup(
            title: l.sectionHidden,
            children: [
              for (final c in hiddenChannels)
                SettingsTile(
                  title: c.name,
                  value: l.showAgain,
                  chevron: false,
                  onTap: () => _state.setChannelHidden(c, false),
                ),
            ],
          ),
        _Keywords(
          key: ValueKey((_kind, filter)),
          state: _state,
          source: s,
          kind: _kind,
          filter: filter,
          onApply: (f) =>
              _change(l.filterSaved, () => _state.setFilter(_source, _kind, f)),
        ),
        const SizedBox(height: 24),
      ];

      return FilterPage(
        title: l.sectionGroups,
        summary: switch (_kind) {
          ContentKind.tv => l.youWillSeeTv(
            shown.length,
            shown.fold(0, (n, c) => n + c.count),
          ),
          ContentKind.movies => l.youWillSeeMovies(
            shown.length,
            shown.fold(0, (n, c) => n + c.count),
          ),
          ContentKind.shows => l.youWillSeeShows(
            shown.length,
            shown.fold(0, (n, c) => n + c.count),
          ),
        },
        undo: _undo,
        children: children,
      );
    },
  );
}

/// TV · Movies · Series, as a segmented strip.
class KindTabs extends StatelessWidget {
  const KindTabs({
    super.key,
    required this.kinds,
    required this.selected,
    required this.onSelected,
  });

  final List<ContentKind> kinds;
  final ContentKind selected;
  final ValueChanged<ContentKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ZaplineColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final k in kinds)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FocusCard(
                  selected: k == selected,
                  radius: 10,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onSelected(k);
                  },
                  child: Center(
                    child: Builder(
                      builder: (context) => Text(
                        switch (k) {
                          ContentKind.tv => l.tv,
                          ContentKind.movies => l.movies,
                          ContentKind.shows => l.series,
                        },
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          // Amber when chosen, unless the card itself is lit.
                          color:
                              k == selected &&
                                  (DefaultTextStyle.of(context).style.color
                                              ?.computeLuminance() ??
                                          1) >
                                      0.2
                              ? ZaplineColors.focus
                              : null,
                          decoration: k == selected
                              ? TextDecoration.underline
                              : null,
                          decorationColor: ZaplineColors.focus,
                          decorationThickness: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.name,
    required this.code,
    required this.groups,
    required this.onTap,
  });

  final String name;
  final String? code;
  final List<CategoryInfo> groups;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final visible = groups.where((c) => !c.hidden).length;
    return SettingsTile(
      leading: Container(
        width: 38,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ZaplineColors.surfaceHigh,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          code?.toUpperCase() ?? '…',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
      title: name,
      subtitle: visible == 0
          ? l.allHidden(groups.length)
          : l.shownOf(visible, groups.length),
      onTap: onTap,
    );
  }
}

/// Keyword include/exclude, folded away under "Advanced".
class _Keywords extends StatefulWidget {
  const _Keywords({
    super.key,
    required this.state,
    required this.source,
    required this.kind,
    required this.filter,
    required this.onApply,
  });

  final AppState state;
  final SourceRecord source;
  final ContentKind kind;
  final GroupFilter filter;
  final ValueChanged<GroupFilter> onApply;

  @override
  State<_Keywords> createState() => _KeywordsState();
}

class _KeywordsState extends State<_Keywords> {
  late final _include = TextEditingController(
    text: widget.filter.include.join(', '),
  );
  late final _exclude = TextEditingController(
    text: widget.filter.exclude.join(', '),
  );
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _include.addListener(() => setState(() {}));
    _exclude.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _include.dispose();
    _exclude.dispose();
    super.dispose();
  }

  GroupFilter get _draft => GroupFilter(
    include: GroupFilter.parseTerms(_include.text),
    exclude: GroupFilter.parseTerms(_exclude.text),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final draft = _draft;
    final changed = draft != widget.filter;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsTile(
            icon: _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            title: l.advancedKeywords,
            chevron: false,
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Hint(l.filterHelp),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TvTextField(
                builder: (readOnly) => TextField(
                  readOnly: readOnly,
                  controller: _include,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: l.showOnlyGroupsWith),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TvTextField(
                builder: (readOnly) => TextField(
                  readOnly: readOnly,
                  controller: _exclude,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: l.hideGroupsWith),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: FocusCard(
                  onPressed: changed ? () => widget.onApply(draft) : () {},
                  child: Text(changed ? l.applyFilter : l.applied),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One country's groups (or the groups without a country): search, all on
/// or off, and each with its switch and PIN lock.
class FilterCountryScreen extends StatefulWidget {
  const FilterCountryScreen({
    super.key,
    required this.state,
    required this.sourceId,
    required this.kind,
    required this.country,
  });

  final AppState state;
  final String sourceId;
  final ContentKind kind;

  /// A key of [countryNames]; `null` for groups without a country.
  final String? country;

  @override
  State<FilterCountryScreen> createState() => _FilterCountryScreenState();
}

class _FilterCountryScreenState extends State<FilterCountryScreen> {
  final _query = TextEditingController();
  final _undo = UndoBar();

  AppState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _undo.dispose();
    super.dispose();
  }

  void _set(Iterable<String> titles, bool hide, String message) {
    HapticFeedback.selectionClick();
    final before = _state.snapshot(widget.sourceId, widget.kind);
    _state.setCategoriesHidden(widget.sourceId, widget.kind, titles, hide);
    _undo.show(message, () => _state.restore(before));
  }

  void _toggleLock(CategoryInfo c) {
    final l = context.l10n;
    if (!_state.hasPin && !c.locked) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.setPinFirst)));
      return;
    }
    final s = _state.sources.firstWhere((s) => s.id == widget.sourceId);
    _state.setGroupLocked(s, c.title, !c.locked);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _state,
    builder: (context, _) {
      final l = context.l10n;
      final lang = Localizations.localeOf(context).languageCode;
      final all = [
        for (final c in _state.categoriesOf(widget.sourceId, widget.kind))
          if (groupCountry(c.title) == widget.country) c,
      ];
      final q = _query.text.trim().toLowerCase();
      final list = q.isEmpty
          ? all
          : all.where((c) => c.title.toLowerCase().contains(q)).toList();
      final visible = all.where((c) => !c.hidden).toList();
      final allOn = visible.length == all.length;
      final name = widget.country == null
          ? l.otherGroups
          : countryName(widget.country!, lang);
      final tv = widget.kind == ContentKind.tv;
      String label(CategoryInfo c) => c.title.isEmpty ? l.noGroup : c.title;

      return FilterPage(
        title: name,
        summary: tv
            ? l.youWillSeeTv(
                visible.length,
                visible.fold(0, (n, c) => n + c.count),
              )
            : l.shownOf(visible.length, all.length),
        undo: _undo,
        children: [
          if (all.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: TvTextField(
                builder: (readOnly) => TextField(
                  readOnly: readOnly,
                  controller: _query,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l.findGroup,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                title: l.allGroupsOf(name),
                subtitle: l.shownOf(visible.length, all.length),
                value: allOn,
                onChanged: (on) => _set(
                  [for (final c in all) c.title],
                  !on,
                  on ? l.allShown : l.allHiddenDone,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Hint(tv ? l.groupSwitchHint : l.categorySwitchHint),
          ),
          SettingsGroup(
            children: [
              for (final c in list)
                _GroupRow(
                  key: ValueKey(c.title),
                  title: label(c),
                  subtitle: [
                    tv ? l.channelCount(c.count) : l.titleCount(c.count),
                    if (c.locked) l.asksForPin,
                  ].join(' · '),
                  locked: c.locked,
                  canLock: tv,
                  value: !c.hidden,
                  onChanged: (on) => _set(
                    [c.title],
                    !on,
                    on ? l.groupShownMsg(label(c)) : l.groupHiddenMsg(label(c)),
                  ),
                  onLock: () => _toggleLock(c),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      );
    },
  );
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.locked,
    required this.canLock,
    required this.value,
    required this.onChanged,
    required this.onLock,
  });

  final String title;
  final String subtitle;
  final bool locked;
  final bool canLock;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FocusCard(
      padding: const EdgeInsets.fromLTRB(18, 6, 10, 6),
      onPressed: () => onChanged(!value),
      // Remotes reach the lock by holding OK.
      onLongPress: canLock ? onLock : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: locked
                        ? ZaplineColors.focus
                        : DefaultTextStyle.of(context).style.color
                              ?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (canLock)
            IconButton(
              tooltip: locked ? l.unlockGroup : l.lockWithPin,
              onPressed: onLock,
              icon: Icon(
                locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 20,
                color: locked ? ZaplineColors.focus : ZaplineColors.textMuted,
              ),
            ),
          ExcludeFocus(
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// The message of the last change and its Undo, shown at the bottom.
class UndoBar extends ChangeNotifier {
  String? message;
  VoidCallback? _undo;

  bool get canUndo => _undo != null;

  void show(String text, VoidCallback undo) {
    message = text;
    _undo = undo;
    notifyListeners();
  }

  void undo() {
    final u = _undo;
    _undo = null;
    message = null;
    notifyListeners();
    u?.call();
  }
}

/// A filters page: the list, and a bar at the bottom with what will show
/// and Undo for the last change.
class FilterPage extends StatelessWidget {
  const FilterPage({
    super.key,
    required this.title,
    required this.summary,
    required this.undo,
    required this.children,
  });

  final String title;
  final String summary;
  final UndoBar undo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final phone = context.isPhone;
    final l = context.l10n;
    return Scaffold(
      appBar: phone ? AppBar(title: Text(title)) : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: m.pagePadding,
              children: [
                if (!phone)
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: m.title,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ...children,
              ],
            ),
          ),
          ListenableBuilder(
            listenable: undo,
            builder: (context, _) => Container(
              padding: EdgeInsets.fromLTRB(
                m.pagePadding.left,
                10,
                m.pagePadding.right - 8,
                10,
              ),
              decoration: const BoxDecoration(
                color: ZaplineColors.rail,
                border: Border(top: BorderSide(color: ZaplineColors.line)),
              ),
              child: Row(
                children: [
                  Icon(
                    undo.canUndo
                        ? Icons.check_circle_rounded
                        : Icons.visibility_outlined,
                    size: 20,
                    color: undo.canUndo
                        ? ZaplineColors.ok
                        : ZaplineColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (undo.message case final msg?)
                          Text(
                            msg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: undo.message == null ? 14 : 12.5,
                            fontWeight: undo.message == null
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: undo.message == null
                                ? ZaplineColors.text
                                : ZaplineColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (undo.canUndo)
                    TextButton(
                      onPressed: undo.undo,
                      style: TextButton.styleFrom(
                        foregroundColor: ZaplineColors.focus,
                        textStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(l.undo),
                    )
                  else
                    const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
