import 'dart:io';

import 'pin_server.dart';
import 'setup_receiver.dart';
import 'transfer_crypto.dart';

/// Serves backup download and restore to a phone or PC browser over the
/// LAN while the backup screen is open.
class BackupServer extends PinServer {
  BackupServer._(
    super.server,
    super.pin,
    super.address,
    this._export,
    this._restore,
    this._name,
    this._key,
  );

  /// `null` on a device waiting to receive: it doesn't hand out its own
  /// setup.
  final String Function()? _export;

  /// Decrypts setups sent by another Zapline (see [TransferCipher]).
  final String? _key;

  @override
  String? get fragmentKey => _key;
  final Future<String> Function(String json) _restore;

  /// What a phone sending its setup calls this device.
  final String _name;

  static Future<BackupServer?> start({
    required String Function()? export,
    required Future<String> Function(String json) restore,
    String? pin,
    InternetAddress? bindTo,
    String? name,
    bool encrypted = false,
  }) async {
    final b = await PinServer.bind(pin: pin, bindTo: bindTo);
    if (b == null) return null;
    final (server, address, p, others) = b;
    return BackupServer._(
      server,
      p,
      address,
      export,
      restore,
      name ?? Platform.localHostname,
      encrypted ? TransferCipher.newKey() : null,
    )..alternates = others;
  }

  @override
  Future<void> handle(HttpRequest req) async {
    if (await serveSetup(
      this,
      req,
      name: _name,
      key: _key,
      restore: _restore,
    )) {
      return;
    }
    final res = req.response;
    final pin = req.uri.queryParameters['pin'];
    final export = _export;
    switch ((req.method, req.uri.path)) {
      case ('GET', '/'):
        res.headers.contentType = ContentType.html;
        res.write(_page(pin ?? ''));
      case ('GET', '/backup.json') when export != null:
        if (!checkPin(req, res)) return;
        final now = DateTime.now();
        String two(int n) => n.toString().padLeft(2, '0');
        res.headers
          ..contentType = ContentType.json
          ..set(
            'Content-Disposition',
            'attachment; filename="zapline-backup-'
                '${now.year}${two(now.month)}${two(now.day)}.json"',
          );
        res.write(export());
      default:
        res.statusCode = HttpStatus.notFound;
    }
  }

  static String _page(String pin) {
    final safePin = pin.replaceAll(RegExp(r'[^0-9]'), '');
    return '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>Zapline · Backup and restore</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; background: #0B0E13; color: #EEF2F7;
         font: 16px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; }
  main { max-width: 460px; margin: 0 auto; padding: 28px 20px 40px; }
  .brand { color: #F5B841; font-weight: 800; font-size: 18px; }
  h1 { font-size: 26px; margin: 6px 0 18px; }
  section { background: #141922; border-radius: 16px; padding: 18px;
            margin-bottom: 16px; }
  h2 { font-size: 18px; margin: 0 0 6px; }
  p { color: #B6C0CE; margin: 0 0 14px; }
  .btn { display: block; width: 100%; height: 52px; border: 0;
         border-radius: 14px; background: #F5B841; color: #1A1204;
         font: inherit; font-weight: 800; font-size: 17px; text-align: center;
         line-height: 52px; text-decoration: none; cursor: pointer; }
  input { display: block; width: 100%; margin-bottom: 12px; color: #EEF2F7;
          background: #0B0E13; border: 1px solid #2A3342; border-radius: 10px;
          padding: 12px; font: inherit; }
  .warn { color: #F5B841; font-size: 14px; }
  #status { margin-top: 12px; min-height: 24px; }
  .ok { color: #7FD6A4; } .err { color: #FF8A7A; }
</style>
</head>
<body>
<main>
  <div class="brand">Zapline</div>
  <h1>Backup and restore</h1>
  <label id="pinrow" ${safePin.isEmpty ? '' : 'hidden'}>Code shown on the TV
    <input id="pin" inputmode="numeric" maxlength="4" value="$safePin">
  </label>
  <section>
    <h2>Download a backup</h2>
    <p>Your sources, favourites and guide fixes in one file.</p>
    <p class="warn">The file contains your source passwords. Keep it
    private.</p>
    <a class="btn" id="dl" href="#">Download backup</a>
  </section>
  <section>
    <h2>Restore</h2>
    <p>Pick a Zapline backup file. Sources already on the TV are kept.</p>
    <input id="file" type="file" accept=".json,application/json">
    <button class="btn" id="restore" type="button">Restore to TV</button>
    <div id="status" role="status" aria-live="polite"></div>
  </section>
</main>
<script>
  const pin = () => encodeURIComponent(document.getElementById('pin').value);
  document.getElementById('dl').addEventListener('click', (e) => {
    e.preventDefault();
    location.href = '/backup.json?pin=' + pin();
  });
  const s = document.getElementById('status');
  document.getElementById('restore').addEventListener('click', async () => {
    const f = document.getElementById('file').files[0];
    if (!f) { s.className = 'err'; s.textContent = 'Choose a file first.'; return; }
    s.className = ''; s.textContent = 'Restoring… the TV is downloading your sources.';
    try {
      const r = await fetch('/restore?pin=' + pin(), { method: 'POST', body: await f.text() });
      const j = await r.json();
      s.className = j.ok ? 'ok' : 'err';
      s.textContent = j.message;
    } catch (_) {
      s.className = 'err';
      s.textContent = 'The TV did not answer. Is the backup screen still open?';
    }
  });
</script>
</body>
</html>''';
  }
}
