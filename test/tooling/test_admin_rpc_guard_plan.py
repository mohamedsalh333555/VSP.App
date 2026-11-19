import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('guard_plan', ROOT / 'scripts/admin_rpc_guard_plan.py')
plan = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(plan)


class GuardPlanTests(unittest.TestCase):
    def test_comments_strings_identifiers_and_dollar_quotes_do_not_select_fake_begin(self):
        sources = [
            "-- BEGIN fake\nDECLARE x text; BEGIN RETURN; END;",
            "/* BEGIN /* nested BEGIN */ */ BEGIN RETURN; END;",
            "DECLARE x text := 'BEGIN ''quoted'''; BEGIN RETURN; END;",
            'DECLARE "BEGIN" text; BEGIN RETURN; END;',
            'DECLARE x text := $tag$ BEGIN fake $tag$; BEGIN RETURN; END;',
            'DECLARE beginning text; BEGIN RETURN; END;',
            "DECLARE x text := E'escaped\\\' BEGIN fake'; BEGIN RETURN; END;",
        ]
        for source in sources:
            with self.subTest(source=source):
                offset = plan.begin_offset(source)
                self.assertEqual(source[offset:offset + 8], ' RETURN;')

    def test_unicode_offsets_are_postgres_characters_not_utf8_or_utf16_units(self):
        source = '-- 🔒 أمان\nBEGIN RETURN; END;'
        offset = plan.begin_offset(source)
        self.assertEqual(offset, source.index('BEGIN') + 5)
        self.assertNotEqual(offset, len(source[:offset].encode()))

    def test_lowercase_and_crlf_are_preserved(self):
        source = 'declare x text;\r\nbegin\r\nreturn;\r\nend;'
        result = plan.build_plan({'production': [{'signature': 'admin_test()', 'prosrc': source}]})
        self.assertEqual(len(result['variants']), 2)
        for variant in result['variants']:
            self.assertNotEqual(variant['before_sha256'], variant['after_sha256'])

    def test_unterminated_input_fails_closed(self):
        for source in ("'BEGIN", '/* BEGIN', '$tag$ BEGIN', '-- BEGIN only'):
            with self.subTest(source=source), self.assertRaises(ValueError):
                plan.begin_offset(source)

    def test_duplicate_source_is_one_variant_with_multiple_origins(self):
        functions = [{'signature': 'admin_test(uuid)', 'prosrc': 'BEGIN RETURN; END;'}]
        result = plan.build_plan({'production': functions, 'staging': functions})
        self.assertEqual(result['function_count'], 1)
        self.assertEqual(len(result['variants']), 1)
        self.assertEqual(result['variants'][0]['origins'], ['production', 'staging'])

    def test_output_contains_no_source_body_or_credentials(self):
        source = "DECLARE token text := 'private-secret'; BEGIN RETURN; END;"
        result = plan.build_plan({'production': [{'signature': 'admin_test()', 'prosrc': source}]})
        self.assertNotIn('private-secret', str(result))
        self.assertNotIn('prosrc', str(result))

    def test_inventory_mismatch_requires_review(self):
        with self.assertRaises(ValueError):
            plan.build_plan({'production': [{'signature': 'admin_test()', 'prosrc': 'BEGIN RETURN; END;'}], 'staging': []})

    def test_unsafe_signature_is_rejected(self):
        with self.assertRaises(ValueError):
            plan.build_plan({'production': [{'signature': 'admin_test(); DROP TABLE users;', 'prosrc': 'BEGIN RETURN; END;'}]})

    def test_input_server_hash_mismatch_is_rejected(self):
        with self.assertRaises(ValueError):
            plan.build_plan({'production': [{'signature': 'admin_test()', 'prosrc': 'BEGIN RETURN; END;', 'source_md5': 'bad'}]})


if __name__ == '__main__':
    unittest.main()
