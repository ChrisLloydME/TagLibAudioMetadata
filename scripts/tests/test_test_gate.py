import json
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'summarize-test-run.py'
PASS = (
    "Test asfPublicWriteSurfacesPreserveSparseDateOwners() with 80 test cases passed after 1 second.\n"
    "Test asfCustomFieldLifecycleOwnsOnlyItsCaseAliases() with 24 test cases passed after 1 second.\n"
    "Test asfContentDescriptionVectorAndMalformedBounds() passed after 1 second.\n"
    "Test allPublicWriteSurfacesRequireContainerStateEvidence() passed after 1 second.\n"
    "Test publicWriteSurfacesPreserveSparseNativeOwners() with 2080 test cases passed after 1 second.\n"
    "Test allSixteenDatePresenceMasksAreExplicit() passed after 1 second.\n"
    "Test textLifecyclePreservesEveryDatePresenceState() with 114 test cases passed after 1 second.\n"
    "Test unrelatedWriteSurfacesPreserveDateState() with 176 test cases passed after 1 second.\n"
    "Test interactionManifestIncludesEveryNativeField() passed after 1 second.\n"
    "Test everyFieldPreservesAllSiblingDateStates() with 4128 test cases passed after 1 second.\n"
    "Test everyFieldPreservesAllOtherPresentOwners() with 264 test cases passed after 1 second.\n"
    "Test everyContainerAndDateMaskRequiresTextLifecycleEvidence() passed after 1 second.\n"
    "Test nativeTextLifecycleAcrossSparseContainerStates() with 1248 test cases passed after 1 second.\n"
    "Test allAttributeOwnersAcrossDatePresenceStates() with 168 test cases passed after 1 second.\n"

    "Test Case '-[TagLibAudioMetadataTests.ExternalCorpusPreservationTests testTrackMutationPreservesOtherVisiblePropertiesInExternalCorpus]' skipped (0.001 seconds).\n"
    "Test Case '-[TagLibAudioMetadataTests.SnapshotThroughputBenchmarkTests testOptInIndependentFileSnapshotThroughput]' skipped (0.001 seconds).\n"
    "Test Case '-[TagLibAudioMetadataTests.FormatCapabilityTests testCachedDescriptorsMatchEveryBridgeExtensionAndRemainValueCopies]' passed (0.001 seconds).\n"
    "Test Case '-[TagLibAudioMetadataTests.ReadLookupPreservationTests testRawLookupPreservesFirstIdentityEmptyArraysAndText]' passed (0.001 seconds).\n"
    "Test Case '-[TagLibAudioMetadataTests.ReadLookupPreservationTests testUnicodeLookupRetainsFoundationCaseComparison]' passed (0.001 seconds).\n"
    "Test Case '-[TagLibAudioMetadataTests.ReadLookupPreservationTests testMP4LookupKeepsExactKeysFirstArraysAndFreshReadState]' passed (0.001 seconds).\n"
    "Executed 162 tests, with 2 tests skipped and 0 failures (0 unexpected)\n"
    "Test mp4LifecycleHasNativeOwnerAndPreservesSiblings(_:_:) with 264 test cases passed after 1 second.\n"
    "Test wrongValueKindCannotPartiallyCommitAnotherField(_:) with 88 test cases passed after 1 second.\n"
    "Test everyFieldRequiresAnExplicitCoverageDecision() passed after 1 second.\n"
    "Test unavailableTypedMP4WritesRejectBeforeMutation(_:) with 5 test cases passed after 1 second.\n"
    "Test independentCommentLifecycle(_:_:) with 90 test cases passed after 1 second.\n"
    "Test nativeFrameLifecyclePreservesOtherFramesAndAudio(_:_:) with 66 test cases passed after 1 second.\n"
    "Test flacKnownVectorKeepsDuplicateCommentEntriesAndAudio() passed after 1 second.\n"
    "Test id3KnownVectorAndUnsupportedHeaderBounds() passed after 1 second.\n"
    "Suite SemanticLifecycleMatrixTests passed.\n"
    "Suite FLACSemanticLifecycleTests passed.\n"
    "Suite ID3SemanticLifecycleTests passed.\n"
    "Suite NativeProbeContractTests passed.\n"
    'Test apeNativeItemLifecycle() with 270 test cases passed after 1 second.\n'
    'Test oggNativeCommentLifecycle() with 180 test cases passed after 1 second.\n'
    'Test nativeAttributeLifecycle() with 21 test cases passed after 1 second.\n'
    'Test basicID3DatesPreserveNativeArrays() with 14 test cases passed after 1 second.\n'
    'Test basicAPEDatesPreserveExactBytesAndAudio() with 6 test cases passed after 1 second.\n'
    'Test basicFLACDatesKeepDuplicatesAndWhitespace() with 2 test cases passed after 1 second.\n'
    'Test basicOggDatesPreserveArraysAndAudio() with 4 test cases passed after 1 second.\n'
    'Test basicVerificationRejectsIncorrectDateAndContentGroup() with 2 test cases passed after 1 second.\n'
    'Test unrelatedMP4BasicEditKeepsLegacyOwnersAndArrays() passed after 1 second.\n'
    'Test mp4ExtendedAndZeroSizeAtomsKeepValuesAndAudio() passed after 1 second.\n'
    'Test malformedMP4LengthsAndFreeformsThrowRatherThanGuess() passed after 1 second.\n'
    'Test basicClearOfLegacyBackedMP4FieldsMustCommit() passed after 1 second.\n'
    'Test lowLevelClearMustNotResurrectOldMP4Values() passed after 1 second.\n'
    'Test basicSetMustRetireEditedMP4CompatibilityAliases() passed after 1 second.\n'
    'Test basicWorkMustKeepCanonicalOwnerAndRetireLegacyFreeform() passed after 1 second.\n'
    'Test basicUnrelatedEditMustPreserveMultivalueDatesOnFLAC() passed after 1 second.\n'
    'Test basicUnrelatedEditMustPreserveMultivalueDatesOnAPE() passed after 1 second.\n'
    'Test basicUnrelatedEditMustPreserveMultivalueYearOnID3() passed after 1 second.\n'
    'Test basicUnrelatedEditMustPreserveMP4DateFreeformArrays() passed after 1 second.\n'
    'Test basicUnrelatedEditMustAcceptValidMultivalueMP4Year() passed after 1 second.\n'
    'Test semanticEncoderRemovalRetiresOnlyOwnedCompatibilityAlias() passed after 1 second.\n'
    'Test basicUnrelatedEditPreservesUnknownAdvisoryOnMP4() passed after 1 second.\n'
    'Test mp4MovementUpperBoundWorksAcrossFacadeEntryPoints() passed after 1 second.\n'
    'Test mp4MovementOverflowRejectsAcrossFacadeEntryPointsWithoutMutation() passed after 1 second.\n'
    'Test mp4PairUpperBound65535RoundTrips() passed after 1 second.\n'
    'Test id3EncodedByEditPreservesEncoderSettings() passed after 1 second.\n'
    'Test id3EncoderSettingsEditMustSucceedAndPreserveEncodedBy() passed after 1 second.\n'
    'Test id3EncoderSettingsMustNotPopulateEncodedBy() passed after 1 second.\n'
    'Test id3EncodedByRemovalWithEncoderSettingsMustSucceed() passed after 1 second.\n'
    'Test asfEncoderOwnersRemainIndependent() passed after 1 second.\n'
    'Test explicitYearWritesOnlyTheYearSlot() passed after 1 second.\n'
    'Test basicContentGroupGroupingAndWorkStayIndependent() passed after 1 second.\n'
    'Test asfUnrelatedBasicEditPreservesNativeEncodingSettings() passed after 1 second.\n'
    'Test asfUnrelatedSemanticPatchPreservesNativeEncodingSettings() passed after 1 second.\n'
    'Test id3v23DateWritesRejectBeforeMutation() passed after 1 second.\n'
    'Suite BasicIntegrityMatrixTests passed.\n'
    'Suite AdditionalContainerLifecycleTests passed.\n'
    'Suite ASFNativeLifecycleTests passed.\n'
    'Suite AuditProbeTests passed.\n'
    "Suite ID3ContainerLifecycleTests passed.\n"
    "Test nativeContainerFrameLifecycle() with 396 test cases passed after 1 second.\n"
    "Test unsignedMP4PairsAcrossWriteSurfaces() with 12 test cases passed after 1 second.\n"
    "Test run with 179 tests in 41 suites passed after 8 seconds.\n"
)

