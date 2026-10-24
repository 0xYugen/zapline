import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lineup_core/lineup_core.dart';
import 'package:lineup_data/lineup_data.dart';

import '../app_state.dart';
import '../pairing/pairing_server.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import '../widgets/qr_panel.dart';
import '../widgets/tv_text_field.dart';
import 'backup_screen.dart';

/// Add-source screen. A single URL field accepts an M3U link, an Xtream
/// `get.php` link (credentials are extracted automatically) or a bare server
/// address followed by username and password.
///
/// On TVs and desktops a QR code lets a phone fill the same form over the
/// local network, so nothing has to be typed with a remote.
class AddSourceScreen extends StatefulWidget {
  const AddSourceScreen({super.key, required this.state});

  final AppState state;

  @override
  State<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends State<AddSourceScreen> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _detected;
  PairingServer? _pairing;

  @override
  void initState() {
    super.initState();
    _url.addListener(_detect);
    if (!kIsWeb) _startPairing();
  }

  Future<void> _startPairing() async {
    final server = await PairingServer.start(onSubmit: _fromPhone);
    if (!mounted) {
      await server?.close();
      return;
    }
    setState(() => _pairing = server);
  }

  /// A phone submitted the form: add the source exactly as if typed here.
  Future<PairingReply> _fromPhone(PairingSubmission s) async {
    if (widget.state.isSyncing || _busy) {
      return const PairingReply.error(
        'The TV is busy loading another source. Try again in a moment.',
      );
    }
    setState(() {
      _busy = true;
      _error = null;
      _url.text = s.url;
    });
    try {
      final r = await widget.state.addSource(
        SourceInput(
          url: s.url,
          username: s.username,
          password: s.password,
          guideUrl: s.guideUrl,
        ),
      );
      _leaveIfPushed();
      return PairingReply.ok(
        'Done! ${r.channels} channels added'
        '${r.guide.programmes > 0 ? ' with their TV guide' : ''}.',
      );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) setState(() => _error = msg);
      return PairingReply.error('The TV could not connect: $msg');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _leaveIfPushed() {
    // Opened from the channel list to add another source: go back to it.
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    // Stops accepting connections; a reply still in flight is delivered.
    _pairing?.close();
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _detect() {
    final creds = detectXtreamCredentials(_url.text);
    final label = creds == null
        ? null
        : 'Xtream login detected: ${creds.username} @ ${creds.baseUrl.host}';
    if (label != _detected) setState(() => _detected = label);
  }

  Future<void> _submit() async {
    if (_busy || _url.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.state.addSource(
        SourceInput(
          url: _url.text,
          username: _detected == null ? _user.text : '',
          password: _detected == null ? _pass.text : '',
        ),
      );
      _leaveIfPushed();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _progressText(SyncProgress? p) => switch (p?.stage) {
    null || SyncStage.channels =>
      p == null || p.count == 0 ? 'Connecting…' : 'Loaded ${p.count} channels',
    SyncStage.guide => 'Loading TV guide… ${p!.count} programmes',
    SyncStage.linking => 'Matching channels with the guide…',
    SyncStage.done => 'Done',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pairing = _pairing;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: _form(context, t)),
              if (wide && pairing != null) ...[
                const SizedBox(width: 64),
                QrPanel(
                  server: pairing,
                  title: 'Use your phone',
                  subtitle:
                      'Scan the code and paste your details there. '
                      'No typing on the TV.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, TextTheme t) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lineup',
            style: t.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: LineupColors.focus,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            Navigator.of(context).canPop()
                ? 'Add a source'
                : 'Add your first source',
            style: t.displaySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste a playlist link or your server address. '
            'Xtream links are recognised automatically and the TV guide '
            'is set up for you.',
            style: t.titleMedium?.copyWith(color: LineupColors.textMuted),
          ),
          const SizedBox(height: 32),
          TvTextField(
            child: TextField(
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: _detected != null
                  ? TextInputAction.go
                  : TextInputAction.next,
              // With credentials in the link there is nothing else to
              // fill in: the keyboard's action key connects directly.
              onSubmitted: (_) => _detected != null
                  ? _submit()
                  : FocusScope.of(context).nextFocus(),
              decoration: const InputDecoration(
                labelText: 'Playlist URL or server address',
              ),
            ),
          ),
          if (_detected != null) ...[
            const SizedBox(height: 10),
            Text(_detected!, style: const TextStyle(color: LineupColors.ok)),
          ] else ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TvTextField(
                    child: TextField(
                      controller: _user,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username (Xtream only)',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TvTextField(
                    child: TextField(
                      controller: _pass,
                      obscureText: true,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Password (Xtream only)',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          FocusCard(
            onPressed: _submit,
            child: Center(
              child: _busy
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Text(
                      'Connect',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          if (_busy)
            ListenableBuilder(
              listenable: widget.state,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _progressText(widget.state.progress),
                  style: const TextStyle(color: LineupColors.textMuted),
                ),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: LineupColors.live)),
          ],
          // First run on a new device: bring everything back at once.
          if (!Navigator.of(context).canPop()) ...[
            const SizedBox(height: 12),
            FocusCard(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BackupScreen(state: widget.state),
                ),
              ),
              child: const Center(
                child: Text(
                  'Restore from a backup',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          Text(
            'Lineup includes no channels or playlists. It only plays '
            'sources you add.',
            style: t.bodyMedium?.copyWith(color: LineupColors.textMuted),
          ),
        ],
      ),
    );
  }
}
