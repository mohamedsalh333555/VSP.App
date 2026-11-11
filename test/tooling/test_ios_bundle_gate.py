import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('ios_gate', Path(__file__).resolve().parents[2] / 'scripts/verify_ios_bundle.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class IOSBundleGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.bundle = Path(self.temp.name) / 'Runner.app'
        self.bundle.mkdir()
        self.info = {'CFBundleIdentifier': 'app.vsp.sports', 'CFBundleExecutable': 'Runner',
                     'DTPlatformName': 'iphoneos', 'DTSDKName': 'iphoneos26.2',
                     'MinimumOSVersion': '13.0', 'GOOGLE_ANALYTICS_IDFA_COLLECTION_ENABLED': False}
        (self.bundle / 'Runner').write_bytes(b'\xcf\xfa\xed\xfe' + b'test fixture only')
        self.manifest = self.bundle / 'SDK.bundle' / 'PrivacyInfo.xcprivacy'
        self.manifest.parent.mkdir()
        self.manifest.write_bytes(plistlib.dumps({'NSPrivacyTracking': False}))

    def inspect(self):
        (self.bundle / 'Info.plist').write_bytes(plistlib.dumps(self.info))
        return gate.inspect_bundle(self.bundle)

    def test_compiled_metadata_and_manifest_inventory(self):
        result = self.inspect()
        self.assertEqual(result['privacy_manifest_count'], 1)
        self.assertEqual(result['privacy_manifests'][0]['path'], 'SDK.bundle/PrivacyInfo.xcprivacy')

    def test_old_sdk_rejected(self):
        self.info['DTSDKName'] = 'iphoneos18.5'
        with self.assertRaisesRegex(ValueError, 'SDK_26'): self.inspect()

    def test_simulator_is_not_a_device_build(self):
        self.info['DTPlatformName'] = 'iphonesimulator'
        with self.assertRaisesRegex(ValueError, 'SDK_26'): self.inspect()

    def test_placeholder_identity_rejected(self):
        self.info['CFBundleIdentifier'] = 'com.example.vspApplication'
        with self.assertRaisesRegex(ValueError, 'BUNDLE_ID'): self.inspect()

    def test_old_deployment_target_rejected(self):
        self.info['MinimumOSVersion'] = '12.0'
        with self.assertRaisesRegex(ValueError, 'MINIMUM_13'): self.inspect()

    def test_ad_identifier_must_be_disabled(self):
        del self.info['GOOGLE_ANALYTICS_IDFA_COLLECTION_ENABLED']
        with self.assertRaisesRegex(ValueError, 'IDFA'): self.inspect()

    def test_missing_manifests_rejected(self):
        self.manifest.unlink()
        with self.assertRaisesRegex(ValueError, 'INVENTORY_EMPTY'): self.inspect()

    def test_non_binary_placeholder_rejected(self):
        (self.bundle / 'Runner').write_text('not a compiled binary')
        with self.assertRaisesRegex(ValueError, 'NOT_MACHO'): self.inspect()


if __name__ == '__main__': unittest.main()
