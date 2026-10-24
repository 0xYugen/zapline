import 'package:flutter/material.dart';
import 'package:lineup_data/lineup_data.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import 'add_source_screen.dart';

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
  String? _message;

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

  void _delete(SourceRecord s) {
    if (_confirmDelete != s.id) {
      setState(() => _confirmDelete = s.id);
      return;
    }
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
        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 40),
            children: [
              const Text(
                'Sources',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 24),
              FocusCard(
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
                    Text(
                      'Add a source',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  style: const TextStyle(color: LineupColors.textMuted),
                ),
              ],
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
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LineupColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                s.name,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: LineupColors.line,
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
              const Spacer(),
              Text(
                syncing
                    ? 'Syncing… ${state.progress ?? ''}'
                    : synced == null
                    ? 'Never synced'
                    : 'Synced ${synced.day}/${synced.month} '
                          '${synced.hour.toString().padLeft(2, '0')}:'
                          '${synced.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: LineupColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${cov.channels} channels · guide for ${cov.matched} '
            '(${(cov.ratio * 100).round()}%)',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: cov.ratio,
              minHeight: 8,
              color: cov.ratio > 0.9 ? LineupColors.ok : LineupColors.focus,
              backgroundColor: LineupColors.line,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FocusCard(
                onPressed: syncing || state.isSyncing
                    ? () {}
                    : () => _refresh(s),
                child: const Text(
                  'Refresh',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              FocusCard(
                onPressed: () => _delete(s),
                child: Text(
                  _confirmDelete == s.id ? 'Press again to remove' : 'Remove',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _confirmDelete == s.id ? LineupColors.live : null,
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
