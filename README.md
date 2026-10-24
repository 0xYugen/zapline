# Lineup

A free, open-source IPTV player for TV, phone, desktop and web.

Lineup plays **your own** sources: Xtream-compatible logins, M3U/M3U8 playlists
and Stalker portals, with XMLTV guides. Every feature is free: multiple
sources, multiple guides, catch-up, favourites. No account, no ads, no
paywall.

> **Lineup does not provide any content.** It ships with no playlists,
> channels or links, and the project does not endorse any provider. You are
> responsible for the legality of the sources you add.

> "Lineup" is a working codename and may change before the first store release.

## Status

Phase 0 (foundations). See [docs/ROADMAP.md](docs/ROADMAP.md).

## Targets

| Platform | Status |
|---|---|
| Android TV, Fire OS (Fire TV Stick 4K/4K Max, Cube) | planned for MVP |
| Android phones and tablets | planned for MVP |
| Windows, macOS, Linux | planned for MVP |
| iOS | after licence review of the video stack |
| Web (lite) | phase 3 |
| tvOS, Fire TV on Vega OS, Tizen, webOS | under evaluation |

## Repository layout

```
apps/lineup/          Flutter app (TV, mobile, desktop)
packages/lineup_core/ Pure Dart core: M3U, Xtream-compatible API, XMLTV, EPG matching
docs/                 Architecture and roadmap
```

`lineup_core` has no Flutter dependency and can be reused by other clients.

## Development

Requires the Flutter SDK (stable channel).

```sh
dart pub get                      # resolves the whole workspace
dart test packages/lineup_core    # core unit tests
cd apps/lineup && flutter run     # run the app
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Contributions are accepted under the
MIT licence with a Developer Certificate of Origin sign-off.

## Licence

[MIT](LICENSE). The name and logo are covered by the
[trademark policy](TRADEMARK.md).
