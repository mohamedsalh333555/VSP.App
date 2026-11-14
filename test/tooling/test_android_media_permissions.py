import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CHECKER = Path(__file__).resolve().parents[2] / 'scripts/verify_android_media_permissions.py'
BASE = "package: name='app.vsp.sports'\nuses-permission: name='android.permission.INTERNET'\nuses-permission: name='android.permission.CAMERA'\n"


class CompiledMediaGateTests(unittest.TestCase):
    def check_output(self, output, apk_exists=True):
        # A controlled SDK-tool fixture tests the gate, not a real APK build.
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            aapt = directory / 'aapt'
            aapt.write_text('#!' + sys.executable + '\nprint(' + repr(output) + ')\n')
            aapt.chmod(0o755)
            apk = directory / 'fixture.apk'
            if apk_exists:
                apk.write_bytes(b'tool-test-fixture-only')
            return subprocess.run([sys.executable, str(CHECKER), '--apk', str(apk), '--aapt', str(aapt)], capture_output=True, text=True)

    def test_accepts_scoped_media_with_optional_hardware(self):
        result = self.check_output(BASE + "uses-feature-not-required: name='android.hardware.camera'\n")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_every_broad_media_storage_permission(self):
        for permission in ['READ_EXTERNAL_STORAGE', 'WRITE_EXTERNAL_STORAGE', 'READ_MEDIA_IMAGES', 'READ_MEDIA_VIDEO', 'MANAGE_EXTERNAL_STORAGE']:
            with self.subTest(permission=permission):
                self.assertEqual(self.check_output(BASE + f"uses-permission: name='android.permission.{permission}'\n").returncode, 1)

    def test_rejects_required_camera_or_location(self):
        for feature in ['camera', 'camera.any', 'camera.autofocus', 'location', 'location.gps', 'location.network']:
            with self.subTest(feature=feature):
                self.assertEqual(self.check_output(BASE + f"uses-feature: name='android.hardware.{feature}'\n").returncode, 1)

    def test_rejects_ad_identifier_and_attribution_permissions(self):
        for permission in ['com.google.android.gms.permission.AD_ID', 'android.permission.ACCESS_ADSERVICES_AD_ID', 'android.permission.ACCESS_ADSERVICES_ATTRIBUTION']:
            with self.subTest(permission=permission):
                self.assertEqual(self.check_output(BASE + f"uses-permission: name='{permission}'\n").returncode, 1)

    def test_missing_artifact_is_blocked_not_passed(self):
        self.assertEqual(self.check_output(BASE, apk_exists=False).returncode, 2)

    def test_unrecognized_permission_output_cannot_pass(self):
        self.assertEqual(self.check_output('unexpected tool output').returncode, 1)


if __name__ == '__main__':
    unittest.main()
