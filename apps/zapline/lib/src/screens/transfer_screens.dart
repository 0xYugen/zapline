import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:http/http.dart' as http;
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../cast/cast_link.dart';
import '../l10n.dart';
import '../layout.dart';
import '../pairing/backup_server.dart';
import '../pairing/transfer_crypto.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import '../widgets/qr_panel.dart';
import '../widgets/tv_text_field.dart';

/// Waits for another Zapline (a phone) to send its whole setup over the
/// home network: shows a QR code to scan, then what arrived while the
/// channels download.
class TransferReceiveScreen extends StatefulWidget {
  const TransferReceiveScreen({super.key, required this.state});

  final AppState state;

  @override
  State<TransferReceiveScreen> createState() => _TransferReceiveScreenState();
}

enum _Receive { starting, waiting, receiving, done, noNetwork }

class _TransferReceiveScreenState extends State<TransferReceiveScreen> {
  BackupServer? _server;
  _Receive _stage = _Receive.starting;
  String? _summary;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final server = await BackupServer.start(
      // Waiting to receive: this device's own setup stays here.
      export: null,
      restore: _received,
      encrypted: true,
    );
    if (!mounted) {
      await server?.close();
      return;
    }
    setState(() {
      _server = server;
      _stage = server == null ? _Receive.noNetwork : _Receive.waiting;
    });
  }

  /// Answers the phone at once and restores in the background: adding
  /// the sources downloads their channels, which takes a while.
  Future<String> _received(String json) async {
    Backup.parse(json); // throws on anything that isn't a backup
    setState(() => _stage = _Receive.receiving);
    widget.state
        .restoreBackup(json)
        .then(
          (summary) {
            if (mounted) {
              setState(() {
                _stage = _Receive.done;
                _summary = summary;
              });
            }
          },
          onError: (Object e) {
            if (mounted) {
              setState(() {
                _stage = _Receive.done;
                _summary = '$e';
              });
            }
          },
        );
    return 'received';
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final phone = context.isPhone;
    final server = _server;
    final Widget body = switch (_stage) {
      _Receive.starting => const Center(
        child: CircularProgressIndicator(color: ZaplineColors.focus),
      ),
      _Receive.noNetwork => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l.noLocalNetwork, textAlign: TextAlign.center),
        ),
      ),
      _Receive.waiting => Center(
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
                    if (!phone)
                      Text(
                        l.receiveTitle,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      l.receiveIntro,
                      style: const TextStyle(
                        fontSize: 16,
                        color: ZaplineColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final (i, step) in [
                      l.receiveStep1,
                      l.receiveStep2,
                      l.receiveStep3,
                    ].indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: ZaplineColors.surfaceHigh,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: ZaplineColors.focus,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                step,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: phone ? 0 : 48, height: phone ? 16 : 0),
              if (server != null)
                QrPanel(
                  server: server,
                  title: l.scanWithZapline,
                  subtitle: l.sameWifi,
                ),
            ],
          ),
        ),
      ),
      _Receive.receiving || _Receive.done => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _stage == _Receive.done
                    ? Icons.check_circle_rounded
                    : Icons.downloading_rounded,
                size: 64,
                color: _stage == _Receive.done
                    ? ZaplineColors.ok
                    : ZaplineColors.focus,
              ),
              const SizedBox(height: 16),
              Text(
                l.receivedTitle,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _stage == _Receive.done
                    ? (_summary ?? '')
                    : l.downloadingChannels,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: ZaplineColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              if (_stage == _Receive.receiving)
                const SizedBox(
                  width: 320,
                  child: LinearProgressIndicator(
                    color: ZaplineColors.focus,
                    backgroundColor: ZaplineColors.line,
                  ),
                )
              else
                FocusCard(
                  autofocus: true,
                  selected: true,
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: Text(
                    l.startWatching,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
        ),
      ),
    };
    return Scaffold(
      appBar: phone ? AppBar(title: Text(l.receiveTitle)) : null,
      body: body,
    );
  }
}

/// A device that answered but turned the code down.
class _Refused implements Exception {
  const _Refused(this.message);
  final String message;
}

/// The device found by scanning: where to send and what it is called.
typedef _Target = ({Uri base, String pin, String name, String? key});

