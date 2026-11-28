#!/usr/bin/env python3
"""Fail closed on incomplete, stale, mixed or unexecuted contract evidence.

XCTest and Swift Testing logs are only supporting evidence. Acceptance also
requires a fresh source/build manifest, the exact catalog scenario set, each
scenario's exact assertion budget, completed framework summaries and only the
two reviewed opt-in XCTest skips.
"""
from __future__ import annotations

import argparse
from collections import Counter
import test_manifest
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
    "canonicalNativeValueWinsDespiteLegacyAliasDiagnostic": 1,
    "ordinaryNumberEditsRecoverAndRetireOnlyOwnedGroup": 21,
    "numberTextRetiresProvenanceInSameSave": 4,
    "canonicalNumbersBeatConflictingOrMalformedPrivateProvenance": 1,
    "ambiguousMissingSiblingNeedsValueButFullReplacementSucceeds": 1,
    "malformedMissingSiblingDoesNotDisappearDuringPartialEdit": 1,
    "staleAndInvalidMixedWritesCannotPartiallyCleanPrivateData": 1,
    "convenienceNumberTextExplicitZeroIsAuthoritative": 4,
    "metadataPatchNumberTextExplicitZeroIsAuthoritative": 3,
    "convenienceDiscExplicitZeroIsAuthoritative": 3,
    "convenienceNumberTextRetiresEditedGroupProvenance": 1,
    "partialMalformedPrivateTextMustNotSupplyMissingSibling": 2,
    "strictPrivateTextStillRecoversMissingSibling": 1,
    "zeroValuedNativeComponentUsesCanonicalOrRecoveredCounterpart": 1,
    "titleOnlyWriteDoesNotCreateOrMigrateNumberPair": 1,
    "readsDoNotMutateBytesOrVersion": 1,
    "fullExplicitReplacementRetiresOnlyEditedGroup": 1,
    "explicitIntentMatrix": 60,
    "explicitIntentFacadeVerificationDisabled": 30,
    "opaquePrivateEvidenceIsNotRecovered": 2,
    "canonicalNativeTotalBeatsOpaquePrivateEvidence": 1,
    "strictSinglePrivateEvidenceStillRecoversMissingSibling": 2,
    "matchingStrictNamespacesRecoverAndBothRetire": 1,
    "conflictingStrictNamespacesRejectWithoutMutation": 1,
    "id3ExplicitZeroReopensAndAllowsTotalOnlyEdit": 2,
    "id3ZeroPaddedExplicitZeroRoundTrips": 1,
    "convenienceRetiresBothSelectedGroupsAndPreservesOthers": 1,
    "convenienceTrackSelectionRetiresEvenWhenValueUnchanged": 1,
    "facadeAndPatchUseOneStage": 1,
    "lowLevelBridgePreservesUnmodeledPrivateOwners": 1,
    "facadeDoesNotCreatePrivateAtoms": 1,
    "contractNumberIntentAndRetirement": 1,
    "contractID3NumberIntent": 1,

    "contractFullModelRetiresEditedReleaseAlias": 1,
    "contractPreviouslyUnobservedSurfaces": 1,
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
    'editsProviderWrittenAtomsAndSeparateTextInOneTransaction': 1,
    'discoversAndEditsAllWritableNonPropertyMapMP4Fields': 1,
    'rawGroupingAndDatePreserveSingleOwnerWithoutDuplication': 1,
    'rawEditsAndDeletesPreserveShadowedFreeformsAcrossNativeMP4Atoms': 1,
    'rawNonCanonicalMP4AliasesRejectWithoutCreatingDuplicateFreeforms': 1,
    'untouchedMP4FreeformsPreserveExactLocaleAndDataBytes': 1,
    'duplicateFreeformsAndUTF16AtomsSurviveMP4Saves': 1,
    'explicitDeletionOfUnparsedMP4AtomsRejectsAtomicallyAcrossAPIs': 1,
    'unrelatedEditsPreserveDuplicateMixedCommentOrderAndBytes': 1,
    'structuredPropertiesAndReplaceHonorMP4FreeformsAliasesAndRollback': 1,
    'rawReplaceAndMP4WritesPreserveCaseCollisionsAndBinaryFreeforms': 1,
    'emptyEditorPatchEnforcesVersionAudioAndFileGuards': 1,
    'preservesLegacyAdvisoryUntilAnExactNativeEdit': 1,
    'rejectsInvalidAndStaleChangesWithoutPartialWrites': 1,
    'manualMP4SnapshotAndEditorFieldInitializer': 1,
    'offersNativeRowsOnlyForMP4Files': 1,
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
    'AutomaticNumberingTests', 'PreReleaseAuditTests', 'NumberingContractRepairTests', 'ContractNumberIntentTests', 'ContractBuilderOracleSelfTests', 'ContractClaimsTests', 'ContractMP4ScenarioTests',
    'ContractBridgeAndEncodingTests', 'ContractNativeContainerTests', 'ContractFieldCoverageTests',
    'MP4MetadataEditorTests',
)

