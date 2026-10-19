# Clean-Room Audit Remediation — 2026-10-19

Completion date: 2026-10-19. This is the authoritative handover for remediation of [CLEAN_ROOM_AUDIT_2026-10-19.md](../audits/AUD-2026-10-19-clean-room.md). The audit and earlier historical audit/remediation reports were preserved unchanged. The conclusions below come from current implementation inspection, focused reproductions, committed regressions, native parsers, and final executed checks; the auditor's suggested designs were not treated as instructions.

## A. Executive Summary

**Outcome: READY WITH CAVEATS. MERGE RECOMMENDATION: YES. Remaining merge blockers: none identified.**

All twenty audit findings have an explicit disposition below. The five reported high-severity integrity defects are repaired. MP4 semantic patches use native schema freeform storage and verify both native aliases and scalar readback. Qualified ID3 comment/lyric patches replace or remove the full represented field. Legacy MPEG and TrueAudio values are promoted before creation of the preferred ID3v2 tag. Number pairs use native ID3 frames across the supported ID3 families. Unrelated MP4 edits preserve number aliases, and track-only writes retain disc aliases.

Medium-severity repairs cover preserving MPEG saves, AAC native capabilities/collection replay, MP4 date updates, explicit raw/native namespace validation, and complete ASF erasure. Lower-severity work adds exact artwork checks, available bit-depth projections, custom-field case identity, accurate display/removal contracts, and privilege-file rejection. Independent final experiments also found and repaired stale ASF common-field aliases and native APE date renaming. A mixed ID3/APEv2 TrueAudio layout now fails safely because the pinned handler cannot reconcile both metadata surfaces.

The suite grew from 186 to **208 tests**: 153 XCTest tests and 55 Swift Testing tests, including 22 new regression functions. Final Debug with both opt-ins enabled passed all 208 without skips. Final Release, Xcode, ASAN, and TSAN each passed 206 with the two default opt-in skips and zero failures. The skipped corpus and benchmark checks were executed successfully in the final Debug run. Five strict architecture/platform builds and both public consumers passed. A separate public-API harness plus FFmpeg/ffprobe verified eight generated formats independently.

Remaining caveats are bounded: raw APIs require PropertyMap keys rather than native atom identifiers; generic number displays normalize formatting; some structured records have no individual deletion operation; unmodeled TrueAudio APEv2 fields and privilege-bearing files reject; less-common formats and minimum-OS/device runtime remain unverified. The precompiled TagLib dependency is not sanitizer-instrumented. No dependency upgrade, AudioMator change, public Audio Payload Identity API, merge, history rewrite, or main-branch modification was performed.

## B. Complete Finding Resolution Matrix

“Fixed” means the reported behavior is corrected within the documented supported contract. “Bounded” means a genuine API/representation limit is explicitly defined and unsafe ambiguous requests fail, rather than a confirmed silent-loss defect being accepted. Commit IDs resolve on the remediation branch; detailed evidence follows in section D.

