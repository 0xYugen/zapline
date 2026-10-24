# Contributing

Thanks for helping! A few rules keep the project healthy and distributable.

## Developer Certificate of Origin

Every commit must be signed off (`git commit -s`), certifying the
[DCO](https://developercertificate.org/): you wrote the change or have the
right to submit it under the MIT licence.

## Licences of dependencies

Lineup is MIT and is distributed through app stores, so:

- **Never copy code from GPL/AGPL projects** (Kodi add-ons, Hypnotix,
  Megacubo, Fred TV, OwnTV, M3UAndroid, Dispatcharr...). Reading them for
  understanding is fine; reimplement from specs and observed behaviour.
- New dependencies must be MIT, BSD, Apache-2.0, ISC, Zlib, Unlicense or
  similar. LGPL is allowed only for the video engine (libmpv/FFmpeg) and only
  as builds that are verified LGPL (`-Dgpl=false`, no `--enable-gpl`).
- Avoid "non-commercial" licences (CC BY-NC etc.); they are not open source.

## Content policy

- Do not add playlists, channel lists, provider links or provider names to
  code, tests, screenshots, docs or issues. Test fixtures use `*.example`
  domains.
- Issues asking where to find streams will be closed.

## Code

- Run `dart format .`, `dart analyze` and the tests before opening a PR.
- Keep `lineup_core` free of Flutter and `dart:io` imports so it runs on
  every platform, web included.
- Everything in the repository is written in English.
