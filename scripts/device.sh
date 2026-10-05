#!/usr/bin/env bash
# Prints the id of a running iOS simulator or Android emulator for
# `flutter run -d`, starting one first if none is running.
#
# flutter's -d matches a device's name or id, never its platform, so
# `flutter run -d ios` fails even with an iPhone simulator open (its id is a
# UUID). Progress messages go to stderr so stdout is only the id.
set -euo pipefail

platform="${1:?usage: device.sh ios|android}"

find_id() {
  flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
for d in json.load(sys.stdin):
    if d["targetPlatform"].startswith(sys.argv[1]):
        print(d["id"])
        break
' "$platform"
}

id=$(find_id || true)

if [ -z "$id" ]; then
  case "$platform" in
    ios)
      udid=$(xcrun simctl list devices available | grep -m1 'iPhone' \
        | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' || true)
      [ -n "$udid" ] || { echo "No iPhone simulator installed. Add one in Xcode > Settings > Components." >&2; exit 1; }
      echo "Booting iOS simulator..." >&2
      xcrun simctl boot "$udid"
      ;;
    android)
      avd=$(flutter emulators 2>/dev/null \
        | awk -F' • ' '$4 ~ /android/ { sub(/ +$/, "", $1); print $1; exit }')
      [ -n "$avd" ] || { echo "No Android emulator set up. Create one in Android Studio > Device Manager." >&2; exit 1; }
      echo "Starting Android emulator $avd (a cold boot can take a minute)..." >&2
      flutter emulators --launch "$avd" >/dev/null
      ;;
    *)
      echo "usage: device.sh ios|android" >&2
      exit 2
      ;;
  esac

  for _ in $(seq 1 90); do
    id=$(find_id || true)
    [ -n "$id" ] && break
    sleep 2
  done
  [ -n "$id" ] || { echo "Timed out waiting for the $platform device to appear." >&2; exit 1; }
fi

# simctl boots headless; bring the window up so there is something to look at.
[ "$platform" = ios ] && open -a Simulator

echo "$id"
