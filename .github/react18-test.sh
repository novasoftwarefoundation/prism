#!/bin/sh
# Checks that an interrupted `.github/react18.sh --update` puts package.json and
# package-lock.json back, for each signal that can end it: Ctrl-C (INT), SIGTERM, a
# closed terminal (HUP) and Ctrl-\ (QUIT). A stub npm pins package.json, then sends the
# signal to the script while `npm install` runs, as a terminal sends it to the whole
# foreground job.
#
#   .github/react18-test.sh [shell]    # the shell that runs react18.sh, default sh
#
# CI runs it with sh, which is dash on Ubuntu: dash runs no EXIT trap when a signal
# ends it, so each signal needs a trap of its own.
set -eu

shell=${1:-sh}
script=$(cd "$(dirname "$0")" && pwd)/react18.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir "$work/bin"
cat > "$work/bin/npm" <<'EOF'
#!/bin/sh
case "$1" in
  pkg) printf '{"pinned": true}\n' > package.json ;;
  install) kill -s "$SIGNAL" "$PPID" ;;
esac
EOF
chmod +x "$work/bin/npm"

failed=0

for case in INT:130 TERM:143 HUP:129 QUIT:131; do
  signal=${case%:*}
  expected=${case#*:}
  dir="$work/$signal"
  mkdir "$dir" "$dir.before"
  printf '{"name": "package"}\n' > "$dir.before/package.json"
  printf '{"lockfileVersion": 3}\n' > "$dir.before/package-lock.json"
  cp "$dir.before/package.json" "$dir.before/package-lock.json" "$dir/"

  status=0
  (cd "$dir" && PATH="$work/bin:$PATH" SIGNAL=$signal "$shell" "$script" --update) || status=$?

  if [ "$status" != "$expected" ]; then
    echo "SIG$signal: react18.sh exited with $status, not $expected"
    failed=1
  fi

  for file in package.json package-lock.json; do
    if ! cmp -s "$dir/$file" "$dir.before/$file"; then
      echo "SIG$signal: $file was not put back"
      failed=1
    fi
  done

  if [ -e "$dir/test/react18" ]; then
    echo "SIG$signal: the React 18 lockfile was written"
    failed=1
  fi
done

if [ "$failed" = 0 ]; then echo "react18.sh --update puts the package back on INT, TERM, HUP and QUIT ($shell)"; fi
exit "$failed"
