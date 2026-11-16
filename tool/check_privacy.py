#!/usr/bin/env python3
"""Check authored manifest and, in CI, actual merged APK permissions."""
import argparse
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

parser=argparse.ArgumentParser()
parser.add_argument('--apk')
parser.add_argument('--apkanalyzer')
args=parser.parse_args()
a='{http://schemas.android.com/apk/res/android}'
path=Path('android/app/src/main/AndroidManifest.xml')
root=ET.parse(path).getroot()
forbidden={'android.permission.INTERNET','android.permission.ACCESS_NETWORK_STATE',
           'com.google.android.gms.permission.AD_ID','android.permission.ACCESS_BACKGROUND_LOCATION'}
permissions={p.get(a+'name'):p for p in root.findall('uses-permission')}
assert not forbidden.intersection(permissions)
assert permissions['android.permission.ACCESS_FINE_LOCATION'].get(a+'maxSdkVersion')=='30'
assert permissions['android.permission.BLUETOOTH_SCAN'].get(a+'usesPermissionFlags')=='neverForLocation'
app=root.find('application')
assert app is not None and app.get(a+'allowBackup')=='false'
assert app.get(a+'usesCleartextTraffic')=='false'
assert Path('assets/licenses/Windows-MIT.txt').exists()
if args.apk:
    assert args.apkanalyzer
    xml=subprocess.check_output([args.apkanalyzer,'manifest','print',args.apk],text=True)
    merged=ET.fromstring(xml)
    granted={p.get(a+'name') for p in merged.findall('uses-permission')}
    assert not forbidden.intersection(granted),granted
    assert merged.find('application').get(a+'allowBackup')=='false'
    print('Merged APK has no INTERNET/network-state/AD_ID/background-location permission and disables backup.')
print('Offline/privacy manifest checks passed.')
