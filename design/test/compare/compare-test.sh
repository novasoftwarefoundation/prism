#!/bin/sh
# compare.sh's page shows only the images its run made, with xcodebuild faked so it runs
# anywhere in a second: an image an earlier run left in the folder is of another commit, and a
# run that made no images stops instead of showing the old ones.
#
#   sh design/test/compare/compare-test.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
fail() {
  echo "not ok: $1" >&2
  exit 1
}

# An xcodebuild that makes the iOS images, as the test does, or none with FAKE_MAKES_NONE.
mkdir "$scratch/bin"
cat > "$scratch/bin/xcodebuild" << 'EOF'
#!/bin/sh
[ -n "${FAKE_MAKES_NONE:-}" ] && exit 0
for image in compare-ios-default.png compare-ios-ax5.png; do
  echo new > "$TEST_RUNNER_PRISM_COMPARE/$image"
done
EOF
chmod +x "$scratch/bin/xcodebuild"

# An Android image of an earlier run, then iOS alone.
out="$scratch/out"
mkdir "$out"
echo old > "$out/compare-android-100.png"
PATH="$scratch/bin:$PATH" sh "$here/compare.sh" --only ios "$out" > /dev/null
grep -q 'srcset="compare-ios-default.png 3x"' "$out/index.html" || fail "the page shows this run's iOS image"
grep -q 'srcset="compare-android-100.png 3x"' "$out/index.html" && fail "the page shows an earlier run's Android image"
grep -q 'Font size 100%: not made' "$out/index.html" || fail "the page says Android was not made"
echo "ok: the page shows only this run's images"

# An iOS image of an earlier run, and a run that makes none.
rm -rf "$out"
mkdir "$out"
echo old > "$out/compare-ios-default.png"
if FAKE_MAKES_NONE=1 PATH="$scratch/bin:$PATH" sh "$here/compare.sh" --only ios "$out" > /dev/null 2>&1; then
  fail "a run that made no images succeeds"
fi
[ -f "$out/compare-ios-default.png" ] && fail "a run that made no images leaves the earlier one"
echo "ok: a run that made no images stops, and leaves no earlier image"
