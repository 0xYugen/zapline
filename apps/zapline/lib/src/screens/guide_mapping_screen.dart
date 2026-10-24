import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../l10n.dart';
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
      appBar: phone ? AppBar(title: Text(context.l10n.fixTvGuide)) : null,
      body: Padding(
        padding: phone
            ? const EdgeInsets.fromLTRB(16, 4, 16, 0)
            : const EdgeInsets.fromLTRB(56, 40, 56, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!phone) ...[
              Text(
                context.l10n.fixTvGuide,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              _unmatched.isEmpty
                  ? (widget.only != null
                        ? context.l10n.fixDone
                        : context.l10n.fixAllMatched)
                  : context.l10n.fixUnmatched(_unmatched.length),
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
              ? Center(
                  child: Text(
                    context.l10n.pickChannelAbove,
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
          q.isEmpty
              ? context.l10n.suggestionsFor(c.name)
              : context.l10n.guideChannels,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TvTextField(
          builder: (readOnly) => TextField(
            readOnly: readOnly,
            controller: _query,
            focusNode: _search,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: context.l10n.searchTheGuide,
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (options.isEmpty)
          Text(
            context.l10n.nothingFoundTryAnother,
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
