# Audit Remediation Report — 2026-10-18

**Scope:** `TagLibAudioMetadata` repository at audit commit `03473c9`.
**Remediation branch:** `fix/comprehensive-audit-remediation` (created from `main`; `main` was not modified).
**Audit input:** `AUDIT_REPORT.md` (independent audit; treated as evidence, not authority).
**Status:** completed for the fixes listed below; residual and unverified work is listed explicitly.

---

## A. Executive Summary

The audit identified 14 production findings, 8 lower-priority production observations, 12 public-API/compatibility findings, 15 test findings, and 15 documentation findings. I revalidated each finding against source and runtime probes before changing code. The remediation branch implements concrete preservation, verification, capability, artwork, WAV/RIFF, ASF, number-pair, ALAC, and error-typing fixes, adds independent WAV/RIFF regression coverage and generated format fixtures, and updates the public documentation to match actual behavior.

The most important corrections are:

- Structured `properties` writes are now deltas. Omitted keys and native data survive a partial structured write, and supplied values are verified.
- Basic read-modify-write preserves full recording dates, documented aliases, qualified people keys, multiple described comments/lyrics, and custom fields. ID3 no longer emits duplicate TYER/TDRC or writes lossy ID3v1 projections during an ID3v2 update.
- Raw `.merge` preserves MP4 hidden atoms and WAV INFO; WAV updates target INFO or ID3v2 according to key ownership; RIFF `.id3v2Only` now removes INFO.
- Unsupported structured ID3 collection frames fail instead of reporting success; NULs and role-qualified typed fields fail before mutation.
- Number totals use canonical keys; unrepresentable partial track/disc removal is rejected; MP3/WAV stale total frames are removed.
- ALAC codec/bit depth, multi-value capability flags, AAC/APE/ASF/TTA artwork, ASF custom attributes/advisory, and typed write errors were corrected.
- `F_FULLFSYNC` is requested with an `fsync` fallback, and `.durable` is documented as an OS-level flush rather than a hardware guarantee.

Validation on the final working tree: **153 tests executed, 151 passed, 2 opt-in skips, 0 failures**; Debug build and SwiftPM Release build succeeded. Sanitizer, alternate deployment targets, and independent MP4/ASF oracles remain unverified and are not claimed.

---

## B. Finding-by-Finding Resolution Matrix

Legend: **FIXED** = confirmed defect corrected and covered by source/test evidence; **IMPROVED** = concrete part corrected, remaining limitation documented; **PARTIALLY FIXED** = important part fixed, residual work remains; **NOT A DEFECT** = audit description did not survive revalidation; **DEPENDENCY-BLOCKED** = requires changing the pinned TagLib binary; **DEFERRED** = valid work intentionally not done; **UNVERIFIED** = not reproduced or not tested.

### Production findings

