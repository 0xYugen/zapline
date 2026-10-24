import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../layout.dart';
import '../pairing/pairing_server.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/focus_card.dart';
import '../widgets/qr_panel.dart';
import '../widgets/tv_text_field.dart';
import 'backup_screen.dart';
import 'transfer_screens.dart';

/// What the user says they have; `null` means one field that recognises
/// either (TV and desktop, where a phone can also fill it via QR code).
enum SourceType { xtream, m3u }

/// First run on a phone: the logo, one line on what Zapline is, and the
/// three ways to start.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    void open(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));

    Widget choice(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap, {
      bool primary = true,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FocusCard(
        radius: 16,
        padding: const EdgeInsets.all(16),
        onPressed: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primary
                    ? const Color(0xFF2B2412)
                    : ZaplineColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: primary ? ZaplineColors.focus : ZaplineColors.text,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Opacity(
                    opacity: 0.7,
                    child: Text(subtitle, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: ZaplineColors.surface,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: ZaplineColors.line),
                    ),
                    alignment: Alignment.center,
                    child: const ZaplineMark(size: 54),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(child: ZaplineWordmark(height: 36)),
                const SizedBox(height: 14),
                Text(
                  l.tagline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: ZaplineColors.textMuted,
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    l.howDoYouGetChannels.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: ZaplineColors.textMuted,
                    ),
                  ),
                ),
                choice(
                  Icons.dns_outlined,
                  l.xtreamChoice,
                  l.xtreamChoiceHint,
                  () => open(
                    AddSourceScreen(state: state, type: SourceType.xtream),
                  ),
                ),
                choice(
                  Icons.link_rounded,
                  l.m3uChoice,
                  l.m3uChoiceHint,
                  () =>
                      open(AddSourceScreen(state: state, type: SourceType.m3u)),
                ),
                choice(
                  Icons.settings_backup_restore_rounded,
                  l.restoreChoice,
                  l.restoreChoiceHint,
                  () => open(TransferReceiveScreen(state: state)),
                  primary: false,
                ),
                const SizedBox(height: 24),
                Text(
                  l.noChannelsIncluded,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ZaplineColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Adds a source. With [type] it asks only for what that kind needs;
/// without, one address field recognises an M3U link, an Xtream `get.php`
/// link (credentials included) or a server followed by username and
/// password. On TVs and desktops a QR code lets a phone fill the same form
/// over the local network, so nothing has to be typed with a remote.
class AddSourceScreen extends StatefulWidget {
  const AddSourceScreen({super.key, required this.state, this.type});

  final AppState state;
  final SourceType? type;

  @override
  State<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends State<AddSourceScreen> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _guide = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  /// Credentials found in a pasted Xtream link.
  XtreamCredentials? _detected;
  PairingServer? _pairing;

  SourceType? get _type => widget.type;

  @override
  void initState() {
    super.initState();
    _url.addListener(_detect);
    // A phone is the device you would pair with: no QR code on phones.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !kIsWeb && !context.isPhone && _type == null) {
        _startPairing();
      }
    });
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
      _leave();
      return PairingReply.ok(
        'Done! ${r.channels} channels added'
        '${r.guide.programmes > 0 ? ' with their TV guide' : ''}.',
      );
    } catch (e) {
      final msg = _friendly(e);
      if (mounted) setState(() => _error = msg);
      return PairingReply.error('The TV could not connect: $msg');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Back to wherever the user came from (the welcome screen, settings).
  void _leave() {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  void dispose() {
    // Stops accepting connections; a reply still in flight is delivered.
    _pairing?.close();
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    _guide.dispose();
    super.dispose();
  }

  void _detect() {
    final creds = detectXtreamCredentials(_url.text);
    if (creds?.username != _detected?.username ||
        creds?.baseUrl != _detected?.baseUrl) {
      setState(() => _detected = creds);
      // The Xtream form shows the fields filled in from the link.
      if (creds != null && _type == SourceType.xtream) {
        _user.text = creds.username;
        _pass.text = creds.password;
      }
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) _url.text = text;
  }

  /// Turns network and server errors into something a viewer can act on.
  String _friendly(Object e) {
    final l = context.l10n;
    final raw = e.toString().replaceFirst('Exception: ', '');
    final lower = raw.toLowerCase();
    if (lower.contains('already added')) return l.errorDuplicate;
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('timed out') ||
        lower.contains('network is unreachable')) {
      return l.errorUnreachable;
    }
    if (lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('auth') ||
        lower.contains('credential')) {
      return l.errorLogin;
    }
    if (lower.contains('404')) return l.errorNotFound;
    return l.errorGeneric(raw);
  }

  Future<void> _submit() async {
    if (_busy || _url.text.trim().isEmpty) return;
    final xtream = _type == SourceType.xtream;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.state.addSource(
        SourceInput(
          url: _url.text,
          username: xtream || _detected == null ? _user.text.trim() : '',
          password: xtream || _detected == null ? _pass.text : '',
          guideUrl: _guide.text,
        ),
      );
      _leave();
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pairing = _pairing;
    final phone = context.isPhone;
    final title = switch (_type) {
      SourceType.xtream => l.xtreamChoice,
      SourceType.m3u => l.m3uChoice,
      null => null,
    };
    return Scaffold(
      appBar: phone && Navigator.of(context).canPop()
          ? AppBar(title: title == null ? null : Text(title))
          : null,
      body: Align(
        alignment: phone ? Alignment.topCenter : Alignment.center,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(phone ? 20 : 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: _form(context)),
              if (wide && pairing != null) ...[
                const SizedBox(width: 64),
                QrPanel(
                  server: pairing,
                  title: l.useYourPhone,
                  subtitle: l.pairingHint,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final phone = context.isPhone;
    final type = _type;
    final first = !Navigator.of(context).canPop();

    Widget field(
      TextEditingController c,
      String label, {
      bool autofocus = false,
      TextInputType? keyboard,
      Widget? suffix,
      TextInputAction? action,
      ValueChanged<String>? onSubmitted,
    }) => TvTextField(
      builder: (readOnly) => TextField(
        readOnly: readOnly,
        controller: c,
        autofocus: autofocus,
        keyboardType: keyboard,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: action,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(labelText: label, suffixIcon: suffix),
      ),
    );

    final paste = ExcludeFocus(
      child: IconButton(
        tooltip: l.paste,
        onPressed: _paste,
        icon: const Icon(Icons.content_paste_rounded),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (type == null) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: ZaplineLockup(height: 32),
            ),
            const SizedBox(height: 16),
            Text(
              first ? l.addFirstSource : l.addSource,
              style: (phone ? t.headlineMedium : t.displaySmall)?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            switch (type) {
              SourceType.xtream => l.xtreamFormHint,
              SourceType.m3u => l.m3uFormHint,
              null => l.addSourceHint,
            },
            style: (phone ? t.bodyLarge : t.titleMedium)?.copyWith(
              color: ZaplineColors.textMuted,
            ),
          ),
          SizedBox(height: phone ? 20 : 32),
          field(
            _url,
            switch (type) {
              SourceType.xtream => l.serverAddress,
              SourceType.m3u => l.playlistLink,
              null => l.urlOrServer,
            },
            autofocus: !phone,
            keyboard: TextInputType.url,
            suffix: phone ? paste : null,
            action: type == null && _detected != null
                ? TextInputAction.go
                : TextInputAction.next,
            onSubmitted: (_) => type == null && _detected != null
                ? _submit()
                : FocusScope.of(context).nextFocus(),
          ),
          if (_detected case final d?) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: ZaplineColors.ok,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l.xtreamDetected(d.username, d.baseUrl.host),
                    style: const TextStyle(color: ZaplineColors.ok),
                  ),
                ),
              ],
            ),
          ],
          if (type == SourceType.xtream ||
              (type == null && _detected == null)) ...[
            const SizedBox(height: 14),
            _credentials(context),
          ],
          if (type == SourceType.m3u) ...[
            const SizedBox(height: 14),
            field(
              _guide,
              l.epgLinkOptional,
              keyboard: TextInputType.url,
              onSubmitted: (_) => _submit(),
            ),
          ],
          if (type != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ZaplineColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: ZaplineColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.storedOnDevice,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ZaplineColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_busy)
            ListenableBuilder(
              listenable: widget.state,
              builder: (context, _) => _Progress(widget.state.progress),
            ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2E1715),
                border: Border.all(color: const Color(0xFF5A2A24)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: ZaplineColors.live,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!)),
                ],
              ),
            ),
          // Touch gets the brand's primary button; the remote a card that
          // shows focus.
          if (phone)
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Text(l.connect),
            )
          else
            FocusCard(
              selected: true,
              onPressed: _submit,
              child: Center(
                child: _busy
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Text(
                        l.connect,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          // First run on a new TV: bring everything back at once.
          if (type == null && first) ...[
            const SizedBox(height: 12),
            FocusCard(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BackupScreen(state: widget.state),
                ),
              ),
              child: Center(
                child: Text(
                  l.restoreFromBackup,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          if (type == null) ...[
            const SizedBox(height: 32),
            Text(
              l.noChannelsIncluded,
              style: t.bodyMedium?.copyWith(color: ZaplineColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Username and password: side by side, or stacked on a phone.
  Widget _credentials(BuildContext context) {
    final l = context.l10n;
    final optional = _type == null;
    final user = TvTextField(
      builder: (readOnly) => TextField(
        readOnly: readOnly,
        controller: _user,
        autocorrect: false,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: optional ? l.usernameXtreamOnly : l.username,
        ),
      ),
    );
    final pass = TvTextField(
      builder: (readOnly) => TextField(
        readOnly: readOnly,
        controller: _pass,
        obscureText: !_showPassword,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: optional ? l.passwordXtreamOnly : l.password,
          suffixIcon: ExcludeFocus(
            child: IconButton(
              tooltip: _showPassword ? l.hidePassword : l.showPassword,
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
      ),
    );
    if (context.isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [user, const SizedBox(height: 12), pass],
      );
    }
    return Row(
      children: [
        Expanded(child: user),
        const SizedBox(width: 12),
        Expanded(child: pass),
      ],
    );
  }
}

/// Connecting, in three steps: login, channels, TV guide.
class _Progress extends StatelessWidget {
  const _Progress(this.p);

  final SyncProgress? p;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stage = p?.stage;
    final count = p?.count ?? 0;
    final step = switch (stage) {
      null => 0,
      SyncStage.channels => count == 0 ? 0 : 1,
      SyncStage.guide => 2,
      SyncStage.linking || SyncStage.done => 3,
    };
    final steps = [
      (l.stepLogin, step > 0),
      (step >= 1 ? l.stepChannelsCount(count) : l.stepChannels, step > 1),
      (
        stage == SyncStage.guide
            ? l.stepGuideCount(count)
            : stage == SyncStage.linking
            ? l.stepMatching
            : l.stepGuide,
        step > 2,
      ),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZaplineColors.surface,
        border: Border.all(color: ZaplineColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.connecting,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final (i, (label, done)) in steps.indexed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      done
                          ? Icons.check_circle_rounded
                          : i == step
                          ? Icons.downloading_rounded
                          : Icons.circle_outlined,
                      size: 16,
                      color: done
                          ? ZaplineColors.ok
                          : i == step
                          ? ZaplineColors.focus
                          : ZaplineColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: done || i == step
                            ? ZaplineColors.text
                            : ZaplineColors.textMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (step + 0.5) / 4,
              minHeight: 6,
              color: ZaplineColors.focus,
              backgroundColor: ZaplineColors.line,
            ),
          ),
        ],
      ),
    );
  }
}