| Finding | Independent validity assessment | Final disposition and implementation | Verification evidence | Related commits | Remaining limitation |
| --- | --- | --- | --- | --- | --- |
| AUD-01 | Valid: Basic, Patch, TagLib PropertyMap, and native freeform spellings diverged; checking one raw key admitted stale semantic values. | Fixed. MP4 freeform Patch storage comes from the field schema; recognized native aliases are removed, canonical arrays are inspected, and text/removal semantic readback is checked. Basic preserves unchanged native freeform arrays; targeted replay does not manufacture aliases. MusicIP spaced spelling is recognized in both schema copies and the reader. | `CleanRoomMP4Tests` covers all six reported fields, Basic and external seeds, replacement/removal, competing WORK/AcoustID aliases, exact atom counts, unrelated items, and mdat bytes. Independent ffprobe reports NEW-ID and NEW-WORK only. | `be15af7`, `58b6583` | Only documented recognized alias groups are semantic equivalents; arbitrary private native items are not inferred to be aliases. |
| AUD-02 | Valid: unqualified COMMENT/LYRICS mutations did not own qualified keys; verification could confirm a no-op. | Fixed. Scalar Patch expands removal to every represented qualified key, then verifies the complete native comment/lyric collection as well as raw/scalar expectations. Raw patches retain individual-key semantics. | `CleanRoomID3Tests.qualifiedCommentAndLyricScalarPatchesOwnCompleteCollections` checks multi-entry described/language-qualified replacement/removal on MP3, AAC, WAV, AIFF, TTA, DSF, DFF, with an independent ID3 parser and unchanged title. | `57183f5`, `95b4933` | This is scalar field ownership, not an individual-language edit API. WAV INFO remains a separate preserved surface; contradictory fallback states cause verification failure rather than partial deletion success. |
| AUD-03 | Valid: creating sparse ID3v2 while saving only that surface hid legacy fields from preferred-tag readers. | Fixed. Promote the visible legacy map before first ID3v2 creation; reject unrepresentable promotion. Preserve secondary on-disk tags. Applied to MPEG and the related TrueAudio path. | `CleanRoomMPEGTests.firstID3v2PromotesLegacyFieldsWithoutChangingID3v1` covers MP3/MP2/TTA through number text, low-level numbering, typed numbering, and advisory; independent TIT2/TPE1/TALB/TDRC/COMM checks, identical ID3v1 bytes, and identical audio remainder. | `52db36b`, `58b6583` | Promotion is limited to representable visible metadata; unsupported promotion throws. Mixed TrueAudio APEv2 fields now reject separately. |
| AUD-04 | Valid: duplicated format dispatch let several primary ID3 formats fall through to separate generic totals. | Fixed. A shared primary-ID3 selector and native pair helper emit combined TRCK/TPOS/MVIN; stale total TXXX aliases are removed. Basic, Patch, exact text, and low-level paths use the correct native surface. Partial track/disc validation includes all primary ID3 families. | `CleanRoomID3Tests.nativeNumberPairsAcrossID3ContainersAndPublicWriters`: 7 formats × 5 public writer routes, independent frames, movement pairs, unrelated custom preservation, and byte-identical rejection of unsupported partial removal. | `57183f5` | Numeric writers may normalize padding; exact ID3 text writes preserve both components. Generic/Xiph formats intentionally store separate components. |
| AUD-05 | Valid: cleanup flags exceeded both an unrelated Basic edit and a track-only low-level request. | Fixed. Basic compares native pairs before cleanup; track-only uses track=true/disc=false. | `CleanRoomMP4Tests.unrelatedBasicAndTrackOnlyWritesPreserveNumberAliases` seeds all eight recognized aliases and native pairs; compares independent atoms and encoded audio. | `be15af7` | Changing a corresponding number pair intentionally canonicalizes its recognized aliases. |
| AUD-06 | Valid: default MPEG save duplicated/rewrote other tag surfaces, provoking preservation failures or empty secondary tags. | Fixed. Native number/advisory deltas use the preserving MPEG save policy. | `CleanRoomMPEGTests.mixedTagDeltaPreservesSecondaryBytesAndDoesNotCreateEmptyTags`; mixed tags, distinct modern/legacy title, exact ID3v1 bytes, no new TAG tail, and both patch routes. | `52db36b` | No cross-process write lock is introduced. |
| AUD-07 | Valid: AAC was read through ID3v2 while its capability and writer selected a generic path. | Fixed. AAC declares native ID3v2 container support and uses the MPEG Basic/structured writer, enabling existing native collection replay. | AAC language/description preservation compares independent COMM/USLT payload bytes before/after a title edit; AAC participates in all number/comment/lyric tests. | `57183f5` | AAC metadata here is TagLib's MPEG/ID3 handling, not a promise about arbitrary AAC container variants. |
| AUD-08 | Valid API-contract defect: one native date had two inconsistent writable projections and an unrelated error. | Fixed/bounded. `updateBasicMetadata` resolves one-field intent: release date derives year; year replaces the date prefix; clearing either alone clears the shared value. Full replacement enforces consistency with `MetadataValidationError.conflictingMP4Date`. | `CleanRoomContractTests` exercises release-only, year-only, clearing, consistent updates, contradictory replacement, and byte-identical rejection. The existing date contract test now asserts the precise error for its actual empty-release payload. | `4d20e1d`, `cf90d4e` | Full replacements must provide consistent projections. Typed recording-date `.date` remains unsupported on MP4; use `.releaseDate`. |
| AUD-09 | Valid: native key uppercasing could silently ignore requests when verification was disabled. | Fixed by explicit namespace validation, rather than extending PropertyMap into a second native-atom API. Swift raw overloads and low-level raw writers reject `----:` keys, including uppercase-prefix variants and verification-disabled calls, with directions to structured atoms. | Both raw string/array overloads, merge/replace, verification on/off, raw removal, low-level raw write, exact error, unchanged bytes, and successful structured alternative are tested. | `4d20e1d` | Native keys are intentionally unsupported by Raw; use prefixless TagLib PropertyMap names or structured native atoms. |
| AUD-10 | Valid: clearing the visible map could not remove unexposed ASF attributes. | Fixed. Native ASF erase clears the whole attribute map and verifies that no attributes remain after saving, in addition to normal residual checks. | `CleanRoomASFTests` seeds string/binary/numeric attributes and a picture, then independently verifies an empty ASF attribute set and identical packet tail. | `978cbc7` | Erase is not a forensic scrub of every unknown container byte. |
| AUD-11 | Valid: one freeform atom had two Basic identities and replay could create a case duplicate. | Fixed. Basic custom keys have one uppercase identity; native updates retain existing spelling and collapse edited case aliases. Targeted PropertyMap replay restores untouched native freeforms. A directly related ASF common-field alias defect was also repaired. | `CleanRoomMP4Tests.customCaseProjectionHasOneIdentityAndPreservesNativeSpelling`, no uppercase duplicate atom; independent ASF alias/sibling tests and final ffprobe title checks. | `be15af7`, `58b6583`, `3b1d711` | Structured native keys remain case-sensitive. Pre-existing unrelated private collisions are not globally rewritten. |
| AUD-12 | Valid documentation defect; a single MP4-wide separator was inaccurate. | Fixed documentation. ID3 generally uses comma-space; MP4 artist/genre and generic/Xiph use semicolon-space; some native MP4/freeform fields use comma-space. | `CleanRoomLimitationTests.multiValueDisplaySeparatorsFollowTheActualProjection` checks MP3/M4A/FLAC display plus authoritative arrays. README, SUPPORT, and model comments agree. | `897d267` | Display strings are not an array serialization format. |
| AUD-13 | Valid omission. ASF's sample width is a declared container property even when the codec is lossy. | Fixed. Ogg FLAC, APE, WavPack, and ASF project available bitsPerSample. | `CleanRoomAudioPropertiesTests`: 16-bit APE/Ogg FLAC/WavPack independently confirmed by ffprobe; ASF WAVEFORMATEX width parsed independently. | `cb4318a` | Zero still means unavailable. Sample width does not imply lossless compression. |
| AUD-14 | Valid verification gap in Basic writes. | Fixed. Basic supplies exact expected artwork bytes and normalized MIME. Optional context properties add precise checks without changing the existing initializer signature or legacy `.present` meaning. | `CleanRoomArtworkTests`: correct expectations pass; swapped same-length bytes and wrong MIME abort public writes and preserve whole-file bytes on MP3/M4A/FLAC. | `d1d0405` | Explicit low-level `.present` remains presence-only for compatibility; callers can request exact checks. |
| AUD-15 | Valid display/formatting limit, not loss of the numeric pair. Native ID3 total padding also needed repair. | Native exact ID3 text fixed by the unified writer; generic first-component display and normalized total padding explicitly documented and tested. | ID3 exact 03/12 and 01/02 native checks; generic FLAC/Ogg 03 and 01 displays with exact numeric totals/raw total keys. | `57183f5`, `897d267` | Generic numberText is a normalized display, not exact slash-text storage. |
| AUD-16 | Valid API gap; implicit empty-payload deletion was never safely defined. | Bounded. ASF attributes remain upserts and URL/UFID have no individual structured removal operation. Empty URL/UFID now reject even without readback verification; docs distinguish omitted/empty/set/remove. No ambiguous deletion API was added. | `CleanRoomLimitationTests.emptyURLAndUFIDRejectRatherThanPretendToRemove` seeds real records, checks both verification modes, and compares original bytes. | `897d267` | Individual structured deletion remains a future explicit API; full erase is available only when deleting everything is intended. |
| AUD-17 | Valid native preservation risk, although whole-map replacement intentionally owns the preferred map. | Fixed secondary overwrite. Raw MPEG replacements save ID3v2 with StripNone/DoNotDuplicate instead of rewriting ID3v1; replacement ownership is documented. | Both raw overloads on MP3/MP2 retain exact ID3v1 tails and encoded remainder while persisting the replacement title. | `b7d6cbc` | Omitted preferred-map values may intentionally disappear or be shadowed. Whole replacement is not a native archive; use deltas for preservation. |
| AUD-18 | Source-level clone caveat is valid; original report did not reproduce it. | Addressed with an explicit safe boundary: both transaction engines reject setuid/setgid files before staging, avoiding silent privilege-bit loss or restoration. Ordinary copy/ACL/xattr/flush behavior is retained. | `CleanRoomPrivilegeTests` checks all three bit combinations, both engines, unchanged inode/mode/data. Final Xcode and unsandboxed SwiftPM runs pass. | `b09438a` | Clear privilege bits explicitly before editing. The agent sandbox strips them during setup, so this test requires a host that can retain them. |
| AUD-19 | Valid evidence gap, not evidence that every source-only format is broken. | Partly closed and accurately bounded. A generated AIFF fixture now exercises native number, scalar comment/lyric, and Basic paths. Remaining source-only/experimental/read-only evidence is explicitly labeled. No invented support claim or unnecessary dependency/fixture expansion. | New AIFF fixture and the cross-ID3 tests execute in Debug/Release/sanitizers. Five platform builds verify compilation only. | `57183f5`, `897d267`, `6ac6f42` | Speex, S3M, IT, Shorten, MOD, uncommon aliases, and device/minimum-OS runtime remain unverified. AIFF's configured upstream label was conservatively retained. |
| AUD-20 | Confirmed design observation, not a write defect. | Documentation clarified: successful warnings are non-fatal advisories; mismatches/residuals throw; empty warnings do not expand low-level verification scope. | Documentation checked against `throwOnVerificationFailures`, public verifier tests, failure rollback tests, and complete suites. | `897d267`, `6ac6f42` | A low-level call with no requested facade expectations does not gain semantic verification from an empty array. |