| ID | Severity | Resolution | What changed / remaining |
|---|---|---|---|
| P-01 | CRITICAL | FIXED | Structured `properties` merge over current map; `includeProperties:false` with non-empty properties throws; empty arrays remove one key; property verification added. |
| P-02 | HIGH | FIXED | Basic carries full recording date into TDRC/©day/Xiph DATE when year is unchanged; TYER write removed; ID3v2-only save avoids ID3v1 joined projection; year edits still replace with year text. |
| P-03 | HIGH | FIXED | Generic reader accepts `PUBLISHER`, `CATALOG`, `ORIGINAL YEAR`, MusicBrainz space aliases; Basic preservation restores unchanged alias keys; FLAC/Ogg/MP3 probes pass. |
| P-04 | HIGH | FIXED | Basic custom-field verification compares values, not presence; NULs rejected before mutation; qualified people keys excluded from custom fields and preserved; typed role fields rejected with `roleQualifiedFieldRequiresRawAPI`. |
| P-05 | HIGH | FIXED | APIC/COMM/USLT are no longer emitted in `id3v2Frames`; those frame types are rejected in the collection and must use artwork/comments/lyrics. |
| P-06 | MEDIUM | FIXED | Described `COMMENT:*`/`LYRICS:*` keys are schema-known, read into the Basic projection, preserved on unrelated edits, and not silently collapsed; FLAC/Ogg/MP3 probes pass. |
| P-07 | MEDIUM | PARTIALLY FIXED | Raw `.merge` is now a true delta and preserves MP4 hidden atoms, formatting, track/disc pairs, and WAV INFO. `.replace` remains a visible-map replacement by design and is documented as such; native data not exposed by PropertyMap is not reconstructable. |
| P-08 | MEDIUM | FIXED | Dedicated structured artwork paths for AAC, APE/WavPack/Musepack, ASF, TrueAudio, FLAC/Xiph, MP4, ID3; artwork verification is container-agnostic for caller-supplied `container`; capability flags and docs aligned. |
| P-09 | MEDIUM | FIXED | Canonical `TRACKTOTAL`/`DISCTOTAL`; alternate total keys removed; MP3/WAV stale total frames removed; unrepresentable first-component removal rejected; removing both components clears the pair; generic removal preserves total. |
| P-10 | MEDIUM | FIXED | ALAC reported as `ALAC` with bit depth; AAC artwork exposed; multi-value flags corrected; MP4 schema excludes recording date; fixture/evidence table updated. |
| P-11 | MEDIUM | FIXED | Bridge/filesystem transaction errors are mapped to `TagLibManagerError.operationFailed(String)`; validation errors remain typed; missing reads now consistently throw `invalidFile`. |
| P-12 | MEDIUM | FIXED | `.id3v2Only` now strips RIFF INFO after writing ID3v2; `.preserveInfo` keeps INFO; `.syncBasicFieldsToInfo` still fails preflight. WAV structured properties merge into ID3 only. |
| P-13 | MEDIUM | FIXED | ASF structured attributes upsert by key/language/stream/type without clearing siblings; Basic ASF custom fields and advisory are written as native attributes and read back. |
| P-14 | LOW | FIXED | `F_FULLFSYNC` is requested on staged files and directories with `fsync` fallback; `.durable` documentation states OS-level flush, not hardware/power-loss guarantee. |
| P-15 | MEDIUM | FIXED | `.performer`, `.involvedPeople`, `.musicianCredits` are rejected by typed Patch with an explicit raw/structured direction; raw qualified keys remain supported. |
| P-16 | LOW | IMPROVED | Format-dependent Basic display separators are documented; no silent separator normalization was introduced. |
| P-17 | LOW | FIXED | Artwork MIME is compared with bytes, so a same-byte MIME correction is applied; regression test covers FLAC. |
| P-18 | MEDIUM | FIXED | `expectedVersion` added to structured writes, whole-map raw writers, and `writeTagMetadata`; versionless behavior documented as targeting current state. |
| P-19 | LOW | IMPROVED | `probeFile` documentation now states it validates parsing but not POSIX write permission/ACLs/disk/sandbox. No permission probe was added. |
| P-20 | MEDIUM | FIXED | Non-empty structured properties with `includeProperties:false` throw `propertiesRequireIncludeProperties` before mutation. |
| P-21 | LOW | IMPROVED | `.matroska` and `.pattern` are documented as reserved, unused public cases; they were not removed to avoid a source break. |
| P-22 | LOW | IMPROVED | `StructuredID3v2Frame.fields` and `RawPropertyEntry` value/count authority are documented; fields remain for compatibility. |

### Public API and compatibility findings

