# Verification hardening — 2026-10-18

## A. Executive summary

**READY WITH CAVEATS.** The practical verification gaps from the previous independent review were investigated without reopening a repository-wide audit. Genuine DSF, DSDIFF, Monkey’s Audio and Musepack fixtures now exercise their complete file handlers. Independent ASF metadata inspection, deterministic snapshot-conflict tests, broader encoded-audio checks and representative source compilation materially improve the evidence.

Three existing production defects were exposed and repaired:

1. ASF WORD updates added a DWORD sibling while reporting verified success.
2. Normalized ASF number writers discarded separate totals instead of storing native paired text.
3. An unsupported ASF GUID request with readback disabled was accepted as a binary attribute.

All repairs have focused regression coverage and incremental commits. No demonstrated merge-blocking defect remains in the final reviewed scope. DSD native collection mutation remains deliberately unsupported; tests verify rejection/unchanged originals rather than extending capabilities.

The final suite has **186 tests**. Debug and Address Sanitizer each passed **184**, with **2 intentional opt-in skips**; Release passed **all 186**, with both opt-in facilities enabled. Detailed results and qualifications appear in I. None of these counts is inherited from the previous review.

Four pinned upstream fixtures were independently recognized and decoded with FFmpeg. An additional eight-format generated-tone corpus was built reproducibly and the strengthened corpus test passed against it. This is controlled synthetic coverage, not an independently curated application corpus or a representative user music library.

The assignment adds 13 tests, including compile coverage, and preserves previous tests and history. No main change, merge, push, dependency upgrade, public test hook, transaction redesign or downstream application work was performed.

## B. Verification coverage matrix

| Target | Objective and actual work | Formats | Evidence/result | Remaining gap |
|---|---|---|---|---|
| DSD runtime | Read Basic/Raw/Structured; independently seed TIT2, COMM, USLT, APIC, opaque XZZZ; mutate TITLE by raw delta; exercise Basic/artwork mutation and unsupported replay. | Genuine DSF and uncompressed DSDIFF | Native frames and audio data compared independently; DSD64 rate, stereo, duration, known title, languages, captions and picture bytes asserted. Basic/artwork supported paths pass; unsupported native collection replacement and Basic replay reject without commit. | Not DST-compressed DSDIFF, every layout or native collection writer. |
| APE/Musepack | Exercise public Basic, typed, raw and structured writes, custom arrays, artwork, stale versions, unsupported collections and removal. | APE 3.99; Musepack SV7 | Independent APEv2 item parser compares flags/values, front/back entries, multi-values and tag-independent file bytes. Actual title/album changes and artwork removal are required. Both handlers pass. | Not all APE versions or MPC SV8; no universal role/codec conformance claim. |
| ASF native identity | Independently seed and inspect types 0–6, same-name differing language/type siblings, stream numbers, binary/GUID data and existing picture data. | WMA/ASF | Bounded parser covers Extended Content Description, Metadata and Metadata Library records, Header Extension nesting and complete post-header media bytes. Target update plus unchanged siblings/picture/audio pass. Three defects repaired (D). | Not a full ASF decoder or all possible object types; semantic schema validation of arbitrary third-party headers remains outside the oracle. |
| Read consistency | Force mutation after genuine native extraction but before final version validation; append in place, atomically replace same-byte inode, and commit another metadata revision. | FLAC snapshots | Both Basic/full snapshot construction reject changed identities; fresh reads and stale-token rejection controls pass. No random sleeps or global mutable hooks. | Does not pause inside TagLib parsing or prove cross-process race freedom. |
| Encoded audio | Perform Basic title, typed album, raw custom delta, structured title, artwork update and complete metadata clear; require real persisted changes. | FLAC, MP3, AAC, Vorbis, Opus, TTA, WavPack | FLAC frame region, reconstructed Ogg packet payloads and tag-independent byte regions remain identical at every step. New DSD/APE/MPC and ASF tests provide additional media invariants. Existing MP4/WAV checks were rerun in full suite. | Not decoded PCM equivalence for all mutated copies, malformed/chained Ogg conformance, or every handler. |
| Source compatibility | Extend public-only compilation beyond 10 existing legacy writer references. | Swift facade and explicit bridge import | Adds 17 reader/erase/deprecated/version-aware references and public error recovery checks. Existing warn/unchanged references and both consumer packages compile/run. | Representative 0.5.3-era source use, not binary ABI or an exhaustive historical downstream corpus. |
| External corpus | Inspect skip/preconditions; require actual track mutation, total persistence and non-empty unrelated visible metadata; use public version-aware API. | Eight independently generated tone containers | Enabled corpus test passes; all generated files independently decode. Old helper-only test could miss an unapplied total. | Generated corpus is not an external application corpus; hidden metadata preservation is established by separate format tests. |
| Performance opt-in | Run warmed serial/concurrent snapshots; extend observations to native-preserving writes and dirty-file flushes. | FLAC snapshots; MP3 writes; one local filesystem | Enabled benchmark passes; actual measurements in G. Setup/seeding is outside timers; no gating thresholds. | No before/after historical baseline, large-file matrix or durability experiment. |
| Release provenance | Inspect existing tag targets and only their relevant commit ranges. | 0.5.1–0.5.3 | Selected changelog summaries reconstructed with exact tag boundaries and supporting commits. | Publication dates, historical test results and comprehensive compatibility claims not invented. |

