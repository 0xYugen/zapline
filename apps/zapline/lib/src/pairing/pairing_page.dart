/// The page a phone sees after scanning the TV's QR code. Self-contained
/// (no external assets) because it is served from the TV on the LAN.
String pairingPage({required String pin}) {
  // Only digits ever reach the markup.
  final safePin = pin.replaceAll(RegExp(r'[^0-9]'), '');
  final pinField = safePin.isEmpty
      ? '''
      <label>Code shown on the TV
        <input name="pin" inputmode="numeric" pattern="[0-9]{4}" maxlength="4"
               autocomplete="one-time-code" required>
      </label>'''
      : '<input type="hidden" name="pin" value="$safePin">';

  return '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>Zapline · Add a source</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; background: #0B0E13; color: #EEF2F7;
         font: 16px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; }
  main { max-width: 440px; margin: 0 auto; padding: 28px 20px 40px; }
  .brand { color: #F5B841; font-weight: 800; font-size: 18px; }
  h1 { font-size: 26px; margin: 6px 0 4px; letter-spacing: -0.02em; }
  p.lead { color: #B6C0CE; margin: 0 0 20px; }
  label { display: block; font-size: 14px; font-weight: 600; color: #B6C0CE;
          margin-bottom: 14px; }
  input { display: block; width: 100%; margin-top: 6px; height: 48px;
          padding: 0 14px; border-radius: 10px; border: 1px solid #2A3342;
          background: #141922; color: #EEF2F7; font: inherit; }
  input:focus { outline: 3px solid #F5B841; border-color: transparent; }
  .row { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
  .hint { font-size: 13px; color: #9AA6B8; margin: -6px 0 14px; }
  details { margin: 6px 0 18px; color: #B6C0CE; }
  summary { cursor: pointer; font-weight: 600; }
  button { width: 100%; height: 54px; border: 0; border-radius: 14px;
           background: #F5B841; color: #1A1204; font: inherit;
           font-size: 17px; font-weight: 800; cursor: pointer; }
  button:disabled { opacity: .6; }
  #status { margin-top: 16px; min-height: 24px; }
  .ok { color: #7FD6A4; } .err { color: #FF8A7A; }
  footer { margin-top: 28px; font-size: 12px; color: #9AA6B8; }
</style>
</head>
<body>
<main>
  <div class="brand">Zapline</div>
  <h1>Add a source to your TV</h1>
  <p class="lead">Paste your playlist link, or your server address with
  username and password.</p>
  <form id="f" autocomplete="off">
    <label>Playlist link or server address
      <input name="url" type="url" inputmode="url" required
             placeholder="http://server.example:8080">
    </label>
    <p class="hint">An Xtream link (get.php?username=…) already contains the
    login: no need to fill the fields below.</p>
    <div class="row">
      <label>Username<input name="username" autocapitalize="none"></label>
      <label>Password<input name="password" type="password"></label>
    </div>
    <details>
      <summary>Extra TV guide (optional)</summary>
      <label style="margin-top:10px">XMLTV guide link
        <input name="guide" type="url" inputmode="url"
               placeholder="http://guide.example/epg.xml.gz">
      </label>
    </details>
    $pinField
    <button id="b" type="submit">Send to TV</button>
    <div id="status" role="status" aria-live="polite"></div>
  </form>
  <footer>Your details travel only over your home network, straight to the
  TV. Zapline includes no channels or playlists.</footer>
</main>
<script>
  const f = document.getElementById('f');
  const b = document.getElementById('b');
  const s = document.getElementById('status');
  f.addEventListener('submit', async (e) => {
    e.preventDefault();
    b.disabled = true;
    s.className = '';
    s.textContent = 'Connecting… the TV is loading your channels.';
    try {
      const r = await fetch('/add', {
        method: 'POST',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: new URLSearchParams(new FormData(f)).toString(),
      });
      const j = await r.json();
      s.className = j.ok ? 'ok' : 'err';
      s.textContent = j.message;
      if (j.ok) f.reset();
    } catch (_) {
      s.className = 'err';
      s.textContent = 'The TV did not answer. Is "Add a source" still open?';
    } finally {
      b.disabled = false;
    }
  });
</script>
</body>
</html>''';
}