## C. Engineering Changes and Decisions

### C.1 Shared native ID3 dispatch and legacy surfaces

The defect was not that separate generic totals are inherently wrong; they are correct for Xiph and several PropertyMap families. The failure was selecting that representation for primary ID3 containers. `NativeID3v2TagForWrite`, `SetNativeID3NumberPair`, and the preserving save helper now separate primary native ID3 behavior from generic storage without replacing the transaction architecture. FLAC's optional legacy ID3 surface is deliberately excluded because Xiph owns its metadata writes.

Creation of the first preferred MPEG/TrueAudio ID3v2 tag copies the visible legacy properties first. Existing ID3v2 tags are not globally merged with secondary tags, which would reintroduce old values or lossy duplication. MPEG saves explicitly retain secondary bytes. Unrepresentable promotion fails safely. Independent tests examine preferred-tag frames rather than accepting the package reader's fallback merge as proof.

Scalar typed comments and lyrics own every represented qualified entry. A raw delta still addresses individual PropertyMap keys. The preservation verifier checks native collection content; a missing unqualified key alone cannot prove scalar removal. WAV typed writes retain the original ID3-focused INFO-preserving route. Native collection replay limitations on DSD remain fail-safe and are not silently generalized.

### C.2 MP4 native identity and verification

MP4 freeform descriptions are case-sensitive native identifiers and are not interchangeable with TagLib's PropertyMap canonical keys. Typed freeform patches therefore use the existing field schema's native mapping and explicit alias group; structured native atoms perform the write. Verification checks canonical native arrays, absence of competing recognized aliases, and semantic Basic text/removal. Basic and targeted replay preserve untouched native freeform arrays and spellings instead of rebuilding them from uppercased display/property projections.

