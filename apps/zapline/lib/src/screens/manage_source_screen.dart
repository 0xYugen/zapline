import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../format.dart';
import '../free_epg.dart';
import '../layout.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import '../widgets/free_epg_picker.dart';
import '../widgets/tv_text_field.dart';

/// Everything about one source: name, extra TV guides and their time
/// shift, which groups to show (filter + per-group choices + parental
/// locks) and hidden channels.
class ManageSourceScreen extends StatefulWidget {
  const ManageSourceScreen({
    super.key,
    required this.state,
    required this.sourceId,
  });

  final AppState state;
  final String sourceId;

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

  SourceRecord _current() =>
      widget.state.sources.firstWhere((s) => s.id == widget.sourceId);

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
    setState(() => _message = 'Refreshing…');
    try {
      await widget.state.refresh(_current());
      if (mounted) setState(() => _message = 'Refreshed.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Refresh failed: $e');
    }
  }

  void _addGuide() {
    final url = _guide.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      setState(() => _message = 'Enter a full link, starting with http.');
      return;
    }
    if (_source.extraGuideUrls.contains(url)) return;
    _guide.clear();
    _save(
      _source.copyWith(extraGuideUrls: [..._source.extraGuideUrls, url]),
      'Guide added. Refresh to load it.',
    );
  }

  Future<void> _addFreeEpg() async {
    final epg = await pickFreeEpg(
      context,
      first: widget.state.likelyFreeEpg(widget.sourceId),
    );
    if (epg == null || !mounted) return;
    setState(() => _message = 'Loading the free EPG for ${epg.name}…');
    try {
      final r = await widget.state.addFreeEpg(_current(), epg);
      if (!mounted) return;
      setState(() {
        _source = _current();
        _message =
            '${epg.name} EPG added: TV guide for ${r.coverage.matched} of '
            '${r.coverage.channels} channels.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Refresh failed: $e');
    }
  }

  void _shiftGuide(int minutes) => _save(
    _source.copyWith(
      guideOffset: _source.guideOffset + Duration(minutes: minutes),
    ),
    'Guide shift saved. Refresh to apply it.',
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
                  g.title.isEmpty ? 'Channels without a group' : g.title,
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
                      setState(
                        () => _message =
                            'Set a PIN in Settings before locking groups.',
                      );
                    } else {
                      state.setGroupLocked(_source, g.title, !g.locked);
                    }
                    done();
                  },
                  child: Text(
                    g.locked ? 'Unlock (no PIN needed)' : 'Lock with PIN',
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
                    child: const Text(
                      'Follow the filter again',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final groups = state.groupInfo(widget.sourceId);
        final hidden = state.hiddenChannels(widget.sourceId);
        final (shownGroups, allGroups, shownChannels) = state.previewFilter(
          widget.sourceId,
          _draftFilter,
        );
        final filterChanged = _draftFilter != _source.groupFilter;

        // One flat list so it stays lazy with thousands of groups.
        final phone = context.isPhone;
        final items = <Widget Function()>[
          if (!phone)
            () => Text(
              'Manage ${_source.name}',
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
          () => const PageSection('Name'),
          () => Row(
            children: [
              Expanded(
                child: TvTextField(
                  builder: (readOnly) => TextField(
                    readOnly: readOnly,
                    controller: _name,
                    autofocus: !context.isPhone,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FocusCard(
                onPressed: () => _save(
                  _source.copyWith(name: _name.text.trim()),
                  'Name saved.',
                ),
                child: const Text('Save'),
              ),
            ],
          ),
          () => const PageSection('TV guides (EPG)'),
          () => const Text(
            'The EPG from the source itself is loaded automatically. Add '
            'more EPG links (XMLTV) here; the first match per channel wins.',
            style: TextStyle(color: ZaplineColors.textMuted),
          ),
          () => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FocusCard(
                onPressed: state.isSyncing ? () {} : _addFreeEpg,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.public_rounded, size: 20),
                    SizedBox(width: 10),
                    Flexible(child: Text('Add a free EPG by country')),
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
                        'Free EPG · ${c.name} (${Uri.parse(url).host})',
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
                      'Guide removed.',
                    ),
                    child: const Text('Remove'),
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
                      decoration: const InputDecoration(
                        labelText: 'Add an EPG link (XMLTV, .xml or .xml.gz)',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FocusCard(onPressed: _addGuide, child: const Text('Add')),
              ],
            ),
          ),
          () => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: LabeledRow(
              label: 'Guide time shift',
              subtitle: 'For guides that show the wrong times.',
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
                  Text(state.isSyncing ? 'Refreshing…' : 'Refresh now'),
                ],
              ),
            ),
          ),
          () => const PageSection('Show these groups'),
          () => const Text(
            'Words separated by commas. IT matches "IT | Sport" but not '
            '"Hits"; ital* matches Italia and Italy; IT| matches that exact '
            'text. Hiding always wins.',
            style: TextStyle(color: ZaplineColors.textMuted),
          ),
          () => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FocusCard(
                  onPressed: () => _preset(['it', 'ita', 'ital*'], []),
                  child: const Text('Italian only'),
                ),
                FocusCard(
                  onPressed: () => _preset([], ['xxx', 'adult', '18+']),
                  child: const Text('Hide adult'),
                ),
                FocusCard(
                  onPressed: () => _preset([], ['vod', 'series', 'movies']),
                  child: const Text('Hide VOD and series'),
                ),
                FocusCard(
                  onPressed: () {
                    _include.clear();
                    _exclude.clear();
                  },
                  child: const Text('Clear'),
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
                decoration: const InputDecoration(
                  labelText: 'Show only groups with (empty = all)',
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Hide groups with',
                ),
              ),
            ),
          ),
          () => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Shows $shownGroups of $allGroups groups · '
                    '$shownChannels channels',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                FocusCard(
                  onPressed: () => _save(
                    _source.copyWith(groupFilter: _draftFilter),
                    'Filter applied.',
                  ),
                  child: Text(filterChanged ? 'Apply filter' : 'Applied'),
                ),
              ],
            ),
          ),
          () => const PageSection('Groups'),
          () => const Text(
            'OK shows or hides a group. Hold OK to lock it with the PIN or to '
            'make it follow the filter again.',
            style: TextStyle(color: ZaplineColors.textMuted),
          ),
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
                        g.title.isEmpty ? 'Channels without a group' : g.title,
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
                      '${g.channels} · '
                      '${g.hidden ? 'hidden' : 'shown'}'
                      '${g.explicit == null ? ' by filter' : ''}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          if (hidden.isNotEmpty) ...[
            () => const PageSection('Hidden channels'),
            for (final c in hidden)
              () => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FocusCard(
                  onPressed: () => state.setChannelHidden(c, false),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.name)),
                      const Text('Show again'),
                    ],
                  ),
                ),
              ),
          ],
          () => const SizedBox(height: 48),
        ];

        return Scaffold(
          appBar: phone ? AppBar(title: Text(_source.name)) : null,
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
