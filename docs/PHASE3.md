# Phase 3 design — differentiation

Status: draft for discussion. Scope: web client with a self-hosted relay,
recording, multi-view, device sync and Dispatcharr as a source. Apple TV
(tvOS) and Fire TV on Vega OS are out of scope for now.

Principles that hold for everything below:

- **No Zapline cloud.** No servers run by the project and no accounts.
  Anything that needs a server runs on the user's own hardware: the relay.
  This keeps users' data private, costs nothing to run, and keeps the
  project away from hosting or forwarding anybody's streams.
- **Same app everywhere.** The Flutter app stays the only client. The relay
  is optional: the TV and desktop apps keep working without it.
- **Respect provider limits.** Many Xtream accounts allow one or two
  connections at a time. Recording and multi-view each open more, so the
  app has to count connections and warn before it goes over.

## 1. Web client and self-hosted relay (~7 weeks)

### Why a relay

A browser cannot play most IPTV sources directly:

| Problem | Cause |
| --- | --- |
| Panel API calls fail | Xtream panels and most M3U hosts send no CORS headers |
| `http://` streams blocked | Mixed content on an `https://` page |
| MPEG-TS won't play | Browsers play HLS (Safari) or fMP4 through MSE, not raw TS |
| No sound | AC-3/E-AC-3 and MP2 audio are missing from most browsers |
| Credentials exposed | Xtream URLs carry username and password in their path |

### The relay

`zapline-relay`: one Dart program (shares `zapline_core`), shipped as a
self-contained binary (`dart compile exe`) and a Docker image for NAS boxes
(Synology, Unraid, Raspberry Pi). It:

1. **Serves the web app** (the Flutter web build) so there's one URL to open.
2. **Proxies panel APIs, M3U and XMLTV** for the sources configured *on the
   relay*, adding CORS headers. Credentials stay on the relay; the browser
   sees only `/s/{source}/…`. It's never an open proxy: unknown hosts are
   refused.
3. **Proxies streams**, in three levels:
   - *pass-through*: HLS with playlist URLs rewritten to the relay;
   - *remux*: MPEG-TS to HLS/fMP4 with `ffmpeg -c copy` (no quality loss,
     little CPU);
   - *audio transcode*: video copied, AC-3/MP2 audio converted to AAC.
   ffmpeg is an optional external program the user installs (or is
   included in the Docker image). Without it, only pass-through works.
4. **Pairs devices** with the existing PIN flow (`PinServer`: 4-digit code,
   lock after 5 wrong tries) and then issues a long random token. It
   listens on the LAN by default; the docs explain how to put it behind a
   reverse proxy with HTTPS for remote use.
5. Later, it is the natural place for **scheduled recordings** (§2) and
   **sync** (§4), because it's always on while TVs sleep.

### Web client

- Flutter web build of the same app. Storage: `package:sqlite3` already
  ships a WASM build with OPFS storage (verified in the 3.8 sources we
  use). FTS5 in that build and a web worker in place of the sync isolate
  still need checking.
- Playback: a `WebEngine` behind `PlaybackEngine` using hls.js (Chrome,
  Firefox) or native HLS (Safari), via JS interop. `video_player_web` alone
  doesn't play HLS outside Safari.
- PWA: installable, offline shell; channel data comes from the relay.
- Without a relay, the web app can still use sources that send CORS
  headers and serve HLS over HTTPS, and says so clearly.
- We publish the web build, but never host a relay.

### Risks

- CPU on small NAS boxes when transcoding audio for several clients. Remux
  is cheap; transcoding is per stream.
- Panels may ban an IP that suddenly fetches on behalf of several devices.
  The relay shares a single upstream connection when two clients watch the
  same channel.

## 2. Recording (~4 weeks)

- **What it records:** the stream bytes as they arrive (TS written to file,
  HLS segments appended), with no transcoding, so CPU use is tiny.
- **How:** "Record" on a programme in the guide or in the player; padding
  before/after (default 2/5 minutes, configurable); series rule later.
  Where the provider keeps an archive, offer "download from the archive"
  instead, which doesn't need the device to stay on.
