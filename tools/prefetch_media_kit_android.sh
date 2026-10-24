#!/usr/bin/env sh
# Pre-downloads media_kit's libmpv Android binaries into the Gradle build
# folder. The plugin's own downloader uses Java's URL client, which GitHub's
# release CDN currently answers with HTTP 406. Gradle still verifies the MD5
# checksums after this script runs.
#
# Temporary: Android playback moves to Media3 (see docs/ROADMAP.md).
set -eu

VERSION=v1.1.7
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/apps/lineup/build/media_kit_libs_android_video/$VERSION"
mkdir -p "$DEST"

for abi in arm64-v8a armeabi-v7a x86_64 x86; do
  f="$DEST/default-$abi.jar"
  [ -s "$f" ] && continue
  echo "Downloading default-$abi.jar"
  curl -fsSL -o "$f" \
    "https://github.com/media-kit/libmpv-android-video-build/releases/download/$VERSION/default-$abi.jar"
done
