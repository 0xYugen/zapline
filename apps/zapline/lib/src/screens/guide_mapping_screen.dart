import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../layout.dart';
import '../theme.dart';
import '../widgets/channel_logo.dart';
import '../widgets/focus_card.dart';
import '../widgets/tv_text_field.dart';

/// Lets the user link channels the automatic matcher left without a guide.
///
/// Left: channels without a guide. Right: ranked suggestions for the
/// selected channel plus a search over every guide channel. A choice is
/// stored as an override and survives re-syncs.
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

class _GuideMappingScreenState extends State<GuideMappingScreen> {
  late List<Channel> _unmatched = _load();

  List<Channel> _load() => widget.only != null
      ? [widget.only!]
      : widget.state.unmatchedChannels(widget.sourceId);
  Channel? _selected;
  final _query = TextEditingController();
  final _firstOption = FocusNode();
  final _search = FocusNode();
  String? _message;

  @override
  void initState() {
    super.initState();
    _selected = _unmatched.firstOrNull;
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _firstOption.dispose();
    _search.dispose();
    super.dispose();
  }

  void _assign(XmltvChannel g) {
    final c = _selected;
    if (c == null) return;
    widget.state.assignGuide(c, g.id);
    setState(() {
      _message = '${c.name} now uses the guide of ${g.displayName}.';
      _unmatched = widget.only != null
          ? const []
          : widget.state.unmatchedChannels(widget.sourceId);
      _selected = _unmatched.firstOrNull;
      _query.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final phone = context.isPhone;
    return Scaffold(
      appBar: phone ? AppBar(title: const Text('Fix TV guide')) : null,
      body: Padding(
        padding: phone
            ? const EdgeInsets.fromLTRB(16, 4, 16, 0)
            : const EdgeInsets.fromLTRB(56, 40, 56, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!phone) ...[
              const Text(
                'Fix TV guide',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              _unmatched.isEmpty
                  ? (widget.only != null
                        ? 'Done. Press Back to return.'
                        : 'Every channel of this source has a guide.')
                  : '${_unmatched.length} '
                        '${_unmatched.length == 1 ? 'channel has' : 'channels have'}'
                        ' no guide. Pick one, then choose the matching guide '
                        'channel.',
              style: const TextStyle(color: ZaplineColors.textMuted),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _message!,
                  style: const TextStyle(color: ZaplineColors.ok),
                ),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: phone
                  ? _phoneBody(selected)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 360,
                          child: FocusTraversalGroup(
                            child: ListView.builder(
                              itemCount: _unmatched.length,
                              itemBuilder: (context, i) {
                                final c = _unmatched[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: FocusCard(
                                    autofocus: i == 0,
                                    selected: identical(c, selected),
                                    onFocused: () => setState(() {
                                      _selected = c;
                                      _query.clear();
                                    }),
                                    // Straight to the best suggestion; the search
                                    // field (and the TV keyboard) only if none.
                                    onPressed: () =>
                                        (_firstOption.context != null
                                                ? _firstOption
                                                : _search)
                                            .requestFocus(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        ChannelLogo(
                                          channel: c,
                                          width: 44,
                                          height: 32,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            c.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: selected == null
                              ? const SizedBox.shrink()
                              : FocusTraversalGroup(
                                  child: _candidates(selected),
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

  /// Phones: the channel to fix is picked from a dropdown-like row above
  /// its suggestions, since two columns don't fit.
  Widget _phoneBody(Channel? selected) {
    if (_unmatched.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _unmatched.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = _unmatched[i];
              final on = identical(c, selected);
              return ChoiceChip(
                label: Text(c.name),
                selected: on,
                showCheckmark: false,
                selectedColor: ZaplineColors.focus,
                labelStyle: TextStyle(
                  color: on ? ZaplineColors.onFocus : ZaplineColors.text,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) => setState(() {
                  _selected = c;
                  _query.clear();
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: selected == null
              ? const Center(
                  child: Text(
                    'Pick a channel above.',
                    style: TextStyle(color: ZaplineColors.textMuted),
                  ),
                )
              : _candidates(selected),
        ),
      ],
    );
  }

  Widget _candidates(Channel c) {
    final q = _query.text.trim();
    final options = q.isEmpty
        ? [for (final (g, _) in widget.state.guideSuggestions(c)) g]
        : widget.state.searchGuide(q);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          q.isEmpty ? 'Suggestions for ${c.name}' : 'Guide channels',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TvTextField(
          builder: (readOnly) => TextField(
            readOnly: readOnly,
            controller: _query,
            focusNode: _search,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Search the guide',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (options.isEmpty)
          const Text(
            'Nothing found. Try another name.',
            style: TextStyle(color: ZaplineColors.textMuted),
          ),
        Expanded(
          child: ListView(
            children: [
              for (final (i, g) in options.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: FocusCard(
                    focusNode: i == 0 ? _firstOption : null,
                    onPressed: () => _assign(g),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            g.displayName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(g.id, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