Number alias canonicalization is scoped to an actual pair change. Low-level track-only writes never request disc cleanup. Basic custom-field identity is normalized for editing, while the native key spelling is retained when an existing item is updated.

Raw namespace validation was chosen over a new implicit translation layer. PropertyMap arrays and native atoms have different identity and ownership rules; structured atoms already provide the correct case-sensitive interface. All raw native-prefix requests now fail explicitly, including verification-disabled calls. Prefixless PropertyMap keys continue to work.

MP4 Basic update intent is derived from the captured original model: changing only releaseDate updates year; changing only year retains the date suffix; clearing either alone clears the shared ©day. Full replacement remains an explicit complete-model operation and rejects contradictory projections with a precise date-conflict error. No silent year-only no-op was substituted for the old rejection.

### C.3 Erasure, artwork, and audio-property projection

ASF erase removes native attributes, including values absent from the visible PropertyMap, and verifies the native result. Residuals are thrown failures, not successful partial-erasure warnings. The independent parser checks that packet data is unchanged.

Basic artwork writes now carry exact bytes and normalized MIME into verification. Existing low-level presence-only expectations and the public initializer signature remain compatible. Additional bit-depth extraction uses the pinned dependency's available APIs; ASF declared width is documented separately from codec losslessness.

### C.4 Related defects discovered during required independent verification

The final external harness was intentionally more demanding than a package-reader round trip. It found two related alias failures and one unsupported native layout:

- **CR-01, stale ASF aliases:** common fields can also exist as custom native attributes. Updating the standard title alone left an old custom `title` that ffprobe preferred. Common aliases are now classified semantically and cleared on an intentional common-field edit; unrelated attributes, including schema-looking PUBLISHER, remain preserved. Native tests cover both Basic and typed title edits, exact sibling attributes, and unchanged packet tail. Commit `3b1d711`.
- **CR-02, APE Date/Year replay:** TagLib normalized an unchanged native Date item to Year during PropertyMap replay. The complete date text survived, but unrelated native identity changed. Generic Basic, number, and delta writes now preserve original APE Date/Year items when their properties are unchanged. Independent APE item/audio tests cover the repaired sequence. Commit `3b1d711`.
- **CR-03, mixed TrueAudio APEv2/ID3:** the pinned handler writes ID3 but does not reconcile unmodeled APEv2 fields; FFmpeg could continue showing stale APEv2 title/number fields. These inputs now throw before commit across Basic, typed text/number, raw replacement without verification, structured writes without verification, low-level numbering, and erase. Seven attempted operations preserve original bytes. An encoder-only provenance footer is harmless to editable field identity and stays preserved. Commit `1fff9f0`.

The corpus generator now removes FFmpeg's APEv2 TTA surface before seeding native ID3. This is not removal of a failing assertion: the unsupported mixed layout has its own explicit rejection regression, while the corpus continues testing successful supported writes. The independent eight-format experiment was repeated successfully after these repairs.

### C.5 Compatibility and transaction safety

No existing public product or writer overload was removed. The artwork context gains optional properties with defaults; its prior initializer remains intact. `RawMetadataPatchError` gains a native-key case and Equatable conformance; `MetadataValidationError` gains an explicit MP4 date-conflict case. Applications with exhaustive error switches may need a new case. AAC capabilities become more accurate and expose native structured editing.

Intentional behavioral changes are safe rejection of raw native-prefix keys, empty structured URL/UFID payloads, privilege-bearing files, and unmodeled TrueAudio APEv2 metadata. MP4 full replacement still requires a consistent model, while single-field Basic updates are now usable. Generic number display normalization is documented rather than hidden behind an exact-text promise.

Same-entry coordination, the process-wide native mutex, expected-version checks, hard-link/symlink rejection, sibling staging, rollback, final identity checks, atomic rename, staged-file synchronization, parent-directory synchronization, and committed-but-durability-uncertain reporting remain in place. Privilege-file rejection occurs before staging in both engines. No merge, cross-process locking feature, dependency upgrade, or Audio Payload Identity product work was added.

## D. Testing and Verification

### D.1 Final environment and tested revision

