import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../format.dart';
import '../free_epg.dart';
import '../l10n.dart';
import '../layout.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import '../widgets/free_epg_picker.dart';
import '../widgets/tv_text_field.dart';

/// The parts of a source the user can change, each a page of its own from
/// the source's details.
enum SourceSection { guide, groups, hidden, name }

/// One source's settings: its TV guides and their time shift, which groups
/// to show (filter, per-group choices, parental locks), hidden channels and
/// its name. [section] shows one part; `null` shows them all.
class ManageSourceScreen extends StatefulWidget {
  const ManageSourceScreen({
    super.key,
    required this.state,
    required this.sourceId,
    this.section,
  });

  final AppState state;
  final String sourceId;
  final SourceSection? section;

  @override
  State<ManageSourceScreen> createState() => _ManageSourceScreenState();
}

class _ManageSourceScreenState extends State<ManageSourceScreen> {
  late SourceRecord _source = _current();
  late final _name = TextEditingController(text: _source.name);
  final _guide = TextEditingController();
  late final _include = TextEditingController(
    text: _source.groupFilter.include.join(', '),
  );
  late final _exclude = TextEditingController(
    text: _source.groupFilter.exclude.join(', '),
  );
  String? _message;

  /// Which filter the fields edit: channels, films or series.
  _FilterKind _kind = _FilterKind.tv;

  GroupFilter _filterOf(_FilterKind k) => switch (k) {
    _FilterKind.tv => _source.groupFilter,
    _FilterKind.movies => _source.movieFilter,
    _FilterKind.shows => _source.showFilter,
  };

  void _editKind(_FilterKind k) {
    final f = _filterOf(k);
    setState(() => _kind = k);
    _include.text = f.include.join(', ');
    _exclude.text = f.exclude.join(', ');
  }

  SourceRecord _withFilter(SourceRecord s, _FilterKind k, GroupFilter f) =>
      switch (k) {
        _FilterKind.tv => s.copyWith(groupFilter: f),
        _FilterKind.movies => s.copyWith(movieFilter: f),
        _FilterKind.shows => s.copyWith(showFilter: f),
      };

  SourceRecord _current() =>
      widget.state.sources.firstWhere((s) => s.id == widget.sourceId);

  bool _shows(SourceSection s) => widget.section == null || widget.section == s;

  @override
  void initState() {
    super.initState();
    _include.addListener(_rebuild);
    _exclude.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _guide.dispose();
    _include.dispose();
    _exclude.dispose();
    super.dispose();
  }

  GroupFilter get _draftFilter => GroupFilter(
    include: GroupFilter.parseTerms(_include.text),
    exclude: GroupFilter.parseTerms(_exclude.text),
  );

  void _save(SourceRecord updated, String message) {
    widget.state.updateSource(updated);
    setState(() {
      _source = _current();
      _message = message;
    });
  }

  Future<void> _refresh() async {
    final l = context.l10n;
    setState(() => _message = l.refreshing);
    try {
      await widget.state.refresh(_current());
      if (mounted) setState(() => _message = l.refreshed);
    } catch (e) {
      if (mounted) setState(() => _message = l.refreshFailed('$e'));
    }
  }

