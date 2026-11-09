# Documentation system reconstruction

| Field | Value |
| --- | --- |
| Record ID | `DOC-2026-11-09-documentation-reconstruction` |
| Type | Documentation |
| Date | `2026-11-09` |
| Status | Final |
| Examined revision | `1380f7d` production source plus comment-only wording updates; documentation working tree |
| Branch | `codex/metadata-mapping-spec` |
| Environment | macOS 27.2, arm64; Xcode 27.2 (27B52); Apple Swift 6.4.2 |
| Supersedes | The current-owner role of `DOC-2026-10-24-documentation-completion` |
| Superseded by | `none` |
| Related records | `DOC-2026-10-24-documentation-completion`, `REM-2026-11-09-mapping-2-2-implementation`, `REM-2026-11-09-numbering-acceptance-repairs` |
| Scope | Re-read the Swift facade, schema, mapping catalog, bridge header, registry, transactions, and tests; rebuilt the documentation system around source-derived reference pages and narrower guides. Production behavior was not intentionally changed. Historical records were not revalidated. |

## Summary

The documentation was broad but internally inconsistent. Current pages disagreed with the source and with each other: the field schema claimed 79 fields while the enum had 101; it claimed the shared DATE/YEAR owner maps were empty while they were populated; the format page said mapping contract 2.2 was not implemented and that MP4 `.date` writes were unsupported; the architecture page described a selective Basic read and private-atom migration that no longer existed; the API page omitted public properties and listed two error cases on the wrong enum; and the status page overstated the current test result. The previous check passed all of these because it searched for strings rather than source-derived invariants.

This pass:

- moved current docs into `guide/`, `reference/`, `explanation/`, and `operations/`, with a task-based hub;
- made `MetadataMappingCatalog.swift` the authoritative mapping table and removed the Markdown-to-Swift generator;
- added generated manager API, model, field, format, and mapping reference pages;
- generated those pages from Swift/C++ source and made `check-docs.py` verify their freshness;
- corrected the semantic contradictions and documented code limitations as limitations;
- split the old monolithic usage page into focused guides.

## Scope and revision

The production source was `1380f7d`; the only source changes in this pass are comments in `MetadataFieldSchema.swift` and `MetadataMappingCatalog.swift`. The reviewed surface included every Swift file under `Sources/TagLibAudioMetadata/`, the public bridge header and transaction coordinator, the format registry and container masks, the structured mutation/inspection paths, and the test and fixture layout. Apart from those comments, the working tree contains documentation, scripts, generated reference pages, and this record only.

The review did not:

- change production behavior or public API;
- add a DocC catalog or generated symbol documentation served by a documentation host;
- revalidate historical audit findings beyond the source checks needed for current prose;
- run AddressSanitizer, ThreadSanitizer, Release in this pass, minimum-platform builds, consumers, the opt-in corpus, the benchmark, or device/simulator runtime checks;
- verify application adoption or the mirrored application specification.

Debug and Release suites were run at source `1380f7d` before the rewrite; Debug was repeated after the documentation changes with the same counts. The only source changes in this pass are comments in `MetadataFieldSchema.swift` and `MetadataMappingCatalog.swift`; no behavior changed.

## Method

- Read the public declarations, source comments, schema, mapping catalog, bridge header, registry, and transaction code rather than trusting prior prose.
- Compared the field and mapping tables with Swift source and regenerated them.
- Parsed the bridge format registry, container masks, and field allowlists to generate the format matrix.
- Parsed the public Swift declarations to generate manager and model references.
- Parsed the public header to check bridge selector and constant coverage.
- Added generator `--check` modes and wired them into `scripts/check-docs.py`.
- Rewrote stale statements against source; where source behavior is a limitation rather than the documented ideal, the limitation was documented instead of changing production code.
- Ran the full Debug and Release SwiftPM suites before the documentation rewrite; results are recorded in [Status](../../operations/STATUS.md).

## Findings

### D-01 — Field counts and shared ownership were stale

- **Severity:** High
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** The old `FIELD_SCHEMA.md` said "79 fields" while `MetadataFieldSchema.swift` had 101 cases and the generated table had 101 rows. It also said `sharedPropertyMapKeyOwners` and `preferredSharedPropertyMapKeyOwner` were empty, while the source maps `DATE` and `YEAR` to `{.date, .year}` with `.year` preferred.
- **Impact:** Consumers and maintainers could not trust the registry summary or shared-key behavior.

### D-02 — Mapping contract status was inverted

