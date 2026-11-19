#!/usr/bin/env python3
"""Inspect the compiled unsigned iOS bundle; does not certify store disclosures."""
import argparse
import json
import plistlib
import re
from pathlib import Path


def inspect_bundle(bundle):
    bundle = Path(bundle)
    with (bundle / 'Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    if info.get('CFBundleIdentifier') != 'app.vsp.sports':
        raise ValueError('IOS_BUNDLE_ID_MISMATCH')
    sdk = re.fullmatch(r'iphoneos(\d+)(?:\.\d+)*', info.get('DTSDKName', ''))
    if info.get('DTPlatformName') != 'iphoneos' or not sdk or int(sdk.group(1)) < 26:
        raise ValueError('IOS_SDK_26_REQUIRED')
    minimum = str(info.get('MinimumOSVersion', ''))
    if not re.fullmatch(r'\d+(?:\.\d+)*', minimum) or int(minimum.split('.')[0]) < 13:
        raise ValueError('IOS_MINIMUM_13_REQUIRED')
    if info.get('GOOGLE_ANALYTICS_IDFA_COLLECTION_ENABLED') is not False:
        raise ValueError('IOS_ANALYTICS_IDFA_NOT_DISABLED')
    executable = info.get('CFBundleExecutable', '')
    if not executable or Path(executable).name != executable:
        raise ValueError('IOS_EXECUTABLE_INVALID')
    binary = bundle / executable
    with binary.open('rb') as stream:
        magic = stream.read(4)
    if magic not in (b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'):
        raise ValueError('IOS_EXECUTABLE_NOT_MACHO')
    manifests = []
    for path in sorted(bundle.rglob('PrivacyInfo.xcprivacy')):
        with path.open('rb') as stream:
            manifest = plistlib.load(stream)
        if not isinstance(manifest, dict):
            raise ValueError('IOS_PRIVACY_MANIFEST_INVALID')
        manifests.append({'path': str(path.relative_to(bundle)), 'declarations': manifest})
    if not manifests:
        raise ValueError('IOS_PRIVACY_MANIFEST_INVENTORY_EMPTY')
    return {'compiled_bundle_checks': 'PASS', 'bundle_id': info['CFBundleIdentifier'],
            'sdk': info['DTSDKName'], 'minimum_os': minimum,
            'privacy_manifest_count': len(manifests), 'privacy_manifests': manifests,
            'limits': ['Unsigned compile is not a signed archive, install or App Store acceptance',
                       'Manifest inventory is not complete App Privacy/Data Safety verification',
                       'Google OAuth, Apple sign-in and APNs need real account/device validation']}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--bundle', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    result = inspect_bundle(args.bundle)
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.output).write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: value for key, value in result.items() if key != 'privacy_manifests'}))


if __name__ == '__main__':
    main()