| ID | Resolution | What changed / remaining |
|---|---|---|
| A-01 | FIXED | Structured properties are delta semantics; docs and examples no longer imply replace-all; `includeProperties` is validated. |
| A-02 | PARTIALLY FIXED | `.replace` no longer injects private MP4 formatting atoms; hidden/native replacement limits and WAV INFO behavior are documented. `.replace` still owns the visible map by design. |
| A-03 | FIXED | Role-qualified typed fields are rejected with a role-aware error; custom keys map to the same error path. |
| A-04 | FIXED | Partial first-component removal on ID3/MP4 is rejected with `unsupportedPartialPairRemoval`; docs explain removing both components. |
| A-05 | PARTIALLY FIXED | Concrete capability contradictions (ALAC, AAC artwork, multi-value flags, MP4 date schema, fixture levels) corrected. Capability remains family-level, not a single per-API oracle; docs explain the split. |
| A-06 | FIXED | Manager write errors use typed cases; `operationFailed` wraps bridge/filesystem failures; read failures already mapped to `failedToReadWithUnderlying`; docs list all error types. |
| A-07 | FIXED | `.skip` added (`.unchanged` deprecated alias); `expectedTextFields` keys documented. |
| A-08 | FIXED | Version tokens added to structured/raw/low-level write APIs; docs list them. |
| A-09 | PARTIALLY FIXED | `writeTagMetadata` remains for source compatibility; its `CTagLibBridge` import requirement and facade alternatives are documented. It was not moved or re-exported. |
| A-10 | FIXED | `.warn` compiles again as deprecated and has no verification bypass; docs state this. |
| A-11 | IMPROVED | Basic separator and raw-value authority documented; model redundancy retained for compatibility. |
| A-12 | FIXED | `probeFile` limits documented; missing reads now throw `invalidFile` consistently across Basic, raw, structured, and snapshot reads. |

### Test findings

| ID | Resolution | What changed / remaining |
|---|---|---|
| T-01 | PARTIALLY FIXED | Independent RIFF chunk/INFO and ID3v2 frame parsers added for date/WAV tests; no independent MP4 or ASF oracle. |
| T-02 | PARTIALLY FIXED | The Basic round-trip warning assertion now requires an empty warning list; other older broad assertions were not all rewritten. |
| T-03 | FIXED | Verification-failure test now uses recognized `title` rather than unrecognized `TITLE`. |
| T-04 | PARTIALLY FIXED | New tests compare public raw/structured outputs and independent RIFF bytes; unified projection test itself remains path-vs-path. |
| T-05 | PARTIALLY FIXED | New delta/preservation tests cover the dangerous partial-map case; the old test was not rewritten. |
| T-06 | PARTIALLY FIXED | Regression coverage added for major production defects and new fixtures; not every individual lower-priority finding has a dedicated test. |
| T-07 | FIXED | Fixture capability list updated for ALAC/ASF/TTA/WavPack; WAV INFO/ID3 tests added. |
| T-08 | FIXED | Added ALAC M4A, ASF/WMA, TrueAudio, and WavPack fixtures; AAC/ASF/APE-family artwork tests. |
| T-09 | PARTIALLY FIXED | Debug and SwiftPM Release builds succeeded; xcodebuild Release was blocked by sandbox manifest-cache permissions. Sanitizers and alternate platform matrices were not run. |
| T-10 | PARTIALLY FIXED | New format fixtures exercise metadata/artwork paths; no payload hash matrix beyond existing WAV coverage. |
| T-11 | PARTIALLY FIXED | New tests use public APIs; existing internal-helper tests remain. |
| T-12 | PARTIALLY FIXED | New tests assert typed errors; older string/throw-only assertions remain. |
| T-13 | PARTIALLY FIXED | `.warn` is compilable again; no dedicated compile-only source-compatibility test was added. |
| T-14 | DEFERRED | `expectedVersion` concurrency is tested; a deterministic end-to-end changed-during-read race test is not. |
| T-15 | PARTIALLY FIXED | New test clears a Basic projection and asserts qualified/custom fields survive; older clearing tests were not all rewritten. |

### Documentation findings