- **Where it runs:**
  - desktop: in-process, with a tray/notification;
  - Android TV / Fire TV: a foreground service with a notification
    (Android 14+ needs a declared foreground-service type and a Play
    policy declaration), files saved to app storage or a USB drive picked
    by the user. Sticks have little free space: show it and stop early;
  - relay: server-side recordings that every device can play back.
- **Connection limit:** Xtream `user_info.max_connections` is already
  available. If recording would go over the limit, ask: stop watching,
  skip the recording, or record and switch the TV to the recorded stream
  (time-shift).
- **Library:** a "Recordings" group with resume, delete and free space.
- Recordings are for private use; there's no way to share them through
  the app.

## 3. Multi-view (~2 weeks)

- 2 or 4 tiles; one has the audio and a highlight. D-pad moves between
  tiles, OK makes the tile full screen, the channel list (already in the
  player) replaces the tile's channel.
- **Decoder limit:** TV sticks have a small number of hardware decoders.
  Android reports `maxSupportedInstances` per codec: allow 4 tiles only
  when the device says so, otherwise 2. Desktop: 4.
- Every tile is one provider connection: show the count and refuse the
  extra tile instead of failing on the server side.
- Engines: several `VideoPlayerController`s (Android) or mpv players
  (desktop) already work side by side. Muted tiles may get a lower HLS
  variant when one exists.

## 4. Device sync (~4 weeks)

**What syncs:** sources (with credentials), favourites, hidden channels,
group choices and locks, guide links, settings, recents, and later
watch positions for VOD. The guide and channel lists don't: every device
downloads them from the provider.

**Transport**, in order:

1. *LAN, by hand* — exists today as backup/restore through the phone.
2. *Relay* — the relay stores the latest encrypted state; devices push and
   pull.
3. *Any WebDAV folder* (Nextcloud, NAS) — same encrypted file, no relay
   needed.

**Format:** one record per item with a hybrid logical clock timestamp and
tombstones for deletions; merge is last-writer-wins per record, which is
enough for preferences and never loses unrelated changes. This needs
`updated_at` and tombstone columns on the preference tables (schema v4).

**Encryption:** end to end. A key derived from a passphrase (Argon2id)
encrypts the state (XChaCha20-Poly1305, `package:cryptography`). The relay
or WebDAV server only sees a blob. Pairing a new device: scan a QR shown by
a device already in sync, which carries the key, so nobody has to type a
passphrase on a TV.

## 5. Dispatcharr as a source (~1 week)

[Dispatcharr](https://github.com/Dispatcharr/Dispatcharr) is an open-source
stream manager people already run at home. It publishes M3U and XMLTV, an
HDHomeRun emulation and an Xtream-compatible output, so it works with
Zapline today as an M3U or Xtream source. The work here:

- a "Dispatcharr" preset in "Add a source" that only asks for the address
  and fills in the right M3U/XMLTV or Xtream endpoints (to check against
  its current API docs);
- use Dispatcharr's channel numbers and groups as they are;
- later: discover it on the LAN.

## Order and estimate

| Step | Weeks |
| --- | --- |
| Relay: API/M3U/XMLTV proxy, pairing, Docker image | 3 |
| Web client: WebEngine, OPFS storage, PWA | 3 |
| Relay stream remux / audio transcode | 1 |
| Recording on desktop and Android, library | 3 |
| Recording on the relay | 1 |
| Multi-view | 2 |
| Sync: schema v4, merge, WebDAV and relay transport, QR pairing | 4 |
| Dispatcharr preset | 1 |
| **Total** | **18** |

Phase 2 leftovers (tracks, reminders, picture-in-picture, Stalker,
VOD/series, translations, credential-free Xtream URLs) come first, since
users notice them sooner than any of the above.

## Open questions

- Ship ffmpeg inside the Docker image (licence: LGPL build, documented) or
  ask users to install it?
- WebDAV only, or also Google Drive / Dropbox app folders for sync? They
  need OAuth client IDs owned by the project.
- Whether to keep recordings when a source is removed.
