# Independent post-remediation engineering review — 2026-10-18

## A. Executive summary

**Decision: READY WITH CAVEATS.** This decision applies to the completed review branch, not the third-party remediation HEAD in isolation. No demonstrated merge-blocking defect remains unresolved in the reviewed contracts. Do not merge automatically.

The original audit identified real and serious defects in partial structured writes, Basic date/alias preservation, custom-field verification, and native ID3 frame mutation. Its favorable assessment of the staging/rollback design was also justified. Some findings were documentation or product-contract questions rather than production defects: parser probing cannot promise future editability, family capability labels are not per-operation guarantees, and wrapper parity tests have a legitimate purpose without being independent parser oracles.

The remediation substantially improved the package, but its “fixed” classifications were too broad. Independent reproductions found omitted artwork deletion on APE/ASF structured writes; loss of native comment/lyric language and description information; incomplete date-array preservation; stale aliases after intentional clearing; WAV INFO deletion through typed patches; false success for opaque ID3 payload edits; and unvalidated embedded NULs through alternate writers. New error wrapping discarded recoverable native causes, and defaulted version parameters broke legacy function references. These defects were repaired and committed incrementally. Sections C and D describe the evidence and corrections.

The resulting implementation has materially stronger preservation and verification coverage. It is still a metadata editor built on a pinned TagLib dependency, not a lossless archive of every native structure. Whole-map replacement owns the visible PropertyMap, explicitly unverified writes remain unverified, and low-level atomic bridge writes do not inherit facade semantic verification. Unsupported native representations are rejected where the writer cannot honor them.

Independent final verification: Debug, Release, and Address Sanitizer each ran **173 tests: 171 passed, 2 opt-in skips, 0 failures**. Focused Thread Sanitizer ran 13 concurrency/version tests successfully. Strict compilation and iOS arm64/macOS x86_64 cross-compilation succeeded. These are separate from the previous agent’s results. No device, simulator, minimum-OS runtime, external corpus, or power-loss test was performed.

Remaining caveats concern fixture breadth, dependency guarantees, coarse capability descriptors, incomplete independent binary-format coverage, and concurrency boundaries already described in the current documentation. They do not establish a remaining unsafe supported operation. The DSD structured-read correction is build-validated only.

## B. Original audit finding verification

### Method and evidence key

The local, excluded [original audit](../../../AUDIT_REPORT.md) and committed [remediation report](../remediation/REM-2026-10-18-comprehensive-audit.md) were read as historical evidence. The complete remediation diff from `03473c9` to `62504ff` was examined alongside current callers, tests, and documentation. The matrix below independently classifies all **64 findings**. “Verified” applies to the stated invariant and evidence, not every possible file produced by third-party software.

Source references:

- **W**: [Swift writes](../../../Sources/TagLibAudioMetadata/TagLibMetadataManager+Write.swift), [verification](../../../Sources/TagLibAudioMetadata/TagLibMetadataManager+Verification.swift), and [reads](../../../Sources/TagLibAudioMetadata/TagLibMetadataManager+Read.swift).
- **S**: [Swift structured API](../../../Sources/TagLibAudioMetadata/TagLibMetadataManager+Structured.swift), [native structured mutation](../../../Sources/CTagLibBridge/Internal/TLStructuredMutation.inc), and [inspection](../../../Sources/CTagLibBridge/Internal/TLStructuredInspection.inc).
- **N**: [native delta writer](../../../Sources/CTagLibBridge/Internal/TLPropertyMapDelta.inc), [Basic/native writes](../../../Sources/CTagLibBridge/Internal/TLWriteBridgeOperations.inc), and [PropertyMap writes](../../../Sources/CTagLibBridge/Internal/TLPropertyMapWrites.inc).
- **C**: [capability API](../../../Sources/TagLibAudioMetadata/FormatCapability.swift), [native registry](../../../Sources/CTagLibBridge/TLFormatRegistry.mm), and [schema](../../../Sources/TagLibAudioMetadata/MetadataFieldSchema.swift).
- **I**: [ReviewMetadataIntegrityTests](../../../Tests/TagLibAudioMetadataTests/Integration/ReviewMetadataIntegrityTests.swift), 15 new tests.
- **J**: [ReviewNativeContainerTests](../../../Tests/TagLibAudioMetadataTests/Integration/ReviewNativeContainerTests.swift), 4 new tests.
- **K**: [ReviewSourceCompatibilityTests](../../../Tests/TagLibAudioMetadataTests/ReviewSourceCompatibilityTests.swift), 1 new compile test covering 10 function references.
- **R**: [AuditRemediationRegressionTests](../../../Tests/TagLibAudioMetadataTests/Integration/AuditRemediationRegressionTests.swift), the previous agent’s 16 tests, inspected and strengthened.
- **F**: [FixtureMetadataRoundTripTests](../../../Tests/TagLibAudioMetadataTests/Integration/FixtureMetadataRoundTripTests.swift), including the corrected legacy-warning test.
- **Q**: [WAVInfoProjectionTests](../../../Tests/TagLibAudioMetadataTests/Integration/WAVInfoProjectionTests.swift), including independently seeded INAM/INFO preservation checks.
- **V**: [SnapshotVersionTests](../../../Tests/TagLibAudioMetadataTests/Transactions/SnapshotVersionTests.swift), [ReliabilityFailureTests](../../../Tests/TagLibAudioMetadataTests/Transactions/ReliabilityFailureTests.swift), and same-file/concurrency suites.
- **Docs**: current [README](../../../README.md), [SUPPORT](../../USAGE.md), [ARCHITECTURE](../../ARCHITECTURE.md), [THREAD_SAFETY](../../TRANSACTIONS.md), [INSTALLATION](../../INSTALLATION.md), and [CHANGELOG](../../../CHANGELOG.md).

### Production findings

