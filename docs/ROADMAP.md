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
