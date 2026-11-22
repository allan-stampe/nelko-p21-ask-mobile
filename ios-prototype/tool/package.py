import hashlib, plistlib, shutil, subprocess, zipfile
from pathlib import Path
app=Path('build/ios/iphoneos/Runner.app')
p=plistlib.loads((app/'Info.plist').read_bytes())
assert p['CFBundleIdentifier']=='dk.ask.nelkop21.ios'
assert p['CFBundleShortVersionString']=='0.0.1'
assert p['CFBundleSupportedPlatforms']==['iPhoneOS']
assert float(p['MinimumOSVersion'])==15.0
assert p['NSBluetoothAlwaysUsageDescription']
assert not p.get('UIBackgroundModes')
for binary in ['Runner','Frameworks/App.framework/App','Frameworks/Flutter.framework/Flutter']:
    arch=subprocess.check_output(['lipo','-archs',str(app/binary)],text=True).strip()
    assert arch=='arm64',(binary,arch)
    load=subprocess.check_output(['otool','-l',str(app/binary)],text=True)
    assert 'cryptid 1' not in load
out=Path('out');out.mkdir(exist_ok=True)
stage=Path('work/package/Payload');stage.mkdir(parents=True,exist_ok=True)
shutil.copytree(app,stage/'Runner.app',dirs_exist_ok=True)
ipa=out/'NELKO-P21-ASK-iOS-BLE-Test-v0.0.1-unsigned.ipa'
subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(stage),str(ipa.resolve())],check=True)
with zipfile.ZipFile(ipa) as z:
    assert z.testzip() is None
    assert 'Payload/Runner.app/Info.plist' in z.namelist()
(out/'SHA256SUMS.txt').write_text(hashlib.sha256(ipa.read_bytes()).hexdigest()+'  '+ipa.name+'\n')
for src,name in [('README.md','IOS-README.md'),('PROTOCOL.md','IOS-PROTOCOL.md'),('../LICENSE','LICENSE'),('../assets/licenses/Windows-MIT.txt','Windows-MIT.txt'),('../THIRD_PARTY_NOTICES.md','THIRD_PARTY_NOTICES.md'),('../assets/licenses/Go-Fonts.txt','GO-FONTS-LICENSE.txt')]:
    shutil.copyfile(src,out/name)
print('Verified device arm64 IPA; intentionally unsigned. Install only after local Apple signing.')