| ID | Resolution | What changed / remaining |
|---|---|---|
| D-01 | FIXED | Structured example and prose now describe delta semantics and safe partial writes. |
| D-02 | FIXED | Basic preservation claims narrowed to verified behavior; separators, provenance, and replacement scope documented. |
| D-03 | FIXED | Low-level write docs distinguish mapped-field replacement, custom-field preservation, and manager verification. |
| D-04 | FIXED | FLAC/Xiph/AAC/ASF/APE/TTA artwork support documented per actual paths. |
| D-05 | FIXED | RIFF `.id3v2Only` implemented and documented; `.sync` remains preflight-rejected. |
| D-06 | IMPROVED | Capability granularity and probe limits documented; capability model remains coarse by design. |
| D-07 | FIXED | Error reference now lists `operationFailed`, validation errors, Patch/Raw errors, and read behavior. |
| D-08 | FIXED | Numeric-equivalence claim qualified with paired-removal limitation. |
| D-09 | FIXED | Patch verification projection wording corrected. |
| D-10 | FIXED | Architecture no longer claims production ACL/xattr verification; describes copyfile flags plus tests. |
| D-11 | FIXED | `.warn` compatibility restored; `writeTagMetadata` custom-field and version behavior documented. |
| D-12 | PARTIALLY FIXED | Changelog acknowledges the missing 0.5.1–0.5.3 release notes and points to maintenance history; dates/boundaries were not invented. |
| D-13 | FIXED | `probeFile` described as parser validation, not editability proof. |
| D-14 | IMPROVED | Unused `.matroska`/`.pattern` cases documented as reserved; not removed. |
| D-15 | IMPROVED | API-specific Basic/Patch/Structured artwork/version/preservation guidance added; not a complete per-format narrative for every field. |

---

## C. Detailed Changes by Area

### C.1 Structured metadata

- `MergedRawPropertyMapValues` merges supplied keys into the existing PropertyMap instead of replacing it.
- Writes to AAC, APE/WavPack/Musepack, ASF, WAV, AIFF, MP4, MPEG, FLAC/Ogg, and fallback FileRef paths use the appropriate native surface.
- `StructuredMetadata.properties` empty values remove one key; omitted values are untouched.
- `includeProperties:false` with non-empty properties throws `propertiesRequireIncludeProperties`.
- `structuredWriteVerification` compares requested property values.
- APIC/COMM/USLT are emitted only through artwork/comments/lyrics; collection-frame types are rejected in `id3v2Frames`.
- ASF attributes upsert without deleting unrelated keys; ASF `WM/Picture` is written directly and read back into Basic/structured artwork.
- APE-family and AAC artwork paths use the tag surface that actually persists data.

### C.2 Basic metadata

- Basic writes read the current Basic+raw state in the transaction and preserve fields whose Basic projection did not change.
- Full recording dates are carried into the writer when the year projection is unchanged; year edits replace the date.
- ID3 TYER duplication was removed; MP3 saves ID3v2 only to avoid lossy ID3v1 joined projections.
- Documented aliases and `COMMENT:*`/`LYRICS:*`/`PERFORMER:*`/`INVOLVEDPEOPLE:*`/`MUSICIANCREDITS:*` keys are schema-aware.
- NULs in Basic custom values and keys, and schema-known/role-qualified custom keys, fail before staging.
- Basic custom-field verification compares values.
- WAV Basic writes target ID3v2; INFO is left untouched. A separate INFO-preserving delta method prevents INFO-only values being copied into ID3 during preservation.
- ASF Basic custom fields and advisory are written as ASF attributes.

### C.3 Number pairs and raw maps

- Generic total writers emit only `TRACKTOTAL`/`DISCTOTAL`.
- MP3/WAV native pair writes remove stale TXXX total frames.
- Partial first-component removal on ID3/MP4 is rejected; both-component removal clears the pair.
- Raw `.merge` is a verified delta; raw `.replace` no longer creates private MP4 formatting atoms.
- WAV deltas update INFO or ID3v2 according to key ownership; `.id3v2Only` removes INFO.
- `RawPropertyEntry` lookup no longer appends the joined display projection to `values`, and order is preserved.

### C.4 Capability, artwork, codec, and errors

- ALAC codec/bit depth from `MP4::Properties`.
- AAC ID3 artwork read/write; APE/WavPack/MPC/ASF/TTA structured artwork; FLAC/Xiph artwork.
- Artwork MIME is corrected even when bytes are unchanged.
- Multi-value capability flags corrected for ID3/MP4/WAV/AIFF/TTA/ASF/DSF/DSDIFF.
- MP4 recording-date schema excluded in favor of release date.
- `operationFailed(String)`, `MetadataValidationError`, role/partial-pair Patch errors, and `ArtworkVerificationExpectation.skip` added.
- `F_FULLFSYNC` with `fsync` fallback in both transaction engines.