## C. Fixtures and independent oracles

### Genuine acquired fixtures

All four files were copied unchanged from [TagLib 2.3.1 commit 54ae7d8ac45755e286a5c574280f48d5bef93aef](https://github.com/taglib/taglib/tree/54ae7d8ac45755e286a5c574280f48d5bef93aef/tests/data), the same upstream revision already used by this repository. License texts remain in ThirdParty/TagLib. Full SHA-256 values and redistribution provenance are recorded in [Audio/README](../Tests/TagLibAudioMetadataTests/Audio/README.md).

| Local fixture | Upstream file | Bytes | Independent validation |
|---|---|---|---|
| hardening.dsf | empty10ms.dsf | 8,284 | FFprobe dsd_lsbf_planar; FFmpeg full decode exits 0. |
| hardening.dff | empty10ms.dff | 7,186 | FFprobe dsd_msbf; FFmpeg full decode exits 0. |
| hardening.ape | mac-399.ape | 85,212 | FFprobe APE, stereo 44.1 kHz, 3.550023 s; full decode exits 0. |
| hardening.mpc | click.mpc | 1,588 | FFprobe musepack7, stereo 44.1 kHz; full decode exits 0. |

These are genuine format files, not renamed substitutes or header-only fuzz fixtures. The pinned TagLib binary recognizes them at runtime through the package. Upstream tests independently specify DSD64 stereo and APE/MPC 44.1 kHz stereo. FFmpeg reports DSD’s packed byte rate as 352,800 Hz while TagLib reports the one-bit rate 2,822,400 Hz; tests compare the correct quantities. Decoder-delay accounting differs for the short MPC fixture, so exact duration equality across readers is not asserted.

[HardeningFixtureSupport](../Tests/TagLibAudioMetadataTests/Integration/HardeningFixtureSupport.swift) supplies bounded test-only native readers and builders. DSF metadata pointers/chunk lengths and DSDIFF FRM8/chunk bounds are checked; ID3v2.4 frames are seeded with independently specified language, description, payload and opaque data. The DSF layout follows [Sony’s specification](https://dsd-guide.com/sites/default/files/white-papers/DSFFileFormatSpec_E.pdf); [TagLib’s DSDIFF reference](https://taglib.org/api/namespaceTagLib_1_1DSDIFF.html) distinguishes the conventional ID3 extension from the underlying DSDIFF standard.

APEv2 inspection validates footer size/count, item bounds and flags. Keys are compared case-insensitively as required by the native tag identity; initial mixed-case assertions were corrected rather than changing valid production normalization. APE/MPC artwork writes intentionally support one front cover. The test independently seeds an additional back image and checks preservation/removal through public APIs.

### Independent ASF metadata oracle

[HardeningASFTests](../Tests/TagLibAudioMetadataTests/Integration/HardeningASFTests.swift) implements a targeted, test-only reader of ASF objects and native attribute records. It checks 64-bit sizes without overflowing Int, record counts/lengths, UTF-16 boundaries, object boundaries and bounded Header Extension depth. Malformed/truncated object and record tests require rejection.

The reader follows ASF Header/Extension, Extended Content Description, Metadata and Metadata Library layouts, not package-generated expected projections. [Microsoft’s file-structure documentation](https://learn.microsoft.com/en-us/windows/win32/medfound/asf-file-structure) identifies the object and media-data boundaries. The independently seeded library includes language-list records, stream 1, repeated names with differing identities, WORD/DWORD/QWORD/Boolean/string/binary/GUID values. Initial fixture construction mistakes (Boolean width and duplicate empty library objects) were diagnosed and corrected before relying on runtime results. They were not reported as production failures.

Native expected values are explicit. An unrelated WM/Picture entry is captured and compared as a complete native attribute value. The post-header bytes containing media objects and data packets must remain equal. FFprobe also recognized the disposable independently seeded ASF file. This is much stronger than searching for sentinels, but still not comprehensive ASF validation.

### Encoded-payload oracle and generated corpus

[HardeningAudioPayloadTests](../Tests/TagLibAudioMetadataTests/Integration/HardeningAudioPayloadTests.swift) skips FLAC metadata blocks, reconstructs Ogg packets independently of page repagination, excludes only Vorbis/Opus comment packets, and removes recognized ID3/APE tag regions for relevant formats. Encoded audio and immutable codec-header payloads must remain equal after each real operation. It does not use whole-file equality as an audio oracle.

[scripts/make-preservation-corpus.py](../scripts/make-preservation-corpus.py) creates a new output directory and eight FFmpeg-generated 731 Hz, stereo 48 kHz, 0.15-second tone containers with explicit title/artist/album/comment/date/track/disc/custom metadata. It never reads user music or overwrites an existing corpus. Native experimental Vorbis/Opus encoders are explicitly enabled; encoder availability is a prerequisite, not silently skipped.

FFmpeg’s TTA muxer emits APEv2 while the pinned TTA reader projects ID3. The script independently prepends valid ID3v2.4 with known values so the visible-map assertions have real unrelated metadata to protect. All eight final generated files decoded successfully. The original three partial/diagnostic corpus attempts were not used as passing evidence.

The generated files remain disposable under /tmp; the reproducible script is committed. No user-library corpus was available. Real APE/MPC/DSD evidence comes from the genuine committed fixtures, not the generated corpus.

## D. New findings and repairs

### VH-01 — Verified ASF WORD update creates conflicting DWORD sibling

- **Severity/confidence:** High; independently reproduced.
- **Location:** [TLStructuredMutation.inc](../Sources/CTagLibBridge/Internal/TLStructuredMutation.inc), ApplyStructuredASFAttributes.
- **Trigger:** Existing native WORD (type 5), key HARDEN_WORD, language 0/stream 1, value 42. Submit the public int projection with value 7.
- **Evidence:** The operation returned verified success, but independent parsing found both the old WORD and a new DWORD (type 3). The verifier’s int projection could find the new numeric value without detecting the stale native sibling.
- **Root cause:** WORD and DWORD share public type int, while the writer always constructed an unsigned-int DWORD before identity-based upsert.
- **Correction:** Detect existing native width for the requested name/language/stream. Retain an unambiguous WORD using its unsigned-short constructor; use DWORD for new int attributes. Reject an overflowing WORD or an ambiguous same-identity WORD/DWORD combination before saving.
- **Coverage:** wordAttributeUpdateRetainsNativeTypeAndCardinality and ambiguousIntegerWidthsRejectBeforeCommit; independent exact type/value/cardinality checks and byte-preserving rejection with readback disabled.
- **Commit/status:** `019c327`; fixed. No public type redesign.

### VH-02 — Normalized ASF number totals do not persist

- **Severity/confidence:** Medium; independently reproduced as a verified-write failure/rollback, not successful corruption in that facade path.
- **Location:** [TLPropertyMapCodec.inc](../Sources/CTagLibBridge/Internal/TLPropertyMapCodec.inc), [TLPropertyMapWrites.inc](../Sources/CTagLibBridge/Internal/TLPropertyMapWrites.inc), [TLPropertyMapDelta.inc](../Sources/CTagLibBridge/Internal/TLPropertyMapDelta.inc), and normalized pair validation.
- **Trigger:** The strengthened enabled corpus test requests track 3/12 through the public typed API on generated WMA.
- **Evidence:** Verification reported expected total 12, observed 0. An independent native regression covers Basic replacement, typed partial updates and formatted number writes.
- **Root cause:** Shared generic writers supplied separate TRACKTOTAL/DISCTOTAL keys that the pinned ASF PropertyMap encoder does not store.
- **Correction:** A small ASF-only adapter combines normalized number/total values into WM/TrackNumber and WM/PartOfSet text pairs before the generic writer persists them. All three normalized writer families use it. Exact raw-map semantics are unchanged. Positive ASF totals require a positive first component in the normalized API.
- **Coverage:** normalizedNumberWritersPersistASFNativePairs checks persisted native pairs, total preservation/removal, absent-first rejection and unchanged media bytes; the eight-format corpus now passes.
- **Commit/status:** `c04a4e2`; fixed. Numeric-equivalent total formatting remains permitted; a supplied total 03 may persist canonically as 3.

### VH-03 — Unsupported ASF GUID write changes native type when verification is disabled

- **Severity/confidence:** Medium; independently reproduced.
- **Location:** [TLStructuredMutation.inc](../Sources/CTagLibBridge/Internal/TLStructuredMutation.inc), native structured payload validation.
- **Trigger:** Independently seeded native GUID attribute, then request type guid with changed 16-byte data and verifyAfterWrite false.
- **Evidence:** No error was thrown and the original file changed. The encoder used the binary ByteVector constructor rather than GuidType. This was an unsupported type substitution, even though semantic readback had been explicitly disabled.
- **Root cause:** The pinned public TagLib Attribute constructors expose binary but no GUID constructor; the bridge accepted both under the binary construction path.
- **Correction:** Reject GUID write payloads at native preflight. Preserve GUID inspection and omission-based preservation; do not fabricate a replacement type.
- **Coverage:** unsupportedGUIDMutationRejectsEvenWithoutReadbackVerification requires rejection/unchanged bytes; independent mixed-type preservation tests establish that omitted native GUIDs remain intact.
- **Commit/status:** `3f7e92f`; fixed by safe rejection. GUID mutation remains dependency-limited and is documented as inspection-only.

These defects already existed at the starting review HEAD. This phase did not attribute them to a particular earlier commit without evidence. No additional production defect was inferred from an invalid fixture, an intentionally unsupported collection write, or a default opt-in skip.

## E. Previously unverified behaviors now supported by runtime evidence

- DSF/DSDIFF structured ID3 collection extraction moved from source/build evidence to runtime checks against independently seeded native frames. Supported Basic/artwork and raw-delta paths now have audio preservation evidence.
- APE 3.99 and MPC SV7 complete file handlers now have recognition/audio-property/public-write evidence. WavPack’s shared tag implementation is no longer the sole basis for those two formats.
- ASF sibling preservation now includes actual names, native types, language indices, stream numbers, binary/GUID values, picture payloads and media bytes. GUID **encoding** is explicitly excluded.
- Snapshot conflict rejection now has deterministic in-place/replace/metadata-edit interleavings during construction, through the same implementation used by public methods.
- Encoded payload preservation extends beyond prior MP4/WAV checks to seven additional format fixtures plus DSD/APE/MPC/ASF checks in their native suites.
- Both previously skipped facilities have actually executed. Release reports them as passes only when their prerequisites are enabled.

Configured fixture labels now include ape/mpc/dsf/dff/opus and the capability tests reflect that evidence. Structured DSD read capability remains distinct from collection-write capability. No claim covers all valid files, compression modes, platforms or native structures.

## F. Opt-in test assessment

### ExternalCorpusPreservationTests

Previously skipped because TAGLIB_PRESERVATION_CORPUS was absent. It copied files safely but invoked an internal in-place helper and never required the intended number/total to persist. It could pass with no unrelated visible metadata. The strengthened test uses the public version-aware patch, changes track to 3 (or 4 if already 3), checks total 12, and requires non-empty unrelated visible properties before comparing them.

It was enabled on eight generated containers; an initial WMA failure exposed VH-02. The corrected final corpus passed in focused Debug and full Release. This validates the facility and a controlled corpus, not an external application library. A user-supplied corpus must contain writable, track-capable audio with unrelated visible metadata; unsupported/empty inputs should fail rather than be counted as preservation evidence.

Default opt-in behavior remains appropriate: inputs, size, licensing and metadata patterns vary. Absence of the external path intentionally skips; an empty or unsuitable supplied selection fails.

### SnapshotThroughputBenchmarkTests

Previously skipped because TAGLIB_BENCHMARK was not 1. The existing setup makes eight disposable FLAC copies, warms them, then times 256 serial reads versus eight workers × 32 reads across three samples. Setup is outside timing, failure collection is synchronized and a zero-failure assertion is meaningful.

The enabled benchmark executed successfully in Release. Added observations time actual native-preserving Basic writes versus raw title deltas and fsync/fullSync on dirty temporary files. These remain measurements without thresholds. Default runs still intentionally skip this environment-sensitive experiment.

### Skip classification

| Run | Corpus | Benchmark |
|---|---|---|
| Default final Debug | Intentionally skipped: external input not enabled | Intentionally skipped by design |
| Enabled final Release | Executed and passed, 8 controlled files | Executed and passed |
| Default full ASAN | Intentionally skipped: external input not enabled | Intentionally skipped by design |

No skipped test is reported as passed. No suitably curated application corpus, device benchmark or historical performance comparison was available.

## G. Performance findings

Final Release measurements on arm64 macOS 27.0, Apple Swift 6.4, FFmpeg 9.0.2, local temporary files. Read caches are warmed and inputs are tiny fixtures. Work was measured with ContinuousClock. No dependency lock was removed.

| Observation | Three samples, seconds per batch |
|---|---|
| 256 serial FLAC snapshots | 0.069558, 0.042826, 0.042779 |
| 256 snapshots, 8 workers | 0.038895, 0.036071, 0.035583 |
| 12 raw MP3 title deltas | 0.103702, 0.110694, 0.139258 |
| 12 Basic MP3 title edits preserving native comment/lyric collections | 0.129635, 0.160020, 0.193116 |

Write setup, native seeding and copying are outside timing; actual staging, readback and file/directory flushes are included. Basic and raw paths do different work. Fixed sample order, small sample count, cache state and shared host scheduling prevent attributing the entire difference to a single preservation pass or treating this as a regression baseline.

For twelve dirty 4 KiB file flush samples, median fsync was **0.0653 ms** (range 0.0583–0.0805 ms); production fullSync was **2.9276 ms** (range 2.8613–3.9495 ms). Writes that dirty the file occur before each measured flush. fullSync requests F_FULLFSYNC and may fall back according to production policy; the benchmark does not instrument which filesystem path was taken. File and directory flushes are not interchangeable, and these results do not measure hardware power-loss durability.

An overhead is measurable, but **no actionable historical performance regression is established**. No arbitrary threshold or optimization was introduced. Numbers are observations for this host/run, not a throughput promise.

## H. Documentation changes

- [README](../README.md), current capability evidence and tests now identify the genuine new fixtures.
- [SUPPORT](SUPPORT.md) states DSD read/write differences, safe rejection when Basic native replay is unsupported, APE front-image write limits, ASF integer-width behavior, GUID inspection-only status, normalized pair semantics and reproducible opt-in commands.
- [Audio provenance](../Tests/TagLibAudioMetadataTests/Audio/README.md) records upstream paths, hashes, formats, license location and independent decoding.
- [CHANGELOG](../CHANGELOG.md) records this phase’s repairs and coverage. Patch release summaries use verified existing targets: 0.5.1 cafcf40, 0.5.2 62dcf9b, 0.5.3 03473c9, with selected supporting commits and no invented publication dates.
- Historical AUDIT_REPORT.md and the prior remediation/independent-review reports remain untouched. Their unverified-status descriptions are historical; this document records the later evidence.

A transient documentation edit used a truncated tool read; its omitted content was restored from the committed source and the intended small diff was reviewed before committing. No truncation or historical record rewrite is present in the branch.

## I. Final verification results

Final tested source: `98b17dcea74daf4e807f4a52bc9fb437f6b143a7`. The subsequent report commit changes documentation only.

Environment: arm64 macOS 27.0, Apple Swift 6.4 (swiftlang-6.4.0.34.1, clang-2100.3.34.1), FFmpeg 9.0.2. Package tools version 6.0; minimum deployment targets macOS 13 and iOS 16. The pinned TagLib 2.3.1-r2 framework/checksum is unchanged.

| Actual final action | Result |
|---|---|
| Xcode BuildProject(buildForTesting: true) | Passed, no reported errors. |
| Xcode RunAllTests({}) | **186 total: 184 passed, 2 skipped, 0 failures, 0 not-run.** |
| `TAGLIB_PRESERVATION_CORPUS=/tmp/taglib-hardening-corpus-final TAGLIB_BENCHMARK=1 swift test -c release --disable-sandbox` | **186 passed, 0 skipped, 0 failed**: 153 XCTest cases and 33 Swift Testing cases in 7 suites. Both opt-ins executed. |
| `swift test --disable-sandbox --sanitize=address` | **184 passed, 2 skipped, 0 failed** across full suite; no ASAN diagnostics. The pinned precompiled TagLib binary itself is not instrumented. |
| `swift test --disable-sandbox --sanitize=thread --filter 'Concurrent\|SameFile\|SnapshotVersion\|HardeningReadConsistencyTests'` | **15 passed**: 13 XCTest concurrency/version cases and 2 new Swift Testing cases. No TSan diagnostics; this was a focused selection, not the full package. |
| `swift build --disable-sandbox -Xswiftc -warnings-as-errors -Xcc -Werror` | Passed for the final library. Intentional deprecated-use warnings in compatibility tests/consumers remain visible. |
| `swift build --disable-sandbox --scratch-path .build/acceptance-ios-arm64 --triple arm64-apple-ios16.0 --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk` | Passed; compile/link evidence only, not device/minimum-OS runtime. |
| `swift build --disable-sandbox --scratch-path .build/acceptance-macos-x86_64 --triple x86_64-apple-macosx13.0 --sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk` | Passed; cross-build only, no x86_64 runtime claim. |
| `swift run --disable-sandbox --package-path IntegrationTests/Consumer TagLibAudioMetadataConsumer` | Passed; public consumer reports 37 readable extensions. |
| `swift run --disable-sandbox --package-path IntegrationTests/Consumer TagLibAudioMetadataLowLevelConsumer` | Passed; explicit bridge product/module use compiled and ran. |
| `python3 scripts/make-preservation-corpus.py /tmp/taglib-hardening-corpus-final` | Generated 8 valid containers. Separate FFmpeg decode-to-null checks passed for all eight. |
| FFprobe and `ffmpeg -v error -i FILE -map 0:a:0 -f null -` | Recognition and complete decoding passed for each newly acquired upstream fixture. |
| Focused SwiftPM filters during development | HardeningFormatTests (3), HardeningASFTests (6), HardeningAudioPayloadTests (1), HardeningReadConsistencyTests (2), compatibility (2 including prior case), existing native/version/capability suites and enabled corpus all passed after relevant corrections. |
| Git ancestry/ref, staged diff and whitespace checks | Passed; protected refs/history remain intact. |

Final default skips are the two existing opt-ins named in F. They were enabled and passed in final Release. No ordinary test was disabled or weakened. Native format tests, real-file tests, rollback/version regressions and new public source-compilation coverage are part of these full runs.

The exact Xcode final result bundle is:

```text
/var/folders/gx/w1cq6f8j41sdgkfp0c5ndb_m0000gn/T/ActionArtifacts/DD800379-29C2-4E8C-91C5-69CDFB3BD7D8/RunAllTests/Test-TagLibAudioMetadata-Package-2026.10.18_22-21-10-+0800.xcresult
```

Other final logs are local ephemeral artifacts: `/tmp/taglib-hardening-release.log`, `/tmp/taglib-hardening-asan.log`, `/tmp/taglib-hardening-tsan.log`, `/tmp/taglib-hardening-strict.log`, `/tmp/taglib-hardening-ios.log`, `/tmp/taglib-hardening-x86.log`, `/tmp/taglib-hardening-consumer.log`, and `/tmp/taglib-hardening-lowlevel.log`.

Development failures were investigated, not concealed: invalid independent fixture construction was corrected; APE key-case and numeric-equivalent total assertions were corrected to the native contract; a Swift Testing diagnostic argument was fixed; native Vorbis encoder availability required the explicit experimental encoder; actual ASF failures became D’s production repairs. An initial Python HTTPS download failed because its certificate store was missing the local trust chain; system curl retrieved the pinned files without disabling TLS verification. SwiftPM serialized shared-build-directory invocations; separate cross-build scratch paths were used.

Not executed: actual iOS/device/simulator/minimum-OS runs, macOS x86_64 runtime, remote CI, an independently curated user/application corpus, hardware power-loss testing, all-version APE/MPC/DSD conformance, a full ASF decoder, or a deterministic interruption inside the native parser.

## J. Remaining issues

### 1. Confirmed merge blockers

**None in the completed focused scope.** VH-01–03 were repaired, focused-tested and included in the final full runs. The prior review’s repairs remain in ancestry and their tests pass.

### 2. Safe-to-defer verification gaps

- Extend APE/MPC coverage to other revisions, DSDIFF to DST compression, and less-used handlers to genuine fixtures. Current evidence is specific to the committed files.
- Add parser-internal synchronization tests if a concrete read inconsistency warrants that additional native seam. Current per-call seam deterministically covers the post-extraction construction/validation interval.
- Extend encoded-payload/decoded-PCM and independent metadata checks to further containers and real-world large files. Current byte/packet checks establish their stated preservation invariants only.
- Collect a curated application corpus and stable performance baseline. Neither is needed to count the controlled generated corpus or local measurements honestly.

### 3. Dependency limitations

- The pinned public ASF API cannot encode GUID attributes. Safe rejection and omission-based preservation are implemented; no dependency upgrade is justified by this phase.
- Precompiled TagLib is not instrumented by the package’s sanitizer build flags. Its serializers/ABI and C++ symbol-interposition boundaries remain documented.
- FullSync/fsync completion does not establish hardware power-loss durability. Filesystem fallback behavior and unusual storage require dedicated evidence.

### 4. Intentional API/product constraints

- DSD collection reading is broader than collection writing. Direct native collection replacement and Basic updates requiring native replay reject; raw deltas can edit unrelated supported fields.
- APE-family artwork writes support one front cover; existing back entries are preserved during unrelated changes and all roles can be removed.
- ASF int projects two native widths. Updates preserve an unambiguous width, otherwise reject. A richer width-aware public model is outside this assignment.
- Normalized ASF/ID3/MP4/WAV pairs require a positive first component for a positive total; exact raw APIs retain their separate semantics.
- Whole-map replacement is a visible-map ownership operation, not a native archive. Explicitly disabling semantic verification still disables readback; validation continues to reject known unsupported encodings.

### 5. Future independent work

- Device/minimum-platform runtime and hosted CI execution.
- Real external-application metadata, broader container variants and adversarial input testing.
- Cross-process coordination or stronger atomic-read guarantees, if separately required by a product contract. No such redesign is claimed here.
- Historical release publication dates and complete downstream compatibility evidence. Reconstructed tag summaries deliberately omit unsupported details.

No theoretical gap or optional untested feature is treated as an automatic blocker. Conversely, the demonstrated less-common ASF defects were repaired rather than dismissed as caveats.

## K. Git summary

| Item | Verified state |
|---|---|
| Original main | `03473c9ae199026b806a5f75c387ca036e325284`; unchanged. |
| Previous independent review HEAD | `737dd0770874e2f980466c53603dfd9924a5f862`; branch ref unchanged. |
| Third-party remediation HEAD | `62504ff1334a0e987ed5ace7c55b62aaa079b3dd`; branch ref unchanged. |
| New branch | `review/verification-hardening`, newly created from the previous review’s final report commit. |
| New commit count | **14 including this report**: 13 prior focused commits listed below, followed by `Record verification hardening evidence and final merge assessment`. |
| Final tested source HEAD | `98b17dcea74daf4e807f4a52bc9fb437f6b143a7`. |
| Final branch HEAD | The report commit immediately following that source HEAD; the exact content-dependent hash is provided in the final handover. Resolve with `git rev-parse review/verification-hardening`. |
| Working tree | Clean before writing this report; only the report is staged at the final documentation checkpoint. Final post-commit status is checked and reported in handover. |
| Preserved history/files | All previous remediation/review commits remain ancestors. AUDIT_REPORT.md remains locally excluded/untracked and untouched. Prior historical reports unchanged. |
| Dependency/package | Package.swift and binary version/checksum configuration unchanged. |
| Main/merge/push | Main untouched. No merge, push, reset, amend, squash, rebase, force-push or history rewrite. No unrelated repository modified. |

Chronological new commits:

```text
e4558fb Add pinned upstream DSD APE and Musepack fixtures with provenance
cc1a80e Verify genuine DSD APE and Musepack metadata and native payload preservation
8fbb101 Exercise deterministic snapshot conflicts with per-call extraction seams
f4c45fd Independently verify ASF attribute identity types artwork and media data
c43fce4 Check encoded audio preservation across seven formats and six writer operations
019c327 Preserve ASF WORD widths and reject ambiguous integer updates
ecea215 Measure opt-in native preservation writes and flush costs
5cba703 Compile legacy readers erase APIs and version-aware function references
c04a4e2 Persist ASF totals through native paired-number properties
1c22a83 Exercise public corpus mutations with generated reproducible tone inputs
3f7e92f Reject unsupported ASF GUID encoding before any staged mutation
e5ed134 Align fixture evidence and document bounded ASF and DSD contracts
98b17dc Record hardening repairs and reconstruct patch notes from verified tags
```

## L. Final merge decision

**READY WITH CAVEATS**

The practical missing coverage has substantially improved: genuine format-level fixtures replace assumptions about shared tag handlers, independent native checks caught real defects, deterministic read-conflict tests pass, both opt-in facilities ran, and the final Debug/Release/sanitizer/build/consumer checks are green. The confirmed defects are repaired with focused commits and public/native regression coverage.

Remaining limitations concern explicit unsupported native operations, dependency boundaries, broader corpus/codec variants and unexecuted platform runtimes. They are documented and bounded, with no remaining reproduced silent-loss or false-success defect in the completed scope. They do not prevent practical integration under the current API contracts.

No merge was performed.