| ID | Original diagnosis | Remediation claim | Independent result and final status | Evidence / remaining limit |
|---|---|---|---|---|
| P-01 | Partial structured properties replace omitted metadata without verification. | Delta semantics and property verification fix it. | **VERIFIED FIXED**, after additional repairs. Delta application is correct, but the remediation still deleted omitted artwork on APE/ASF. Nil versus explicit-empty artwork now has distinct behavior. | S, N; I structured omission/empty tests; J independent MP4 atoms; R partial properties. Empty property array is a no-op; empty values remove the named property. |
| P-02 | Basic edits truncate full dates and duplicate ID3 DATE. | Preserve full date if year unchanged; remove TYER duplication. | **VERIFIED FIXED**, after extending preservation to complete DATE arrays and YEAR aliases. An unrelated edit retains the underlying values; editing/clearing the scalar year has explicit replacement semantics. | W, N; I date-array test on MP3/FLAC/Ogg; R independent ID3 date inspection. MP4 recording/release ownership remains distinct. |
| P-03 | Declared aliases are unreadable or deleted. | Alias-aware reads and preservation. | **VERIFIED FIXED** for the reported aliases, with an additional intentional-replacement repair. Unchanged aliases survive; changed/cleared publisher/catalog/comment/lyric groups no longer retain stale alternatives. | W, N; R alias/MusicBrainz cases; I explicit alias replacement and clearing. This is not proof for every arbitrary native synonym. |
| P-04 | Custom verification checks presence; qualified edits/NULs silently fail. | Compare values, reject NULs and unsupported qualified fields. | **VERIFIED FIXED**, after closing alternate bridge/raw paths and fixing empty-value deletion verification. Unchanged native schema-named custom fields also remain editable through unrelated Basic changes. | W, S, native public writer preflight; I exact value/deletion/NUL rollback tests; J ASF custom-name test. Qualified writes require the appropriate raw/native API. |
| P-05 | APIC/COMM/USLT in the generic frame list falsely verify. | Reject those entries and use dedicated collections. | **VERIFIED FIXED**, after rejecting the equivalent opaque/unknown-frame loophole. Unsupported payload mutations cannot match a wildcard verifier. | S; R dedicated collection rejection; I independently seeded XZZZ frame. Opaque frames remain inspectable and can be preserved by omission. |
| P-06 | Basic writes collapse described comments/lyrics or fail. | Preserve described PropertyMap keys. | **VERIFIED FIXED** for exercised native ID3 and Xiph paths, after preserving native collections as well as map keys. PropertyMap restoration alone changed language/description. | W, S; I independent COMM/USLT payload checks on MP3/WAV/TTA and explicit edits; R described fields. DSD runtime behavior is unverified. |
| P-07 | Whole-map merge rewrites untouched MP4/RIFF native data. | True delta merge; replacement remains limited. | **ACCEPTABLE LIMITATION** for explicit replacement; the reported merge defect is repaired. Independent MP4 ilst/mdat and seeded RIFF checks support delta preservation. | W, N; J MP4 atom walker; R WAV/MP4 merge; I lowercase merge. Replacement owns visible keys and cannot reconstruct arbitrary opaque native metadata. |
| P-08 | Artwork support and capabilities disagree. | Add missing native paths and align flags. | **PARTIALLY FIXED** in the broad cross-format claim. AAC, TTA, WavPack, ASF, MP4, FLAC/Xiph and ID3 fixtures pass; missing DSD structured read extraction was repaired, but DSD/APE/Musepack end-to-end runtime evidence remains incomplete. | C, S, unified extraction; R/I/J artwork tests. This status records verification breadth, not a demonstrated remaining data-loss path. |
| P-09 | Number removal/text/canonical totals are inconsistent. | Canonical totals and safe partial removal. | **VERIFIED FIXED** for reviewed facade and legacy paths after total-only validation and low-level stale-alias cleanup. Independent totals remain supported on Xiph; normalized native pairs reject an absent first component with a positive total. | W, N; I pair rejection/native TXXX checks; R and F formatting/removal tests. Raw/native representations can expose lower-level forms outside the typed contract. |
| P-10 | Codec, multi-value and field support descriptors are misleading. | Correct ALAC/AAC, flags and MP4 schema. | **ACCEPTABLE LIMITATION** after concrete contradictions were corrected. Capability families remain coarse storage/operation guidance, not a universal per-field writer guarantee. | C; R capability checks; F format paths; Docs explain separate API restrictions. No exhaustive field × API × format matrix is claimed. |
| P-11 | Write errors mix manager errors and private NSError domains. | Wrap as operationFailed(String). | **VERIFIED FIXED** for the public write boundary, after replacing lossy wrapping with a typed case retaining NSError. Original domain, code, nested cause and commit information remain available. | Manager transaction mapping; I native code/rollback check; R missing-write assertion. Validation errors remain their documented typed enums. Legacy read-error payload debt is A-06. |
| P-12 | RIFF policy is ineffective. | Strip INFO for id3v2Only; preserve otherwise. | **VERIFIED FIXED**, after checking the final native save and confirming persisted INFO absence. Typed patches were separately repaired to leave pre-existing INFO intact. | S; R policy tests and Q independently seeded INAM/INFO chunk tests. Sync-to-INFO remains explicitly rejected before mutation. |
| P-13 | ASF replacement deletes siblings; Basic custom/advisory unsafe. | Identity-aware upsert and native Basic attributes. | **VERIFIED FIXED** for represented tested types. Same-key different-stream sibling payloads survive, targeted values change, and unchanged native PUBLISHER custom attributes no longer block unrelated edits. | S, W; J independently checked UTF-16 payload sentinels and identity/count; R advisory. Not a complete independent ASF binary/GUID parser. |
| P-14 | Durable status overstates fsync guarantees. | F_FULLFSYNC with fallback; narrow durability contract. | **ACCEPTABLE LIMITATION**. Source and failure-path checks support OS-level flush reporting; hardware/power-loss survival cannot be inferred. | Swift/native transactions; V directory-sync failure tests; Docs. Unsupported-operation fallback is source-reviewed, not tested on every filesystem. |
| P-15 | Typed role-qualified fields are accepted without roles. | Reject typed requests; direct users to raw/structured forms. | **VERIFIED FIXED**. Ambiguous requests fail before mutation; unchanged qualified metadata survives unrelated Basic edits. | Schema/patch validation, W; R qualified-field rejection/preservation. A richer typed role model is optional product work. |
| P-16 | Basic display separators vary across formats. | Document rather than normalize. | **ACCEPTABLE LIMITATION**. A display string cannot substitute for native multi-value arrays; format-specific presentation is intentional. | W/reads, Docs; F cardinality preservation tests. Use raw/structured arrays when cardinality matters. |
| P-17 | Same-byte artwork MIME correction is ignored. | Compare MIME as well as bytes. | **VERIFIED FIXED**, after retaining the entire native picture map during the correction. Caption/type/dimensions must not be discarded. | Native artwork merge; I MIME-plus-description test, R original MIME test. Native container normalization still applies. |
| P-18 | Sibling writers lack version parameters. | Add optional expectedVersion throughout facade. | **ACCEPTABLE LIMITATION** at the direct bridge boundary; **facade omission repaired**. Tokens are checked inside the atomic transaction, and legacy method types are restored by forwarding overloads. | W, S, compatibility extension; R stale-version tests; K 10 references. Direct low-level bridge methods remain versionless/current-state operations. |
| P-19 | Probe is treated as writability guarantee. | Clarify parser-only behavior. | **ACCEPTABLE LIMITATION**. Probe cannot promise later permissions, sandbox, space, or race outcomes. | Read API comment and Docs corrected in this review. Actual writes perform transaction checks. |
| P-20 | includeProperties false silently ignores supplied properties. | Reject inconsistent input. | **VERIFIED FIXED**. Non-empty supplied properties require opt-in before staging. | S; R inclusion/deletion test. Empty properties alone carry no mutation intent. |
| P-21 | Matroska/pattern cases imply unsupported functionality. | Retain reserved cases, document them. | **ACCEPTABLE LIMITATION**. Removing public enum cases would create avoidable source breakage; no Matroska handler is advertised. | C/schema comments, Docs. Reserved concepts are not capability guarantees. |
| P-22 | Redundant frame/raw model fields have unclear authority. | Document actual authority; retain compatibility. | **ACCEPTABLE LIMITATION**. Raw value arrays are authoritative; generic frame fields are not an arbitrary native encoder. | Model comments, S, Docs; opaque mutation now rejects explicitly. |

### Public API and compatibility findings

