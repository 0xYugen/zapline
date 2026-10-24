#!/usr/bin/env sh
# Android release build with a version code that grows with every commit,
# so each build installs over the previous one as an update.
#
#   tool/build_android.sh            # APKs per ABI (arm64, armv7, x86_64)
#   tool/build_android.sh appbundle  # AAB for Google Play
set -e
cd "$(dirname "$0")/.."
name=$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)
code=$(git rev-list --count HEAD)
target=${1:-apk}
extra=""
[ "$target" = apk ] && extra="--split-per-abi"
flutter build "$target" --release $extra \
  --build-name "$name" --build-number "$code" \
  --dart-define=ZAPLINE_VERSION="$name ($code)"
echo "Built Zapline $name ($code)"
