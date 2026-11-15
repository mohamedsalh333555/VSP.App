import unittest

from scripts.test_booking_public_feed_logo_sync_isolated import require_isolated


class PublicFeedContractTargetGuard(unittest.TestCase):
    def test_no_hosted_target_allowed(self):
        for bad in (
            {},
            {"VSP_CONTRACT_ISOLATED": "1", "PGHOST": "db.example.supabase.co",
             "PGPORT": "5432", "PGDATABASE": "vsp_security_contracts"},
            {"VSP_CONTRACT_ISOLATED": "1", "PGHOST": "127.0.0.1",
             "PGPORT": "5432", "PGDATABASE": "postgres"},
            {"VSP_CONTRACT_ISOLATED": "1", "PGHOST": "127.0.0.1",
             "PGPORT": "6543", "PGDATABASE": "vsp_security_contracts"},
        ):
            with self.assertRaises(RuntimeError):
                require_isolated(bad)

    def test_disposable_sql_service_allowed(self):
        require_isolated({
            "VSP_CONTRACT_ISOLATED": "1", "PGHOST": "127.0.0.1",
            "PGPORT": "5432", "PGDATABASE": "vsp_security_contracts",
        })


if __name__ == "__main__":
    unittest.main()