| ID | Original diagnosis | Remediation claim | Independent result and final status | Evidence / remaining limit |
|---|---|---|---|---|
| A-01 | Structured properties contract unusable. | Delta semantics. | **VERIFIED FIXED** after omission/artwork repairs. Property updates and explicit collection replacement are separate operations. | S, R, I, J; section E specifies nil/empty semantics. |
| A-02 | Raw replace is not an exact native replacement. | Remove private formatting leakage; document visible-map scope. | **ACCEPTABLE LIMITATION**. Exact whole-file/native reconstruction is not the contract; explicit replace owns the visible map and can remove INFO keys. | W, N, Docs. Prefer delta APIs for preservation. |
| A-03 | Bare typed role fields accepted. | Explicit role-aware validation error. | **VERIFIED FIXED**. No inferred role is silently written. | Schema/patch validation, R. |
| A-04 | Field removal differs for native pairs. | Reject unrepresentable partial removal. | **VERIFIED FIXED** after validating total-only sets as well as remove operations. Both components can be removed; independent Xiph totals remain valid. | I, R, F; format restrictions documented. |
| A-05 | Capability APIs contradict actual paths. | Correct contradictions, retain family granularity. | **ACCEPTABLE LIMITATION**. Confirmed contradictions addressed; labels cannot replace operation validation. | C, R, Docs; DSD runtime caveat remains. |
| A-06 | Error typing inconsistent and recovery unclear. | Typed write wrapper. | **PARTIALLY FIXED**. Writes now retain structured NSError causes; legacy read failures still have their existing message-shaped API. Changing every public error shape was not necessary for safe writes. | Manager mapping, I, R, Docs. New enum cases require exhaustive-switch migration. |
| A-07 | unchanged means skip; verification keys undocumented. | Add skip alias and document keys. | **VERIFIED FIXED** as an API clarification. Deprecated unchanged still compiles and means skip. Unknown text keys do not create successful verification. | Verification model/comments, K, F positive/negative control. Stringly typed keys remain intentional API debt. |
| A-08 | Version checks absent on sibling facade APIs. | Add optional token. | **VERIFIED FIXED**, including old function-reference compatibility repaired here. Token forwarding reaches the same transaction check. | W/S, compatibility extension; R, K, V. |
| A-09 | Facade method takes a non-re-exported bridge type. | Keep method; explain explicit import and alternatives. | **ACCEPTABLE LIMITATION**. Importing CTagLibBridge is still required to construct that model; preserving the entry point avoids a needless break. | Public API, Docs; both consumer products compile/run. |
| A-10 | Deprecated warn no longer compiles. | Restore deprecated case, keep strict rollback. | **VERIFIED FIXED**. Compile test and actual warn invocation pass; verification mismatch never commits. | K; corrected F warning-policy test with positive control. |
| A-11 | Basic separators/model redundancy ambiguous. | Document representation authority. | **ACCEPTABLE LIMITATION**. Display strings are not portable multi-value encodings; retained redundant public fields are compatibility choices. | Model comments, Docs, F arrays. |
| A-12 | Probe and missing-read behavior inconsistent. | Parser scope; invalidFile for missing reads. | **VERIFIED FIXED** for the described read contract. Missing writes instead retain a structured native/filesystem cause; documentation now distinguishes them. | Read API, R, Docs. Probe does not reserve or authorize a later write. |

### Test-suite findings

| ID | Original diagnosis | Remediation claim | Independent result and final status | Evidence / remaining limit |
|---|---|---|---|---|
| T-01 | No independent ID3/MP4/ASF oracle. | Add ID3/RIFF inspection; MP4/ASF deferred. | **PARTIALLY FIXED**, substantially strengthened here. Native ID3 payload checks, an independent MP4 atom/mdat walker, independently seeded APE and RIFF data, and ASF payload sentinels now detect real failures. | I/J/R. ASF sentinel evidence is not a complete container parser; every format is not independently decoded. |
| T-02 | Warning assertions can pass vacuously. | Require no warnings in the Basic test. | **NOT A DEFECT** as a blanket diagnosis: empty-warning success is an appropriate expected result and thrown operations still fail tests. It does not prove persistence. That real coverage gap was addressed separately. | F now asserts actual mutations; I/J independently inspect preservation. No claim that warnings alone establish correctness. |
| T-03 | Failure test uses unrecognized TITLE key. | Use recognized title. | **VERIFIED FIXED**, further strengthened. The test now actually passes warn and first demonstrates that a matching recognized expectation succeeds. | F testVerificationFailureNeverCommitsEvenWithLegacyWarningPolicy. |
| T-04 | Projection parity compares shared implementation. | Add independent tests, retain wrapper test. | **ACCEPTABLE LIMITATION**. Wrapper parity is useful adapter coverage but is not independent evidence of parser correctness. | Existing parity test retained; I/J/R supply independent oracles. |
| T-05 | Partial-property test overlooks omitted metadata. | Add preservation regressions. | **VERIFIED FIXED** for the dangerous reported scenario. New tests require real seeded properties/native artwork and check omission, empty no-op, explicit deletion and unrelated MP4 atoms. | R, I, J. The older focused test may remain narrow without carrying the integrity claim. |
| T-06 | Major production defects lack regressions. | Add broad remediation suite. | **PARTIALLY FIXED**. Twenty additional review tests plus strengthened prior tests caught demonstrated misses. Coverage still does not establish all formats/native representations. | I/J/K and R/F changes; section F states limits. |
| T-07 | Tests encode wrong capability/stale INFO expectations. | Update fixture claims and add RIFF tests. | **VERIFIED FIXED** for the confirmed gaps after independently seeding INAM. The original encoder-only fixture could not detect title deletion. Preserving INFO alongside a new ID3 title is intentional, not itself a defect. | Q seeded RIFF builder and exact chunk comparison; C capability checks. |
| T-08 | Fixture breadth too narrow. | Add ALAC/WMA/TTA/WavPack. | **PARTIALLY FIXED**. New fixtures exercise previously uncovered native routes. DSD, real APE/Musepack, AIFF and other less-used handlers are not established by the new matrix. | R/I/J and Audio README; WavPack tests APE tags but not every APE-family parser. |
| T-09 | Release/sanitizer/platform claims unverified. | Release SwiftPM success; other checks deferred. | **PARTIALLY FIXED**. This review ran full Debug/Release/ASAN, focused TSan, strict build and two cross-builds. Runtime minimum-platform/device/CI matrix remains unexecuted. | Section H contains actual commands/results; no inherited results presented as independent runs. |
| T-10 | Payload preservation mostly WAV-only. | Broader fixtures, no full payload matrix. | **PARTIALLY FIXED**. Independent MP4 mdat equality added; native metadata payload assertions strengthened. No complete compressed-audio decode/hash matrix. | J MP4 parser; existing WAV checks. |
| T-11 | Internal-helper tests dominate some paths. | Add public API tests. | **ACCEPTABLE LIMITATION**. New tests exercise public facade and low-level entry points; helper-level fault injection remains valuable for transaction failures. | I/J/R/F/V. Public tests now accompany critical fixes. |
| T-12 | Error checks are strings/throw-only. | New typed assertions. | **PARTIALLY FIXED**. Critical new paths assert typed cases, exact NSError domain/code and original-byte preservation; older broad assertions remain. | I native failure/NUL tests, R missing-file test, V. |
| T-13 | Source compatibility not compiled. | Restore warn, no dedicated compile test. | **VERIFIED FIXED** for representative affected usage. Ten old function references initially failed compilation; exact-arity forwarding overloads now compile, as do warn/unchanged and consumer products. | K and compatibility extension. Not an exhaustive historical downstream corpus. |
| T-14 | Changed-during-read race lacks deterministic end-to-end test. | Deferred. | **UNVERIFIED** for that exact interleaving. Identity comparisons and stale-write/version tests pass, but are not a substitute for forcing a mutation during parsing. | V and source inspection. No new read race was demonstrated. |
| T-15 | Basic clearing fails to check unrelated data. | Add qualified/custom preservation case. | **VERIFIED FIXED** for the reported omission. Clearing now has unrelated qualified/custom controls and explicit alias/comment/lyric replacement controls. | R clearing test, I alias/native collection tests. Less-used format runtime scope remains limited. |

### Documentation findings