| Item | Actual value |
| --- | --- |
| Host | macOS 27.0.1, build 26A434, arm64 |
| Xcode | 27.1, build 27A9275 |
| Swift | Apple Swift 6.4, swiftlang-6.4.0.34.1, clang-2100.3.34.1 |
| SDKs | macOS 27.0; iPhoneOS/iPhoneSimulator 27.1 |
| FFmpeg/ffprobe | 9.0.2 |
| Final implementation revision | `1fff9f04316842303ecf6e4d49e05ab87ebc3c65` |
| Subsequent changes | Authoritative documentation and this report only |
| Dependency | Existing checksum-pinned TagLib 2.3.1-r2 binary; Package.swift unchanged |

### D.2 Committed regression coverage

| Test suite added | New functions | Main evidence |
| --- | --- | --- |
| CleanRoomMPEGTests | 3 | Legacy-only preferred-tag promotion; mixed tags; raw replacement; exact ID3v1/audio bytes |
| CleanRoomID3Tests | 3 | 35 format/writer number combinations; qualified scalar fields; native AAC replay |
| CleanRoomMP4Tests | 4 | Six fields × two seed routes; stale aliases; number aliases; case identity; independent atom/mdat parser |
| CleanRoomContractTests | 2 | MP4 single-field dates, contradictory full replacement, raw/native namespace rejection |
| CleanRoomASFTests | 1 | Complete native attribute/picture erase and packet-tail equality |
| CleanRoomArtworkTests | 1 | Exact bytes/MIME and whole-file rollback with deliberately wrong expectations |
| CleanRoomAudioPropertiesTests | 1 | Four additional bit-depth projections with independent source checks |
| CleanRoomPrivilegeTests | 1 | Both transaction engines, all three privilege-bit combinations, unchanged inode/mode/data |
| CleanRoomLimitationTests | 3 | Empty URL/UFID rejection; generic exact numeric pair/display; actual separators/arrays |
| CleanRoomNativeAliasTests | 2 | Stale ASF alias cleanup with sibling preservation; native APE Date identity/audio |
| CleanRoomTrueAudioSurfaceTests | 1 | Seven public mutation routes reject unmodeled APEv2 and preserve original bytes |
| **Total** | **22** | **208 tests overall: 153 XCTest + 55 Swift Testing** |

The existing MP4 date test's error assertion was updated because its payload actually has year=2021 and an empty releaseDate. Its byte-identical rejection assertion was retained. Tests were not weakened or disabled to accept implementation mismatches. Temporary failures during development are disclosed below; the final complete suites were rerun after the last native changes.

The new `Audio/clean-room.aiff` is generated stereo silent PCM: 4,410 frames, 44,100 Hz, 16-bit, COMM and SSND chunks. Its provenance is recorded in Audio/README.md. Existing destructive-operation tests use disposable copies; tracked fixtures were not mutated.

### D.3 Executed final checks

| Check | Result | Counts / limits |
| --- | --- | --- |
| Xcode BuildProject(buildForTesting=true) | PASS | Final production/test build, no build errors |
| Xcode RunAllTests | PASS | 208 total, 206 passed, 2 skipped, 0 failed, 0 expected failures, 0 not run |
| Native SwiftPM full Debug with corpus and benchmark enabled | PASS | 153 XCTest passed + 55 Swift Testing passed; 208 passed, 0 failed, 0 skipped |
| Native SwiftPM full Release | PASS | 153 XCTest with 2 skips, 0 failures + 55 Swift Testing passed; 206 passed, 2 skipped |
| Full Address Sanitizer | PASS | Same 208 discovered / 206 passed / 2 default skips; no AddressSanitizer finding |
| Full Thread Sanitizer | PASS | Same 208 discovered / 206 passed / 2 default skips; no ThreadSanitizer finding |
| Strict macOS 13 arm64 build | PASS | `-warnings-as-errors` and `-Werror`; compile/link, not minimum-OS runtime |
| Strict macOS 13 x86_64 build | PASS | Same strict flags; runtime on x86_64 not exercised |
| Strict iOS 16 arm64 build | PASS | Device slice compiled with installed SDK; no device execution/signing claim |
| Strict iOS 16 Simulator arm64 build | PASS | Simulator slice compiled; no simulator runtime claim |
| Strict iOS 16 Simulator x86_64 build | PASS | Simulator slice compiled; no simulator runtime claim |
| Public facade-only consumer | PASS | Compiled and executed; 37 readable extensions |
| Public low-level consumer | PASS | Compiled and executed |
| Legacy/public function-reference tests | PASS | Included in complete Debug/Release/sanitizer suites |
| Generated external preservation corpus | PASS | Eight generated formats; positive requested track/total and unchanged unrelated visible properties |
| Opt-in benchmark | PASS | Executed in final full Debug; no gating threshold or performance improvement claim |
| Separate public-API + ffprobe/packet experiment | PASS | Eight files; requested titles/numbers and MP4 freeforms; unchanged unrelated tags, codec config, and encoded packets |
| Historical audit and previous history checks | PASS | Audit blob unchanged; audited revision is ancestor; no new merge commits; main ID unchanged |

The two default skips are ExternalCorpusPreservationTests and SnapshotThroughputBenchmarkTests. They were not left unverified: both executed in the final Debug run. The generated corpus is reproducible synthetic audio, not a supplied real-world music library; its diversity is limited accordingly.

Strict warning checks compile production targets. Compatibility tests intentionally reference deprecated APIs and emit deprecation warnings during ordinary test builds; those warnings were not suppressed by changing source-compatibility tests. SwiftPM's native-backend deprecation notice is a toolchain notice, not a package compiler warning. Xcode's default build/test route also passed.

