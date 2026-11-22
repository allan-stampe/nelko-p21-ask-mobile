#!/usr/bin/env bash
set -euo pipefail
mkdir -p out/simulator
xcrun simctl list devices available -j > out/simulator/devices.json
sim_id=$(python3 - <<'PY'
import json
j=json.load(open('out/simulator/devices.json'))
for runtime,devices in sorted(j['devices'].items(),reverse=True):
 if 'iOS' not in runtime: continue
 for d in devices:
  if d['isAvailable'] and d['name'].startswith('iPhone'):
   print(d['udid']);raise SystemExit
raise SystemExit('No iPhone simulator available')
PY
)
xcrun simctl boot "$sim_id" || true
xcrun simctl bootstatus "$sim_id" -b
xcrun simctl install "$sim_id" build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$sim_id" dk.ask.nelkop21.ios | tee out/simulator/launch.txt
sleep 5
xcrun simctl spawn "$sim_id" launchctl list | tee out/simulator/processes.txt
grep -F dk.ask.nelkop21.ios out/simulator/processes.txt
xcrun simctl io "$sim_id" screenshot out/simulator/startup.png
xcrun simctl terminate "$sim_id" dk.ask.nelkop21.ios