| ID | Original diagnosis | Remediation claim | Independent result and final status | Evidence / remaining limit |
|---|---|---|---|---|
| D-01 | Structured example causes data loss. | Delta prose/example. | **VERIFIED FIXED** after implementation repairs. Current example matches partial update behavior. | SUPPORT, S, R/I/J. |
| D-02 | Basic preservation promises too broad. | Narrow claims. | **VERIFIED FIXED** for current stated projection/provenance contract, with code repairs for dates, aliases, native collections and artwork. It does not promise byte-identical archival round trips. | README/SUPPORT, W, I/J/R. DSD and opaque dependency limits are explicit. |
| D-03 | Low-level bridge said to verify staged copy. | Distinguish bridge/facade. | **VERIFIED FIXED** by this review. A stale semantic-verification claim remained after remediation; bridge atomicity and facade readback are now explicitly separate. | README/SUPPORT and writeTagMetadata verification-mode guidance. |
| D-04 | FLAC/Xiph artwork incorrectly unsupported. | Align native artwork paths. | **VERIFIED FIXED** for those paths. TTA native collection support and DSD read level were additionally aligned with source. | SUPPORT/C; R/I artwork tests. DSD runtime is not claimed. |
| D-05 | RIFF policy describes nonexistent behavior. | Implement strip/preserve. | **VERIFIED FIXED** after persistence-error checking and independent INFO setup. Unsupported synchronization remains explicit rejection. | SUPPORT/S, R. |
| D-06 | Capability guidance unreliable. | Explain granularity. | **ACCEPTABLE LIMITATION**. Current guidance separates container storage from API-specific validation; family flags are not a write authorization oracle. | README/SUPPORT/C. |
| D-07 | Error reference omits actual public failures. | List wrapper/validation errors. | **VERIFIED FIXED** after retaining underlying causes and correcting missing-write text. New cases and exhaustive-switch migration are documented. | SUPPORT/README/CHANGELOG and manager error comments. |
| D-08 | Universal numeric-equivalence claim. | Qualify pair restrictions. | **VERIFIED FIXED** by this review. A broader stale README claim remained; Basic/typed normalization and exact raw-property verification now have distinct contracts. | README/SUPPORT; I/R/F numeric tests. |
| D-09 | Patch verification said to request structured work only for artwork. | Correct projection description. | **VERIFIED FIXED**. Current comments/docs match requested verification projections rather than promising an artwork-only path. | SUPPORT/W/verification source. |
| D-10 | ACL/xattr wording implies production verification. | Describe copyfile flags and tests. | **VERIFIED FIXED**. Copy preservation and regression checks are distinguished from runtime auditing of every attribute. | ARCHITECTURE, transaction source, V. |
| D-11 | Source compatibility/full replacement overstated. | Restore warn; explain custom preservation. | **VERIFIED FIXED** after restoring exact legacy function types and documenting new enum-case migration. Basic projection replacement does not imply deleting omitted native/custom metadata. | K, compatibility extension, README/SUPPORT/CHANGELOG. |
| D-12 | Missing 0.5.1–0.5.3 release notes. | Acknowledge missing history. | **ACCEPTABLE LIMITATION**. No release boundaries were invented; historical gap is recorded. | CHANGELOG/maintenance records. Release provenance can be improved separately. |
| D-13 | Probe described as editability proof. | Narrow parser wording. | **VERIFIED FIXED**, including a stale public API comment corrected here. | README/SUPPORT/read source comment. |
| D-14 | Reserved public cases imply support. | Document reserved status. | **ACCEPTABLE LIMITATION**. Public cases remain for compatibility, without an advertised handler or active validation rule. | Schema comments/SUPPORT. |
| D-15 | Missing per-API support/preservation detail. | Expand guidance. | **PARTIALLY FIXED**. Current docs explain materially different writer contracts and tested fixture levels. A complete per-field/API/format reference is still absent. | SUPPORT and this report’s E/F; no comprehensive matrix claimed. |

These statuses intentionally differ from the third-party matrix. In particular, “fixed” did not hold at the remediation HEAD for P-01/P-02/P-05/P-06/P-09/P-11/P-12/P-17, D-03/D-08, and representative source compatibility. The final classifications incorporate the corrective commits below.

## C. Newly discovered defects and regressions

Severity reflects the observed failure before the review repair. Confidence is confirmed by runtime reproduction unless stated otherwise. “Regression” means the reviewed remediation changes introduced the faulty behavior; “incomplete” means the reported invariant was still violated through another representation or entry point. Commit references are immutable, focused corrections; small follow-up commits are listed where applicable. Tests use disposable fixture copies exclusively.

### IV-01 — Omitted structured artwork deleted (High; confirmed; regression)

**Location/API:** S, APE/ASF structured helpers; WavPack/WMA structured property-only and empty writes. The new artwork helper unconditionally removed cover entries even when no artwork collection was supplied. A title edit returned success while the seeded JPEG disappeared; an empty structured operation could do the same. **Repair:** distinguish nil omission from an explicit empty collection, preserving omission and retaining explicit clearing. **Evidence:** I `structuredPropertyEditsPreserveOmittedArtwork` and `emptyStructuredWritePreservesArtworkButExplicitRemovalClearsIt` check actual persisted image bytes as well as the projection. **Status:** repaired in `ca653ef`.

### IV-02 — MIME correction discards native picture attributes (High; confirmed; regression)

**Location/API:** artwork merging in N; Basic same-byte MIME edits. Constructing a new minimal picture map retained image bytes but discarded description/type/dimensions. A FLAC cover caption was lost. **Repair:** copy the existing native picture map and change only MIME. **Evidence:** I `basicMIMECorrectionPreservesPictureDescription` requires a real MIME update and an unchanged caption; the original MIME-only test remains. **Status:** repaired in `a952ba8`.

### IV-03 — Unchanged native comment/lyric language rewritten (High; confirmed; incomplete P-06 repair)

**Location/API:** W preservation and S native ID3 dispatch; Basic unrelated edits on MP3/WAV/TTA. Restoring described PropertyMap keys cannot restore the original native language or description spelling. Lyrics became language XXX and descriptions were normalized despite unchanged Basic text. **Repair:** capture unchanged native collections inside the transaction, restore through dedicated native writers, and verify those collections. TrueAudio receives the native writer needed for this restoration. **Evidence:** I `basicTitleEditPreservesNativeCommentAndLyricLanguages` independently parses COMM/USLT payloads, performs a verified title mutation, and includes intentional replacement/clearing controls. **Status:** repaired in `5b8e8ca`. DSD collection replay remains fixture-unverified and must fail safely when unsupported.

### IV-04 — Full date repair loses secondary values/aliases (High; confirmed; incomplete P-02 repair)

**Location/API:** W `originalStandardFieldValues` preservation and N date writes. Saving only the first full DATE still drops additional DATE values and YEAR aliases. **Repair:** preserve the complete unchanged underlying date group, remove aliases on intentional scalar replacement/clearing, keep MP4 release-date ownership separate, and avoid ID3v1 projection duplication during MPEG delta saves. **Evidence:** I `basicUnrelatedEditPreservesDateArraysAndYearAlias` on MP3/FLAC/Ogg plus R independent ID3 date coverage. **Status:** repaired in `57276bc`.

### IV-05 — Explicit custom-field deletion wrongly fails verification (Medium; confirmed; overlooked pre-existing defect)

**Location/API:** W/verification Basic custom expectations. Empty custom text requests deletion, but the verifier required that key to remain present. Legitimate deletion rolled back rather than completing. **Repair:** carry empty expectations and verify absence, retaining value/cardinality comparisons for non-empty values. **Evidence:** I `basicCustomEmptyValueExplicitlyDeletesField` checks deletion and unrelated custom preservation across MP3/M4A/FLAC/Ogg/WMA/WavPack/TTA/AAC. **Status:** repaired in `7911973`; diagnostic interpolation corrected in `22226df`.

### IV-06 — Lowercase raw merge keys falsely mismatch (Medium; confirmed; regression)

**Location/API:** W whole-map raw merge. Mutation canonicalized keys while expected-map construction did not, causing a successful lowercase-key request to fail verification. **Repair:** normalize input keys consistently before mutation/verification and reject ambiguous duplicate case variants. **Evidence:** I `rawMergeAcceptsCaseInsensitiveKeys` checks persisted replacement/removal, key-collision rejection and rollback. **Status:** repaired in `7b227c7`.

### IV-07 — Error wrapping destroys recoverable native causes (Medium; confirmed; regression/incomplete P-11)

