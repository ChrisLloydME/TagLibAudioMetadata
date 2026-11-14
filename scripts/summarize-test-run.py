"""Fail closed if either XCTest or Swift Testing did not complete successfully.

SwiftPM's xunit output is not treated as complete evidence for mixed frameworks.
Counts here distinguish declarations from parameterized case executions, and
the required matrix/oracle test functions and their case counts are checked by
name so a filtered or partially deleted matrix cannot pass on suite banners.
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
skipped = re.findall(r"Test Case '(-\[[^']+\])' skipped", log)
allowed = {
    ('ExternalCorpusPreservationTests',
     'testTrackMutationPreservesOtherVisiblePropertiesInExternalCorpus'),
    ('SnapshotThroughputBenchmarkTests',
     'testOptInIndependentFileSnapshotThroughput'),
}


def xctest_identity(name):
    match = re.fullmatch(r'-\[([^\]\s]+) ([^\]]+)\]', name)
    if not match:
        return None
    # SwiftPM may print the module-qualified class name; the optional module
    # prefix is not part of the identity that can disguise a new skip.
    return (match.group(1).split('.')[-1], match.group(2))


# Record full names and allow only the two existing optional test methods. The
# class and method must both match; an allowlisted method name in another class
# is a new skip and must not pass.
unexpected = [name for name in skipped if xctest_identity(name) not in allowed]
swift_skips = [line for line in log.splitlines()
               if re.search(r'\b(?:Test|Suite)\s+(?!skipped\b).+?\s+skipped\b', line) and 'Test Case ' not in line]
failed_named_tests = sorted(set(re.findall(r'\bTest ([A-Za-z_]\w*)\([^)]*\) failed\b', log)))
failed_xctest = sorted(set(re.findall(r"Test Case '(-\[[^']+\])' failed", log)))
required_xctest = {
    ('ReadLookupPreservationTests', 'testTransactionReadabilityMatchesFullReaderAcrossFixtures'),
    ('ReadLookupPreservationTests', 'testTransactionReadabilityRejectsInvalidFilesBeforeMutation'),
    ('FormatCapabilityTests', 'testCachedDescriptorsMatchEveryBridgeExtensionAndRemainValueCopies'),
    ('ReadLookupPreservationTests', 'testRawLookupPreservesFirstIdentityEmptyArraysAndText'),
    ('ReadLookupPreservationTests', 'testUnicodeLookupRetainsFoundationCaseComparison'),
    ('ReadLookupPreservationTests', 'testMP4LookupKeepsExactKeysFirstArraysAndFreshReadState'),
}
passed_xctest = {xctest_identity(name) for name in re.findall(r"Test Case '(-\[[^']+\])' passed", log)}
missing_xctest = sorted(required_xctest - passed_xctest)
required_suites = ('SemanticLifecycleMatrixTests', 'FLACSemanticLifecycleTests', 'ID3SemanticLifecycleTests', 'NativeProbeContractTests', 'BasicIntegrityMatrixTests', 'AdditionalContainerLifecycleTests', 'ASFNativeLifecycleTests', 'AuditProbeTests', 'ID3ContainerLifecycleTests')
completed_suites = dict(re.findall(r'Suite (\w+) (passed|failed)', log))
missing_suites = [suite for suite in required_suites if suite not in completed_suites]
# Required executable evidence, with the minimum number of parameterized cases
# that the frozen matrices must execute. Counts may grow when the coverage
# inventory grows; they may not silently shrink.
required_tests = {
    'asfAdvisoryAliasEraseVerifiesFinalNativeState': 24,
    'unknownAdvisoryDoesNotSatisfyExactAbsence': 4,
    'unrelatedBasicEditPreservesUnknownAdvisory': 16,
    'unrelatedBasicEditPreservesUnknownASFAliasOwners': 6,
    'advisoryBearingEraseClearsKnownAndUnknownCodes': 64,
    'exactUnknownAdvisoryVerificationRequiresMatchingRawCode': 4,
    'erasedMP4OracleAllowsMissingMetadataWithoutAcceptingBrokenContainers': 1,
    'asfPublicWriteSurfacesPreserveSparseDateOwners': 80,
    'asfCustomFieldLifecycleOwnsOnlyItsCaseAliases': 24,
    'asfContentDescriptionVectorAndMalformedBounds': 1,
    'allPublicWriteSurfacesRequireContainerStateEvidence': 1,
    'publicWriteSurfacesPreserveSparseNativeOwners': 2080,
    'allSixteenDatePresenceMasksAreExplicit': 1,
    'textLifecyclePreservesEveryDatePresenceState': 114,
    'unrelatedWriteSurfacesPreserveDateState': 176,
    'interactionManifestIncludesEveryNativeField': 1,
    'everyFieldPreservesAllSiblingDateStates': 4128,
    'everyFieldPreservesAllOtherPresentOwners': 264,
    'everyContainerAndDateMaskRequiresTextLifecycleEvidence': 1,
    'nativeTextLifecycleAcrossSparseContainerStates': 1248,
    'allAttributeOwnersAcrossDatePresenceStates': 168,

    'mp4LifecycleHasNativeOwnerAndPreservesSiblings': 264,
    'wrongValueKindCannotPartiallyCommitAnotherField': 88,
    'everyFieldRequiresAnExplicitCoverageDecision': 1,
    'unavailableTypedMP4WritesRejectBeforeMutation': 5,
    'independentCommentLifecycle': 90,
    'nativeFrameLifecyclePreservesOtherFramesAndAudio': 66,
    'apeNativeItemLifecycle': 270,
    'nativeContainerFrameLifecycle': 396,
    'unsignedMP4PairsAcrossWriteSurfaces': 12,
    'oggNativeCommentLifecycle': 180,
    'nativeAttributeLifecycle': 21,
    'basicID3DatesPreserveNativeArrays': 14,
    'basicAPEDatesPreserveExactBytesAndAudio': 6,
    'basicFLACDatesKeepDuplicatesAndWhitespace': 2,
    'basicOggDatesPreserveArraysAndAudio': 4,
    'basicVerificationRejectsIncorrectDateAndContentGroup': 2,
    'unrelatedMP4BasicEditKeepsLegacyOwnersAndArrays': 1,
    'mp4ExtendedAndZeroSizeAtomsKeepValuesAndAudio': 1,
    'malformedMP4LengthsAndFreeformsThrowRatherThanGuess': 1,
    'flacKnownVectorKeepsDuplicateCommentEntriesAndAudio': 1,
    'id3KnownVectorAndUnsupportedHeaderBounds': 1,
    # Permanent independently reproduced audit regressions and controls.
    'basicClearOfLegacyBackedMP4FieldsMustCommit': 1,
    'lowLevelClearMustNotResurrectOldMP4Values': 1,
    'basicSetMustRetireEditedMP4CompatibilityAliases': 1,
    'basicWorkMustKeepCanonicalOwnerAndRetireLegacyFreeform': 1,
    'basicUnrelatedEditMustPreserveMultivalueDatesOnFLAC': 1,
    'basicUnrelatedEditMustPreserveMultivalueDatesOnAPE': 1,
    'basicUnrelatedEditMustPreserveMultivalueYearOnID3': 1,
    'basicUnrelatedEditMustPreserveMP4DateFreeformArrays': 1,
    'basicUnrelatedEditMustAcceptValidMultivalueMP4Year': 1,
    'semanticEncoderRemovalRetiresOnlyOwnedCompatibilityAlias': 1,
    'basicUnrelatedEditPreservesUnknownAdvisoryOnMP4': 1,
    'mp4MovementUpperBoundWorksAcrossFacadeEntryPoints': 1,
    'mp4MovementOverflowRejectsAcrossFacadeEntryPointsWithoutMutation': 1,
    'mp4PairUpperBound65535RoundTrips': 1,
    'id3EncodedByEditPreservesEncoderSettings': 1,
    'id3EncoderSettingsEditMustSucceedAndPreserveEncodedBy': 1,
    'id3EncoderSettingsMustNotPopulateEncodedBy': 1,
    'id3EncodedByRemovalWithEncoderSettingsMustSucceed': 1,
    'asfEncoderOwnersRemainIndependent': 1,
    'explicitYearWritesOnlyTheYearSlot': 1,
    'basicContentGroupGroupingAndWorkStayIndependent': 1,
    'asfUnrelatedBasicEditPreservesNativeEncodingSettings': 1,
    'asfUnrelatedSemanticPatchPreservesNativeEncodingSettings': 1,
    'id3v23DateWritesRejectBeforeMutation': 1,
}

# "Test <name>(<arguments>) with <n> test cases passed ..." for parameterized
# declarations and "Test <name>() passed ..." for ordinary declarations.
executed_tests = {}
for match in re.finditer(
        r'\bTest ([A-Za-z_]\w*)\([^)]*\)(?: with (\d+) test cases?)? passed\b', log):
    name = match.group(1)
    count = int(match.group(2) or 1)
    executed_tests[name] = max(executed_tests.get(name, 0), count)
missing_tests = []
for name, minimum in required_tests.items():
    actual = executed_tests.get(name)
    if actual is None:
        missing_tests.append({'test': name, 'expected_cases': minimum, 'actual_cases': None})
    elif actual < minimum:
        missing_tests.append({'test': name, 'expected_cases': minimum, 'actual_cases': actual})

summary = {'runner_exit_status': status, 'xctest_executed': int(xctest[-1][0]) if xctest else None,
           'xctest_skipped': int(xctest[-1][1] or 0) if xctest else None,
           'xctest_failures': int(xctest[-1][2]) if xctest else None,
           'swift_testing_declarations': int(swift[-1][0]) if swift else None,
           'swift_testing_result': swift[-1][2] if swift else None,
           'swift_testing_suites': int(swift[-1][1]) if swift else None,
           'required_case_counts': {name: executed_tests.get(name) for name in required_tests},
           'minimum_required_case_counts': required_tests,
           'skipped_test_names': skipped, 'unexpected_skips': unexpected,
           'swift_testing_skips': swift_skips, 'missing_required_suites': missing_suites,
           'missing_required_tests': missing_tests,
           'failed_named_tests': failed_named_tests,
           'failed_xctest_names': failed_xctest,
           'missing_required_xctest': missing_xctest}
ok = (status == 0 and bool(xctest) and int(xctest[-1][0]) >= 164 and int(xctest[-1][2]) == 0
      and bool(swift) and int(swift[-1][0]) >= 186 and swift[-1][2] == 'passed'
      and not unexpected and not swift_skips and not missing_suites and not missing_tests
      and not failed_named_tests and not failed_xctest and not missing_xctest
      and all(int(result[2]) == 0 for result in xctest)
      and all(result[2] == 'passed' for result in swift)
      and all(completed_suites[suite] == 'passed' for suite in required_suites)
      and int(xctest[-1][1] or 0) == len(skipped))
summary['accepted'] = ok
Path(sys.argv[3]).write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
sys.exit(0 if ok else 1)
