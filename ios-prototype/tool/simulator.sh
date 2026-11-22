#!/usr/bin/env bash
set -euo pipefail
mkdir -p out/simulator
xcrun simctl list devices available -j > out/simulator/devices.json
sim_id=$(python3 - <<'PY'
import json
j=json.load(open('out/simulator/devices.json'))
# Match the pinned SDK; a fresh latest-runtime migration can take many minutes.
devices=j['devices'].get('com.apple.CoreSimulator.SimRuntime.iOS-26-2',[])
for d in sorted(devices,key=lambda d:(d['name']!='iPhone 16e',d['name'])):
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
python3 - <<'PYCODE'
from pathlib import Path
rows=[r.split() for r in Path('out/simulator/processes.txt').read_text().splitlines() if 'dk.ask.nelkop21.ios' in r]
assert any(r[0].isdigit() and int(r[0])>0 for r in rows), 'App process did not remain running'
PYCODE
xcrun simctl io "$sim_id" screenshot out/simulator/startup.png
xcrun simctl terminate "$sim_id" dk.ask.nelkop21.ios
