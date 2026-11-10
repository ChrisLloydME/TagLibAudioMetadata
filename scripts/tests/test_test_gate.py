import json
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'summarize-test-run.py'
PASS = ('Test Case \'-[Corpus testTrackMutationPreservesOtherVisiblePropertiesInExternalCorpus]\' skipped (0.001 seconds).\n'
        'Test Case \'-[Benchmark testOptInIndependentFileSnapshotThroughput]\' skipped (0.001 seconds).\n'
        'Executed 158 tests, with 2 tests skipped and 0 failures (0 unexpected)\n'
        'Test run with 116 tests in 27 suites passed after 8 seconds.\n')

class TestGatePolicy(unittest.TestCase):
    def accepted(self, log, status=0):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'log').write_text(log)
            run = subprocess.run(['python3', str(SCRIPT), str(root / 'log'), str(status), str(root / 'summary')], capture_output=True)
            accepted = json.loads((root / 'summary').read_text())['accepted']
            self.assertEqual(run.returncode == 0, accepted)
            return accepted

    def test_both_frameworks_and_only_known_optional_skips_pass(self):
        self.assertTrue(self.accepted(PASS))

    def test_clean_xctest_cannot_hide_swift_testing_failure(self):
        self.assertFalse(self.accepted(PASS.replace('suites passed', 'suites failed')))

    def test_nonzero_runner_exit_cannot_be_hidden_by_pass_text(self):
        self.assertFalse(self.accepted(PASS, 1))

    def test_missing_either_framework_is_rejected(self):
        self.assertFalse(self.accepted(PASS.split('Test run with')[0]))
        self.assertFalse(self.accepted('Test run with' + PASS.split('Test run with', 1)[1]))

    def test_new_skipped_test_is_rejected(self):
        self.assertFalse(self.accepted(PASS.replace('testOptInIndependentFileSnapshotThroughput', 'testMandatoryNativeWrite')))

    def test_skip_count_without_named_evidence_is_rejected(self):
        self.assertFalse(self.accepted('\n'.join(line for line in PASS.splitlines() if 'skipped (' not in line)))