  void _addGuide() {
    final l = context.l10n;
    final url = _guide.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      setState(() => _message = l.enterFullLink);
      return;
    }
    if (_source.extraGuideUrls.contains(url)) return;
    _guide.clear();
    _save(
      _source.copyWith(extraGuideUrls: [..._source.extraGuideUrls, url]),
      l.guideAdded,
    );
  }

  Future<void> _addFreeEpg() async {
    final l = context.l10n;
    final epg = await pickFreeEpg(
      context,
      first: widget.state.likelyFreeEpg(widget.sourceId),
    );
    if (epg == null || !mounted) return;
    setState(() => _message = l.loadingFreeEpg(epg.name));
    try {
      final r = await widget.state.addFreeEpg(_current(), epg);
      if (!mounted) return;
      setState(() {
        _source = _current();
        _message = l.freeEpgAdded(
          epg.name,
          r.coverage.matched,
          r.coverage.channels,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _message = l.refreshFailed('$e'));
    }
  }

  void _shiftGuide(int minutes) => _save(
    _source.copyWith(
      guideOffset: _source.guideOffset + Duration(minutes: minutes),
    ),
    context.l10n.shiftSaved,
  );

  void _preset(List<String> include, List<String> exclude) {
    if (include.isNotEmpty) _include.text = include.join(', ');
    if (exclude.isNotEmpty) {
      final current = GroupFilter.parseTerms(_exclude.text);
      _exclude.text = {...current, ...exclude}.join(', ');
    }
  }

  Future<void> _groupMenu(GroupInfo g) => showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) {
      final l = context.l10n;
      void done() => Navigator.of(dialogContext).pop();
      final state = widget.state;
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
                Text(
                  g.title.isEmpty ? l.noGroupChannels : g.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                FocusCard(
                  autofocus: true,
                  onPressed: () {
                    if (!state.hasPin && !g.locked) {
                      setState(() => _message = l.setPinFirst);
                    } else {
                      state.setGroupLocked(_source, g.title, !g.locked);
                    }
                    done();
                  },
                  child: Text(
                    g.locked ? l.unlockGroup : l.lockWithPin,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (g.explicit != null) ...[
                  const SizedBox(height: 8),
                  FocusCard(
                    onPressed: () {
                      state.setGroupHidden(_source, g.title, null);
                      done();
                    },
                    child: Text(
                      l.followFilterAgain,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );

  String _title(AppLocalizations l) => switch (widget.section) {
    null => _source.name,
    SourceSection.guide => l.sectionGuide,
    SourceSection.groups => l.sectionGroups,
    SourceSection.hidden => l.sectionHidden,
    SourceSection.name => l.sectionName,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final l = context.l10n;
        final state = widget.state;
        final groups = _shows(SourceSection.groups)
            ? state.groupInfo(widget.sourceId)
            : const <GroupInfo>[];
        final hidden = _shows(SourceSection.hidden)
            ? state.hiddenChannels(widget.sourceId)
            : const <Channel>[];
        final hasMovies = state.db.movieCount(sourceId: widget.sourceId) > 0;
        final hasShows = state.db.showCount(sourceId: widget.sourceId) > 0;
        final kinds = [
          _FilterKind.tv,
          if (hasMovies) _FilterKind.movies,
          if (hasShows) _FilterKind.shows,
        ];
        if (!kinds.contains(_kind)) _kind = _FilterKind.tv;
        final preview = switch (_kind) {
          _FilterKind.tv => () {
            final (g, all, c) = state.previewFilter(
              widget.sourceId,
              _draftFilter,
            );
            return l.filterPreview(g, all, c);
          }(),
          final k => () {
            final (g, all, t) = state.previewVodFilter(
              widget.sourceId,
              _draftFilter,
              movies: k == _FilterKind.movies,
            );
            return l.filterPreviewVod(g, all, t);
          }(),
        };
        final filterChanged = _draftFilter != _filterOf(_kind);
        final sameEverywhere = kinds.every((k) => _filterOf(k) == _draftFilter);
        final all = widget.section == null;

        // One flat list so it stays lazy with thousands of groups.
        final phone = context.isPhone;
        final items = <Widget Function()>[
          if (!phone)
            () => Text(
              _title(l),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
          if (_message != null)
            () => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message!,
                style: const TextStyle(color: ZaplineColors.ok),
              ),
            ),
          if (_shows(SourceSection.name)) ...[
            if (all) () => PageSection(l.sectionName),
            () => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TvTextField(
                      builder: (readOnly) => TextField(
                        readOnly: readOnly,
                        controller: _name,
                        autofocus: !context.isPhone,
                        decoration: InputDecoration(labelText: l.name),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FocusCard(
                    onPressed: () => _save(
                      _source.copyWith(name: _name.text.trim()),
                      l.nameSaved,
                    ),
                    child: Text(l.save),
                  ),
                ],
              ),
            ),
            if (_source.kind == SourceKind.xtream)
              () => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Hint(
                  '${l.server}: ${Uri.tryParse(_source.url)?.host ?? _source.url}'
                  '\n${l.username}: ${_source.username}',
                ),
              ),
          ],
          if (_shows(SourceSection.guide)) ...[
            if (all) () => PageSection(l.tvGuidesEpg),
            () => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Hint(l.epgIntro),
            ),
            () => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FocusCard(
                  onPressed: state.isSyncing ? () {} : _addFreeEpg,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.public_rounded, size: 20),
                      const SizedBox(width: 10),
                      Flexible(child: Text(l.addFreeEpgByCountry)),
                    ],
                  ),
                ),
              ),
            ),
            for (final url in _source.extraGuideUrls)
              () => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: switch (FreeEpg.ofUrl(url)) {
                        final c? => Text(
                          l.freeEpgEntry(c.name, Uri.parse(url).host),
                          overflow: TextOverflow.ellipsis,
                        ),
                        null => Text(url, overflow: TextOverflow.ellipsis),
                      },
                    ),
                    FocusCard(
                      onPressed: () => _save(
                        _source.copyWith(
                          extraGuideUrls: [
                            for (final u in _source.extraGuideUrls)
                              if (u != url) u,
                          ],
                        ),
                        l.guideRemoved,
                      ),
                      child: Text(l.remove),
                    ),
                  ],
                ),
              ),
            () => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TvTextField(
                      builder: (readOnly) => TextField(
                        readOnly: readOnly,
                        controller: _guide,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        onSubmitted: (_) => _addGuide(),
                        decoration: InputDecoration(labelText: l.addEpgLink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FocusCard(onPressed: _addGuide, child: Text(l.add)),
                ],
              ),
            ),
            () => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: LabeledRow(
                label: l.guideTimeShift,
                subtitle: l.guideTimeShiftHint,
                children: [
                  FocusCard(
                    onPressed: () => _shiftGuide(-30),
                    child: const Text('−30 min'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      formatShift(_source.guideOffset),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FocusCard(
                    onPressed: () => _shiftGuide(30),
                    child: const Text('+30 min'),
                  ),
                ],
              ),
            ),
            () => Align(
              alignment: Alignment.centerLeft,
              child: FocusCard(
                onPressed: state.isSyncing ? () {} : _refresh,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(state.isSyncing ? l.refreshing : l.refreshNow),
                  ],
                ),
              ),
            ),
          ],
          if (_shows(SourceSection.groups)) ...[
            if (all) () => PageSection(l.showTheseGroups),
            if (kinds.length > 1)
              () => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final k in kinds)
                      FocusCard(
                        selected: k == _kind,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        onPressed: () => _editKind(k),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(switch (k) {
                              _FilterKind.tv => Icons.live_tv_rounded,
                              _FilterKind.movies => Icons.movie_rounded,
                              _FilterKind.shows => Icons.video_library_rounded,
                            }, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              switch (k) {
                                _FilterKind.tv => l.tv,
                                _FilterKind.movies => l.movies,
                                _FilterKind.shows => l.series,
                              },
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (!_filterOf(k).isEmpty) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.filter_alt_rounded, size: 15),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            () => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Hint(l.filterHelp),
            ),
            () => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FocusCard(
                    onPressed: () => _preset(['it', 'ita', 'ital*'], []),
                    child: Text(l.presetItalian),
                  ),
                  FocusCard(
                    onPressed: () => _preset([], ['xxx', 'adult', '18+']),
                    child: Text(l.presetAdult),
                  ),
                  if (_kind == _FilterKind.tv)
                    FocusCard(
                      onPressed: () => _preset([], ['vod', 'series', 'movies']),
                      child: Text(l.presetVod),
                    ),
                  FocusCard(
                    onPressed: () {
                      _include.clear();
                      _exclude.clear();
                    },
                    child: Text(l.clear),
                  ),
                ],
              ),
            ),
            () => Padding(
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
            () => Padding(
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
            () => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      preview,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FocusCard(
                    onPressed: () => _save(
                      _withFilter(_source, _kind, _draftFilter),
                      l.filterApplied,
                    ),
                    child: Text(filterChanged ? l.applyFilter : l.applied),
                  ),
                ],
              ),
            ),
            if (kinds.length > 1 && !sameEverywhere)
              () => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FocusCard(
                    onPressed: () {
                      var updated = _source;
                      for (final k in kinds) {
                        updated = _withFilter(updated, k, _draftFilter);
                      }
                      _save(updated, l.filterAppliedEverywhere);
                    },
                    child: Text(l.applyFilterEverywhere),
                  ),
                ),
              ),
            if (_kind == _FilterKind.tv) ...[
              () => PageSection(l.groups),
              () => Hint(l.groupsHelp),
              for (final g in groups)
                () => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FocusCard(
                    key: ValueKey('group-${g.title}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    onPressed: () =>
                        state.setGroupHidden(_source, g.title, !g.hidden),
                    onLongPress: () => _groupMenu(g),
                    child: Row(
                      children: [
                        Icon(
                          g.hidden
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            g.title.isEmpty ? l.noGroupChannels : g.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (g.locked)
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Icon(Icons.lock_outline_rounded, size: 18),
                          ),
                        Text(
                          l.groupState(
                            g.channels,
                            g.hidden ? 'hidden' : 'shown',
                            g.explicit == null ? 'filter' : 'user',
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
          if (_shows(SourceSection.hidden)) ...[
            if (all && hidden.isNotEmpty) () => PageSection(l.sectionHidden),
            if (!all && hidden.isEmpty)
              () => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Hint(l.noHiddenChannels),
              ),
            for (final c in hidden)
              () => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FocusCard(
                  onPressed: () => state.setChannelHidden(c, false),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.name)),
                      Text(l.showAgain),
                    ],
                  ),
                ),
              ),
          ],
          () => const SizedBox(height: 48),
        ];

        return Scaffold(
          appBar: phone ? AppBar(title: Text(_title(l))) : null,
          body: ListView.builder(
            padding: Metrics.of(context).pagePadding,
            itemCount: items.length,
            itemBuilder: (context, i) => items[i](),
          ),
        );
      },
    );
  }
}

enum _FilterKind { tv, movies, shows }
