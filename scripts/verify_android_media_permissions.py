#!/usr/bin/env python3
"""Check the compiled APK, including merged dependency manifest permissions."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

FORBIDDEN = {
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.WRITE_EXTERNAL_STORAGE',
    'android.permission.READ_MEDIA_IMAGES',
    'android.permission.READ_MEDIA_VIDEO',
    'android.permission.MANAGE_EXTERNAL_STORAGE',
}
OPTIONAL_HARDWARE = {
    'android.hardware.camera', 'android.hardware.camera.any', 'android.hardware.camera.autofocus',
    'android.hardware.location', 'android.hardware.location.gps',
    'android.hardware.location.network',
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apk', type=Path, default=Path('build/app/outputs/flutter-apk/app-debug.apk'))
    parser.add_argument('--aapt', type=Path)
    args = parser.parse_args()
    aapt = args.aapt or shutil.which('aapt')
    if not aapt:
        sdk = os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME')
        candidates = list((Path(sdk) / 'build-tools').glob('*/aapt')) if sdk else []
        def version(path):
            return tuple(int(n) for n in re.findall(r'\d+', path.parent.name))
        aapt = max(candidates, key=version) if candidates else None
    if not aapt or not args.apk.is_file():
        print('BLOCKED: built APK and Android aapt are required; source XML is not compiled evidence.', file=sys.stderr)
        return 2
    result = subprocess.run([str(aapt), 'dump', 'badging', str(args.apk)], capture_output=True, text=True, check=True)
    permissions = set(re.findall(r"^uses-permission(?:-sdk-\d+)?: name='([^']+)'", result.stdout, re.M))
    required = set(re.findall(r"^uses-feature: name='([^']+)'", result.stdout, re.M))
    errors = sorted(FORBIDDEN & permissions) + sorted(OPTIONAL_HARDWARE & required)
    package = re.search(r"^package: name='([^']+)'", result.stdout, re.M)
    if not package or package.group(1) != 'app.vsp.sports':
        errors.append('Expected VSP package app.vsp.sports missing: wrong APK or output.')
    if 'android.permission.INTERNET' not in permissions or 'android.permission.CAMERA' not in permissions:
        errors.append('Expected internet/camera permissions missing: check APK or parser.')
    print('Compiled APK requested permissions:', ', '.join(sorted(permissions)))
    print('Required hardware features:', ', '.join(sorted(required)))
    if errors:
        print('FAIL:', ', '.join(errors), file=sys.stderr)
        return 1
    print('PASS: no broad media/storage permissions or required camera/location hardware.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
