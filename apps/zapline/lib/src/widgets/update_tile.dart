import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../updates.dart';
import 'settings_widgets.dart';

/// "New version": on Android it downloads the package and opens the
/// installer, elsewhere it opens the release page.
class UpdateTile extends StatefulWidget {
  const UpdateTile({super.key, required this.state, required this.update});

  final AppState state;
  final AppUpdate update;

  @override
  State<UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<UpdateTile> {
  /// Share downloaded while a download runs.
  double? _done;

  bool get _inApp =>
      Updater.installsInApp &&
      widget.update.apk != null &&
      widget.state.updater != null;

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _go() async {
    if (_done != null) return;
    if (!_inApp) {
      await launchUrl(widget.update.page, mode: LaunchMode.externalApplication);
      return;
    }
    final l = context.l10n;
    final updater = widget.state.updater!;
    setState(() => _done = 0);
    try {
      final apk = await updater.download(
        widget.update,
        onProgress: (d) {
          if (mounted) setState(() => _done = d);
        },
      );
      if (!await updater.install(apk) && mounted) _snack(l.updateAllowInstall);
    } catch (e) {
      if (mounted) _snack(l.updateFailed('$e'));
    } finally {
      if (mounted) setState(() => _done = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final done = _done;
    return SettingsTile(
      leading: done == null
          ? const Icon(Icons.system_update_rounded, color: ZaplineColors.focus)
          : SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                value: done == 0 ? null : done,
                strokeWidth: 3,
                color: ZaplineColors.focus,
              ),
            ),
      title: l.updateAvailable(widget.update.version),
      subtitle: done != null
          ? l.updateDownloading((done * 100).round())
          : _inApp
          ? l.updateHint
          : l.updateHintDesktop,
      value: done == null ? l.updateNow : null,
      accent: true,
      chevron: false,
      onTap: _go,
    );
  }
}