### D.4 Commands and artifacts

The native backend provided independent SwiftPM verification alongside Xcode. Module caches were directed to a writable temporary directory. Privilege-bit tests ran outside the agent filesystem sandbox because that sandbox silently strips the setup bits even when chmod reports success.

```sh
export CLANG_MODULE_CACHE_PATH=/tmp/clean-room-module-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/tmp/clean-room-module-cache

# Final Debug, including both opt-ins:
TAGLIB_PRESERVATION_CORPUS=/tmp/taglib-clean-room-corpus TAGLIB_BENCHMARK=1 \
  swift test --disable-sandbox --build-system native --scratch-path /tmp/taglib-clean-room-native

swift test --disable-sandbox --build-system native --scratch-path /tmp/taglib-clean-room-native -c release
swift test --disable-sandbox --build-system native --scratch-path /tmp/taglib-clean-room-asan --sanitize=address
swift test --disable-sandbox --build-system native --scratch-path /tmp/taglib-clean-room-tsan --sanitize=thread

# Run for each triple/SDK pair in the table above:
swift build --disable-sandbox --build-system native --scratch-path /tmp/taglib-clean-room-platform \
  --triple "$TRIPLE" --sdk "$(xcrun --sdk "$SDK" --show-sdk-path)" \
  -Xswiftc -warnings-as-errors -Xcc -Werror

swift run --disable-sandbox --build-system native --package-path IntegrationTests/Consumer \
  --scratch-path /tmp/taglib-clean-room-consumer TagLibAudioMetadataConsumer
swift run --disable-sandbox --build-system native --package-path IntegrationTests/Consumer \
  --scratch-path /tmp/taglib-clean-room-consumer TagLibAudioMetadataLowLevelConsumer

# Supply a NEW output directory:
python3 scripts/make-preservation-corpus.py /tmp/taglib-clean-room-corpus
```

Host-local logs: `/tmp/clean-room-final-debug.log`, `clean-room-final-release.log`, `clean-room-final-asan.log`, `clean-room-final-tsan.log`, `clean-room-platform-results.log`, `clean-room-platform-<variant>.log`, `clean-room-consumer.log`, and `clean-room-independent-verification.log`. All unqualified names in that list are under `/tmp`. Scratch build roots are those shown above. These are temporary host artifacts; the durable findings, counts, independent packet hashes, and commands are recorded here rather than relying on their continued availability.

Final Xcode build log: `/var/folders/gx/w1cq6f8j41sdgkfp0c5ndb_m0000gn/T/ActionArtifacts/E11C8663-4767-41EA-A367-26E1537F907D/BuildProject/BuildProject-Log-20261019-085452.txt`.

Final Xcode test summary: `/var/folders/gx/w1cq6f8j41sdgkfp0c5ndb_m0000gn/T/ActionArtifacts/E11C8663-4767-41EA-A367-26E1537F907D/RunAllTests/A84BE546-B7D0-4B90-9620-34E475D08F0E.txt`. Result bundle: the same directory's `Test-TagLibAudioMetadata-Package-2026.10.19_08-54-59-+0800.xcresult`.

### D.5 Independent metadata and packet evidence

A separate temporary SwiftPM executable imported only the public package, copied each generated input, applied track=7/12 and disc=2/3 with MetadataPatch, and changed only the Basic title to `Independent clean-room edit`. For M4A it additionally seeded old WORK/Acoustid Id atoms through the public structured API and patched them to NEW-WORK/NEW-ID. The harness asserted the public scalar results, but those assertions were not the independent oracle.

The external oracle ran ffprobe for format **and stream** tags, codec/sample-rate/channel/extradata properties, and used FFmpeg copy-demux output for exact encoded-packet SHA-256 comparison. Unrelated tag names were compared case-insensitively while retaining values. Native ID3/MP4/ASF/APE regression parsers separately inspect the alias identities and duplicates that a flattened external tag dictionary can hide.

Representative oracle commands, applied to both the original and disposable output, were:

```sh
ffprobe -v error -show_entries format_tags:stream_tags:stream=codec_name,sample_rate,channels,extradata -show_data -of json "$FILE"
ffmpeg -v error -i "$FILE" -map 0:a:0 -c copy -f data - | shasum -a 256
```

| Generated file | Requested metadata | Codec config equal | Unrelated tags / packets equal | Encoded-packet SHA-256 after edit (same as before) |
| --- | --- | --- | --- | --- |
| tone.flac | PASS | PASS | PASS | `436273a4d3af9b0bf8c74e66f01db8a9b44fc30a3fcbd0c6f84dd40946e70827` |
| tone.m4a | PASS | PASS | PASS | `89dc9d3ce2157c097847881b39ccad0afde311da2213169e8d78a8d58a911bd5` |
| tone.mp3 | PASS | PASS | PASS | `1e28000a912c7e78a18513b3296c48a6563df00c2b2d68f55426c47adb94bc0c` |
| tone.ogg | PASS | PASS | PASS | `cce4961ae6f2e3f458050cc8b6af6ab14373715814de4fa09a3160f0f6c42992` |
| tone.opus | PASS | PASS | PASS | `f8702312c5e9e67e9e0a7d222ef802db5c3678527f3f0b188e1edb80b3c71425` |
| tone.tta | PASS | PASS | PASS | `7b36f41170835cb574ffac691b972fe3815e9fdd53db91cdd71ce06a3cdc1916` |
| tone.wma | PASS | PASS | PASS | `a794c12f3860e1277599694d7151aa14a38a836c4562b5ef75c3b061afd78916` |
| tone.wv | PASS | PASS | PASS | `bdcebcdb7935c9e12b071ee27211223342224b93cd95452559049a4d6d1c3dfa` |

