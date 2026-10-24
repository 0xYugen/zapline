# Roadmap

Estimates assume one full-time developer, including ~20% margin for device
bugs. Part-time (20 h/week) roughly doubles them.

## Phase 0 — Foundations (~6 weeks)

- [x] Monorepo, MIT licence, contribution rules, trademark policy
- [x] `lineup_core`: M3U parser, Xtream-compatible client, URL detection,
      streaming XMLTV parser, channel ↔ guide matcher, unit tests
- [x] CI (format, analyze, test for the core)
- [x] Flutter app shell with D-pad focus navigation, add-source screen with
      Xtream link detection, channel list, player with zapping and zap-time
      readout; Android TV/Fire TV manifest (leanback, banner placeholder)
- [x] Windows release build verified
- [x] Player abstraction (`PlaybackEngine`): Media3/ExoPlayer on Android and
      web via the official `video_player` plugin, libmpv on desktop and iOS.
      Verified on the Android TV emulator: playback, zapping (1.5–2.6 s to
      remote test CDNs), error screen, ~107 MB PSS while playing HD.
      Android APK no longer ships libmpv (17 MB instead of 29 MB)
- [ ] AC-3/E-AC-3/MP2 on Android: Media3 relies on the device's decoders;
      `video_player` cannot load the Media3 FFmpeg extension. If real devices
      lack them, write our own thin Media3 plugin
- [ ] Verify whether media_kit's prebuilt libmpv/FFmpeg binaries (desktop,
      iOS) are LGPL; otherwise build our own
- [x] Android release APKs (arm64, armv7, x86_64) built; tested on an
      Android TV emulator (API 36): onboarding, D-pad focus, channel list,
      zapping, playback
- [x] Playback verified on Windows against the mock panel (HLS)
- [x] Dev flags: `LINEUP_DEV_SOURCE`, `LINEUP_DEV_AUTOPLAY` (`--dart-define`)
- [ ] LGPL builds of libmpv/FFmpeg, licences of all binaries documented
- [ ] Prototype measured on a real Fire TV Stick 4K: zapping time, memory,
      MPEG-TS + AC-3 + MP2 playback
- [ ] Non-code: legal entity, trademark filing, store developer accounts

**Exit:** zapping and navigation measured on real hardware; binary licences
documented.

## Phase 1 — MVP (~22 weeks, month 7)

- [x] `lineup_data`: SQLite schema (sources, channels with FTS5 search,
      guide channels, programmes, guide links, manual overrides), batched
      guide import (48k programmes in ~0.25 s on desktop), retention window,
      guide coverage
- [x] Source sync: Xtream (+ `xmltv.php`), M3U (+ `url-tvg`), gzip guides
      detected by magic bytes with download backpressure, M3U catch-up
      attributes, guide failures don't fail the sync
- [x] App: sources persisted and shown instantly at startup, sync on a
      background isolate with progress, stale sources refreshed (12 h)
- [x] Channel list with current programme and progress; player info bar with
      now/next
- [x] TV guide grid: 2-hour window paging by 30 min at the D-pad edges,
      lazy rows, "now" line, details header; verified on Android TV emulator
- [x] Sources screen: add, refresh, remove (second press confirms), guide
      coverage
- [x] Manual guide mapping: unmatched channels, ranked suggestions
      (`rankGuideCandidates`), guide search; overrides survive re-syncs
- [x] Catch-up: URL builder for xtream/xc, default, append, shift,
      flussonic and vod with Kodi-compatible placeholders; Xtream panel UTC
      offset from `server_info`; archive programmes marked in the guide and
      playable with OK; "watch from the start" (Left) and "back to live"
      (Right) in the player
- [x] Favourites (hold OK, Menu key, long tap or right click), shown as a
      group; kept across re-syncs (database migration v1 → v2)
- [x] Number-key zapping in the player
- [x] Channel search screen (prefix, accent-insensitive, live results)
- [x] QR onboarding: while "Add a source" is open the TV serves a small
      form on the LAN (PIN required, locks after 5 wrong codes, no cloud);
      verified on the emulator through a forwarded port
- [x] Duplicate sources are refused
- [x] Backup and restore (JSON: sources with credentials, favourites,
      manual guide links) through a PIN-protected page on the LAN, usable
      from a phone (QR) or the desktop browser; "Restore from a backup" on
      first run; verified end to end on the emulator
- [x] Source passwords in the platform keystore (flutter_secure_storage),
      migrated automatically, loaded after the first frame; database
      fallback where no keystore exists
- [ ] Xtream channel URLs still embed username/password in their path:
      store URL templates and fill credentials at play time
- [x] Logos: disk cache, in-flight dedup, decoded at display size, bounded
      image memory (48 MB), initials badge as fallback; in list, guide and
      player
- [ ] Packaging: GitHub releases, F-Droid, Flathub, winget

SQLite data layer and sync · Xtream + M3U sources · automatic Xtream guide via
`xmltv.php` + external XMLTV · virtualised guide grid and mini-guide ·
catch-up (xc, shift, append, flussonic) · unlimited sources · favourites ·
QR onboarding · JSON backup · desktop builds · releases on GitHub, F-Droid,
Flathub, winget.

**Exit:** usable without an account; guide working right after the first
Xtream login.

## Phase 2 — Feature parity (~20 weeks, month 12)

Stalker portals · multiple guides with manual mapping and time offset ·
logical channels with fallback across sources · movies/series with resume ·
parental PIN · selectable video engine · Google Play and Amazon Appstore
(Fire OS) · iOS after licence review.

## Phase 3 — Differentiation (~18 weeks, month 16)

Web PWA with self-hosted relay · recording · multi-view · device sync
(end-to-end encrypted or self-hosted) · Dispatcharr as a source.
Decision on tvOS (separate SwiftUI app, +10 weeks).

## Later

Samsung Tizen and LG webOS via Flutter; React Native client for Fire TV on
Vega OS depending on market share and Amazon policy.