**Location/API:** manager transaction/error boundary. Mapping every native/filesystem failure to a string removed NSError domain, code and nested recovery evidence. **Repair:** retain the legacy string constructor, add `operationFailedWithUnderlying(NSError)` and expose `underlyingError`; document the runtime case and exhaustive-switch migration. **Evidence:** I `nativeFailureRetainsStructuredCauseAndRollsBack` asserts native validation code 243, structured cause and exact original bytes; R checks missing-write causes. **Status:** repaired in `e52c528`, documentation completed in `1e8fb35`.

### IV-08 — Opaque ID3 payload edits falsely verify (High; confirmed; overlooked equivalent P-05 path)

**Location/API:** S frame validation/matching and native frame writer. An independently constructed XZZZ frame contained bytes [1,2,3]; requesting [4,5,6] returned success although the writer ignored the payload. The default verifier matched unsupported types. **Repair:** reject opaque/unknown frame mutations in both facade and native validation; unsupported matching returns false; supported podcast matching is explicit. **Evidence:** I `opaqueID3FramesCannotReportSuccessfulPayloadEdits` seeds native bytes independently and asserts rejection/rollback. **Status:** repaired in `96178a2`. Inspection of unknown frames remains available; omission preserves them.

### IV-09 — Alternate writers bypass NUL validation (High; confirmed; incomplete input-safety repair)

**Location/API:** Basic/native model writers, raw whole-map and scalar/multi-value bridge writes, direct structured writes. With semantic verification disabled or absent, embedded NUL text was silently truncated/dropped by C-string conversion. **Repair:** validate all relevant Basic strings and add bounded recursive native dictionary/array text validation before transaction staging; binary Data is left untouched. Depth is bounded at 64 to reject cyclic/excessively nested payloads safely. **Evidence:** I `bridgeModelWritesRejectEmbeddedNullsWithoutVerification` and `rawAndDirectStructuredWritersRejectNullsEvenWithoutVerification` assert native code 245 where applicable and unchanged original bytes, including verify=false and verification.none paths. **Status:** repaired in `07b1f34` and `4401ba8`; guard layout clarified in `cf33714`.

### IV-10 — Total-only requests bypass normalized pair policy (Medium; confirmed; incomplete P-09 repair)

**Location/API:** W shared number validation, Basic and typed patches on MPEG/AAC, MP4 and WAV. Rejecting only first-component removal left set-total-without-number requests accepted as zero/total or failing late. **Repair:** apply `validateNativeNumberPair` to all affected resulting normalized pairs before mutation; positive totals require a positive first component on these native paths. **Evidence:** I `nativePairsRejectTotalOnlyTypedRequestsBeforeCommit` checks bytes unchanged; Xiph independent-total controls pass. **Status:** repaired in `afee719`. The raw API remains a lower-level representation surface.

### IV-11 — Defaulted version parameters break function references (Medium; confirmed; regression)

**Location/API:** new version-aware facade overloads. Default arguments preserve many calls but do not preserve function types. Ten representative old method references failed to compile. **Repair:** add exact-arity forwarding overloads in [TagLibMetadataManager+Compatibility.swift](../../../Sources/TagLibAudioMetadata/TagLibMetadataManager+Compatibility.swift), forwarding to version-aware methods with nil tokens. **Evidence:** K compiles all ten old references plus deprecated warn/unchanged; version-aware tests still pass. **Status:** repaired in `d373341`. This preserves representative source use, not ABI compatibility across separately compiled modules.

### IV-12 — Intentional replacement leaves stale aliases (High; confirmed; incomplete alias repair)

**Location/API:** W alias cleanup and native delta dispatch. Preservation logic left native TXXX PUBLISHER/CATALOG and described COMMENT/LYRICS aliases after a scalar edit or clear. Old values could reappear or prevent verified clearing. **Repair:** remove the represented alias/description group before writing a changed scalar, while preserving unchanged groups, dedicated numeric formatting, and MP4 date ownership. **Evidence:** I `explicitBasicEditsReplaceAndClearAliasGroups` on MP3/FLAC/Ogg checks replacement, clearing and unrelated data. **Status:** repaired in `534ed42`.

### IV-13 — INFO-preserving native entry lacks mutex/exception boundary (High; source-confirmed; regression)

**Location/API:** N `applyPropertyMapValuesPreservingInfoSurfaceInPlace`. The added native entry touched TagLib without the global recursive bridge mutex or the standard C++ exception containment used by peer entry points. Concurrent files could bypass the package’s serialization guarantee; exceptions could cross the bridge. No runtime race was claimed. **Repair:** apply the existing mutex and exception macro at this entry. **Evidence:** caller tracing, focused concurrent/WAV tests and final TSan selection (13 passes). **Status:** repaired in `bd6fb03`; no broad transaction redesign.

### IV-14 — Typed WAV patch deletes INFO; fixture misses it (High; confirmed; regression plus test false negative)

**Location/API:** W/N typed patch versus raw-delta key ownership. A shared helper removed RIFF INFO fields when a typed patch updated the same canonical key through ID3. The nominal INFO-only fixture contained encoder information, not an INAM title, so title preservation tests passed without establishing their claimed scenario. **Repair:** independently seed INAM; require its presence before mutation; route typed patches and Basic alias cleanup through ID3-only behavior while retaining raw-delta ownership semantics. **Evidence:** strengthened Q INFO tests compare complete INFO chunk bytes and require a real title update; the seeded case failed before the repair. **Status:** test groundwork `e13af81`; root correction `a8d066e`.

### IV-15 — APE cover reader labels back covers as front (Medium; confirmed; regression)

**Location/API:** APE structured artwork inspection. All native Cover Art entries were assigned Front Cover. **Repair:** map native Front/Back/Other key identities accurately. **Evidence:** J `apeArtworkReaderDistinguishesNativeCoverRoles` constructs APEv2 front/back binary entries independently on a WavPack fixture; the prior result had only role 3. **Status:** repaired in `d6622b3`. This validates the shared APE tag path, not an entire APE audio parser.

### IV-16 — Unchanged native custom names rejected (Medium; confirmed; regression)

**Location/API:** W Basic custom validation on ASF. The native string attribute PUBLISHER legitimately appears in customFields, but the new schema-known-name ban rejected an unrelated title update. **Repair:** allow unchanged read-provenance entries; continue rejecting new/edited ambiguous schema-known custom names. **Evidence:** J `nativeASFCustomNamesDoNotBlockUnrelatedBasicEdits` verifies persisted preservation and safe rejection/unchanged bytes for an intentional ambiguous edit. **Status:** repaired in `846c4e7`.

### IV-17 — RIFF policy final save result ignored (Medium; source-confirmed; remediation persistence gap)

**Location/API:** S id3v2Only policy. The pinned TagLib API’s strip operation returns void; the subsequent file.save() returns Bool, which was ignored. A failure could escape the native persistence check. **Repair:** propagate save failure and reopen the staged WAV to confirm INFO absence before commit. **Evidence:** actual pinned wavfile.h signatures were checked; R independently confirms INFO removal/preservation. No deterministic final-save fault injection was added, so failure propagation is source-validated. **Status:** repaired in `0cfd6b5`.

### IV-18 — Current documentation still overstates safety/compatibility (Medium; confirmed; incomplete documentation repair)

**Location/API:** README, SUPPORT, INSTALLATION, CHANGELOG and API comments. Remaining claims conflated bridge atomicity with semantic verification, implied universal numeric-equivalent verification, described missing writes as invalidFile, and treated all Unreleased work as already on main. TTA support descriptions lagged the native writer. **Repair:** correct current contracts, fixture/source evidence levels, underlying-error recovery and enum-switch migration; preserve historical audit/remediation reports. **Evidence:** direct comparison of public signatures and execution paths with current docs. **Status:** `88c48cb`, `2d7a5e6`, `1e8fb35`.