class TestGatePolicy(unittest.TestCase):
    def accepted(self, log, status=0):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'log').write_text(log)
            run = subprocess.run(['python3', str(SCRIPT), str(root / 'log'), str(status), str(root / 'summary')], capture_output=True)
            accepted = json.loads((root / 'summary').read_text())['accepted']
            self.assertEqual(run.returncode == 0, accepted)
            return accepted

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
        self.assertFalse(self.accepted(PASS.replace('Executed 162 tests', 'Executed 161 tests')))
        self.assertFalse(self.accepted(PASS.replace('run with 179 tests', 'run with 178 tests')))

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

    def test_missing_basic_preservation_execution_is_rejected(self):
        self.assertFalse(self.accepted(PASS.replace('Test basicID3DatesPreserveNativeArrays() with 14 test cases passed after 1 second.\n', '')))

    def test_additional_container_cases_cannot_shrink(self):
        for count in [270, 180, 21, 396, 12]:
            self.assertFalse(self.accepted(PASS.replace(f'with {count} test cases', f'with {count - 1} test cases')))

    def test_audit_regression_and_malformed_mp4_oracle_are_required(self):
        for name in ['mp4PairUpperBound65535RoundTrips', 'malformedMP4LengthsAndFreeformsThrowRatherThanGuess']:
            self.assertFalse(self.accepted(PASS.replace(f'Test {name}() passed after 1 second.\n', '')))

    def test_runner_rejects_extra_filter_arguments(self):
        runner = SCRIPT.with_name('validate-tests.sh')
        result = subprocess.run(['bash', str(runner), 'debug', '--filter', 'OneTest'], capture_output=True)
        self.assertEqual(result.returncode, 2)

    def test_runner_rejects_unknown_configuration(self):
        runner = SCRIPT.with_name('validate-tests.sh')
        result = subprocess.run(['bash', str(runner), 'not-a-configuration'], capture_output=True)
        self.assertEqual(result.returncode, 2)
