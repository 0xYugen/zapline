import 'package:flutter/material.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../layout.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import '../widgets/tv_text_field.dart';

/// A source's name, and the server and user it logs in with. Its guides
/// and filters have pages of their own.
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
  SourceRecord get _source =>
      widget.state.sources.firstWhere((s) => s.id == widget.sourceId);

  late final _name = TextEditingController(text: _source.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    widget.state.updateSource(_source.copyWith(name: name));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.nameSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = _source;
    return AdaptivePage(
      title: l.sectionName,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: TvTextField(
                  builder: (readOnly) => TextField(
                    readOnly: readOnly,
                    controller: _name,
                    autofocus: !context.isPhone,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(labelText: l.name),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FocusCard(onPressed: _save, child: Text(l.save)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            [
              if (s.kind == SourceKind.xtream) ...[
                '${l.server}: ${Uri.tryParse(s.url)?.host ?? s.url}',
                '${l.username}: ${s.username}',
              ] else
                s.url,
            ].join('\n'),
            style: const TextStyle(color: ZaplineColors.textMuted, height: 1.5),
          ),
        ),
      ],
    );
  }
}