### IV-19 — DSD structured ID3 collections omitted (Medium; source-confirmed; overlooked pre-existing omission)

**Location/API:** [TLUnifiedExtraction.inc](../../../Sources/CTagLibBridge/Internal/TLUnifiedExtraction.inc) DSF/DSDIFF dispatch and native capability registry. Unified reads exposed Basic tags but omitted native ID3 collection extraction. **Repair:** append native structured ID3 collections and describe read capability accordingly; write capability remains limited to its implemented path. **Evidence:** source tracing and all builds/cross-builds. **Status:** implemented in `d2ceb80`; **runtime UNVERIFIED** because no DSD fixture was available. This is not evidence that every DSD native structured write is supported. Unsupported replay must reject before commit.

### IV-20 — Legacy number writers retain stale totals (Medium; confirmed; incomplete cross-entry-point P-09 repair)

**Location/API:** N integer/formatted number writers and Basic native paired fields. The typed path removed duplicate total aliases, but legacy writers left TXXX TRACKTOTAL/TOTALTRACKS frames, yielding conflicting representations. **Repair:** reuse cleanup on Basic, integer and formatted ID3 writes and preserve other tag surfaces during MPEG saves. **Evidence:** I `lowLevelTrackWritesRemoveStaleID3TotalAliases` independently parses seeded native frames on MP3/WAV and verifies requested pair persistence. **Status:** repaired in `ec488f1`.

### IV-21 — Back-only artwork gains an unintended front cover (High; confirmed; overlooked pre-existing preservation defect)

**Location/API:** native Basic artwork merge. When no front cover existed, the Basic projection used another image, but merge logic did not recognize that unchanged fallback and created an extra front cover. Reproduced on Ogg/ASF during an unrelated title edit. **Repair:** when no front exists, retain the existing byte-matching fallback map instead of creating a duplicate; changed image data can still create the intended front image. **Evidence:** I `unrelatedBasicEditDoesNotDuplicateBackOnlyArtwork` checks actual title change and complete artwork semantic arrays on six formats (MP3/FLAC/Ogg/WAV/TTA/WMA); other formats are controls. **Status:** repaired in `1ccd112`.

## D. Corrective repairs and rationale

Each C entry identifies the affected source, root cause, regression evidence, coverage and commit. The solution choices were deliberately limited to confirmed invariants:

| Repair | Chosen behavior and why it fits the contract |
|---|---|
| IV-01 | Preserve an omitted collection; reserve explicit empty replacement for deletion. This restores incremental write intent. |
| IV-02 | Modify the native picture map in place semantically, changing only MIME. A correction must not reset unrelated attributes. |
| IV-03 | Preserve native comment/lyric collections when the scalar projection is unchanged. Their language and descriptions cannot be reconstructed from a joined string. |
| IV-04 | Retain full raw date arrays for unchanged projections; replace the group only for an actual scalar edit. This avoids treating a display year as complete intent. |
| IV-05 | Verify deletion as absence. Requiring a deleted key to exist contradicts the write contract. |
| IV-06 | Canonicalize keys once for both mutation and expected state; reject colliding input spellings. |
| IV-07 | Preserve typed native causes without deleting the old string constructor. Recovery decisions require structured evidence. |
| IV-08 | Reject opaque mutation rather than pretend to encode unsupported bytes; preserve omitted opaque frames. |
| IV-09 | Enforce text validity at native public boundaries as well as the facade. Verification options cannot authorize silent truncation. |
| IV-10 | Validate the entire resulting normalized pair before mutation; retain independent totals on formats that support them. |
| IV-11 | Forward old method types to new implementations. Exact overloads avoid duplicating transaction semantics. |
| IV-12 | Clear obsolete members of an intentionally edited alias group, then emit the new representation. Unchanged groups retain provenance. |
| IV-13 | Use existing serialization/exception conventions; no new locking model is introduced. |
| IV-14 | Separate typed ID3 ownership from raw visible-key ownership. The same canonical name can exist on two native tag surfaces. |
| IV-15 | Derive artwork role from the native APE key rather than a fixed front-cover default. |
| IV-16 | Accept unchanged native provenance while rejecting ambiguous newly supplied schema names. |
| IV-17 | Check the native save and persisted policy result before commit. A void strip call cannot establish persistence success. |
| IV-18 | Describe current execution paths and compatibility boundaries; historical reports remain historical. |
| IV-19 | Reuse the existing native ID3 extractor for DSD read dispatch. No unsupported DSD writer is advertised or invented. |
| IV-20 | Apply existing alias cleanup consistently to all corresponding legacy number paths. |
| IV-21 | Reuse a matching native fallback artwork entry when the Basic image is unchanged. This preserves role and cardinality. |

The review added independent-oracle tests in `f4a99eb` and strengthened the warn-policy/positive-control test in `fc0d7ba`. These are verification repairs rather than invented production findings. Small diagnostic/formatting follow-ups were committed separately without amending history.

## E. Metadata integrity and API assessment

**Basic metadata.** The facade distinguishes a display projection from preserved raw/native provenance. An unrelated edit retains complete date values, aliases, unmodified multi-values, qualified fields, custom entries, native comments/lyrics and additional artwork in the tested paths. Explicit Basic replacement owns represented Basic fields; omitted custom/native metadata has its documented preservation semantics. Empty custom values request deletion. Changed alias groups are cleared coherently rather than restored stale. A new ambiguous schema-known custom key is rejected, while an unchanged native attribute of that spelling is retained.

Preservation comparisons occur against the current staged read inside the transaction; the review did not add a cache that can reapply an old external revision. `updateBasicMetadata` carries its snapshot version into the writer. Versionless explicit replacement targets current state and intentionally applies the supplied model; callers requiring conflict detection must supply the token.

**Typed patches.** Omitted fields remain unchanged; removal is explicit. Qualified role fields without a role model are rejected. Positive native totals with missing first components are rejected before mutation, rather than silently converted to zero/total. Both components can be removed. FLAC/Ogg can retain independent totals. Formatting text, including leading-zero semantics, follows the relevant API/container contract and is not a universal raw-map equivalence rule. WAV typed changes target ID3 and preserve complete pre-existing INFO bytes in the seeded regression.

**Raw patches and maps.** Raw deltas and whole-map merge operate on named keys and verify the resulting visible values/cardinality; case normalization is consistent. Whole-map replace deliberately owns visible map keys and is not a native archive. It may remove represented INFO or other visible fields. Native structures absent from the projection cannot be reconstructed by this API. Invalid text is rejected even when verifyAfterWrite is false; disabling verification still opts out of semantic readback checks.

**Structured metadata.** `includeProperties: true` enables field-level property deltas; omitted properties survive, an empty property collection is a no-op, and an empty value array explicitly removes its key. Non-empty properties with includeProperties false are invalid. Omitted native collections are preserved; explicit collection replacement/removal has collection-wide scope. APIC/COMM/USLT belong in dedicated collections. Opaque/unknown ID3 frames are inspection-only and cannot be mutated through a wildcard encoder. Supported text/URL/user-text/chapter and other implemented frame forms retain their existing tests. Structured Properties are verified against expected visible state; native requested collections are separately checked.

**Dates, aliases, comments and lyrics.** Recording dates and MP4 release-date ownership are kept distinct. Year-only Basic display does not authorize truncating unchanged full dates. Native language and description spelling require native collection preservation, not merely a map merge. Explicit comment/lyric edits can intentionally replace their represented group; omission does not have that meaning.

**Artwork and native containers.** Tests exercise bytes/MIME/type/description and collection cardinality where applicable, including back-only and multiple-image cases. APE cover roles reflect native key identity. MP4 independent checks compare untouched ilst payloads and audio mdat data. ASF checks require the targeted attribute to change and a same-key sibling stream to remain present. FLAC picture-map attributes survive MIME corrections. Capability labels describe implemented storage surfaces; they do not promise that every format/API combination can encode every role, binary type, or native frame.

