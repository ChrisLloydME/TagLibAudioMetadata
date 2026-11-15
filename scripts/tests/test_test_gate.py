import importlib.util
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/summarize-test-run.py'
CATALOG = ROOT / 'scripts/package-test-system/contract-catalog.json'
LEGACY_LOG = Path(__file__).resolve().parent / 'fixtures/legacy-complete-pass.log'


import sys
sys.path.insert(0, str(ROOT / 'scripts'))


def _script_module():
    spec = importlib.util.spec_from_file_location('summarize_test_run', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


SUMMARIZER = _script_module()
import test_manifest  # noqa: E402


def build_pass_log() -> str:
    log = LEGACY_LOG.read_text()
    expected = SUMMARIZER.REQUIRED_TESTS
    existing = set()
    import re
    for match in re.finditer(r'\bTest ([A-Za-z_]\w*)\([^)]*\)(?: with \d+ test cases?)? passed\b', log):
        existing.add(match.group(1))
    extra = []
    for name, minimum in expected.items():
        if name in existing:
            continue
        if minimum == 1:
            extra.append(f"Test {name}() passed after 1 second.")
        else:
            extra.append(f"Test {name}() with {minimum} test cases passed after 1 second.")
    for suite in SUMMARIZER.REQUIRED_SUITES:
        if f"Suite {suite} passed." not in log:
            extra.append(f"Suite {suite} passed.")
    log = log.replace(
        'Test run with 231 tests in 42 suites passed after 8 seconds.',
        'Test run with 274 tests in 51 suites passed after 8 seconds.',
    )
    final = 'Test run with 274 tests in 51 suites passed after 8 seconds.'
    if final in log:
        log = log.replace(final, '\n'.join(extra) + '\n' + final if extra else final)
    else:
        log = log + '\n'.join(extra) + '\n' + final + '\n'
    return log if log.endswith('\n') else log + '\n'


PASS = build_pass_log()


def valid_calibration(manifest):
    definitions = json.loads((ROOT / 'scripts/calibration-mutants.json').read_text())['mutants']
    return {'schema_version': 2, 'runner': 'canonical-package-tests', 'acceptance': 'accepted',
        'source_restored': True, 'source_hash': manifest['source_hash'], 'commit': manifest['commit'],
        'definition_hash': SUMMARIZER._sha256(ROOT / 'scripts/calibration-mutants.json'),
        'expected_mutant_ids': [row['id'] for row in definitions],
        'control': {key: 0 for key in ('build_exit_status', 'exit_status', 'final_build_exit_status', 'final_exit_status')} | {
            'named_tests_passed': True, 'final_named_tests_passed': True},
        'mutants': [{'id': row['id'], 'status': 'killed', 'restored': True, 'build_exit_status': 0,
            'exit_status': 1, 'named_failure': True, 'test_filter': row['test_filter'],
            'activation_witness': [row['witness']]} for row in definitions]}


def expected_evidence() -> dict:
    catalog = json.loads(CATALOG.read_text())
    return SUMMARIZER.expected_scenarios(catalog)


def write_evidence(directory: Path, expected: dict, manifest: dict) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    for index, (scenario, requirement) in enumerate(sorted(expected.items())):
        checks = [{"name": name, "passed": True, "detail": ""}
                  for name in requirement["checks"]]
        record = {
            "schema_version": 1,
            "scenario_id": scenario,
            "runtime_test": requirement["runtime_test"],
            "adapter": requirement["adapter_label"],
            "campaign": {"id": manifest["run_id"], "mode": manifest["mode"], "source_hash": manifest["source_hash"]},
            "outcome": requirement["outcome"],
            "checks": checks,
            "check_count": len(checks),
            "passed": True,
            "pid": 1,
            "recorded_at": "2026-11-15T00:00:00Z",
        }
        (directory / f"{index:03d}.{scenario}.json").write_text(json.dumps(record))
    invocations = directory / "invocations"
    invocations.mkdir()
    tests = json.loads((ROOT / "scripts/package-test-system/runtime-invocations.json").read_text())["tests"]
    index = 0
    for test, calls in tests.items():
        for call in calls:
            adapter, outcome = call.split("|")
            event = {"schema_version": 1, "runtime_test": test, "adapter": adapter, "outcome": outcome,
                     "campaign": {"id": manifest["run_id"], "mode": manifest["mode"], "source_hash": manifest["source_hash"]}}
            (invocations / f"{index}.json").write_text(json.dumps(event))
            index += 1


class TestGatePolicy(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = test_manifest.build("debug")
        cls.expected = expected_evidence()

    def accepted(self, log, status=0, *, evidence_mutator=None, manifest_mutator=None,
                 manifest_after_mutator=None, mode="debug", omit_manifest=False,
                 omit_evidence=False, omit_after=False, calibration_mutator=None, omit_calibration=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'log').write_text(log)
            evidence = root / 'evidence'
            if not omit_evidence:
                write_evidence(evidence, self.expected, self.manifest)
                if evidence_mutator:
                    evidence_mutator(evidence)
            manifest = json.loads(json.dumps(self.manifest))
            manifest_after = json.loads(json.dumps(self.manifest))
            if manifest_mutator:
                manifest_mutator(manifest)
            if manifest_after_mutator:
                manifest_after_mutator(manifest_after)
            (root / 'manifest.json').write_text(json.dumps(manifest))
            (root / 'manifest-after.json').write_text(json.dumps(manifest_after))
            calibration = valid_calibration(self.manifest)
            if calibration_mutator: calibration_mutator(calibration)
            (root / 'calibration.json').write_text(json.dumps(calibration))
            command = ['python3', str(SCRIPT), str(root / 'log'), str(status), str(root / 'summary'),
                       '--mode', mode]
            if not omit_calibration:
                command += ['--calibration', str(root / 'calibration.json')]
            if not omit_evidence:
                command += ['--evidence-dir', str(evidence)]
            if not omit_manifest:
                command += ['--manifest', str(root / 'manifest.json')]
                if not omit_after:
                    command += ['--manifest-after', str(root / 'manifest-after.json')]
            run = subprocess.run(command, capture_output=True)
            accepted = json.loads((root / 'summary').read_text())['accepted']
            self.assertEqual(run.returncode == 0, accepted)
            return accepted

    # --- retained legacy policy checks ---------------------------------

    def test_every_selective_projection_contract_is_required(self):
        for name in ['testSelectiveViewsMatchFullExtractionAcrossNativeFixtures',
                     'testRichSelectiveViewsPreserveNativeValuesAndArtwork',
                     'testValidationOnlyRejectsInvalidInputsWithoutMutation']:
            with self.subTest(name=name):
                modified = "\n".join(line for line in PASS.splitlines() if name not in line)
                self.assertFalse(self.accepted(modified))

    def test_missing_advisory_erase_regression_cannot_pass(self):
        self.assertFalse(self.accepted(PASS.replace(
            "Test asfAdvisoryAliasEraseVerifiesFinalNativeState() with 24 test cases passed after 1 second.\n", "")))

    def test_advisory_matrix_case_count_cannot_shrink(self):
        self.assertFalse(self.accepted(PASS.replace(
            'advisoryBearingEraseClearsKnownAndUnknownCodes() with 64 test cases',
            'advisoryBearingEraseClearsKnownAndUnknownCodes() with 63 test cases')))

    def test_missing_readability_preflight_evidence_is_rejected(self):
        self.assertFalse(self.accepted(PASS.replace(
            "Test Case '-[TagLibAudioMetadataTests.ReadLookupPreservationTests testTransactionReadabilityRejectsInvalidFilesBeforeMutation]' passed (0.001 seconds).\n", "")))

    def test_missing_cached_descriptor_evidence_is_rejected(self):
        self.assertFalse(self.accepted(PASS.replace(
            "Test Case '-[TagLibAudioMetadataTests.FormatCapabilityTests testCachedDescriptorsMatchEveryBridgeExtensionAndRemainValueCopies]' passed (0.001 seconds).\n", "")))

    def test_wrong_lookup_class_cannot_substitute_for_preservation_test(self):
        self.assertFalse(self.accepted(PASS.replace(
            'ReadLookupPreservationTests testUnicodeLookupRetainsFoundationCaseComparison',
            'OtherTests testUnicodeLookupRetainsFoundationCaseComparison')))

    def test_state_matrix_evidence_cannot_be_removed_or_shrunk(self):
        for count in (114, 176, 4128, 1248, 168, 2080, 80, 24):
            with self.subTest(count=count):
                self.assertFalse(self.accepted(PASS.replace(f'with {count} test cases', f'with {count - 1} test cases')))
        self.assertFalse(self.accepted('\n'.join(line for line in PASS.splitlines() if 'everyFieldPreservesAllSiblingDateStates' not in line)))

    def test_declaration_totals_cannot_shrink_below_reviewed_inventory(self):
        self.assertFalse(self.accepted(PASS.replace('Executed 181 tests', 'Executed 180 tests')))
        self.assertFalse(self.accepted(PASS.replace('run with 274 tests', 'run with 273 tests')))
        self.assertFalse(self.accepted(PASS.replace('in 51 suites', 'in 50 suites')))

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

    def test_earlier_failure_cannot_be_hidden_by_later_passing_summary(self):
        self.assertFalse(self.accepted('Test run with 1 test in 1 suite failed.\n' + PASS))
        self.assertFalse(self.accepted('Executed 1 test, with 1 failure (0 unexpected)\n' + PASS))

    def test_mandatory_matrix_suites_cannot_be_filtered_out(self):
        self.assertFalse(self.accepted(PASS.replace('Suite FLACSemanticLifecycleTests passed.\n', '')))

    def test_missing_required_matrix_test_function_is_rejected_even_if_suite_still_passes(self):
        self.assertFalse(self.accepted(PASS.replace(
            'Test independentCommentLifecycle(_:_:) with 90 test cases passed after 1 second.\n', '')))

    def test_missing_required_oracle_test_is_rejected(self):
        self.assertFalse(self.accepted(PASS.replace(
            'Test flacKnownVectorKeepsDuplicateCommentEntriesAndAudio() passed after 1 second.\n', '')))

    def test_required_parameterized_case_count_cannot_shrink(self):
        self.assertFalse(self.accepted(PASS.replace('with 264 test cases', 'with 263 test cases')))

    def test_failed_named_test_cannot_be_hidden_by_passing_summary(self):
        self.assertFalse(self.accepted(
            'Test independentCommentLifecycle(_:_:) failed after 1 second.\n' + PASS))

    def test_failed_xctest_name_cannot_be_hidden_by_zero_failure_summary(self):
        self.assertFalse(self.accepted(
            "Test Case '-[TagLibAudioMetadataTests.InjectedTests testInjected]' failed (0.001 seconds).\n" + PASS))

    def test_swift_testing_skip_is_not_hidden_by_pass_summary(self):
        self.assertFalse(self.accepted('Test mandatoryNativeWrite() skipped.\n' + PASS))

    def test_allowlisted_skip_name_must_match_exactly(self):
        self.assertFalse(self.accepted(PASS.replace('testOptInIndependentFileSnapshotThroughput', 'testOptInIndependentFileSnapshotThroughputSuffix')))

    def test_allowlisted_skip_method_in_another_class_is_rejected(self):
        self.assertFalse(self.accepted(PASS.replace(
            'TagLibAudioMetadataTests.ExternalCorpusPreservationTests',
            'TagLibAudioMetadataTests.InjectedCorpusTests')))

    def test_real_xctest_optional_skip_diagnostic_is_not_a_swift_testing_skip(self):
        diagnostic = ('/test/Corpus.swift:8: -[TagLibAudioMetadataTests.ExternalCorpusPreservationTests '
                      'testTrackMutationPreservesOtherVisiblePropertiesInExternalCorpus]'
                      ' : Test skipped - External corpus is opt-in.\n')
        self.assertTrue(self.accepted(diagnostic + PASS))

    def test_new_public_write_contract_regressions_cannot_be_filtered(self):
        for name in ('mp4IntPairOverflowRejectsWithoutMutation',
                     'numberTextPreflightRunsBeforeStaging',
                     'fullModelPreservesUnmodeledOwners',
                     'musicBrainzAliasCleanupUsesCaseInsensitiveIdentity',
                     'v23ContainersPreserveVersionDatesAndAudio',
                     'xmTrackerNameTypedRouteWritesNativeBytes',
                     'registrySemanticAndTotalProjectionsAreConsistent'):
            with self.subTest(name=name):
                modified = "\n".join(line for line in PASS.splitlines() if name not in line)
                self.assertFalse(self.accepted(modified))

    def test_new_public_write_contract_case_minima_cannot_shrink(self):
        for name, old, new in (
            ('legacyV23StatusFlagsReadLiteralDates(_:)', 'with 4 test cases', 'with 3 test cases'),
            ('generatedPaddingWidthRejectsBeforeFormatting(_:)', 'with 3 test cases', 'with 2 test cases'),
            ('mp4RawCanonicalFreeformSetAndRemove(_:)', 'with 2 test cases', 'with 1 test case'),
            ('v23ContainersPreserveVersionDatesAndAudio(_:_:)', 'with 6 test cases', 'with 5 test cases'),
        ):
            with self.subTest(name=name):
                self.assertFalse(self.accepted(PASS.replace(old, new)))

    def test_release_acceptance_case_minima_cannot_shrink(self):
        for name, count in [('structuredMP4RejectsEncodingAndRangeBypasses', 7),
                            ('allPublicNumericWritersRejectNativeOverflow', 9)]:
            with self.subTest(name=name):
                original = f'Test {name}(_:) with {count} test cases'
                reduced = f'Test {name}(_:) with {count - 1} test cases'
                self.assertIn(original, PASS)
                self.assertFalse(self.accepted(PASS.replace(original, reduced)))

    def test_release_acceptance_methods_are_required(self):
        for name in ['explicitZeroTotalIsNotRecoveredFromOldNumberText', 'allPublicNumericWritersRejectNativeOverflow', 'structuredMP4RejectsEncodingAndRangeBypasses', 'malformedNumberTextCannotEraseExistingPairs', 'excessiveInheritedPaddingDoesNotRemoveTrack', 'protectedDateFlagsSurviveOrRejectUnrelatedMutation', 'structuredPayloadsRequireExplicitValues', 'nativeMP4EncodersRetainValidBoundaryValues', 'legacyID3MustFitItsDeclaredContainerChunk', 'directStructuredValidationPrecedesFileAccess']:
            with self.subTest(name=name):
                modified = "\n".join(line for line in PASS.splitlines() if name not in line)
                self.assertFalse(self.accepted(modified))
        self.assertFalse(self.accepted(PASS.replace('Suite ReleaseAcceptanceTests passed.\n', '')))

    def test_new_public_write_contract_suite_cannot_be_filtered(self):
        self.assertFalse(self.accepted(PASS.replace('Suite PublicWriteContractRepairTests passed.\n', '')))

    def test_missing_basic_preservation_execution_is_rejected(self):
        self.assertFalse(self.accepted(PASS.replace('Test basicID3DatesPreserveNativeArrays() with 14 test cases passed after 1 second.\n', '')))

    def test_additional_container_cases_cannot_shrink(self):
        for count in [270, 180, 21, 396, 12]:
            self.assertFalse(self.accepted(PASS.replace(f'with {count} test cases', f'with {count - 1} test cases')))

    def test_audit_regression_and_malformed_mp4_oracle_are_required(self):
        for name in ['mp4PairUpperBound65535RoundTrips', 'malformedMP4LengthsAndFreeformsThrowRatherThanGuess']:
            self.assertFalse(self.accepted(PASS.replace(f'Test {name}() passed after 1 second.\n', '')))

    def test_every_remediation_method_is_required(self):
        names = ['testLegacyDateIdentityUsesDescriptionsAndExactArrays', 'testAllFacadeMutationSurfacesProtectStandaloneDates', 'testLowLevelModelReadsAndPreservesContentGroupArtistsAndPeaks', 'testASFLowLevelWritesUpdateExistingCanonicalAttributes', 'testLowLevelWritesPreserveUnknownAdvisoryRawCode', 'testAPEReleaseTypeAndStatusAreWritableThroughTypedAndBasic', 'testBasicNumberTextMismatchRejectsAndMixedPairsCommit', 'testASFLowLevelAdvisoryEditRemovesAliases', 'testV23StandaloneTDATSurvivesBasicAndStructuredUnrelatedWrites', 'testDirectBridgeV23WritesRejectWithoutMutation', 'testV23DateWritesRejectBeforeMutation', 'testV23RawDeltaPreservesCanonicalDatesAndRejectsStandaloneLoss', 'testV23ConflictingTORYAndTDORRejectWithoutMutation']
        for name in names:
            with self.subTest(name=name):
                self.assertFalse(self.accepted("\n".join(line for line in PASS.splitlines() if name not in line)))

    def test_runner_rejects_extra_filter_arguments(self):
        runner = SCRIPT.with_name('validate-tests.sh')
        result = subprocess.run(['bash', str(runner), 'debug', '--filter', 'OneTest'], capture_output=True)
        self.assertEqual(result.returncode, 2)

    def test_runner_rejects_unknown_configuration(self):
        runner = SCRIPT.with_name('validate-tests.sh')
        result = subprocess.run(['bash', str(runner), 'not-a-configuration'], capture_output=True)
        self.assertEqual(result.returncode, 2)

    # --- contract-system policy checks ---------------------------------

    def test_missing_scenario_execution_is_rejected(self):
        target = 'S-MP4-TYPED-01'
        def mutate(directory):
            for path in directory.glob(f"*.{target}.json"):
                path.unlink()
        self.assertFalse(self.accepted(PASS, evidence_mutator=mutate))

    def test_duplicate_scenario_execution_is_rejected(self):
        def mutate(directory):
            source = next(directory.glob('*.S-MP4-TYPED-01.json'))
            shutil.copy(source, directory / 'duplicate.S-MP4-TYPED-01.json')
        self.assertFalse(self.accepted(PASS, evidence_mutator=mutate))

    def test_scenario_assertion_budget_cannot_shrink(self):
        def mutate(directory):
            path = next(directory.glob('*.S-MP4-TYPED-01.json'))
            record = json.loads(path.read_text())
            record['checks'] = record['checks'][:-1]
            record['check_count'] -= 1
            path.write_text(json.dumps(record))
        self.assertFalse(self.accepted(PASS, evidence_mutator=mutate))

    def test_unexpected_scenario_execution_is_rejected(self):
        def mutate(directory):
            record = {
                'schema_version': 1, 'scenario_id': 'S-UNEXPECTED-01',
                'runtime_test': 'contractMP4TypedVertical', 'adapter': 'policy-fixture',
                'outcome': 'supported', 'checks': [{'name': 'x', 'passed': True, 'detail': ''}],
                'check_count': 1, 'passed': True, 'pid': 1,
                'recorded_at': '2026-11-15T00:00:00Z',
            }
            (directory / 'unexpected.json').write_text(json.dumps(record))
        self.assertFalse(self.accepted(PASS, evidence_mutator=mutate))

    def test_stale_manifest_source_hash_is_rejected(self):
        def mutate(manifest):
            manifest['source_hash'] = '0' * 64
        self.assertFalse(self.accepted(PASS, manifest_mutator=mutate))

    def test_mixed_configuration_manifest_is_rejected(self):
        def mutate(manifest):
            manifest['mode'] = 'release'
        self.assertFalse(self.accepted(PASS, manifest_mutator=mutate))

    def test_source_change_during_campaign_is_rejected(self):
        def mutate(manifest):
            manifest['source_hash'] = 'f' * 64
        self.assertFalse(self.accepted(PASS, manifest_after_mutator=mutate))

    def test_missing_manifest_is_rejected(self):
        self.assertFalse(self.accepted(PASS, omit_manifest=True))

    def test_missing_scenario_evidence_directory_is_rejected(self):
        self.assertFalse(self.accepted(PASS, omit_evidence=True))

    def test_truncated_log_is_rejected(self):
        lines = PASS.splitlines()
        self.assertFalse(self.accepted('\n'.join(lines[:-1]) + '\n'))

    def test_missing_framework_completion_is_rejected(self):
        self.assertFalse(self.accepted(PASS.replace('Test run with 274 tests in 51 suites passed after 8 seconds.\n', '')))

    def test_contract_suite_cannot_be_filtered(self):
        for suite in ('ContractBuilderOracleSelfTests', 'ContractMP4ScenarioTests',
                      'ContractNativeContainerTests', 'ContractFieldCoverageTests'):
            with self.subTest(suite=suite):
                self.assertFalse(self.accepted(PASS.replace(f'Suite {suite} passed.\n', '')))

    def test_new_contract_test_cannot_be_removed(self):
        for name in ('contractMP4TypedVertical', 'contractV23DateRejections',
                     'contractBridgeStructuredValidation', 'contractEveryFieldHasCoverageDecision',
                     'contractCatalogReconciliation'):
            with self.subTest(name=name):
                modified = "\n".join(line for line in PASS.splitlines() if name not in line)
                self.assertFalse(self.accepted(modified))


    def test_missing_post_run_manifest_is_rejected(self):
        self.assertFalse(self.accepted(PASS, omit_after=True))

    def test_minimal_manifest_cannot_replace_full_build_identity(self):
        def minimal(manifest):
            for key in list(manifest):
                if key not in {"mode", "commit", "source_hash"}: del manifest[key]
        self.assertFalse(self.accepted(PASS, manifest_mutator=minimal, manifest_after_mutator=minimal))

    def test_manifest_identity_fields_are_required_even_when_both_match(self):
        for field in ("schema_version", "run_id", "toolchain", "target", "sdk", "system_hashes", "file_hashes", "build_options"):
            with self.subTest(field=field):
                def remove(m): m.pop(field)
                self.assertFalse(self.accepted(PASS, manifest_mutator=remove, manifest_after_mutator=remove))

    def test_debug_scenarios_cannot_be_replayed_in_release(self):
        def release(m):
            m["mode"] = "release"
            m["build_options"] = test_manifest.options("release")
        self.assertFalse(self.accepted(PASS, mode="release", manifest_mutator=release, manifest_after_mutator=release))

    def test_campaign_replay_is_rejected(self):
        def stale(directory):
            for path in directory.rglob("*.json"):
                row = json.loads(path.read_text()); row["campaign"]["id"] = "previous-campaign"
                path.write_text(json.dumps(row))
        self.assertFalse(self.accepted(PASS, evidence_mutator=stale))

    def test_same_count_placeholder_assertions_and_fake_adapters_are_rejected(self):
        def placeholders(directory):
            for path in directory.glob("*.json"):
                row = json.loads(path.read_text()); row["adapter"] = "nonexistent.adapter"
                row["checks"] = [{"name": "placeholder", "passed": True} for _ in row["checks"]]
                path.write_text(json.dumps(row))
        self.assertFalse(self.accepted(PASS, evidence_mutator=placeholders))

    def test_same_count_assertion_substitution_is_rejected(self):
        def substitute(directory):
            path = next(directory.glob("*.S-MP4-TYPED-01.json")); row = json.loads(path.read_text())
            row["checks"][0]["name"] = row["checks"][1]["name"]
            path.write_text(json.dumps(row))
        self.assertFalse(self.accepted(PASS, evidence_mutator=substitute))

    def test_missing_or_duplicated_invocations_are_rejected(self):
        def missing(directory): next((directory / "invocations").glob("*.json")).unlink()
        def duplicate(directory):
            source = next((directory / "invocations").glob("*.json"))
            shutil.copy(source, source.with_name("duplicate.json"))
        self.assertFalse(self.accepted(PASS, evidence_mutator=missing))
        self.assertFalse(self.accepted(PASS, evidence_mutator=duplicate))

    def test_invocation_outcome_and_runtime_identity_cannot_be_substituted(self):
        for field, value in (("outcome", "not-executed"), ("runtime_test", "wrongTest"), ("adapter", "fake.adapter"), ("schema_version", 99)):
            with self.subTest(field=field):
                def mutate(directory):
                    path = next((directory / "invocations").glob("*.json")); row = json.loads(path.read_text())
                    row[field] = value; path.write_text(json.dumps(row))
                self.assertFalse(self.accepted(PASS, evidence_mutator=mutate))

    def test_incomplete_stale_or_inactive_calibration_cannot_accept(self):
        self.assertFalse(self.accepted(PASS, omit_calibration=True))
        for kind in ("subset", "duplicate", "stale", "unrestored", "compile-failure", "not-activated", "control-missing"):
            with self.subTest(kind=kind):
                def mutate(row):
                    if kind == "subset": row["mutants"].pop()
                    if kind == "duplicate": row["mutants"].append(row["mutants"][0])
                    if kind == "stale": row["source_hash"] = "0" * 64
                    if kind == "unrestored": row["mutants"][0]["restored"] = False
                    if kind == "compile-failure": row["mutants"][0]["build_exit_status"] = 1
                    if kind == "not-activated": row["mutants"][0]["activation_witness"] = []
                    if kind == "control-missing": row["control"]["named_tests_passed"] = False
                self.assertFalse(self.accepted(PASS, calibration_mutator=mutate))

    def test_claim_blessing_is_rejected_before_running_tests(self):
        import os
        result = subprocess.run(["bash", str(ROOT / "scripts/validate-tests.sh"), "debug"],
            env=os.environ | {"TAGLIB_WRITE_CLAIMS": "1"}, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Claim blessing", result.stderr)
