# Zapline

![Zapline](docs/brand/zapline-lockup.png)

A free, open-source IPTV player for TV, phone, desktop and web.

Zapline plays **your own** sources: Xtream-compatible logins, M3U/M3U8 playlists
and Stalker portals, with XMLTV guides. Every feature is free: multiple
sources, multiple guides, catch-up, favourites. No account, no ads, no
paywall.

> **Zapline does not provide any content.** It ships with no playlists,
> channels or links, and the project does not endorse any provider. You are
> responsible for the legality of the sources you add.

## Install

Builds are on the [releases page](https://github.com/0xYugen/zapline/releases/latest).

**Android TV and Fire TV**: install the free *Downloader* app from the
store on the TV, open it and type:

```
https://github.com/0xYugen/zapline/releases/latest/download/zapline-tv.apk
```

Then open Zapline on the TV, choose *Receive* and scan the code with Zapline
on your phone: sources, guides and settings come across.

**Android phones**: download
[zapline-phone.apk](https://github.com/0xYugen/zapline/releases/latest/download/zapline-phone.apk)
(64-bit) and open it.

## Status

Android phone and TV builds are out; desktop builds are next. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Targets

| Platform | Status |
|---|---|
| Android TV, Fire OS (Fire TV Stick 4K/4K Max, Cube) | available ([zapline-tv.apk](https://github.com/0xYugen/zapline/releases/latest/download/zapline-tv.apk)) |
| Android phones and tablets | available ([zapline-phone.apk](https://github.com/0xYugen/zapline/releases/latest/download/zapline-phone.apk)) |
| Windows, macOS, Linux | in progress: the app and its desktop layout are done, release builds not yet published |
| iOS | after licence review of the video stack |
| Web (lite) | phase 3 |
| Samsung (Tizen), LG (webOS), tvOS, Fire TV on Vega OS | under evaluation |

## Repository layout

```
apps/zapline/          Flutter app (TV, mobile, desktop)
packages/zapline_core/ Pure Dart core: M3U, Xtream-compatible API, XMLTV,
                      EPG matching, catch-up URLs
packages/zapline_data/ SQLite storage, source sync, backup format
tools/mock_panel/     Local Xtream-compatible test server (demo/demo)
packaging/            Flatpak, winget and desktop metadata
docs/                 Architecture, roadmap, releasing
```

`zapline_core` has no Flutter dependency and can be reused by other clients.

## Development

Requires the Flutter SDK (stable channel).

```sh
dart pub get                      # resolves the whole workspace
dart test packages/zapline_core    # core unit tests
cd apps/zapline && flutter run     # run the app
```

## Releasing

See [docs/RELEASING.md](docs/RELEASING.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Contributions are accepted under the
MIT licence with a Developer Certificate of Origin sign-off.

## Licence

[MIT](LICENSE). The name and logo are covered by the
[trademark policy](TRADEMARK.md).