- **Severity:** High
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** `METADATA_MAPPING_SPEC.md` began "accepted target design; not implemented" while its own implementation-status section and the Swift catalog marked the package-side registry, dates, numbers, advisory, and MP4-exclusive fields implemented in the working tree. `FORMATS.md` described the 2.2 matrix as future behavior.
- **Impact:** Readers could mistake implemented behavior for a proposal, or infer support for untested areas.

### D-03 — The API reference was not complete

- **Severity:** High
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** The hand-written `API_REFERENCE.md` omitted 22 `BasicMetadata` properties, `StructuredID3v2Frame.v23ID`/`v24ID`/descriptions, `StructuredMP4Atom.remove`, `MetadataNativeStorageKind.isExtension`, and many model initializers. It placed `ambiguousNumberRecovery` and `conflictingYearRepresentations` on `MetadataValidationError` instead of `MetadataPatchValidationError`.
- **Impact:** A caller following the supposed complete index could not compile correct code or would handle unreachable cases.

### D-04 — Format and number behavior contradicted the code and tests

- **Severity:** High
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** The old docs said partial track/disc removal was rejected on MPEG/ID3, AAC, MP4, WAV, AIFF, TrueAudio, DSF, DSDIFF, and ASF. Source rejects only ASF number-zero-plus-total; tests assert MP4 `0/total` and ID3 `/total`. The docs also said MP4 `.date` was unsupported, while the catalog gives `.date` and `.year` the same preferred `©day` target, with only the pair being rejected.
- **Impact:** Applications could disable supported edits or attempt rejected ones.

### D-05 — Read-path and preservation descriptions were stale

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** `readMetadataResult` and `readBasicSnapshot` were described as avoiding structured models; both request `.all` and derive structured metadata internally. Basic preservation was described as replaying raw state through `preservedStandardValues`; that helper has no caller, and actual preservation uses native MP4/Xiph/APE/ID3 paths.
- **Impact:** Performance and preservation expectations were wrong.

### D-06 — Basic replacement does not write MP4-exclusive fields

- **Severity:** High
- **Confidence:** Confirmed
- **Status:** Documented limitation
- **Evidence:** `BasicMetadata` exposes the MP4-exclusive properties, but `replaceBasicMetadata` does not assign them to the bridge model; the header has no matching properties. Tests reach those fields through `MetadataPatch`.
- **Impact:** A Basic read/modify/write silently ignores those edits. The docs now state the limitation and direct callers to `MetadataPatch`/structured writes.

### D-07 — Structured comments/lyrics support was overstated

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** Replace-all structured comments/lyrics are implemented on ID3-backed paths and TrueAudio. MP4 ignores them; APE-family and FLAC/Ogg reject them. The old docs implied general replace-all semantics.
- **Impact:** Callers could expect verification success for collections the writer never handled.

### D-08 — ID3 structured type and field behavior was incomplete

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** `versionedText` is writable and requires version-specific identities; it was omitted from the documented allowlist. `StructuredID3v2Frame.fields` is merged into the bridge payload, not ignored. `StructuredMP4Atom.remove` was missing from the reference.
- **Impact:** Callers could not discover the supported path, or could overwrite reserved payload keys.

### D-09 — Source-of-truth direction was backwards

- **Severity:** High
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** `MetadataMappingCatalog.swift` was generated by `scripts/generate-mapping-registry.py` from a Markdown specification. That makes documentation normative over production code and lets a prose edit silently change the mapping table.
- **Impact:** Contradicted the repository's stated source-of-truth rule and made the mapping table harder to validate.
- **Repair:** The Swift catalog is now declarative source. `scripts/generate-mapping-registry.py` was removed; `scripts/generate-mapping-matrix.py` renders the documentation matrix from the catalog.

### D-10 — Validation status overstated the latest run

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** The old status page reported zero Swift Testing failures and a passed privilege regression in the same summary. The current sandbox run has one environment-dependent failure: `CleanRoomPrivilegeTests` cannot preserve setuid/setgid bits. The page also mixed counts from different revisions.
- **Impact:** Maintainers could treat an unverified or environment-dependent result as green.
- **Repair:** Status now separates the current Debug/Release observation, environment, counts, failure, and un-run checks.

### D-11 — Documentation structure duplicated ownership

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** The old usage page duplicated preservation, transaction, audio-identity, and verification contracts; the API page duplicated field-schema rules; the hub owner table was the only navigation layer while the file tree was flat and mixed current docs with records.
- **Impact:** Every behavioral change required edits in several places, and stale copies survived.
- **Repair:** Current docs are grouped by purpose, the old usage page was split into four guides, and detailed contracts have one owner with links.

### D-12 — The old documentation check could not detect drift

