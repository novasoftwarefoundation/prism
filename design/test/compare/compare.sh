#!/bin/sh
# The compare: the same screen, a component of every kind, on Android, iOS and the web, at the
# default text size and at the largest, from this checkout, into a folder (default
# design/test/compare/out): six images and index.html, which shows them side by side.
#
#   design/test/compare/compare.sh [--only android|ios|web] [folder]
#
# compare-android-100.png, compare-android-200.png  Compose on the JVM (Robolectric), font size
#   100% and 200% (design/test/compose, CompareScreenTest). Needs Gradle 9.9.2 (GRADLE, or
#   gradle on the PATH), JDK 17 (JAVA_HOME) and the Android SDK with the 37.1 platform
#   (ANDROID_HOME), as CI's kotlin job.
# compare-ios-default.png, compare-ios-ax5.png  SwiftUI on the iOS Simulator, Dynamic Type
#   Large and AX5 (design/test/swiftui, CompareScreenTests). Needs Xcode and the simulator
#   IOS_SIMULATOR (default "iPhone 17").
# compare-web-100.png, compare-web-200.png  Prism's React components with the web package's
#   CSS in Chrome, zoom 100% and 200% (web.mjs). Needs Node and Google Chrome (CHROME, or
#   found).
#
# Each is 3 pixels a point, dp or CSS pixel, of a screen 393 wide. Release runs make the
# same images and attach them to the GitHub release (.github/workflows/release.yml).
set -eu

repo=$(cd "$(dirname "$0")/../../.." && pwd)
only=
if [ "${1:-}" = --only ]; then
  only=$2
  shift 2
  case $only in android | ios | web) ;; *) echo "--only android, ios or web, not $only" >&2; exit 2 ;; esac
fi
mkdir -p "${1:-$repo/design/test/compare/out}"
out=$(cd "${1:-$repo/design/test/compare/out}" && pwd)
logs=$(mktemp -d)
trap 'rm -rf "$logs"' EXIT

# Runs a step with its output in a log, which it shows when the step fails.
step() {
  name=$1
  shift
  echo "$name"
  "$@" > "$logs/log" 2>&1 || {
    tail -n 80 "$logs/log" >&2
    echo "$name failed" >&2
    exit 1
  }
}

android() {
  step "Android: Compose at 100% and 200%" env PRISM_COMPARE="$out" "${GRADLE:-gradle}" \
    -p "$repo/design/test/compose" --no-daemon testDebugUnitTest --tests '*.CompareScreenTest' --rerun
}

ios() {
  # xcodebuild hands TEST_RUNNER_-prefixed variables to the tests, without the prefix.
  step "iOS: SwiftUI at Large and AX5" env TEST_RUNNER_PRISM_COMPARE="$out" xcodebuild test \
    -scheme PrismChecks-Package -destination "platform=iOS Simulator,name=${IOS_SIMULATOR:-iPhone 17}" \
    -derivedDataPath "${TMPDIR:-/tmp}/prism-compare-xcode" -only-testing:PrismTests/CompareScreenTests \
    -quiet
}

web_shot() { # image, window width, device scale factor, page
  height=$("$chrome" --headless=new --disable-gpu --hide-scrollbars --user-data-dir="$logs/chrome" \
    --virtual-time-budget=5000 --window-size="$2,1000" --force-device-scale-factor="$3" \
    --dump-dom "$4" 2> /dev/null | sed -n 's/.*data-height="\([0-9]*\)".*/\1/p')
  [ -n "$height" ] || { echo "Chrome gave no height for $4" >&2; exit 1; }
  step "  $1" "$chrome" --headless=new --disable-gpu --hide-scrollbars --user-data-dir="$logs/chrome" \
    --virtual-time-budget=5000 --window-size="$2,$height" --force-device-scale-factor="$3" \
    --screenshot="$out/$1" "$4"
}

web() {
  chrome=${CHROME:-}
  if [ -z "$chrome" ]; then
    chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    [ -x "$chrome" ] || chrome=$(command -v google-chrome || command -v chromium || true)
  fi
  [ -n "$chrome" ] || { echo "No Chrome: set CHROME to its binary" >&2; exit 1; }
  if [ ! -d "$repo/targets/react/node_modules" ]; then
    step "Web: npm ci in targets/react" npm ci --prefix "$repo/targets/react"
  fi
  step "Web: React components at 100% and 200% zoom" npm run --prefix "$repo/targets/react" build
  node "$repo/design/test/compare/web.mjs" "$out"
  # A 393 px screen, with room past its edge to show what runs off it. At 200% the screen is
  # half as wide in CSS pixels and each one twice the size, as with Chrome's zoom.
  web_shot compare-web-100.png 457 3 "file://$out/compare-web.html"
  web_shot compare-web-200.png 229 6 "file://$out/compare-web.html#200"
}

case $only in
  android) android ;;
  ios) (cd "$repo/design/test/swiftui" && ios) ;;
  web) web ;;
  *)
    android
    (cd "$repo/design/test/swiftui" && ios)
    web
    ;;
esac

commit=$(git -C "$repo" rev-parse --short HEAD)
[ -z "$(git -C "$repo" status --porcelain)" ] || commit="$commit with changes"
cell() { # image, caption
  if [ -f "$out/$1" ]; then
    printf '<td><figure><img srcset="%s 3x" alt="%s"><figcaption>%s</figcaption></figure></td>\n' "$1" "$2" "$2"
  else
    printf '<td>%s: not made</td>\n' "$2"
  fi
}
{
  cat << EOF
<!doctype html>
<html lang="en">
<meta charset="utf-8">
<title>Prism compare</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 24px; color: #222; }
  table { border-spacing: 32px 0; margin-left: -32px; }
  th { text-align: left; font-size: 20px; }
  td { vertical-align: top; }
  figure { margin: 0 0 32px; }
  img { display: block; box-shadow: 0 0 0 1px #ddd; }
  figcaption { margin-top: 8px; color: #666; }
</style>
<h1>Prism compare</h1>
<p>The same screen on each target, at the default text size and at the largest, from $commit.</p>
<table>
<tr><th>Android</th><th>iOS</th><th>Web</th></tr>
<tr>
EOF
  cell compare-android-100.png "Font size 100%"
  cell compare-ios-default.png "Dynamic Type Large (default)"
  cell compare-web-100.png "Zoom 100%"
  echo '</tr>'
  echo '<tr>'
  cell compare-android-200.png "Font size 200%"
  cell compare-ios-ax5.png "Dynamic Type AX5"
  cell compare-web-200.png "Zoom 200%"
  echo '</tr>'
  echo '</table>'
} > "$out/index.html"
echo "$out/index.html"
