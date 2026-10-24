# Architecture

## Goals

1. Adding a source and getting a working guide must take under a minute,
   with no typing on a TV remote.
2. Smooth on a 1.5–2 GB Fire TV stick with 50k channels and a 300 MB guide.
3. One codebase for Android, Android TV, Fire OS, Windows, macOS, Linux and
   iOS, plus a lighter web build.
4. Everything MIT, or LGPL only where unavoidable (video decoding).

## Layers

```
┌───────────────────────────────────────────────────────────┐
│ apps/lineup (Flutter)                                     │
│  UI: TV (D-pad focus) · mobile · desktop                  │
│  Player abstraction ──► Media3 (Android) | libmpv (desktop/iOS) │
│  Pairing server (QR onboarding over the LAN)              │
├───────────────────────────────────────────────────────────┤
│ Data layer: SQLite (FTS5 search) + background sync jobs   │
├───────────────────────────────────────────────────────────┤
│ packages/lineup_core (pure Dart, no Flutter, no dart:io)  │
│  M3U parser · Xtream-compatible client · Stalker client   │
│  Streaming XMLTV parser · channel ↔ guide matcher         │
└───────────────────────────────────────────────────────────┘
```

## Key decisions

| Topic | Decision | Why |
|---|---|---|
| UI framework | Flutter | Covers 7 targets from one codebase; official Tizen/webOS ports exist for later |
| Video, Android family | Media3/ExoPlayer (Apache-2.0) + FFmpeg audio extension (LGPL build) | Best hardware decoding on cheap TV boxes; plays MPEG-TS and HLS; AC-3/E-AC-3/MP2 via extension |
| Video, desktop and iOS | libmpv, LGPL build only | Plays raw MPEG-TS and every codec; GPL builds are banned (App Store, MIT) |
| Video, web | hls.js + mpegts.js (Apache-2.0) | Browsers cannot play raw TS; AC-3 is still unreliable in Chrome |
| Storage | SQLite everywhere (FTS5 for search) | Handles 100k+ rows; same schema on all platforms |
| Guide import | Streaming XMLTV parse straight into SQLite, bounded window (default 1 day back, 7 ahead) | Guides of 100–700 MB crash DOM parsers on low-RAM devices |
| Xtream guide | One `xmltv.php` download, not per-channel `get_short_epg` calls | Thousands of requests trigger panel rate limits |
| Guide matching | Manual override → exact `tvg-id` → normalised name; nothing fuzzier | A wrong guide is worse than none; unmatched channels go to a review screen |
| Multi-source | "Logical channels" grouping streams from several sources, with automatic fallback | Free alternative to paid backup features |
| Onboarding | TV shows a QR code + PIN; phone opens a form served by the TV on the LAN | No remote typing, no cloud, no account |
| Web streams | No team-hosted proxy, ever. Optional self-hosted relay (Docker) | Legal exposure and blocking risk of a public relay |
| Fire TV | Fire OS devices only for now | Vega OS runs no APKs and no Flutter |

## Performance rules

- Lists and the guide grid are virtualised on both axes; never build widgets
  for off-screen rows or programmes.
- Logos are decoded at display size with a bounded memory cache.
- Sync and guide import run off the UI isolate and write in batched
  transactions.
- Zapping: short initial buffer, HTTP keep-alive, optional preload of the
  adjacent channel.
- Every source's JSON is parsed tolerantly (ids as strings or ints, dates as
  strings, numbers or null; empty results as `[]`, `{}` or `null`).

## Open risks

- LGPL relinking obligations for statically linked libmpv on iOS: legal review
  before App Store submission.
- No official Xtream or Stalker specification: test against real panels and
  keep parsers tolerant.
- Flutter performance on low-end sticks is unmeasured: the Phase 0 prototype
  must prove it on a Fire TV Stick 4K.
