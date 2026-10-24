# Documentation system completion

| Field | Value |
| --- | --- |
| Record ID | `DOC-2026-10-24-documentation-completion` |
| Type | Documentation |
| Date | `2026-10-24` |
| Status | Final |
| Examined revision | `fefdb88` production source; documentation-only working tree |
| Branch | `docs/documentation-architecture-restructure` |
| Environment | macOS 27.0.1 (26A434), arm64; Xcode 27.1 (27A9275); Apple Swift 6.4 |
| Supersedes | `none` (supersedes the current-owner role of `DOC-2026-10-21` by adding the missing reference layer) |
| Superseded by | `none` |
| Related records | `DOC-2026-10-21-documentation-reconstruction`, `DOC-2026-10-19-documentation-restructure` |
| Scope | Re-read the Swift facade, field registry, public bridge, format registry, and transaction and audio-identity code; rebuilt the current documentation layer around them. Production behavior was not changed. Historical records were not revalidated. |

## Summary

The previous pass had a coherent hub but an incomplete reference layer and several statements that were broader than the source. The highest-impact problems were an API reference that claimed completeness without listing every public declaration, no field-schema reference at all, bridge documentation buried inside the Swift reference, contradictory `RIFFMetadataWritePolicy` scope, an incorrect privilege-test description in `STATUS.md`, and a documentation check that could not detect registry drift.

This pass adds a generated field-schema reference, a dedicated public bridge reference, a complete public Swift reference including compatibility overloads and model initializers, and source-checked format/field/API coverage in `scripts/check-docs.py`. It also rewrites the current topic documents so each has a narrow owner and links to the others instead of restating them.

## Scope and revision

The source inspection covered `Package.swift`, every Swift file under `Sources/TagLibAudioMetadata/`, the public bridge header and transaction coordinator, the format registry and container masks, the structured mutation and inspection paths, and the tests used to confirm counts, permissions, and fixture coverage. The production source revision was `fefdb88`; the working tree contains documentation, generated documentation tables, check tooling, and this record only.

The review deliberately did not:

- change production behavior or public API;
- revalidate historical audit findings beyond the source checks needed for current prose;
- add a DocC catalog or generated symbol documentation;
- run Xcode `RunAllTests`, AddressSanitizer, ThreadSanitizer, Release, minimum-platform builds, consumers, the opt-in corpus, or the benchmark;
- execute device, simulator, minimum-OS, or x86_64 runtime checks.

## Method

- Read the public declarations and source behavior instead of trusting prior prose.
- Compared the Swift field registry with the generated field tables and the bridge's ordered mapping tables.
- Parsed the format registry to verify family count, extension count, and extension coverage in the format matrix.
- Cross-checked the transaction pipeline, `expectedVersion`/audio guards, structured mutation dispatch, and verification helpers.
- Ran the full SwiftPM test suite to refresh the observed status and confirm the known privilege-bit limitation.
- Ran `scripts/check-docs.py` after the rewrite and added checks for generated field tables, format coverage, and public-manager-function index coverage.

## Findings

### F-01 — The field registry had no canonical reference

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** `MetadataFieldSchema.swift` defines 79 public fields with `PropertyMap`, ID3v2, MP4, and flags. The previous `API_REFERENCE.md` listed categories and a key table but no per-field mapping reference.
- **Impact:** Implementers had to read Swift source to learn whether a key was an ID3 text frame, a TXXX frame, an MP4 atom, a freeform item, a multi-value field, or a role-qualified key.

### F-02 — Bridge documentation was incomplete and buried in the Swift reference

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** The public bridge has a 20+ selector surface, projection-key rules, a separate product/import requirement, and a transaction contract that differs from the facade. The previous reference compressed this into two tables at the end of `API_REFERENCE.md` and did not document all projection-shape details.
- **Impact:** Low-level consumers could miss the product requirement or assume the bridge performs facade semantic verification.

### F-03 — The API reference was not actually complete

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** The previous document omitted several public compatibility overloads, most model initializers, `FormatCapability.init`, `MetadataFieldSchema.init`, `MetadataFormatMapping.init`, and the full `MetadataWriteVerificationContext` property set. It claimed to cover the complete public surface.
- **Impact:** Consumers could not tell which overloads were supported or how to construct model values for tests and tools.

### F-04 — RIFF policy scope and bridge readback wording were contradictory

- **Severity:** High for a caller who relied on the broad wording
- **Confidence:** Confirmed by source inspection
- **Status:** Fixed
- **Evidence:** `writeStructuredMetadataWithVerification` rejects `.syncBasicFieldsToInfo` only for WAV and AIFF/AIFF-C; other formats ignore the policy value. The previous API reference said the policy "is reserved and rejects with `unsupportedWritePolicy`" without that scope. It also described `writeTagMetadata` readback limits inconsistently between sections.
- **Impact:** A caller could expect a throw for MP4/ASF/Xiph or overestimate the default bridge-model write's verification.

### F-05 — Status described the privilege test with the wrong modes

- **Severity:** Medium
- **Confidence:** Confirmed by test source and the observed run
- **Status:** Fixed
- **Evidence:** `CleanRoomPrivilegeTests` requests `0o4644`, `0o2644`, and `0o6644`. The previous `STATUS.md` said the observed mode was `0644` instead of `2468`, which does not match the test's requested bits. The fresh run observed mode `420` decimal (`0o644`) and failed at the test's own precondition.
- **Impact:** Readers could misdiagnose the environment-dependent failure or think the test asserted an unrelated mode.

### F-06 — Warnings were described as uniformly non-fatal