XCTEST_MINIMUM = 181
SWIFT_TESTING_MINIMUM = 326
SWIFT_SUITE_MINIMUM = 56


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
    identities = json.loads((ROOT / "scripts/package-test-system/scenario-assertions.json").read_text())
    if set(identities) != set(expected): raise ValueError("assertion/scenario inventory mismatch")
    for key, value in expected.items():
        identity = identities[key]
        if identity["runtime_test"] != value["runtime_test"] or len(identity["checks"]) != value["check_count"]:
            raise ValueError("assertion requirement mismatch: " + key)
        value.update({"checks": identity["checks"], "adapter_label": identity["adapter_label"]})
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
        if not isinstance(record, dict):
            errors.append("scenario evidence is not an object: " + path.name)
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


def verify_evidence(expected: dict[str, dict], records: dict[str, dict], manifest: dict | None = None) -> list[str]:
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
        identity = {"id": (manifest or {}).get("run_id"), "mode": (manifest or {}).get("mode"),
                    "source_hash": (manifest or {}).get("source_hash")}
        if not all(identity.values()) or record.get("campaign") != identity:
            errors.append(f"scenario {scenario} campaign mismatch")
        if record.get("adapter") != requirement["adapter_label"]:
            errors.append(f"scenario {scenario} adapter identity mismatch")
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
        if isinstance(checks, list) and Counter(str(c.get("name")) for c in checks if isinstance(c, dict)) != Counter(requirement["checks"]):
            errors.append(f"scenario {scenario} assertion identity mismatch")
        if record.get("passed") is not True:
            errors.append(f"scenario {scenario} did not report an overall pass")
        if not isinstance(record.get("adapter"), str) or not record["adapter"].strip():
            errors.append(f"scenario {scenario} did not name its adapter")
    return errors


def verify_invocations(directory: Path, manifest: dict | None) -> list[str]:
    expected = json.loads((ROOT / "scripts/package-test-system/runtime-invocations.json").read_text())["tests"]
    observed = {}
    identity = {"id": (manifest or {}).get("run_id"), "mode": (manifest or {}).get("mode"), "source_hash": (manifest or {}).get("source_hash")}
    errors = []
    for path in (directory / "invocations").glob("*.json"):
        try: event = json.loads(path.read_text())
        except (ValueError, OSError): errors.append("invalid invocation record"); continue
        if not isinstance(event, dict): errors.append("invocation is not an object"); continue
        if event.get("schema_version") != 1: errors.append("invocation schema mismatch")
        if event.get("campaign") != identity: errors.append("invocation campaign mismatch")
        if event.get("outcome") not in {"returned", "threw"}: errors.append("invalid invocation outcome")
        test = event.get("runtime_test")
        key = str(event.get("adapter")) + "|" + str(event.get("outcome"))
        observed.setdefault(test, []).append(key)
    if set(observed) != set(expected): errors.append("runtime invocation test set mismatch")
    for test in expected:
        if Counter(observed.get(test, [])) != Counter(expected[test]): errors.append("runtime invocation identity/multiplicity mismatch: " + test)
    registered = {row["id"] for row in json.loads((ROOT / "scripts/package-test-system/execution-adapters.json").read_text())["adapters"]}
    if {key.split("|")[0] for calls in expected.values() for key in calls} != registered:
        errors.append("adapter runtime coverage inventory mismatch")
    return errors


def validate_manifest(manifest: dict | None, manifest_after: dict | None, mode: str) -> list[str]:
    errors: list[str] = []
    if not isinstance(manifest, dict):
        return ["canonical evidence requires a campaign manifest"]
    if manifest.get("mode") != mode:
        errors.append(f"manifest mode mismatch: {manifest.get('mode')!r} != {mode!r}")
    required = {"schema_version", "run_id", "created_at", "mode", "commit", "branch", "toolchain", "system_hashes",
                "file_hashes", "source_hash", "git_status", "tracked_diff_hash", "build_options", "sdk", "target"}
    if manifest.get("schema_version") != 2 or not required.issubset(manifest):
        errors.append("manifest schema or required identity fields missing")
    if not isinstance(manifest.get("toolchain"), dict) or not {"swift", "xcodebuild", "platform", "machine", "developer_dir"}.issubset(manifest.get("toolchain") or {}):
        errors.append("manifest toolchain identity missing")
    if manifest.get("build_options") != test_manifest.options(mode): errors.append("manifest build options mismatch")
    if not manifest.get("sdk") or not isinstance(manifest.get("target"), dict): errors.append("manifest SDK/target missing")
    if set(manifest.get("system_hashes") or {}) != set(test_manifest.SYSTEM_FILES): errors.append("manifest system identity incomplete")
    current = test_manifest._source_state()
    if manifest.get("file_hashes") != current["file_hashes"]: errors.append("manifest file inventory mismatch")
    if not isinstance(manifest_after, dict): errors.append("post-run manifest is required")
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
    if isinstance(manifest_after, dict):
        stable_before = {k: v for k, v in manifest.items() if k not in {"created_at"}}
        stable_after = {k: v for k, v in manifest_after.items() if k not in {"created_at"}}
        if stable_before != stable_after:
            errors.append("source or toolchain identity changed during the test campaign")
    return errors


