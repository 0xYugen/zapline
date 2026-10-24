import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../pairing/backup_server.dart';
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
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backup and restore',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Save your sources, favourites and guide fixes to a '
                      'file, or bring them back on a new device. Open the '
                      'page shown here in a browser on the same network.',
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.45,
                        color: LineupColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'The backup file contains your source passwords: keep '
                      'it private.',
                      style: TextStyle(color: LineupColors.focus),
                    ),
                    // A TV has no browser of its own: only desktops get the
                    // local address.
                    if (server != null && _isDesktop) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'On this computer, open',
                        style: TextStyle(color: LineupColors.textMuted),
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
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text(
                          'This device is not connected to a local network.',
                          style: TextStyle(color: LineupColors.live),
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
                                ? 'Restoring… ${widget.state.progress ?? ''}'
                                : 'Press Back when you are done.',
                            style: const TextStyle(
                              color: LineupColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (server != null) ...[
                const SizedBox(width: 40),
                QrPanel(
                  server: server,
                  title: 'Use your phone',
                  subtitle: 'Scan to download a backup or restore one.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