All requested titles were independently visible. Native combined or separate track/disc values reflected 7/12 and 2/3 according to the format. M4A ffprobe exposed exactly `Acoustid Id=NEW-ID` and `WORK=NEW-WORK`, without the old seeded values. This is verification evidence for the tested mutations, not a new public audio identity feature or an exhaustive decoder audit.

### D.6 Development failures and corrections

Intermediate broad tests caught two introduced regressions: a typed WAV route rebuilt INFO, and a generic semantic removal check treated compilation's boolean projection as empty text. Commit `95b4933` restored the INFO-focused path and limited semantic text checks appropriately; the independent INFO tests and boolean-removal test then passed. The old MP4 date test initially expected the new error with the wrong releaseDate payload; `cf90d4e` corrects that assertion without changing its rollback requirement.

The initial separate external experiment failed because the oracle initially looked only for format-level Ogg tags, and also exposed genuine stale ASF aliases, native APE date migration, and unsupported mixed-surface TTA behavior. The Ogg oracle was corrected to inspect stream tags; production defects were repaired in `3b1d711` and `1fff9f0`, with new regressions. The complete final checks and independent experiment were repeated after those changes. No final check failure remains outstanding.

The agent-sandbox privilege setup failed to retain setuid/setgid; a simple independent chmod/stat probe confirmed this host restriction. The test was rerun successfully outside that sandbox, including in final Xcode and native suites. This was not converted into a passing assertion or ignored skip.

### D.7 Verification limits

Sanitizers instrument package Swift/Objective-C++ code, not the precompiled TagLib binary. Minimum deployment targets were compiled with current SDKs; older macOS/iOS versions, iOS devices/simulator execution, and x86_64 execution were not tested. No real-world user music corpus was supplied. Hardware power-loss behavior, hostile concurrent external writers, and all possible native metadata variants were not simulated. Source-only format claims remain source-only. No tests or assertions were suppressed to claim broader evidence.

## E. Documentation Changes and Migration Guidance

Updated authoritative documentation is README.md, docs/SUPPORT.md, docs/ARCHITECTURE.md, docs/THREAD_SAFETY.md, CHANGELOG.md, MAINTENANCE_PROGRESS.md, model comments, and fixture provenance. Historical dated reports and the independent audit are unchanged.

Callers should use structured MP4 atoms for `----:` keys, `updateBasicMetadata` for single-field MP4 year/releaseDate edits, and consistent projections for complete Basic replacements. Handle the new date/native-key errors; do not retry a rejected unsupported layout blindly. Reconcile mixed TrueAudio APEv2 metadata with an appropriate external tool before editing, and clear privilege bits explicitly if editing such an audio file is intended.

Typed scalar comment/lyric replacement now intentionally removes older qualified entries; use structured collections when editing language/description-specific records. Pair changes may canonicalize recognized number aliases. Exact ID3 text preserves padding; generic display remains normalized. Use raw arrays or structured records as authoritative values rather than splitting Basic display strings.

Successful warnings are advisories. Residual erasure or requested-value mismatch is an exception and leaves the original destination unchanged. A committed-but-durability-uncertain result still means the rename occurred and should not be treated as a safe retry. Existing contracts for that state remain intact.

## F. Remaining Issues, Classified

| Classification | Remaining item | Technical justification / action |
| --- | --- | --- |
| Merge blockers | None identified | All confirmed silent-loss, stale-semantic-success, and unintended-alias defects found in this remediation were repaired or converted into explicit safe failure for unsupported native input. |
| Non-blocking defects | None knowingly left from the reported confirmed integrity defects | API gaps and evidence gaps below are not described as successful unsupported mutations. A new reproducible counterexample should still be treated as a defect. |
| Intentional limitation | Raw native MP4 identifiers are unsupported | Separate native identity cannot safely use global PropertyMap normalization; structured atoms are the supported alternative. Rejection is tested with verification both on and off. |
| Intentional limitation | Generic number-text slash/total padding is normalized | Separate numeric keys preserve the semantic pair; exact native display is not promised. Tests assert both components and actual display. |
| Intentional limitation | No individual structured ASF attribute / ID3 URL / UFID removal | An explicit removal model is still needed; empty URL/UFID rejects rather than no-ops. ASF upsert omission/empty-string semantics are documented. |
| Intentional limitation | Privilege-bearing files reject | Avoids copy/clone privilege-bit changes and avoids implicitly restoring privilege on altered contents. Explicit caller action is required. |
| External dependency constraint | Mixed TrueAudio APEv2 fields reject | The pinned TTA handler cannot reconcile the secondary surface. Encoder-only provenance is retained, other unmodeled APEv2 fields fail atomically. An upstream adapter or dedicated reconciliation tool is future work. |
| External dependency constraint | Precompiled TagLib has no sanitizer instrumentation; dynamic C++ interposition remains unsupported | Package sanitizer success cannot establish safety inside the dependency. No dependency upgrade was necessary for the repairs. |
| Unverified risk | Source-only/experimental families and uncommon aliases | Speex, S3M, IT, Shorten, MOD and less-common aliases lack runtime fixtures here; configured evidence labels remain bounded. |
| Unverified risk | Minimum-OS/device/simulator/x86 runtime | All relevant slices compile strictly; runtime evidence is the current arm64 macOS host only. |
| Unverified risk | Third-party corpus diversity, malformed resource exhaustion, external writer races, hardware durability | Generated corpus and existing representative fixtures are finite; existing documented parser/filesystem limits remain. No cross-process lock or forensic-erasure promise is added. |
| Optional future improvement | Explicit native removal APIs; additional format fixtures; broader schema single-sourcing | Useful follow-ups, not prerequisites for the documented repaired contracts. Avoid introducing implicit deletion or a speculative architecture rewrite in this remediation. |

