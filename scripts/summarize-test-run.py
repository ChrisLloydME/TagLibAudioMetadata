#!/usr/bin/env python3
"""Fail closed on incomplete, stale, mixed or unexecuted contract evidence.

XCTest and Swift Testing logs are only supporting evidence. Acceptance also
requires a fresh source/build manifest, the exact catalog scenario set, each
scenario's exact assertion budget, completed framework summaries and only the
two reviewed opt-in XCTest skips.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

from test_inventory import validate as validate_test_inventory

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "scripts/package-test-system/contract-catalog.json"
EVIDENCE_SCHEMA_VERSION = 1

# The two reviewed optional XCTest identities. Both class and method matter.
ALLOWED_SKIPS = {
    ("ExternalCorpusPreservationTests",
     "testTrackMutationPreservesOtherVisiblePropertiesInExternalCorpus"),
    ("SnapshotThroughputBenchmarkTests",
     "testOptInIndependentFileSnapshotThroughput"),
}

REQUIRED_XCTEST = {
    ("RemediationPreservationTests", "testLegacyDateIdentityUsesDescriptionsAndExactArrays"),
    ("RemediationPreservationTests", "testAllFacadeMutationSurfacesProtectStandaloneDates"),
    ("RemediationPreservationTests", "testLowLevelModelReadsAndPreservesContentGroupArtistsAndPeaks"),
    ("RemediationPreservationTests", "testASFLowLevelWritesUpdateExistingCanonicalAttributes"),
    ("RemediationPreservationTests", "testLowLevelWritesPreserveUnknownAdvisoryRawCode"),
    ("RemediationPreservationTests", "testAPEReleaseTypeAndStatusAreWritableThroughTypedAndBasic"),
    ("RemediationPreservationTests", "testBasicNumberTextMismatchRejectsAndMixedPairsCommit"),
    ("RemediationPreservationTests", "testASFLowLevelAdvisoryEditRemovesAliases"),
    ("RemediationPreservationTests", "testV23StandaloneTDATSurvivesBasicAndStructuredUnrelatedWrites"),
    ("RemediationPreservationTests", "testDirectBridgeV23WritesRejectWithoutMutation"),
    ("RemediationPreservationTests", "testV23DateWritesRejectBeforeMutation"),
    ("RemediationPreservationTests", "testV23RawDeltaPreservesCanonicalDatesAndRejectsStandaloneLoss"),
    ("RemediationPreservationTests", "testV23ConflictingTORYAndTDORRejectWithoutMutation"),
    ('SelectiveExtractionTests', 'testLegacyID3ProjectionOptionsHaveLiteralDateOwners'),
    ('SelectiveExtractionTests', 'testSelectiveViewsMatchFullExtractionAcrossNativeFixtures'),
    ('SelectiveExtractionTests', 'testRichSelectiveViewsPreserveNativeValuesAndArtwork'),
    ('SelectiveExtractionTests', 'testValidationOnlyRejectsInvalidInputsWithoutMutation'),
    ('ReadLookupPreservationTests', 'testTransactionReadabilityMatchesFullReaderAcrossFixtures'),
    ('ReadLookupPreservationTests', 'testTransactionReadabilityRejectsInvalidFilesBeforeMutation'),
    ('FormatCapabilityTests', 'testCachedDescriptorsMatchEveryBridgeExtensionAndRemainValueCopies'),
    ('ReadLookupPreservationTests', 'testRawLookupPreservesFirstIdentityEmptyArraysAndText'),
    ('ReadLookupPreservationTests', 'testUnicodeLookupRetainsFoundationCaseComparison'),
    ('ReadLookupPreservationTests', 'testMP4LookupKeepsExactKeysFirstArraysAndFreshReadState'),
}

# Counts may grow when the reviewed inventory grows; they may not shrink.
REQUIRED_TESTS = {
    'explicitZeroTotalIsNotRecoveredFromOldNumberText': 1,
    'allPublicNumericWritersRejectNativeOverflow': 9,
    'structuredMP4RejectsEncodingAndRangeBypasses': 7,
    'malformedNumberTextCannotEraseExistingPairs': 1,
    'excessiveInheritedPaddingDoesNotRemoveTrack': 1,
    'protectedDateFlagsSurviveOrRejectUnrelatedMutation': 1,
    'structuredPayloadsRequireExplicitValues': 1,
    'nativeMP4EncodersRetainValidBoundaryValues': 1,
    'legacyID3MustFitItsDeclaredContainerChunk': 1,
    'directStructuredValidationPrecedesFileAccess': 1,
    'legacyDateFlagsRetainLiteralOwners': 4,
    'lowLevelMP4WritableTextOwnersMatchCatalog': 15,
    'legacyDatesAreIndependentAndBasicEditsPreserveThem': 1,
    'basicClearArtworkRemovesNativeCollections': 1,
    'movementAndReleaseOwnersAgreeAcrossEntrypoints': 1,
    'typedASFAdvisoryPersistsNativeAttribute': 1,
    'basicMixedNumbersAndText': 7,
    'lowLevelLegacyReplacementRejectsWithoutMutation': 1,
    'basicMusicBrainzUsesCanonicalUFIDAndClearsIt': 1,
    'emptyStructuredWritesAndUnsupportedCollectionsDoNotCommit': 1,
    'everyTransactionRejectsUnreadableStagedOutput': 1,
    'versionedTextWritesAndRemovalsVerify': 1,
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
    'legacyV23StatusFlagsReadLiteralDates': 4,
    'legacyV23GroupingFlagSkipsBoundedIdentifier': 1,
    'undecodableV23FrameTransformsStillReject': 2,
    'dsdiffPropertyChildID3UsesBoundedTraversal': 1,
    'mp4IntPairOverflowRejectsWithoutMutation': 1,
    'asfNoncanonicalTypeIsCanonicalTextOrRejected': 1,
    'crossFormatStructuredCollectionsRejectAtomically': 1,
    'mp4KnownAtomCannotChangeCodec': 1,
    'generatedPaddingWidthRejectsBeforeFormatting': 3,
    'maximumGeneratedPaddingStillWrites': 1,
    'numberTextPreflightRunsBeforeStaging': 1,
    'asfZeroNumberTextPairRejectsBeforeStaging': 1,
    'fullModelPreservesUnmodeledOwners': 1,
    'privateProvenanceSurvivesOrdinaryWrites': 1,
    'ordinaryAliasRetiresOnlyForEditedPair': 1,
    'musicBrainzAliasCleanupUsesCaseInsensitiveIdentity': 1,
    'mp4RawCanonicalFreeformSetAndRemove': 2,
    'rawAPIsStillRejectNativeMP4Keys': 1,
    'v23ContainersPreserveVersionDatesAndAudio': 6,
    'xmTrackerNameTypedRouteWritesNativeBytes': 1,
    'registrySemanticAndTotalProjectionsAreConsistent': 1,
    'roleQualifiedTypedPatchStillRejects': 1,
    'yearPrefixFilterRemainsBasicSpecific': 1,
    # Independent contract system: builders/oracles, native scenarios,
    # sequence/transaction suites and catalog audits.
    'synchsafeBoundariesAndLiteralVectors': 1,
    'id3FrameSizesAndVersionLayouts': 1,
    'id3FlagsGroupingAndTagFlagsRoundTrip': 1,
    'mp4IntegerEncodingsAndBounds': 1,
    'riffChunkBoundsAlignmentAndTruncation': 1,
    'flacBuilderPreservesDuplicatesWhitespaceAndAudio': 1,
    'malformedNativeEvidenceIsRejected': 1,
    'fieldSchemaMatchesReviewedClaims': 1,
    'formatCapabilitiesMatchReviewedClaims': 1,
    'contractMP4TypedVertical': 1,
    'contractMP4PublicSequence': 1,
    'contractFullModelRetention': 1,
    'contractRawValueModes': 1,
    'contractRawDeltaAndBridgeReplace': 1,
    'contractNumberTextSurfaces': 1,
    'contractMP4NumericBounds': 1,
    'contractInvalidNumberTextRejects': 1,
    'contractVerificationDisabled': 1,
    'contractEraseAndReopen': 1,
    'contractStaleGuards': 1,
    'contractBatchPerFile': 1,
    'contractBridgeReadsRegistry': 1,
    'contractBridgeStructuredValidation': 1,
    'contractBridgeWipe': 1,
    'contractEncodingFamilies': 1,
    'contractArtworkAndQualifiedCollections': 1,
    'contractV23FlaggedPreservation': 1,
    'contractV23DateRejections': 1,
    'contractPrivateProvenance': 1,
    'contractFLACArrayPreservation': 1,
    'contractFLACExplicitRemoval': 1,
    'contractWAVAndAIFFID3': 1,
    'contractASFAdvisoryPreservation': 1,
    'contractASFPartialPairRejects': 1,
    'contractTrackerRoute': 1,
    'contractUnsupportedRoutesReject': 1,
    'contractNormalizationPlan': 1,
    'contractNativeTextOtherFamilies': 1,
    'contractEveryFieldHasCoverageDecision': 1,
    'contractEveryFormatHasCoverageDecision': 1,
    'contractCatalogReconciliation': 1,
}

REQUIRED_SUITES = (
    'IndependentDiagnosticRepairTests', 'SemanticLifecycleMatrixTests', 'FLACSemanticLifecycleTests',
    'ID3SemanticLifecycleTests', 'NativeProbeContractTests', 'BasicIntegrityMatrixTests',
    'AdditionalContainerLifecycleTests', 'ASFNativeLifecycleTests', 'AuditProbeTests',
    'ID3ContainerLifecycleTests', 'PublicWriteContractRepairTests', 'ReleaseAcceptanceTests',
    'ContractBuilderOracleSelfTests', 'ContractClaimsTests', 'ContractMP4ScenarioTests',
    'ContractBridgeAndEncodingTests', 'ContractNativeContainerTests', 'ContractFieldCoverageTests',
)

XCTEST_MINIMUM = 181
SWIFT_TESTING_MINIMUM = 272
SWIFT_SUITE_MINIMUM = 51


def xctest_identity(name: str):
    match = re.fullmatch(r'-\[([^\]\s]+) ([^\]]+)\]', name)
    if not match:
        return None
    return (match.group(1).split('.')[-1], match.group(2))


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _current_head() -> str | None:
    result = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def _current_source_hash() -> str | None:
    sys.path.insert(0, str(ROOT / "scripts"))
    try:
        import test_manifest
    except Exception:
        return None
    return test_manifest.current_source_hash()


def expected_scenarios(catalog: dict) -> dict[str, dict]:
    expected: dict[str, dict] = {}
    for contract in catalog.get("contracts", []):
        outcome = contract.get("outcome", "supported")
        runtime = contract.get("runtime_test")
        for scenario in contract.get("scenarios", []):
            expected[scenario["scenario_id"]] = {
                "runtime_test": runtime,
                "check_count": scenario["expected_assertions"],
                "outcome": outcome,
                "contract_id": contract.get("contract_id"),
            }
    for audit in catalog.get("audit_scenarios", []):
        expected[audit["scenario_id"]] = {
            "runtime_test": audit["runtime_test"],
            "check_count": audit["expected_assertions"],
            "outcome": "supported",
            "contract_id": None,
        }
    return expected


def collect_evidence(directory: Path) -> tuple[dict[str, dict], list[str]]:
    errors: list[str] = []
    records: dict[str, dict] = {}
    if not directory.is_dir():
        return {}, [f"scenario evidence directory does not exist: {directory}"]
    for path in sorted(directory.glob("*.json")):
        try:
            record = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            errors.append(f"unreadable scenario evidence {path.name}: {error}")
            continue
        scenario = record.get("scenario_id")
        if not isinstance(scenario, str) or not scenario:
            errors.append(f"scenario evidence without an id: {path.name}")
            continue
        if record.get("schema_version") != EVIDENCE_SCHEMA_VERSION:
            errors.append(f"scenario evidence schema mismatch: {scenario}")
        if scenario in records:
            errors.append(f"duplicate scenario evidence: {scenario}")
            continue
        records[scenario] = record
    return records, errors


def verify_evidence(expected: dict[str, dict], records: dict[str, dict]) -> list[str]:
    errors: list[str] = []
    missing = sorted(set(expected) - set(records))
    unexpected = sorted(set(records) - set(expected))
    if missing:
        errors.append(f"missing scenario execution evidence: {missing}")
    if unexpected:
        errors.append(f"unexpected scenario execution evidence: {unexpected}")
    for scenario, requirement in sorted(expected.items()):
        record = records.get(scenario)
        if record is None:
            continue
        if record.get("runtime_test") != requirement["runtime_test"]:
            errors.append(f"scenario {scenario} runtime test mismatch: {record.get('runtime_test')!r} != {requirement['runtime_test']!r}")
        if record.get("check_count") != requirement["check_count"]:
            errors.append(f"scenario {scenario} assertion budget mismatch: {record.get('check_count')!r} != {requirement['check_count']!r}")
        if record.get("outcome") != requirement["outcome"]:
            errors.append(f"scenario {scenario} outcome mismatch: {record.get('outcome')!r} != {requirement['outcome']!r}")
        checks = record.get("checks")
        if not isinstance(checks, list) or len(checks) != requirement["check_count"]:
            errors.append(f"scenario {scenario} did not report its full check list")
        elif not all(isinstance(check, dict) and check.get("passed") is True for check in checks):
            errors.append(f"scenario {scenario} recorded a failed check")
        if record.get("passed") is not True:
            errors.append(f"scenario {scenario} did not report an overall pass")
        if not isinstance(record.get("adapter"), str) or not record["adapter"].strip():
            errors.append(f"scenario {scenario} did not name its adapter")
    return errors


def validate_manifest(manifest: dict | None, manifest_after: dict | None, mode: str) -> list[str]:
    errors: list[str] = []
    if manifest is None:
        return ["canonical evidence requires a campaign manifest"]
    if manifest.get("mode") != mode:
        errors.append(f"manifest mode mismatch: {manifest.get('mode')!r} != {mode!r}")
    head = _current_head()
    if head is None:
        errors.append("cannot resolve current Git HEAD for manifest validation")
    elif manifest.get("commit") != head:
        errors.append("manifest commit does not match current HEAD")
    current_source = _current_source_hash()
    if current_source is None:
        errors.append("cannot recompute current source identity")
    elif manifest.get("source_hash") != current_source:
        errors.append("source identity changed after the manifest was written")
    for relative, expected_hash in (manifest.get("system_hashes") or {}).items():
        path = ROOT / relative
        if not path.is_file():
            errors.append(f"manifest system file is missing: {relative}")
        elif _sha256(path) != expected_hash:
            errors.append(f"manifest system file changed: {relative}")
    if manifest_after is not None:
        stable_before = {k: v for k, v in manifest.items() if k not in {"created_at", "run_id"}}
        stable_after = {k: v for k, v in manifest_after.items() if k not in {"created_at", "run_id"}}
        if stable_before != stable_after:
            errors.append("source or toolchain identity changed during the test campaign")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log")
    parser.add_argument("status", type=int)
    parser.add_argument("summary")
    parser.add_argument("--evidence-dir")
    parser.add_argument("--manifest")
    parser.add_argument("--manifest-after")
    parser.add_argument("--mode", choices=["debug", "release"], default="debug")
    args = parser.parse_args()

    log = Path(args.log).read_text(encoding="utf-8")
    status = args.status
    xctest = re.findall(r'Executed (\d+) tests?, with (?:(\d+) tests? skipped and )?(\d+) failures?', log)
    swift = re.findall(r'Test run with (\d+) tests? in (\d+) suites? (passed|failed)', log)
    skipped = re.findall(r"Test Case '(-\[[^']+\])' skipped", log)
    unexpected = [name for name in skipped if xctest_identity(name) not in ALLOWED_SKIPS]
    swift_skips = [line for line in log.splitlines()
                   if re.search(r'\b(?:Test|Suite)\s+(?!skipped\b).+?\s+skipped\b', line)
                   and 'Test Case ' not in line]
    failed_named_tests = sorted(set(re.findall(r'\bTest ([A-Za-z_]\w*)\([^)]*\) failed\b', log)))
    failed_xctest = sorted(set(re.findall(r"Test Case '(-\[[^']+\])' failed", log)))
    passed_xctest = {xctest_identity(name) for name in re.findall(r"Test Case '(-\[[^']+\])' passed", log)}
    missing_xctest = sorted(REQUIRED_XCTEST - passed_xctest)
    completed_suites = dict(re.findall(r'Suite (\w+) (passed|failed)', log))
    missing_suites = [suite for suite in REQUIRED_SUITES if suite not in completed_suites]

    executed_tests: dict[str, int] = {}
    for match in re.finditer(r'\bTest ([A-Za-z_]\w*)\([^)]*\)(?: with (\d+) test cases?)? passed\b', log):
        name = match.group(1)
        count = int(match.group(2) or 1)
        executed_tests[name] = max(executed_tests.get(name, 0), count)
    missing_tests = []
    for name, minimum in REQUIRED_TESTS.items():
        actual = executed_tests.get(name)
        if actual is None:
            missing_tests.append({'test': name, 'expected_cases': minimum, 'actual_cases': None})
        elif actual < minimum:
            missing_tests.append({'test': name, 'expected_cases': minimum, 'actual_cases': actual})

    framework_errors: list[str] = []
    nonempty_lines = [line for line in log.splitlines() if line.strip()]
    if not nonempty_lines:
        framework_errors.append("test log is empty")
    else:
        final_line = nonempty_lines[-1]
        if not (re.search(r'Test run with \d+ tests? in \d+ suites? (passed|failed)', final_line)
                or re.search(r'Executed \d+ tests?, with', final_line)):
            framework_errors.append("test log is truncated or has no framework completion summary")
    for marker in ("Build failed", "error: SwiftCompile", "Testing cancelled", "Fatal error:"):
        if marker in log:
            framework_errors.append(f"test log contains failure marker: {marker}")

    manifest = None
    manifest_after = None
    if args.manifest:
        try:
            manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            framework_errors.append(f"unreadable campaign manifest: {error}")
    if args.manifest_after:
        try:
            manifest_after = json.loads(Path(args.manifest_after).read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            framework_errors.append(f"unreadable post-run manifest: {error}")
    manifest_errors = validate_manifest(manifest, manifest_after, args.mode)

    scenario_errors: list[str] = []
    expected: dict[str, dict] = {}
    observed: dict[str, dict] = {}
    if args.evidence_dir:
        try:
            catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
            expected = expected_scenarios(catalog)
        except (OSError, json.JSONDecodeError) as error:
            scenario_errors.append(f"unreadable contract catalog: {error}")
        observed, collection_errors = collect_evidence(Path(args.evidence_dir))
        scenario_errors.extend(collection_errors)
        scenario_errors.extend(verify_evidence(expected, observed) if expected else [])
    else:
        scenario_errors.append("canonical evidence requires --evidence-dir")

    inventory_errors = validate_test_inventory(required_names=set(REQUIRED_TESTS))
    xctest_ok = bool(xctest) and int(xctest[-1][0]) >= XCTEST_MINIMUM and int(xctest[-1][2]) == 0
    swift_ok = bool(swift) and int(swift[-1][0]) >= SWIFT_TESTING_MINIMUM
    swift_ok = swift_ok and int(swift[-1][1]) >= SWIFT_SUITE_MINIMUM and swift[-1][2] == 'passed'
    ok = (
        not inventory_errors and status == 0 and xctest_ok and swift_ok
        and not unexpected and not swift_skips and not missing_suites and not missing_tests
        and not failed_named_tests and not failed_xctest and not missing_xctest
        and all(int(result[2]) == 0 for result in xctest)
        and all(result[2] == 'passed' for result in swift)
        and all(completed_suites[suite] == 'passed' for suite in REQUIRED_SUITES)
        and int(xctest[-1][1] or 0) == len(skipped)
        and not framework_errors and not manifest_errors and not scenario_errors
    )
    summary = {
        'source_inventory_errors': inventory_errors,
        'runner_exit_status': status,
        'campaign_manifest_commit': (manifest or {}).get('commit'),
        'campaign_manifest_mode': (manifest or {}).get('mode'),
        'campaign_source_hash': (manifest or {}).get('source_hash'),
        'manifest_errors': manifest_errors,
        'framework_errors': framework_errors,
        'xctest_executed': int(xctest[-1][0]) if xctest else None,
        'xctest_skipped': int(xctest[-1][1] or 0) if xctest else None,
        'xctest_failures': int(xctest[-1][2]) if xctest else None,
        'swift_testing_declarations': int(swift[-1][0]) if swift else None,
        'swift_testing_result': swift[-1][2] if swift else None,
        'swift_testing_suites': int(swift[-1][1]) if swift else None,
        'required_case_counts': {name: executed_tests.get(name) for name in REQUIRED_TESTS},
        'minimum_required_case_counts': REQUIRED_TESTS,
        'skipped_test_names': skipped,
        'unexpected_skips': unexpected,
        'swift_testing_skips': swift_skips,
        'missing_required_suites': missing_suites,
        'missing_required_tests': missing_tests,
        'failed_named_tests': failed_named_tests,
        'failed_xctest_names': failed_xctest,
        'missing_required_xctest': missing_xctest,
        'scenario_expected_count': len(expected),
        'scenario_observed_count': len(observed),
        'scenario_errors': scenario_errors,
        'accepted': ok,
    }
    Path(args.summary).write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
