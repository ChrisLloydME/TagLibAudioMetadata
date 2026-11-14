import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('test_inventory', Path(__file__).resolve().parents[1] / 'test_inventory.py')
INVENTORY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(INVENTORY)


class RequiredTestOwnerPolicy(unittest.TestCase):
    def check(self, source, extra=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Probe.swift').write_text(source)
            if extra:
                (root / 'Other.swift').write_text(extra)
            return INVENTORY.validate(root, {'matrix': {'suite': 'Owner', 'path': 'Probe.swift'}})

    def test_every_required_name_needs_a_manifest_owner(self):
        self.assertTrue(INVENTORY.validate(manifest={}, required_names={'newRequiredTest'}))

    def test_expected_suite_is_accepted(self):
        self.assertFalse(self.check('struct Owner { @Test func matrix() {} }'))

    def test_same_name_in_another_suite_is_rejected(self):
        self.assertTrue(self.check('struct Substitute { @Test func matrix() {} }'))

    def test_duplicate_name_in_another_file_is_rejected(self):
        self.assertTrue(self.check('struct Owner { @Test func matrix() {} }',
                                   'struct Substitute { @Test func matrix() {} }'))

    def test_comment_or_string_cannot_replace_required_function(self):
        self.assertTrue(self.check('struct Owner { let text = "func matrix() {}" /* func matrix() {} */ }'))