## G. Git Summary

| Item | Recorded state |
| --- | --- |
| Starting branch | `review/verification-hardening` |
| Starting audited revision | `615bc8c928a57fc221dace14849455031d4d73ba` |
| Initial working tree | Only `docs/CLEAN_ROOM_AUDIT_2026-10-19.md` was untracked; no pre-existing unrelated tracked changes |
| Working branch | `fix/clean-room-audit-remediation` |
| Audit preservation commit | `7039631`; unchanged audit Git blob `b8a80c36e8b33b4897640974a15ef4f06d355d92` |
| Final tested implementation HEAD | `1fff9f04316842303ecf6e4d49e05ab87ebc3c65` |
| Final pre-report documentation HEAD | `6ac6f428d9e513d949de1896f6b9122a97eb4831` |
| Final handover HEAD | The commit containing this report; resolve with the command below (a Git commit cannot embed its own object ID without changing that ID) |
| Working-tree status at handover | Clean after the final report commit; no pre-existing unrelated changes remain |
| Main before and after | `03473c9ae199026b806a5f75c387ca036e325284` |
| History preservation | Audited revision remains an ancestor; existing history was not amended, squashed, reset, rebased, or rewritten |
| Merge status | No merge performed; no merge commits introduced after the audited revision |

Completed coherent work was committed throughout the assignment, not accumulated until completion. The focused commits before this final report are:

| Commit | Message |
| --- | --- |
| `7039631` | Preserve independent clean-room audit for remediation |
| `52db36b` | Preserve legacy MPEG metadata when creating and saving ID3v2 deltas |
| `57183f5` | Unify native ID3 number pairs and qualified scalar patch semantics |
| `be15af7` | Align MP4 semantic patches with native freeform identity and preservation |
| `95b4933` | Retain WAV INFO and typed boolean semantics during patch verification |
| `4d20e1d` | Define safe MP4 date updates and reject native keys in raw PropertyMaps |
| `cf90d4e` | Assert the precise empty-release MP4 date conflict in legacy coverage |
| `978cbc7` | Erase complete native ASF attribute maps with independent packet checks |
| `d1d0405` | Verify Basic artwork bytes and MIME with rollback regression coverage |
| `cb4318a` | Project available bit depth for Ogg FLAC APE WavPack and ASF |
| `b7d6cbc` | Preserve MPEG secondary tags during raw whole-map replacement |
| `b09438a` | Reject privileged files before transactional clone or copy staging |
| `897d267` | Specify display and structured removal limits and reject empty native payloads |
| `58b6583` | Extend legacy promotion to TrueAudio and prevent MP4 replay aliases |
| `3b1d711` | Remove stale ASF common aliases and retain unchanged native APE dates |
| `1fff9f0` | Reject unreconciled TrueAudio APEv2 surfaces before committing writes |
| `6ac6f42` | Document clean-room contracts limitations and completed verification |

This report is committed separately with message `Record complete clean-room remediation evidence and merge assessment`. To obtain the exact final report/HEAD object ID from the repository without a self-referential hash:

```sh
git log -1 --format='%H %s' -- docs/CLEAN_ROOM_REMEDIATION_2026-10-19.md
git rev-parse HEAD
git status --porcelain
git rev-parse main
git merge-base --is-ancestor 615bc8c928a57fc221dace14849455031d4d73ba HEAD
git rev-list --merges 615bc8c928a57fc221dace14849455031d4d73ba..HEAD
git hash-object docs/CLEAN_ROOM_AUDIT_2026-10-19.md
```

The final two commands respectively produce no merge IDs and the audit blob recorded above. Main was never checked out or modified during this work. No merge into main or any other branch was performed.

## H. Final Merge Assessment

**READY WITH CAVEATS**

**MERGE RECOMMENDATION: YES**

**Remaining merge blockers: none identified.** The confirmed reported integrity defects and directly related counterexamples are repaired with native regression coverage and final comprehensive verification. Unsupported native surfaces fail without committing, and the retained limits are explicit. The recommendation is based on actual supported-contract evidence, not a claim of every format, native variant, platform runtime, third-party parser, or filesystem condition being exhaustively verified.