def verify_calibration(result: dict | None, manifest: dict | None) -> list[str]:
    if not isinstance(result, dict): return ["complete acceptance requires calibration evidence"]
    definitions = json.loads((ROOT / "scripts/calibration-mutants.json").read_text())["mutants"]
    ids = [row["id"] for row in definitions]
    errors = []
    if (result.get("schema_version") != 2 or result.get("runner") != "canonical-package-tests"
            or result.get("acceptance") != "accepted" or result.get("source_restored") is not True):
        errors.append("calibration was not accepted by the canonical runner")
    if result.get("source_hash") != (manifest or {}).get("source_hash") or result.get("commit") != (manifest or {}).get("commit"):
        errors.append("calibration source/commit mismatch")
    if result.get("definition_hash") != _sha256(ROOT / "scripts/calibration-mutants.json"):
        errors.append("calibration definitions changed")
    rows = result.get("mutants", [])
    if not isinstance(rows, list): return errors + ["invalid calibration mutant list"]
    if result.get("expected_mutant_ids") != ids or Counter(row.get("id") for row in rows if isinstance(row, dict)) != Counter(ids):
        errors.append("calibration mutant set incomplete or duplicated")
    by_id = {row["id"]: row for row in definitions}
    for row in rows:
        definition = by_id.get(row.get("id")) if isinstance(row, dict) else None
        if definition is None: errors.append("unknown calibration mutant"); continue
        if (row.get("status") != "killed" or row.get("restored") is not True or row.get("build_exit_status") != 0
                or row.get("exit_status") != 1 or row.get("named_failure") is not True
                or row.get("test_filter") != definition["test_filter"]
                or not any(definition["witness"] in line for line in row.get("activation_witness", []))):
            errors.append("calibration activation missing: " + definition["id"])
    control = result.get("control", {})
    if any(control.get(key) != 0 for key in ("build_exit_status", "exit_status", "final_build_exit_status", "final_exit_status")) or any(
            control.get(key) is not True for key in ("named_tests_passed", "final_named_tests_passed")):
        errors.append("calibration controls did not pass")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log")
    parser.add_argument("status", type=int)
    parser.add_argument("summary")
    parser.add_argument("--evidence-dir")
    parser.add_argument("--manifest")
    parser.add_argument("--manifest-after")
    parser.add_argument("--calibration")
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
    calibration = None
    if args.calibration:
        try: calibration = json.loads(Path(args.calibration).read_text())
        except (OSError, ValueError): pass
    calibration_errors = verify_calibration(calibration, manifest)

    scenario_errors: list[str] = []
    expected: dict[str, dict] = {}
    observed: dict[str, dict] = {}
    if args.evidence_dir:
        try:
            catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
            expected = expected_scenarios(catalog)
        except (OSError, ValueError, KeyError, TypeError) as error:
            scenario_errors.append(f"unreadable contract catalog: {error}")
        observed, collection_errors = collect_evidence(Path(args.evidence_dir))
        scenario_errors.extend(collection_errors)
        scenario_errors.extend(verify_evidence(expected, observed, manifest) if expected else [])
        scenario_errors.extend(verify_invocations(Path(args.evidence_dir), manifest))
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
        and not framework_errors and not manifest_errors and not scenario_errors and not calibration_errors
    )
    summary = {
        'source_inventory_errors': inventory_errors,
        'runner_exit_status': status,
        'campaign_manifest_commit': (manifest or {}).get('commit'),
        'campaign_manifest_mode': (manifest or {}).get('mode'),
        'campaign_source_hash': (manifest or {}).get('source_hash'),
        'manifest_errors': manifest_errors,
        'calibration_errors': calibration_errors,
        'calibration_source_hash': (calibration or {}).get('source_hash'),
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
