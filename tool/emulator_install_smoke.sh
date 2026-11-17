#!/usr/bin/env bash
set -euo pipefail
apk=$1
report=$2
mkdir -p "$report"
package=dk.ask.nelko_p21_ask_mobile
adb shell getprop > "$report/device-properties.txt"
adb shell getconf PAGE_SIZE > "$report/page-size.txt"
adb logcat -c
# Test a fresh installation, with no -t, low-target bypass, resigning or repacking.
if adb shell pm list packages | tr -d '\r' | grep -Fxq "package:$package"; then
  echo 'Unexpected pre-existing package in fresh emulator' >&2
  exit 1
fi
set +e
adb install --no-streaming "$apk" > "$report/install.txt" 2>&1
result=$?
set -e
cat "$report/install.txt"
adb logcat -d > "$report/install-logcat.txt"
if [ "$result" -ne 0 ]; then exit "$result"; fi
grep -Fxq 'Success' "$report/install.txt"
adb shell dumpsys package "$package" > "$report/package.txt"
adb shell am start -W -n "$package/.MainActivity" > "$report/launch.txt"
cat "$report/launch.txt"
grep -Eq '^Status: ok' "$report/launch.txt"
sleep 8
adb shell pidof "$package" > "$report/pid.txt"
adb logcat -d > "$report/launch-logcat.txt"
adb exec-out screencap -p > "$report/launched.png"
adb shell dumpsys activity activities > "$report/activities.txt"
echo 'Fresh APK installation and app launch succeeded. Bluetooth hardware is NOT validated.'
