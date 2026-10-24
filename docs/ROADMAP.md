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
- [ ] Player abstraction; Media3 on Android (the prototype currently uses
      media_kit/libmpv on every platform)
- [ ] Verify whether media_kit's prebuilt libmpv/FFmpeg binaries are LGPL;
      otherwise build our own
- [ ] Android build (needs Android SDK 36 on the dev machine)
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
