import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../pairing/backup_server.dart';
import '../layout.dart';
import '../theme.dart';
import '../widgets/qr_panel.dart';

/// Backup and restore through a browser on the same network: a phone that
/// scans the QR code, or this computer's own browser on desktop. Works the
/// same on TVs, where there is no file picker.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.state});

  final AppState state;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  BackupServer? _server;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final server = await BackupServer.start(
      export: widget.state.exportBackup,
      restore: widget.state.restoreBackup,
    );
    if (!mounted) {
      await server?.close();
      return;
    }
    setState(() {
      _server = server;
      _failed = server == null;
    });
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final server = _server;
    final phone = context.isPhone;
    return Scaffold(
      appBar: phone ? AppBar(title: Text(context.l10n.backupTitle)) : null,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(phone ? 20 : 40),
          child: Flex(
            direction: phone ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!phone) ...[
                      Text(
                        context.l10n.backupTitle,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      context.l10n.backupIntro,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.45,
                        color: ZaplineColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.backupPrivate,
                      style: TextStyle(color: ZaplineColors.focus),
                    ),
                    // A TV has no browser of its own: only desktops get the
                    // local address.
                    // On a phone, the page is opened from a computer.
                    if (server != null && phone) ...[
                      const SizedBox(height: 20),
                      Text(
                        context.l10n.backupOpenOnComputer,
                        style: TextStyle(color: ZaplineColors.textMuted),
                      ),
                      SelectableText(
                        '${server.url}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        context.l10n.backupCode(server.pin),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ZaplineColors.focus,
                        ),
                      ),
                    ],
                    if (server != null && _isDesktop) ...[
                      const SizedBox(height: 20),
                      Text(
                        context.l10n.backupOpenHere,
                        style: TextStyle(color: ZaplineColors.textMuted),
                      ),
                      SelectableText(
                        'http://localhost:${server.port}/?pin=${server.pin}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (_failed)
                      Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text(
                          context.l10n.noLocalNetwork,
                          style: TextStyle(color: ZaplineColors.live),
                        ),
                      ),
                    const SizedBox(height: 28),
                    Focus(
                      autofocus: true,
                      child: Builder(
                        builder: (context) => ListenableBuilder(
                          listenable: widget.state,
                          builder: (context, _) => Text(
                            widget.state.isSyncing
                                ? context.l10n.restoring(
                                    '${widget.state.progress ?? ''}',
                                  )
                                : phone
                                ? ''
                                : context.l10n.pressBackWhenDone,
                            style: const TextStyle(
                              color: ZaplineColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (server != null && !phone) ...[
                const SizedBox(width: 40),
                QrPanel(
                  server: server,
                  title: context.l10n.useYourPhone,
                  subtitle: context.l10n.backupScan,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