/// Sends this phone's setup to another Zapline on the home network: scan
/// its QR code (or type its address), pick what to send, send.
class TransferSendScreen extends StatefulWidget {
  const TransferSendScreen({super.key, required this.state});

  final AppState state;

  @override
  State<TransferSendScreen> createState() => _TransferSendScreenState();
}

class _TransferSendScreenState extends State<TransferSendScreen> {
  _Target? _target;
  bool _checking = false;
  bool _sending = false;
  bool _sent = false;
  String? _error;
  final _parts = {...BackupPart.values};
  bool _pin = false;

  /// Finds the device behind a scanned or typed code: the addresses it
  /// gave are tried together, and when none answers (a TV showing the
  /// address of a network the phone isn't on, such as Wi-Fi Direct) the
  /// Zapline devices answering on this network are tried on the same port.
  Future<void> _connect(List<Uri> bases, String pin, {String? key}) async {
    if (_checking || _target != null) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final l = context.l10n;
    try {
      var found = await _firstAnswering(bases, pin);
      if (found == null) {
        final port = bases.first.port;
        final nearby = await CastClient.discover();
        found = await _firstAnswering([
          for (final d in nearby)
            Uri(scheme: 'http', host: d.address.address, port: port, path: '/'),
        ], pin);
      }
      if (!mounted) return;
      if (found == null) {
        setState(() => _error = l.deviceNotFound);
        return;
      }
      HapticFeedback.mediumImpact();
      final (base, name) = found;
      setState(() => _target = (base: base, pin: pin, name: name, key: key));
    } on _Refused catch (e) {
      // It answered but said no: a wrong or locked code.
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// The first of [bases] answering as a Zapline device, with its name;
  /// null when none does.
  static Future<(Uri, String)?> _firstAnswering(
    List<Uri> bases,
    String pin,
  ) async {
    if (bases.isEmpty) return null;
    final result = Completer<(Uri, String)?>();
    var left = bases.length;
    for (final base in bases) {
      _hello(base, pin).then(
        (name) {
          if (!result.isCompleted) result.complete((base, name));
        },
        onError: (Object e) {
          if (result.isCompleted) return;
          if (e is _Refused) {
            result.completeError(e);
          } else if (--left == 0) {
            result.complete(null);
          }
        },
      );
    }
    return result.future;
  }

  static Future<String> _hello(Uri base, String pin) async {
    final res = await http
        .get(base.replace(path: '/hello'), headers: {'x-zapline-pin': pin})
        .timeout(const Duration(seconds: 4));
    final body = jsonDecode(res.body) as Map;
    if (body['ok'] != true) throw _Refused('${body['message']}');
    return '${body['message']}';
  }

  void _scanned(Code code) {
    final uri = Uri.tryParse(code.text ?? '');
    final pin = uri?.queryParameters['pin'];
    if (uri == null || uri.scheme != 'http' || pin == null) {
      setState(() => _error = context.l10n.notAZaplineCode);
      return;
    }
    final key = Uri.splitQueryString(uri.fragment)['k'];
    final base = Uri(scheme: 'http', host: uri.host, port: uri.port, path: '/');
    _connect(
      [
        base,
        for (final ip in (uri.queryParameters['alt'] ?? '').split(','))
          if (ip.isNotEmpty) base.replace(host: ip),
      ],
      pin,
      key: key,
    );
  }

  Future<void> _typeAddress() async {
    final l = context.l10n;
    final address = TextEditingController();
    final pin = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.typeCode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TvTextField(
              builder: (readOnly) => TextField(
                readOnly: readOnly,
                controller: address,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l.deviceAddress,
                  hintText: '192.168.1.24:41234',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TvTextField(
              builder: (readOnly) => TextField(
                readOnly: readOnly,
                controller: pin,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(labelText: l.code),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.connect),
          ),
        ],
      ),
    );
    final a = address.text.trim();
    final p = pin.text.trim();
    address.dispose();
    pin.dispose();
    if (ok != true || a.isEmpty || p.isEmpty) return;
    final base = Uri.tryParse(a.contains('://') ? a : 'http://$a/');
    if (base == null || base.host.isEmpty) {
      setState(() => _error = l.deviceNotFound);
      return;
    }
    await _connect([base.replace(path: '/')], p);
  }

  Future<void> _send() async {
    final t = _target!;
    setState(() {
      _sending = true;
      _error = null;
    });
    final l = context.l10n;
    try {
      final json = widget.state.exportBackup(parts: _parts, includePin: _pin);
      // Sealed with the key from the QR code, so the passwords don't cross
      // the Wi-Fi readable.
      final key = t.key;
      final res = await http
          .post(
            t.base.replace(path: '/restore'),
            headers: {
              'content-type': 'application/json',
              'x-zapline-pin': t.pin,
            },
            body: key == null ? json : await TransferCipher.seal(json, key),
          )
          .timeout(const Duration(seconds: 30));
      final body = jsonDecode(res.body) as Map;
      if (body['ok'] != true) throw Exception(body['message']);
      HapticFeedback.mediumImpact();
      setState(() => _sent = true);
    } catch (_) {
      setState(() => _error = l.sendFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = _target;
    return Scaffold(
      appBar: AppBar(title: Text(t == null ? l.sendTitle : l.sendTo(t.name))),
      body: _sent
          ? _done(l, t!)
          : t == null
          ? _scanner(l)
          : _choose(l),
    );
  }

  Widget _scanner(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Stack(
          children: [
            Positioned.fill(
              child: ReaderWidget(
                onScan: _scanned,
                codeFormat: Format.qrCode,
                showGallery: false,
                showToggleCamera: false,
                showFlashlight: false,
                cropPercent: 0.7,
                scanDelaySuccess: const Duration(seconds: 2),
              ),
            ),
            if (_checking)
              const Center(
                child: CircularProgressIndicator(color: ZaplineColors.focus),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          children: [
            Text(
              l.scanTheCode,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              l.scanTheCodeHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: ZaplineColors.textMuted,
                height: 1.4,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ZaplineColors.live),
              ),
            ],
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: OutlinedButton(
          onPressed: _typeAddress,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: ZaplineColors.text,
            side: const BorderSide(color: ZaplineColors.line),
          ),
          child: Text(l.typeCode),
        ),
      ),
    ],
  );

  Widget _choose(AppLocalizations l) {
    final s = widget.state;
    Widget part(BackupPart p, String title, String subtitle) =>
        CheckboxListTile(
          value: _parts.contains(p),
          onChanged: (v) =>
              setState(() => v == true ? _parts.add(p) : _parts.remove(p)),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle),
          controlAffinity: ListTileControlAffinity.leading,
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF17352A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_rounded, color: ZaplineColors.ok),
                const SizedBox(width: 12),
                Expanded(child: Text(l.connectedTo)),
              ],
            ),
          ),
        ),
        CheckboxListTile(
          value: true,
          onChanged: null,
          title: Text(
            l.sendSources,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(l.sourcesCount(s.sources.length)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        part(BackupPart.filters, l.sendFilters, l.sendFiltersHint),
        part(BackupPart.favourites, l.favourites, l.sendFavouritesHint),
        part(BackupPart.guide, l.tvGuide, l.sendGuideHint),
        part(BackupPart.watching, l.sendWatching, l.sendWatchingHint),
        part(BackupPart.settings, l.sendSettings, l.sendSettingsHint),
        if (s.hasPin)
          CheckboxListTile(
            value: _pin,
            onChanged: (v) => setState(() => _pin = v ?? false),
            title: Text(
              l.parentalPin,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(l.sendPinHint),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l.sendReplaces,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: ZaplineColors.textMuted,
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ZaplineColors.live),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FilledButton(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: ZaplineColors.focus,
              foregroundColor: ZaplineColors.onFocus,
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            child: _sending
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(l.send),
          ),
        ),
      ],
    );
  }

  Widget _done(AppLocalizations l, _Target t) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 64,
            color: ZaplineColors.ok,
          ),
          const SizedBox(height: 16),
          Text(
            l.sentTitle,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            l.sentHint(t.name),
            textAlign: TextAlign.center,
            style: const TextStyle(color: ZaplineColors.textMuted),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l.done),
          ),
        ],
      ),
    ),
  );
}