**Versions and transactions.** Source review and V tests support same-entry process-local serialization, expected-version checks under the mutation lock, sibling staging, original-file identity recheck, symlink/hard-link rejection, rollback and cleanup. The newly added INFO entry now follows global TagLib serialization and C++ exception containment. Native/Swift paths remain separate implementations; this review did not refactor them broadly.

The transaction is not a cross-process lock. Another process can race after the final identity check and before rename; the documentation describes this boundary. A failed pre-commit operation preserves the original, as exercised by validation, verification, stale-version and injected filesystem failures. After rename, directory-flush failure is reported as a committed durability uncertainty rather than rolled back fiction.

**Durability and errors.** Both transaction implementations request F_FULLFSYNC and fall back to fsync for unsupported-operation errors such as EINVAL/ENOTSUP/ENOTTY. Other flush failures propagate. Durable is an OS-level completion classification, not a guarantee about controllers, storage hardware, or power loss. Additional flush cost and Basic native preservation passes can add I/O; no throughput improvement is claimed. Public write failures retain structured underlying errors, while validation remains distinguishable. New enum cases require downstream exhaustive switches to add handling; representative legacy call/function syntax is preserved.

## F. Test suite assessment

The final suite contains the previous 153 XCTest cases and **20 new Swift Testing tests in three suites**. The review preserved useful existing tests and did not weaken assertions to obtain green results.

Confirmed false negatives included the encoder-only WAV fixture standing in for an INAM preservation scenario; a warning-policy test that did not actually invoke warn; opaque-frame verification accepting ignored payloads; and MIME tests that checked bytes/MIME without asserting picture attributes. New tests require an actual requested mutation and independently seeded expected values. Deletion, replacement and rejection controls accompany preservation tests.

Independent mechanisms now include:

- A bounds-checked ID3v2 frame inspector locating real ID3 headers, including inside WAV, and comparing native COMM/USLT and total-alias payloads.
- A small bounds-checked ISO BMFF atom walker comparing unrelated ilst entries (including hidden formatting/freeform/pair/artwork atoms) and complete mdat payloads.
- An independent RIFF/INFO builder and chunk inspection requiring an INAM title before the operation.
- Independently constructed APEv2 binary artwork entries for front/back role inspection.
- Persisted UTF-16 ASF sentinel payload checks alongside package identity/count checks.

The ASF mechanism is deliberately narrower than a full independent ASF parser. Package readback remains useful for public semantics but is not the only evidence. Existing wrapper-parity and helper-level fault-injection tests remain appropriate for their limited claims.

The new review tests are separated into integrity, native-container and source-compatibility files rather than expanding the already large remediation file indefinitely. Fixture tests operate only on temporary copies. No real user audio was modified.

Remaining gaps: no DSD fixture, no real APE/Musepack end-to-end matrix, no complete independent parser for every ASF type, no deterministic changed-during-read interleaving, no all-format audio decode matrix, no unusual-filesystem/full-flush fallback matrix, and no actual minimum-platform or device runtime. The opt-in external corpus and throughput benchmark were not enabled.

## G. Documentation assessment

Current documentation was compared with source rather than accepted as a remediation artifact. Corrections cover the distinction between bridge atomicity and semantic verification; Basic projection/custom-field replacement; property deltas versus explicit collection replacement; exact raw verification versus normalized numeric APIs; total-only rejection; version-aware APIs and legacy function types; underlying NSError recovery; new enum-case migration; parser-only probe scope; TTA native support; and source-only DSD read evidence.

README, SUPPORT, INSTALLATION, CHANGELOG, maintenance records, capability comments and affected public API comments were updated. INSTALLATION no longer treats all Unreleased repairs as already on main. A historical release-note gap remains acknowledged rather than reconstructed without evidence.

The original audit and remediation report were preserved intact. Their historical claims should not be read as the final review result. Current guidance deliberately limits claims about opaque metadata, capabilities, hardware durability and platforms. A complete per-field/API/format reference remains useful future work, but its absence does not override explicit preflight errors or turn a family capability label into a promise.

## H. Independent verification results

All results below were executed during this review. The final production source is at `1e8fb357709a1fa698ff8ce4da52c6e6fb5d14c9`; the final report commit changes documentation only.

Environment: Apple Swift 6.4 (swiftlang 6.4.0.34.1), arm64 macOS 27.0, Xcode-provided macOS 27.0 and iPhoneOS 27.1 SDKs. Package tools version 6.0; declared minimums macOS 13/iOS 16. Pinned TagLib 2.3.1-r2 binary and dependency versions were retained.

| Actual action / command | Configuration and result |
|---|---|
| Xcode `BuildProject(buildForTesting: true)` | Final Debug build succeeded; no reported errors. |
| Xcode `RunAllTests({})` | Final Debug: **173 total, 171 passed, 2 skipped, 0 failures, 0 not-run**. |
| `swift test -c release --disable-sandbox` | Final-source Release: 153 XCTest cases (151 pass, 2 skips) plus 20 Swift Testing cases pass; **171 pass / 2 skips / 0 failures**. |
| `swift test --disable-sandbox --sanitize=address` | Same full counts; no Address Sanitizer diagnostics. The precompiled TagLib binary itself is not instrumented. |
| `swift test --disable-sandbox --sanitize=thread --filter 'Concurrent\|SameFile\|SnapshotVersion'` | Final-source focused run: **13 passed**, no Thread Sanitizer diagnostics. This selection does not claim the full suite ran under TSan. |
| `swift build --disable-sandbox -Xswiftc -warnings-as-errors -Xcc -Werror` | Passed on final source. Deprecation use in compatibility tests is intentional and is not hidden by this library build. |
| `swift build --disable-sandbox --scratch-path .build/acceptance-ios-arm64 --triple arm64-apple-ios16.0 --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk` | Passed. Compile/link compatibility, not device/runtime validation. |
| `swift build --disable-sandbox --scratch-path .build/acceptance-macos-x86_64 --triple x86_64-apple-macosx13.0 --sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk` | Passed. Cross-build, not x86_64/minimum-OS runtime validation. |
| `swift run --disable-sandbox --package-path IntegrationTests/Consumer TagLibAudioMetadataConsumer` | Passed; facade consumer reported 37 readable extensions. |
| `swift run --disable-sandbox --package-path IntegrationTests/Consumer TagLibAudioMetadataLowLevelConsumer` | Passed; explicit low-level consumer import/use compiled and ran. |
| Focused Xcode regression runs during individual repairs | Ran integrity/native/compatibility, WAV/RIFF, artwork and concurrency selections as relevant before commits. Failures reproduced the repaired defects; later focused runs passed. |
| `git diff --check`, ancestry/ref/status checks | Passed; final history and clean-tree result in J. |

The two skips are `ExternalCorpusPreservationTests.testTrackMutationPreservesOtherVisiblePropertiesInExternalCorpus` and `SnapshotThroughputBenchmarkTests.testOptInIndependentFileSnapshotThroughput`. They require opt-in inputs/settings and are not silently counted as passes.

Local final logs: `/tmp/taglib-review-release-result.log`, `/tmp/taglib-review-asan-result.log`, `/tmp/taglib-review-tsan-delivery.log`, `/tmp/taglib-review-strict-delivery.log`, `/tmp/taglib-review-ios-delivery.log`, and `/tmp/taglib-review-x86-delivery.log`. These are ephemeral environment artifacts, not committed fixtures.

Final Xcode result bundle:

```text
/var/folders/gx/w1cq6f8j41sdgkfp0c5ndb_m0000gn/T/ActionArtifacts/91886601-AC73-4550-AA8F-FED6D9A3951A/RunAllTests/Test-TagLibAudioMetadata-Package-2026.10.18_21-22-45-+0800.xcresult
```