---

## D. Verification Evidence

### D.1 Builds

| Check | Result |
|---|---|
| Xcode Debug build | Succeeded, 0 errors |
| SwiftPM Release build (`swift build -c release --disable-sandbox`) | Succeeded (`Build complete!`, 18.61 s) |
| `xcodebuild -configuration Release` | Blocked by sandbox access to SwiftPM manifest cache (`Operation not permitted`), not by source errors |

No sanitizer, Thread Sanitizer, iOS device, or minimum-OS binary run was performed in this remediation.

### D.2 Tests

Final suite on the remediation tree:

- **153 total**
- **151 passed**
- **2 skipped** (`ExternalCorpusPreservationTests.testTrackMutationPreservesOtherVisiblePropertiesInExternalCorpus`, `SnapshotThroughputBenchmarkTests.testOptInIndependentFileSnapshotThroughput`)
- **0 failed**, **0 expected failures**, **0 not run**

New regression file: `Tests/TagLibAudioMetadataTests/Integration/AuditRemediationRegressionTests.swift` (16 tests). It covers:

1. structured property merge on M4A with hidden atoms/artwork;
2. include-properties validation and key removal;
3. collection-frame rejection and frame-list exclusion;
4. full-date preservation and TYER absence;
5. documented aliases/qualified people;
6. NUL/role rejection without mutation;
7. partial pair removal rejection and generic removal;
8. canonical totals and WAV INFO preservation;
9. raw merge preservation on M4A/WAV and raw replace atom behavior;
10. MIME correction with identical bytes;
11. `expectedVersion` rejection;
12. RIFF `.preserveInfo`/`.id3v2Only`;
13. AAC/ASF/TTA/WavPack/M4A/MP3 artwork and ASF attribute upsert;
14. capability/ALAC/schema assertions;
15. typed missing-file/read errors.

Independent oracle: the WAV tests parse RIFF chunks and INFO directly rather than relying on the package reader.

### D.3 Runtime probes used during investigation

- Reproduced the original M4A structured partial-map wipe, then confirmed the merged write preserves artist, album, track/disc, artwork, and custom fields.
- Reproduced MP3 `DATE 2021-07-15` truncation and TYER duplication; confirmed full-date preservation and year-edit replacement.
- Reproduced FLAC/Ogg alias loss (`PUBLISHER`, `CATALOG`, `ORIGINAL YEAR`, MusicBrainz space forms); confirmed preservation.
- Reproduced APIC/COMM/USLT false success; confirmed rejection and new collection behavior.
- Reproduced TTA/WavPack/WMA/AAC artwork failures; confirmed successful artwork after the format-specific paths.
- Confirmed ALAC reports `ALAC`/16-bit.
- Confirmed WAV raw merge updates INFO without creating ID3 duplicates and `.id3v2Only` removes INFO.

---

## E. Commits and Files

| Commit | Purpose |
|---|---|
| `ec47f2d` | Fix audit-confirmed metadata preservation defects (production sources) |
| `d688437` | Add audit remediation regression coverage (tests + generated fixtures) |
| `5f3a2a4` | Document audit remediation contracts and evidence |
| `4cd96c1` | Add dated remediation report |
| `09b6f7d` | Finalize report metadata |
| `9adb715` | Clarify empty Basic custom-key validation |
| `a62ab1c` | Cover Basic clearing preservation for qualified fields |
| `c1d726b` | Assert Basic round trips emit no verification warnings |
| `2f918ae` | Add version tokens to compatibility write APIs |
| `47eb91b` | Document follow-up validation and version tokens |
| `c42e822` | Verify ID3v2 dates with an independent parser |
| `8cfa7d7` | Record independent ID3v2 verification |

Representative source files:

