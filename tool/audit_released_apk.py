#!/usr/bin/env python3
"""Audit an immutable release APK; no repacking or resigning is performed."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
from zipfile import ZipFile

p = argparse.ArgumentParser()
p.add_argument('apk', type=Path)
p.add_argument('--sha256', required=True)
p.add_argument('--build-tools', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)
data = a.apk.read_bytes()
assert hashlib.sha256(data).hexdigest() == a.sha256, 'Released APK SHA256 mismatch'

def run(name, args):
    result = subprocess.run([str(x) for x in args], text=True, capture_output=True)
    (a.output / name).write_text(result.stdout + result.stderr)
    print(name, 'exit', result.returncode)
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout

run('signature.txt', [a.build_tools/'apksigner', 'verify', '--verbose', '--print-certs', a.apk])
run('alignment.txt', [a.build_tools/'zipalign', '-c', '-P', '16', '-v', '4', a.apk])
run('badging.txt', [a.build_tools/'aapt2', 'dump', 'badging', a.apk])
run('manifest-tree.txt', [a.build_tools/'aapt2', 'dump', 'xmltree', a.apk, '--file', 'AndroidManifest.xml'])
records = []
with ZipFile(a.apk) as z:
    assert z.testzip() is None, 'ZIP CRC failure'
    assert len(z.namelist()) == len(set(z.namelist())), 'Duplicate ZIP entries'
    assert 'classes.dex' in z.namelist()
    for info in z.infolist():
        if not info.filename.startswith('lib/') or not info.filename.endswith('.so'):
            continue
        content = z.read(info)
        assert content[:4] == b'\x7fELF', info.filename
        machine = struct.unpack_from('<H', content, 18)[0]
        abi = info.filename.split('/')[1]
        assert machine == {'arm64-v8a': 183, 'armeabi-v7a': 40, 'x86_64': 62}[abi]
        name_length, extra_length = struct.unpack_from('<HH', data, info.header_offset + 26)
        offset = info.header_offset + 30 + name_length + extra_length
        record = dict(path=info.filename, elf_machine=machine, elf_bits=64 if content[4] == 2 else 32,
                      bytes=info.file_size, compression=info.compress_type, data_offset=offset,
                      zip_aligned_16k=offset % 16384 == 0)
        dest = a.output/'elf'/info.filename
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(content)
        run(info.filename.replace('/', '_') + '.txt', ['readelf', '-lW', dest])
        records.append(record)
    assert {r['path'].split('/')[1] for r in records} == {'arm64-v8a','armeabi-v7a','x86_64'}
(a.output/'integrity.json').write_text(json.dumps(dict(sha256=a.sha256, size=len(data), zip_crc='OK', libraries=records), indent=2))
print('Release SHA256, ZIP CRC, signature, ZIP alignment and ELF architectures checked.')
