import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../layout.dart';
import '../mobile/mobile_widgets.dart' show requirePinIfSet;
import '../widgets/settings_widgets.dart';
import 'add_source_screen.dart';
import 'backup_screen.dart';
import 'settings_screen.dart';

/// Every source, each opening its details; adding one and backups below.
/// Phones reach the same list from Settings.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key, required this.state});

  final AppState state;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final l = context.l10n;
      return AdaptivePage(
        title: l.sources,
        children: [
          SettingsGroup(
            children: [
              for (final (i, s) in state.sources.indexed)
                SourceTile(
                  state: state,
                  source: s,
                  autofocus: i == 0 && !context.isPhone,
                ),
            ],
          ),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.add_rounded,
                title: l.addSource,
                accent: true,
                chevron: false,
                onTap: () => _open(context, AddSourceScreen(state: state)),
              ),
              SettingsTile(
                icon: Icons.save_alt_rounded,
                title: l.backupTitle,
                onTap: () async {
                  if (await requirePinIfSet(context, state) &&
                      context.mounted) {
                    _open(context, BackupScreen(state: state));
                  }
                },
              ),
            ],
          ),
        ],
      );
    },
  );
}
