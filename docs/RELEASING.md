# Releasing

## One-time setup

### 1. Android signing key

The key identifies the app on every store. **If it is lost, the app can
never be updated again** under the same listing, so keep two offline copies.

```sh
keytool -genkeypair -v -keystore lineup-release.jks -alias lineup \
  -keyalg RSA -keysize 4096 -validity 10000
```

For local release builds create `apps/lineup/android/key.properties`
(already git-ignored):

```properties
storeFile=/absolute/path/to/lineup-release.jks
storePassword=...
keyAlias=lineup
keyPassword=...
```

Without it, release builds are signed with the debug key (fine for testing,
not for publishing).

### 2. GitHub secrets (for the release workflow)

| Secret | Value |
|---|---|
| `LINEUP_KEYSTORE_BASE64` | `base64 -w0 lineup-release.jks` |
| `LINEUP_KEYSTORE_PASSWORD` | store password |
| `LINEUP_KEY_ALIAS` | `lineup` |
| `LINEUP_KEY_PASSWORD` | key password |

### 3. Placeholders to replace

- `OWNER` in `packaging/` (GitHub account hosting the project). Flathub
  requires an app id under a domain you control, or `io.github.OWNER.*`.
- `REPLACE_WITH_SHA256` in the Flatpak and winget manifests (take the values
  from `SHA256SUMS.txt` of the release).
- The final product name if "Lineup" changes: Android `applicationId`
  (`android/app/build.gradle.kts`) must be fixed before the first store
  upload.
- App icon and TV banner: the current ones are placeholders.

## Cutting a release

1. Update `version:` in `apps/lineup/pubspec.yaml` (e.g. `0.2.0+2`; the
   number after `+` must increase for Android).
2. Add `apps/lineup/fastlane/metadata/android/en-US/changelogs/<build>.txt`.
3. `git tag v0.2.0 && git push --tags`.
4. The **Release** workflow builds Android (split APKs + AAB), Windows (zip),
   Linux (tar.gz) and macOS (unsigned zip), and opens a **draft** GitHub
   release with `SHA256SUMS.txt`. Review it, then publish.

## Channels

| Channel | What to submit | Notes |
|---|---|---|
| GitHub Releases | automatic (draft) | primary channel for APK sideloading |
| Google Play | the `.aab` | target the API level Play requires that year; complete the Android TV checklist (banner, D-pad, no touch requirement); listing must say no content is included |
| Amazon Appstore (Fire OS) | `app-armeabi-v7a-release.apk` and `app-arm64-v8a-release.apk` | Fire TV sticks before the 4K generation are 32-bit |
| F-Droid | merge request to fdroiddata using `fastlane/metadata` | builds from source; no proprietary dependencies are used |
| Flathub | `packaging/flatpak/` | manifest not yet test-built (see below) |
| winget | `packaging/winget/` to microsoft/winget-pkgs | portable zip install |

Store listings: never mention providers, show only the app with its own test
streams, keep "Xtream" out of titles and keywords (see the research notes on
store policy).

## Not yet verified

- The Linux and macOS jobs and the Flatpak manifest have not been run yet
  (they need a Linux/macOS machine or CI). The libmpv module in the Flatpak
  manifest also needs FFmpeg from the runtime's codecs extension; expect to
  adjust it on the first Flathub build.
- macOS builds are unsigned and not notarised: Gatekeeper will warn.
- iOS is not packaged: App Store submission waits for the licence review of
  the bundled libmpv/FFmpeg (see docs/ARCHITECTURE.md).
