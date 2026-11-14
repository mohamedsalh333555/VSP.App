import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('policy_plan', Path(__file__).resolve().parents[2] / 'scripts/blocked_admin_policy_plan.py')
plan = importlib.util.module_from_spec(spec)
spec.loader.exec_module(plan)


class PolicyPlanTests(unittest.TestCase):
    def test_preserves_ownership_arm(self):
        old = "owner_id=auth.uid() OR EXISTS(SELECT 1 FROM users u WHERE u.id=auth.uid() AND u.role = ANY (ARRAY['admin'::text,'co_founder'::text]))"
        new = plan.restrict_expression(old)
        self.assertTrue(new.startswith('owner_id=auth.uid() OR EXISTS('))
        self.assertIn('COALESCE(u.is_blocked, false) = false', new)

    def test_mixed_owner_membership_keeps_ordinary_owner_role(self):
        new = plan.restrict_expression("EXISTS(SELECT 1 FROM users WHERE users.id=auth.uid() AND users.role = ANY (ARRAY['owner'::text,'admin'::text]))")
        self.assertIn("users.role NOT IN ('admin','co_founder','cofounder','super_admin') OR", new)

    def test_scalar_role_is_null_for_blocked_admin(self):
        new = plan.restrict_expression("(SELECT users.role FROM users WHERE users.id=auth.uid()) = ANY (ARRAY['admin'::text])")
        self.assertIn('CASE WHEN COALESCE(users.is_blocked, false) THEN NULL::text ELSE users.role END', new)

    def test_single_admin_role(self):
        new = plan.restrict_expression("EXISTS(SELECT 1 FROM users u WHERE u.id=auth.uid() AND u.role = 'admin'::text)")
        self.assertIn('COALESCE(u.is_blocked, false)', new)

    def test_unknown_shape_refused(self):
        with self.assertRaises(ValueError): plan.restrict_expression('true')

    def test_existing_block_check_not_rewritten(self):
        with self.assertRaises(ValueError): plan.restrict_expression("u.role='admin' AND NOT u.is_blocked")


if __name__ == '__main__': unittest.main()