- **Severity:** High
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** The old check passed while the field page contained "79 fields", the shared-key statement was false, and the API page was incomplete. It searched for "101 fields" anywhere, including the generated comment that already stated the correct count.
- **Repair:** `check-docs.py` now checks hub coverage, retired paths, links/fragments, tables, one H1, generated page freshness, registered extension coverage, public Swift declaration coverage, and public bridge selector/constant coverage.

## Repairs

- New layout under `docs/guide/`, `docs/reference/`, `docs/explanation/`, and `docs/operations/`; records remain under `docs/records/`.
- New generated pages: `reference/API.md`, `reference/MODELS.md`, `reference/FIELDS.md` (generated sections), `reference/FORMATS.md` (generated matrix), and `reference/MAPPING_MATRIX.md`.
- `MetadataMappingCatalog.swift` header now states that it is the declarative source of truth; the Markdown-to-Swift generator was removed.
- New generators: `scripts/generate-api-reference.py`, `scripts/generate-format-matrix.py`, and `scripts/generate-mapping-matrix.py`; `scripts/generate-field-schema.py` was rewritten to render the summary, native tables, and patch policy.
- `scripts/check-docs.py` rewritten around the new layout and source-derived invariants.
- `README.md`, the hub, and every current topic page rewritten or corrected; old `docs/USAGE.md` removed after its content was split.
- Records index updated; historical links repaired only where path moves required it.

## Verification

| Check | Result | Scope |
| --- | --- | --- |
| Debug XCTest | 156 executed, 154 passed, 2 skipped, 0 failed | `1380f7d`, macOS 27.2 arm64 |
| Debug Swift Testing | 108 tests, 107 passed, 1 environment-dependent failure | Same |
| Release XCTest | 156 executed, 154 passed, 2 skipped, 0 failed | Same |
| Release Swift Testing | 108 tests, 107 passed, 1 environment-dependent failure | Same |
| `generate-api-reference.py --check` | Passed | 845 declarations scanned |
| `generate-field-schema.py --check` | Passed | 101 fields |
| `generate-format-matrix.py --check` | Passed | 22 families, 37 extensions |
| `generate-mapping-matrix.py --check` | Passed | 100 profiles, 498 target registrations |
| Strict build | Passed | `swift build -Xswiftc -warnings-as-errors -Xcc -Werror` |
| `check-docs.py` | Passed | 45 Markdown files |

The privilege failure is the same host restriction recorded in [Status](../../operations/STATUS.md): the host strips setuid/setgid bits. It was not skipped or weakened.

Not run in this pass: sanitizers, minimum-platform builds, consumers, device/simulator runtime, cross-tool fixtures, and application adoption.

## Remaining limitations

- `replaceBasicMetadata`/`updateBasicMetadata` still do not write the MP4-exclusive Basic fields; this is now documented, not fixed.
- The bridge writer model still lacks those MP4-exclusive properties.
- `.rate` typed writes remain withheld.
- MKV `tvEpisode`/`tvSeason` remain target-only registrations.
- ASF total-only number pairs remain unsupported.
- Structured MP4 comments/lyrics are ignored; APE-family and FLAC/Ogg reject them.
- `StructuredID3v2Frame.fields` can overwrite reserved bridge dictionary keys; callers are told to leave it empty.
- Documentation generation is source-derived but the prose still needs human review; the checks are structural, not semantic.
- No DocC catalog or hosted symbol documentation was added.

## References

- Commits: `1380f7d` `Refresh numbering behavior and validation documentation`
- Sources: `Sources/TagLibAudioMetadata/MetadataFieldSchema.swift`, `MetadataMappingCatalog.swift`, `MetadataNativePlanning.swift`, `TagLibMetadataManager+Read.swift`, `TagLibMetadataManager+Write.swift`, `TagLibMetadataManager+Structured.swift`, `Sources/CTagLibBridge/TLFormatRegistry.mm`, `TLBridgeTransactions.mm`
- Generators: `scripts/generate-api-reference.py`, `scripts/generate-field-schema.py`, `scripts/generate-format-matrix.py`, `scripts/generate-mapping-matrix.py`
- Check: `scripts/check-docs.py`
- Current docs: [documentation hub](../../README.md), [status](../../operations/STATUS.md), [mapping contract](../../reference/MAPPING_SPEC.md)
- Related records: [REM-2026-11-09-mapping-2-2-implementation](../remediation/REM-2026-11-09-mapping-2-2-implementation.md), [REM-2026-11-09-numbering-acceptance-repairs](../remediation/REM-2026-11-09-numbering-acceptance-repairs.md)