An initial sandboxed CLI build could not write the Clang module cache. The authorized expanded-permission rerun succeeded; this was an environment restriction, not a diagnosed production defect. No tests were disabled for that failure. No remote CI, physical power-loss, cross-process stress harness, simulator/device run, or externally supplied corpus was executed.

## I. Remaining issues

### 1. Must fix before merge

**None demonstrated in the final reviewed scope.** The previously demonstrated blockers in C were repaired, regression-tested and committed. This is a practical integration assessment, not a universal preservation proof.

### 2. Safe to defer

- Expand independent ASF parsing and audio-payload checks beyond the current sentinel/MP4/WAV evidence. Existing tests establish specific invariants; further format breadth adds confidence.
- Add a deterministic changed-during-read test. Identity comparison code and stale-write tests are sound evidence for related paths, but do not force that exact interleaving.
- Measure I/O cost of native collection preservation and full-flush requests using the opt-in benchmark. No performance regression threshold was established, and no performance claim is made.
- Consolidate duplicated field/dispatch definitions when justified by behavior changes. Broad stylistic refactoring during a safety review would add unnecessary risk.
- Complete historical release notes if reliable release-boundary evidence becomes available.

### 3. External dependency limitations

- The pinned dynamic TagLib framework is not instrumented by source sanitizer flags; another TagLib in the process may create C++ symbol-interposition/ABI risks already documented.
- Native serializers can normalize structures, and visible-map replacement cannot reconstruct opaque metadata absent from that map. Supported editing is not byte-for-byte archival preservation.
- F_FULLFSYNC/fsync completion is an OS-level result. Hardware power-loss guarantees and filesystem-specific fallback behavior require external guarantees or dedicated tests.

### 4. API or product design decisions

- Family capabilities remain coarse; operation validation and documented format restrictions are authoritative.
- Typed role metadata requires a future role-aware model; raw/native APIs serve currently representable qualified fields.
- Native normalized pairs reject total-only requests; formats with independent totals retain that support.
- Bridge writes remain versionless and semantically unverified unless the facade supplies that policy. The facade’s bridge-model method still requires an explicit bridge import.
- Legacy error/message constructors remain available, while new error cases require exhaustive client switches to handle additional cases. Current migration guidance makes this deliberate behavior change explicit.
- Verification-context string keys and display-string separators remain public API debt; they do not justify speculative incompatible redesign here.

### 5. Unverified risks requiring further evidence

- DSF/DSDIFF structured collection reads are source/build-supported after IV-19, but native runtime round trips were not established. Real DSD, APE/Musepack and less-used handler fixtures are needed before promoting their evidence level.
- iOS device/simulator, minimum OS runtime, macOS x86_64 runtime and hosted CI were not exercised. Cross-compilation should not be presented as those results.
- Concurrent external processes can race the final identity-check/rename interval. Process-local locking is not interprocess coordination. No stronger guarantee is advertised.
- Full binary/GUID ASF identity preservation, malformed/hostile metadata and unusual filesystem behavior are not exhaustively covered by this review.

These are bounded evidence or dependency limitations, not known residual silent-loss reproductions. A new reproducible counterexample should be treated as a defect and reassessed, rather than excused by this decision.

## J. Git summary

| Item | Verified state |
|---|---|
| Original main | `03473c9ae199026b806a5f75c387ca036e325284` (0.5.3 baseline); main was not modified. |
| Third-party branch | `fix/comprehensive-audit-remediation` |
| Third-party HEAD | `62504ff1334a0e987ed5ace7c55b62aaa079b3dd`; local ref unchanged. |
| New review branch | `review/comprehensive-remediation-verification`, created from that remediation HEAD, not from main. |
| Ancestry | main is an ancestor of remediation; remediation is an ancestor of review. All 15 third-party commits are preserved. |
| New commits | **30 including this final report commit**: 29 completed code/test/documentation commits below, followed by `Record independent remediation verification and merge assessment`. |
| Final tested code HEAD | `1e8fb357709a1fa698ff8ce4da52c6e6fb5d14c9`. |
| Final branch HEAD | The commit containing this report, immediately following `1e8fb35`. Its exact hash is recorded in the final handover; a committed report cannot embed its own content-dependent commit hash. Resolve with `git rev-parse review/comprehensive-remediation-verification`. |
| Working tree | Clean before this report was written; the report is the only final staged addition. Final post-commit status is checked in the handover. |
| Historical audit | AUDIT_REPORT.md remains locally excluded/untracked; it was read, not changed or added. The committed historical remediation report was not rewritten. |
| Dependency identity | Package.swift and the pinned binary version/checksum configuration are unchanged. |
| Prohibited operations | No reset, discard, amend, squash, force-push or merge. Main untouched. No merge commits introduced. No push performed. |

New commits, chronological:

```text
ca653ef Preserve omitted artwork in APE and ASF structured writes
a952ba8 Retain native picture attributes during Basic MIME corrections
5b8e8ca Preserve native comment and lyric collections during Basic edits
57276bc Preserve complete recording date values and clear date aliases explicitly
7911973 Verify explicit Basic custom-field deletion as absence
22226df Correct custom-field deletion diagnostic interpolation
7b227c7 Normalize raw merge keys before mutation and verification
e52c528 Retain underlying native and filesystem errors at the facade boundary
96178a2 Reject unverifiable opaque ID3 frame mutations
07b1f34 Reject null-containing metadata across Basic and bridge-model writes
afee719 Validate all total-only requests on native paired-number paths
f4a99eb Independently inspect MP4 atom preservation and ASF sibling payloads
d373341 Preserve legacy writer function types alongside version-aware overloads
534ed42 Remove stale aliases when Basic fields are intentionally replaced or cleared
bd6fb03 Serialize and contain exceptions in INFO-preserving bridge mutations
e13af81 Check independent RIFF INFO bytes after Basic title updates
a8d066e Keep typed WAV patches on ID3v2 without deleting RIFF INFO fields
d6622b3 Report native APE cover roles without labeling back covers as front
846c4e7 Preserve unchanged native custom fields with schema-known names
88c48cb Align capability and safety documentation with independently verified behavior
fc0d7ba Exercise legacy warning policy and a positive verification control
0cfd6b5 Propagate WAV policy save failures and confirm INFO removal
2d7a5e6 Document independent repairs and their compatibility and preservation contracts
4401ba8 Validate raw and native structured text before unverified writes
cf33714 Keep native validation guards separate from transaction dispatch
d2ceb80 Expose native DSD ID3 collections in structured read projections
ec488f1 Clear stale ID3 totals consistently in legacy number writers
1ccd112 Preserve fallback artwork without creating an extra front cover
1e8fb35 Document recovery and exhaustive-switch migration for write errors
```

The number of commits reflects incremental, reviewable repairs and verification improvements, not a claim that there are 30 independent production defects. No previous commit was amended or squashed.

## K. Final merge decision

**READY WITH CAVEATS**

The remediation HEAD alone was insufficiently safe: this review reproduced metadata loss and false-success paths that its tests did not detect. Those confirmed issues now have targeted corrections and regression coverage, with independent native evidence where practical. Transaction rollback/version behavior remains intact, current documentation matches the deliberately limited API contracts, and full Debug/Release/ASAN plus focused concurrency verification pass.

The remaining items are documented evidence gaps, dependency boundaries, and explicit API/product limitations. None is a demonstrated unresolved merge-blocking defect in the reviewed supported operations. Integration should retain those limits, especially DSD/source-only support, coarse capability labels, visible-map replacement scope, and the absence of cross-process or hardware-durability guarantees. Promote those claims only after obtaining the corresponding runtime evidence.

No merge was performed.
