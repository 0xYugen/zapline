import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../layout.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import '../widgets/free_epg_picker.dart';
import 'add_source_screen.dart';
import 'backup_screen.dart';
import 'guide_mapping_screen.dart';
import 'manage_source_screen.dart';

/// Lists the user's sources with their guide coverage, and lets them add,
/// refresh or remove one.
class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  /// Source awaiting a second press to confirm deletion. No modal dialogs:
  /// they are awkward with a remote.
  String? _confirmDelete;
  Timer? _confirmTimer;
  String? _message;

  /// Refresh button of each source; Down from "Add a source" lands on the
  /// first one rather than whichever button sits nearest the centre.
  final _refreshNodes = <String, FocusNode>{};

  FocusNode _refreshNode(String id) =>
      _refreshNodes.putIfAbsent(id, () => FocusNode());

  KeyEventResult _addKey(FocusNode _, KeyEvent e) {
    final first = widget.state.sources.firstOrNull;
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.arrowDown &&
        first != null) {
      _refreshNode(first.id).requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _confirmTimer?.cancel();
    for (final n in _refreshNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh(SourceRecord s) async {
    setState(() => _message = null);
    try {
      final r = await widget.state.refresh(s);
      if (!mounted) return;
      setState(
        () => _message = r.guideErrors.isEmpty
            ? '${s.name}: ${r.channels} channels, '
                  '${r.guide.programmes} guide entries'
            : '${s.name}: channels updated, guide failed '
                  '(${r.guideErrors.join('; ')})',
      );
    } catch (e) {
      if (mounted) setState(() => _message = '${s.name}: $e');
    }
  }

  /// One tap for the device's country; a list otherwise.
  Future<void> _addFreeEpg(SourceRecord s) async {
    final epg =
        widget.state.likelyFreeEpg(s.id) ??
        suggestedFreeEpg() ??
        await pickFreeEpg(context);
    if (epg == null || !mounted) return;
    setState(() => _message = 'Loading the free EPG for ${epg.name}…');
    try {
      final r = await widget.state.addFreeEpg(s, epg);
      if (!mounted) return;
      setState(
        () => _message =
            '${epg.name} EPG added: TV guide for ${r.coverage.matched} of '
            '${r.coverage.channels} channels.',
      );
    } catch (e) {
      if (mounted) setState(() => _message = '${s.name}: $e');
    }
  }

  /// Says what the last sync got from the source's EPG, in plain words.
  static String _guideLine(GuideStatus g) {
    final fallback = g.perChannel
        ? ' What is on now and next is asked channel by channel instead.'
        : ' Add an EPG link in Manage.';
    if (g.errors.isNotEmpty) {
      return 'EPG could not be loaded: ${g.errors.join('; ')}.$fallback';
    }
    if (g.programmes == 0) return 'The source sent an empty EPG.$fallback';
    return 'EPG: ${g.programmes} programmes loaded.';
  }

  void _delete(SourceRecord s) {
    if (_confirmDelete != s.id) {
      // The confirmation expires, so a stray press later never deletes.
      _confirmTimer?.cancel();
      _confirmTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _confirmDelete = null);
      });
      setState(() => _confirmDelete = s.id);
      return;
    }
    _confirmTimer?.cancel();
    widget.state.deleteSource(s.id);
    setState(() => _confirmDelete = null);
    if (widget.state.isEmpty) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final phone = context.isPhone;
        return Scaffold(
          appBar: phone ? AppBar(title: const Text('Sources')) : null,
          body: ListView(
            padding: phone
                ? Metrics.of(context).pagePadding
                : const EdgeInsets.symmetric(horizontal: 64, vertical: 40),
            children: [
              if (!phone) ...[
                const Text(
                  'Sources',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
              ],
              Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: _addKey,
                child: Flex(
                  direction: phone ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: phone
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.center,
                  children: [
                    _Grow(
                      grow: !phone,
                      child: FocusCard(
                        autofocus: true,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AddSourceScreen(state: state),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Add a source',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16, height: 12),
                    FocusCard(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BackupScreen(state: state),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: phone
                            ? MainAxisSize.max
                            : MainAxisSize.min,
                        children: [
                          const Icon(Icons.save_alt_rounded),
                          const SizedBox(width: 12),
                          // A row of unbounded width can't hold a Flexible.
                          _Grow(
                            grow: phone,
                            child: const Text(
                              'Backup and restore',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                key: const ValueKey('message'),
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _message ?? '',
                  style: const TextStyle(color: ZaplineColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              for (final s in state.sources) _sourceCard(state, s),
            ],
          ),
        );
      },
    );
  }

  Widget _sourceCard(AppState state, SourceRecord s) {
    final syncing = state.syncingSourceId == s.id;
    final cov = state.coverage(s.id);
    final synced = s.syncedAt?.toLocal();
    // Keys keep focus on the same button when the list above changes (a
    // result message appears, a "Fix TV guide" button is added).
    return Container(
      key: ValueKey('source-${s.id}'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Lighter than the buttons inside, so they stand out.
        color: ZaplineColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ZaplineColors.line,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  s.kind.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                syncing
                    ? 'Syncing… ${state.progress ?? ''}'
                    : synced == null
                    ? 'Never synced'
                    : 'Synced ${synced.day}/${synced.month} '
                          '${state.time(synced)}',
                style: const TextStyle(color: ZaplineColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${cov.channels} channels · TV guide (EPG) for ${cov.matched} '
            '(${(cov.ratio * 100).round()}%)',
            style: const TextStyle(fontSize: 16),
          ),
          if (cov.ratio < 0.8 && !state.hasFreeEpg(s))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FocusCard(
                key: ValueKey('free-epg-${s.id}'),
                onPressed: state.isSyncing ? () {} : () => _addFreeEpg(s),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_available_rounded, size: 20),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(switch (state.likelyFreeEpg(s.id) ??
                          suggestedFreeEpg()) {
                        final c? => 'Add the free EPG for ${c.name}',
                        null => 'Add a free EPG',
                      }, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          if (state.guideStatus(s.id) case final g?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _guideLine(g),
                style: TextStyle(
                  fontSize: 14,
                  color: g.errors.isEmpty && g.programmes > 0
                      ? ZaplineColors.textMuted
                      : ZaplineColors.live,
                ),
              ),
            ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: cov.ratio,
              minHeight: 8,
              color: cov.ratio > 0.9 ? ZaplineColors.ok : ZaplineColors.focus,
              backgroundColor: ZaplineColors.line,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FocusCard(
                key: ValueKey('refresh-${s.id}'),
                focusNode: _refreshNode(s.id),
                onPressed: syncing || state.isSyncing
                    ? () {}
                    : () => _refresh(s),
                child: const Text(
                  'Refresh',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              FocusCard(
                key: ValueKey('manage-${s.id}'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ManageSourceScreen(state: state, sourceId: s.id),
                  ),
                ),
                child: const Text(
                  'Manage',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (cov.matched < cov.channels) ...[
                FocusCard(
                  key: ValueKey('fix-${s.id}'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          GuideMappingScreen(state: state, sourceId: s.id),
                    ),
                  ),
                  child: Text(
                    'Fix TV guide (${cov.channels - cov.matched})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              FocusCard(
                key: ValueKey('remove-${s.id}'),
                onPressed: () => _delete(s),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_confirmDelete == s.id) ...[
                      const Icon(Icons.warning_amber_rounded, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _confirmDelete == s.id
                          ? 'Press again to remove'
                          : 'Remove',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Expands in a row, sizes to its child in a column.
class _Grow extends StatelessWidget {
  const _Grow({required this.grow, required this.child});

  final bool grow;
  final Widget child;

  @override
  Widget build(BuildContext context) => grow ? Expanded(child: child) : child;
}
