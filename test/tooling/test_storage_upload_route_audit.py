import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "storage_upload_audit", ROOT / "scripts/audit_storage_upload_routes.py"
)
assert SPEC and SPEC.loader
audit_tool = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit_tool)


class StorageUploadRouteAuditTest(unittest.TestCase):
    def test_flags_s3_presigned_put_sources(self):
        source = "const url = getSignedUrl(s3, new PutObjectCommand({Bucket: bucket}))"
        self.assertEqual("s3_presigned_put",
                         audit_tool.inspect_source("functions/server.ts", source)[0]["category"])
        self.assertEqual("s3_presigned_put",
                         audit_tool.inspect_source("lib/a.dart",
                                                   "const x = 'x-amz-copy-source';")[0]["category"])

    def test_flags_signed_tus_and_resumable_uploads(self):
        for value in ["createSignedUploadUrl('x')", "new tus.Upload(file)",
                      "import 'tus-js-client'", "'/upload/resumable'"]:
            self.assertTrue(
                any(x["category"] == "signed_resumable_upload"
                    for x in audit_tool.inspect_source("web/uploader.ts", value)),
                msg=value,
            )

    def test_regular_supabase_signed_read_is_not_s3_presigned_put(self):
        content = ("await supabase.storage.from('photos').upload('path', image);\n"
                   "await supabase.storage.from('docs').createSignedUrl('report', 60);")
        self.assertEqual([], audit_tool.inspect_source("lib/photo.dart", content))

    def test_never_analyze_test_fixtures_or_documentation_as_application_code(self):
        for path in ["docs/readme.md", "test/test_storage.dart",
                     "functions/tests/upload.test.ts",
                     "scripts/audit_storage_upload_routes.py", "lib/foo_test.dart",
                     "web/generated.freezed.dart"]:
            self.assertEqual([], audit_tool.inspect_source(
                path, "new PutObjectCommand({}); new tus.Upload(file)"))

    def test_report_contains_only_path_line_and_category_not_code(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            target = base / "lib/upload.dart"
            target.parent.mkdir()
            target.write_text("final secret = 'private-hidden-token';\n"
                              "const x = 'x-amz-copy-source';\n")
            report = audit_tool.audit(base)
            self.assertEqual("review_required", report["status"])
            self.assertEqual(1, report["files_scanned"])
            self.assertEqual(2, report["findings"][0]["line"])
            self.assertEqual("lib/upload.dart", report["findings"][0]["path"])
            self.assertNotIn("private-hidden-token", json.dumps(report))
            self.assertNotIn("const x", json.dumps(report))

    def test_strict_mode_fails_for_unreviewed_indicator(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            target = base / "web/uploader.js"
            target.parent.mkdir()
            target.write_text("const upload = new tus.Upload(file)")
            self.assertEqual(1, audit_tool.main(
                ["--root", temp, "--strict", "--output", str(base / "audit.json")]))
            self.assertTrue((base / "audit.json").exists())

    def test_missing_root_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            self.assertEqual(2, audit_tool.main(
                ["--root", str(Path(temp) / "absent")]))


if __name__ == "__main__":
    unittest.main()
