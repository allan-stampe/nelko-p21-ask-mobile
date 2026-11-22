#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work
flutter create --platforms=ios --org dk.ask --project-name ask_p21_ios_test --no-pub work/ios-seed
if [[ ! -d ios ]]; then cp -R work/ios-seed/ios ios; fi
cp native/*.swift ios/Runner/
ruby <<'RUBY'
require 'xcodeproj'
project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
group = project.main_group.find_subpath('Runner', false)
['AskBLE.swift', 'BLEFlow.swift'].each do |name|
  ref = group.files.find { |f| f.path == name } || group.new_file(name)
  runner.source_build_phase.add_file_reference(ref, true)
end
project.build_configurations.each { |c| c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0' }
project.targets.each do |t|
  t.build_configurations.each do |c|
    c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    c.build_settings['SWIFT_VERSION'] = '5.0'
    c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = t.name == 'Runner' ? 'dk.ask.nelkop21.ios' : 'dk.ask.nelkop21.ios.tests'
  end
end
project.save
RUBY
python3 <<'PY'
import plistlib
from pathlib import Path
p=Path('ios/Runner/Info.plist')
d=plistlib.loads(p.read_bytes())
d['CFBundleDisplayName']='ASK P21 iOS Test'
d['NSBluetoothAlwaysUsageDescription']='Find og test din NELKO P21 lokalt via Bluetooth. Find and test your NELKO P21 locally over Bluetooth.'
d.pop('UIBackgroundModes',None)
p.write_bytes(plistlib.dumps(d))
p=Path('ios/Podfile')
if p.exists():
 s=p.read_text();s=s.replace("# platform :ios, '13.0'", "platform :ios, '15.0'");p.write_text(s)
PY
flutter pub get