- **Severity:** Low
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** `applyMetadataPatch`, `replaceBasicMetadata`, and several other verified writers append mismatch messages to `warnings` and then call `throwOnVerificationFailures(warnings)`. A successful result therefore normally carries only residual advisories. The previous docs described warnings generally as non-fatal container advisories.
- **Impact:** A caller could treat a verification mismatch list as informational or assume a returned warning was necessarily non-fatal.

### F-07 — Current documents still duplicated contracts and had a flat, hard-to-scan layout

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** The previous hub mixed reading paths, an owner matrix, and evidence vocabulary; `USAGE.md`, `FORMATS.md`, `PRESERVATION.md`, and `API_REFERENCE.md` each carried overlapping structured-format limits and deprecation notes.
- **Impact:** One behavior change required edits in several files, and readers could not tell which statement was canonical.

### F-08 — The documentation check could not detect registry drift

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** The previous check validated links, tables, H1 count, and hub coverage. It did not check that the field registry had a complete table, that all format extensions were listed, or that public manager functions and public types appeared in the API reference.
- **Impact:** A source schema or format change could ship with stale reference documentation while the check passed.

### F-09 — The local-only audit input sat at the repository root

- **Severity:** Low
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** `AUDIT_REPORT.md` was present at the repository root and excluded through `.git/info/exclude`. The records index correctly described it as local-only, but its root location made it look like an unorganized committed document.
- **Impact:** A reader could not tell from the tree whether the file was part of the repository, and the project root carried a 115 KB historical artifact that belongs with local working material or the records archive.

## Repairs or recommendations

- Added `docs/FIELD_SCHEMA.md` with generated tables for all 79 fields, lookup/ownership rules, typed-patch constraints, and cross-language parity notes.
- Added `docs/BRIDGE.md` with the low-level product, bridge model, constants, selectors, projection keys, transaction boundary, and diagnostics.
- Rewrote `docs/API_REFERENCE.md` with the complete public Swift surface, compatibility overloads, model initializers, nested types, errors, and deprecation map; moved bridge and field details to their canonical documents.
- Rewrote `README.md`, `docs/README.md`, `docs/USAGE.md`, `docs/FORMATS.md`, `docs/PRESERVATION.md`, `docs/TRANSACTIONS.md`, `docs/ARCHITECTURE.md`, `docs/TESTING.md`, `docs/STATUS.md`, `docs/MIGRATION.md`, `docs/INSTALLATION.md`, and `docs/DEVELOPMENT.md` against the current source.
- Added `scripts/generate-field-schema.py` and regenerated the field tables from `MetadataFieldSchema.swift`.
- Extended `scripts/check-docs.py` to check generated field-table freshness, family/extension count and extension coverage, and public-manager-function index coverage.
- Corrected the privilege-test description and refreshed the observed status at `fefdb88`.
- Moved the local-only 2026-10-18 audit from the repository root to `.local/audits/AUD-2026-10-18-independent-technical-audit.md`, ignored `.local/` in Git, updated the records index, and excluded `.local/` from the documentation walk.

## Verification

| Check | Result | Counts / limits |
| --- | --- | --- |
| `python3 scripts/check-docs.py` | Pass | Current tree; links, fragments, tables, H1 count, hub coverage, generated field tables, format coverage, public API index |
| `python3 scripts/generate-field-schema.py --check` | Pass | 79 fields; Swift registry only |
| `swift build --disable-keychain --disable-netrc --disable-sandbox` with workspace-local module caches | Pass | Debug build; no production source changes |
| `swift test --disable-keychain --disable-netrc --disable-sandbox` with workspace-local module caches | Observed | 153 XCTest: 151 passed, 2 skipped; 72 Swift Testing: 71 passed, 1 environment-dependent privilege-bit failure |
| Xcode `RunAllTests` | Not run | No current-run claim |
| ASAN / TSAN / Release / minimum-platform / consumers / corpus / benchmark | Not run | Configured in CI; not evidence for this working tree |

## Remaining limitations

- The documentation check is structural and source-table-driven. It cannot prove prose correctness, Swift signatures, or runtime behavior.
- The field-table generator reads only the Swift registry. The bridge has a parallel mapping table and parity tests, but the documentation generator does not parse the bridge.
- `API_REFERENCE.md` remains hand-maintained for signatures and descriptions; the public-manager-function check catches missing function names, not wrong defaults or types.
- No DocC catalog or generated symbol index was added. Xcode Quick Help still depends on the source declarations and their existing comments.
- Historical records were not independently revalidated; their index annotations remain the authority for current relevance.
- The privilege test remains host-dependent and cannot pass in a sandbox that strips setuid/setgid bits.

## References

- Commits: `fefdb88` Record documentation reconstruction in changelog (production source baseline)
- Source: `Sources/TagLibAudioMetadata/`, `Sources/CTagLibBridge/include/TagLibMetadataExtractor.h`, `Sources/CTagLibBridge/TLFormatRegistry.mm`, `Sources/CTagLibBridge/Internal/TLMetadataCore.inc`
- Tests: `Tests/TagLibAudioMetadataTests/Capabilities/FormatCapabilityTests.swift`; `Tests/TagLibAudioMetadataTests/Transactions/CleanRoomPrivilegeTests.swift`; `Tests/TagLibAudioMetadataTests/Transactions/AudioContentIdentityTests.swift`
- Current documentation: [hub](../../README.md), [API reference](../../API_REFERENCE.md), [field schema](../../FIELD_SCHEMA.md), [bridge](../../BRIDGE.md), [formats](../../FORMATS.md), [status](../../STATUS.md)
- Related records: [2026-10-21 reconstruction](DOC-2026-10-21-documentation-reconstruction.md), [2026-10-19 restructure](DOC-2026-10-19-documentation-restructure.md)
