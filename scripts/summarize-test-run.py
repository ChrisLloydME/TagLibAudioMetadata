"""Fail closed if either XCTest or Swift Testing did not complete successfully.

SwiftPM's xunit output is not treated as complete evidence for mixed frameworks.
Counts here distinguish declarations from parameterized case executions.
"""
import json
import re
import sys
from pathlib import Path

log = Path(sys.argv[1]).read_text()
status = int(sys.argv[2])
# XCTest actually uses either ", with 0 failures" or ", with 2 tests skipped and 0 failures".
xctest = re.findall(r'Executed (\d+) tests?, with (?:(\d+) tests? skipped and )?(\d+) failures?', log)
swift = re.findall(r'Test run with (\d+) tests? in (\d+) suites? (passed|failed)', log)
skipped = re.findall(r"Test Case .*?'([^']+)' skipped", log)
allowed = ('testTrackMutationPreservesOtherVisiblePropertiesInExternalCorpus', 'testOptInIndependentFileSnapshotThroughput')
# Record full names and allow only the two existing optional suites.
unexpected = [name for name in skipped if name.rsplit(' ', 1)[-1].rstrip(']') not in allowed]
swift_skips = [line for line in log.splitlines()
               if re.search(r'\b(?:Test|Suite)\s+(?!skipped\b).+?\s+skipped\b', line) and 'Test Case ' not in line]
required_suites = ('SemanticLifecycleMatrixTests', 'FLACSemanticLifecycleTests', 'ID3SemanticLifecycleTests', 'NativeProbeContractTests')
completed_suites = dict(re.findall(r'Suite (\w+) (passed|failed)', log))
missing_suites = [suite for suite in required_suites if suite not in completed_suites]
summary = {'runner_exit_status': status, 'xctest_executed': int(xctest[-1][0]) if xctest else None,
           'xctest_skipped': int(xctest[-1][1] or 0) if xctest else None,
           'xctest_failures': int(xctest[-1][2]) if xctest else None,
           'swift_testing_declarations': int(swift[-1][0]) if swift else None,
           'swift_testing_result': swift[-1][2] if swift else None,
           'skipped_test_names': skipped, 'unexpected_skips': unexpected,
           'swift_testing_skips': swift_skips, 'missing_required_suites': missing_suites}
ok = (status == 0 and bool(xctest) and int(xctest[-1][0]) > 0 and int(xctest[-1][2]) == 0
      and bool(swift) and int(swift[-1][0]) > 0 and swift[-1][2] == 'passed'
      and not unexpected and not swift_skips and not missing_suites
      and all(int(result[2]) == 0 for result in xctest)
      and all(result[2] == 'passed' for result in swift)
      and all(completed_suites[suite] == 'passed' for suite in required_suites)
      and int(xctest[-1][1] or 0) == len(skipped))
summary['accepted'] = ok
Path(sys.argv[3]).write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
sys.exit(0 if ok else 1)