- `Sources/CTagLibBridge/Internal/TLStructuredMutation.inc`
- `Sources/CTagLibBridge/Internal/TLStructuredInspection.inc`
- `Sources/CTagLibBridge/Internal/TLUnifiedExtraction.inc`
- `Sources/CTagLibBridge/Internal/TLPropertyMapCodec.inc`
- `Sources/CTagLibBridge/Internal/TLPropertyMapDelta.inc`
- `Sources/CTagLibBridge/Internal/TLPropertyMapWrites.inc`
- `Sources/CTagLibBridge/Internal/TLWriteBridgeOperations.inc`
- `Sources/CTagLibBridge/TLBridgeTransactions.mm`
- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Write.swift`
- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Verification.swift`
- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Structured.swift`
- `Sources/TagLibAudioMetadata/MetadataSnapshotPatch.swift`
- `Sources/TagLibAudioMetadata/MetadataFieldSchema.swift`

New fixtures are documented with SHA-256 in `Tests/TagLibAudioMetadataTests/Audio/README.md`.

---

## F. Residual Risks and Unverified Areas

1. **TagLib binary is unchanged.** Findings that require a different TagLib parser/serializer (for example arbitrary opaque native reconstruction) remain dependency-bound. No dependency upgrade was attempted.
2. **Artwork coverage is fixture-limited.** AAC, ASF/WMA, TrueAudio, WavPack, M4A, and MP3 are covered; APE/Musepack use the shared APE path but have no repository fixture. Multiple-image APE/ASF behavior is restricted (one front cover for APE).
3. **No sanitizer or platform matrix run.** Debug/Release local builds and macOS tests passed; iOS, watchOS, tvOS, visionOS, sanitizer, and power-loss behavior are not claimed.
4. **No independent ID3v2/MP4/ASF oracle.** WAV uses an independent RIFF parser; other formats still use package/bridge readers for verification. New tests do compare public raw/structured outputs, but that is not a third-party oracle.
5. **Capability model remains coarse.** `writeSupport(for:)`, `structuredWriteSupport`, `canWriteArtwork`, and `preservesMultiValueProperties` are family-level labels. The docs now say so; a per-API capability model was not introduced.
6. **Basic display separators remain format-dependent.** Documented, not normalized; callers that split display strings can still corrupt multi-values.
7. **Raw `.replace` is not byte-exact.** It owns the visible PropertyMap and can remove WAV INFO or opaque native data. `.merge`/`RawMetadataPatch` are the preservation-safe paths.
8. **Low-level `writeTagMetadata` keeps a bridge type.** It remains source-compatible but requires `CTagLibBridge`; it was not moved or re-exported.
9. **`probeFile` does not test POSIX write permission.** Documentation corrected; no permission probe added.
10. **API compatibility is not exhaustively tested.** `.warn` compiles again, but no compile-only matrix for every deprecated overload was added.

---

## G. Dependency and Format Constraints

- Pinned TagLib `2.3.1` dynamic XCFramework was not modified or upgraded.
- MP4 native `trkn`/`disk` cannot represent a missing first component with a retained total; the remediation rejects that state rather than writing `0/total`.
- ID3v2 cannot represent multiple arbitrary descriptions identically across all tag versions; preservation/verification is limited to what TagLib exposes and serializes.
- APE-family artworks use one front-cover item in this implementation; multiple structured images are not promised.
- ASF advisory is represented as an `ITUNESADVISORY` string attribute because ASF has no canonical native equivalent; this is documented behavior, not a cross-tool standard.
- WAV INFO and ID3v2 are separate surfaces; family-level PropertyMap operations now route by key ownership, but opaque/native data not exposed by TagLib remains outside exact verification.

---

## H. Compatibility and Migration Notes

- New public API additions are source-compatible defaults/options: `expectedVersion` parameters, `customFieldValues` on the verification context, `MetadataValidationError`, `TagLibManagerError.operationFailed`, `ArtworkVerificationExpectation.skip`, and role/partial-pair Patch errors.
- Deprecated spelling `.warn` is compilable again, but it does not restore warning-only commits. Verification mismatches still throw before commit.
- `ArtworkVerificationExpectation.unchanged` is deprecated in favor of `.skip`; behavior was already skip.
- Basic writes now preserve more data than before. Callers that relied on an unrelated Basic write deleting aliases/dates/qualified fields should use `MetadataPatch`, raw, or structured deletion instead.
- `MetadataPatch` now rejects role-qualified typed fields and unrepresentable partial pair removal. Raw/structured APIs remain the escape hatch.
- Structured `properties` with `includeProperties:true` are deltas; callers that depended on replacing the full map must remove omitted keys explicitly or use raw `.replace`.
- Raw `.merge` now preserves omitted native data; `.replace` remains the visible-map ownership operation.
- `writeTagMetadata` gains `expectedVersion`; its bridge type dependency is unchanged and documented.

---

## I. Test Coverage Matrix

| Area | Coverage |
|---|---|
| Structured properties | M4A merge, removal, includeProperties rejection, value verification |
| Structured frames | APIC/COMM/USLT rejection; existing text/userText/chapter/TOC tests |
| Basic dates | MP3/FLAC/Ogg full date, TYER absence, year edit |
| Basic aliases/qualified fields | FLAC/Ogg publisher/catalog/original date/MusicBrainz/performer/comments/lyrics |
| Basic validation | NUL, role-qualified custom, typed role rejection, no mutation |
| Number pairs | MP3/M4A partial removal rejection; FLAC generic removal; canonical totals; WAV INFO |
| Raw maps | M4A hidden atoms/formatting; WAV INFO; raw replace atom behavior; version rejection |
| Artwork | AAC/WMA/TTA/WavPack/M4A/MP3 patch+remove; FLAC MIME correction; ASF attributes |
| RIFF | preserveInfo/id3v2Only independent chunk parser |
| Capability | ALAC, multi-value flags, AAC artwork, MP4 date schema |
| Errors | typed operation failure, missing reads, role/partial-pair errors |
| Regression suite | 153 total, 151 pass, 2 opt-in skips |

Existing suite also covers concurrency, transaction failure, hard links, malformed payloads, external categories (opt-in), structured collections, artwork types, explicit advisory, and source API compatibility.

---

## J. Deferred and Recommended Work

1. Add independent MP4 and ASF oracles; ID3v2 dates and WAV now have independent parsers.
2. Add a compile-only/source-compatibility test target that exercises deprecated overloads, `.warn`, `.unchanged`, and bridge-type imports.
3. Add deterministic changed-during-read race tests and sanitizer/thread-sanitizer runs.
4. Normalize or formally deprecate Basic display separators, or provide an array-valued Basic projection.
5. Introduce per-API capability flags if callers need a single control-enablement oracle.
6. Revisit APE/ASF multi-artwork and native GUID/binary attribute completeness with fixtures.
7. Decide whether `writeTagMetadata` moves to the low-level product or the facade re-exports the bridge type.
8. Reconstruct 0.5.1–0.5.3 release notes if release dates and boundaries can be established from repository tags; do not invent them.
9. Consider `F_FULLFSYNC` behavior tests on filesystems that reject it and document the fallback explicitly in release notes.

---

## K. Conclusion and Audit Trail

The remediation fixes the confirmed high-impact data-loss and false-success paths and narrows or documents the remaining limitations. It does not claim that every audit observation is fully resolved: **39 findings are FIXED, 16 are PARTIALLY FIXED, 8 are IMPROVED, and 1 is DEFERRED**; all 64 matrix entries are accounted for. The working tree is clean; the intentionally untracked audit report is excluded locally rather than committed per the earlier instruction.

**Branch:** `fix/comprehensive-audit-remediation`
**Base:** `main` at `03473c9`
**Final code/test/docs/report commits:** `ec47f2d`, `d688437`, `5f3a2a4`, `4cd96c1`, `09b6f7d`, `9adb715`, `a62ab1c`, `c1d726b`, `2f918ae`, `47eb91b`, `c42e822`, `8cfa7d7`
**Final validation:** Debug build pass; SwiftPM Release build pass; 153 tests, 151 pass, 2 skips, 0 failures (plus focused tests for the follow-up commits).
**Audit report:** `AUDIT_REPORT.md` (untracked, local exclude; not committed).
