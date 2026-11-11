# Mapping test acceptance

Mapping conformance requires executable field-operation evidence. Registry membership, documentation agreement and a successful aggregate test count do not establish independent persistence.

## Required layers

1. `MappingContractCoverageTests` checks registry structure, aliases and capabilities. These tests remain useful but are not codec conformance evidence.
2. `SemanticLifecycleMatrixTests` freezes literal expected field/native identities outside the runtime registry. Its inventory accounts for all 101 public field keys: 86 independently specified MP4 fields plus 15 explicit specialized/API/read-only/unsupported decisions. New enum keys without a decision fail the inventory assertion. Existing schemas must not regenerate these expectations automatically to make failures pass.
3. Every field × operation is a separate parameterized case with its own temporary fixture. The 86 MP4 fields produce 258 set/replace/remove cases; native structured setup makes Replace/Remove independent of a broken semantic Set. Another 86 cases reject incorrect value kinds while checking that a valid companion field cannot partially commit. `IndependentMP4Probe` reads ISO BMFF bytes directly, including qualified freeform mean/name identities and numeric payloads; it does not use TagLib or the bridge to verify the destination. Every non-target ilst item payload and every mdat payload must remain byte-identical. Unknown multi-value metadata is also seeded and preserved.
4. The existing Content Group regression independently seeds native sibling arrays and covers all three owners with siblings absent/present. Dates, shared number pairs, comments, artwork, raw/structured operations and native collection semantics retain their specialized suites.
5. Unsupported/read-only/role-qualified MP4 typed writes must throw a validation error before any byte change. Other transaction, stale-version, privilege, raw-array, same-file concurrency and audio-content tests remain required.

Literal native expectations were initially transcribed from the mapping contract's documented targets. The document tables are generated from production, so this is not an external certification of their correctness. The behavioral and byte-level assertions add independence from the production encoder/decoder; future mapping changes require explicit review of the test contract. The MP4 atom reader is a deliberately limited test oracle, not a general media parser.

## Cross-format native matrices

`FLACSemanticLifecycleTests` covers 30 fields × three independent operations. `IndependentFLACProbe` reads native Vorbis Comment entries directly, retaining duplicate values and whitespace, and compares all non-target comments, non-padding metadata-block payloads and complete audio bytes. Vendor text and padding are not treated as immutable audio evidence.

`ID3SemanticLifecycleTests` covers 22 fields × three operations on MP3 with explicitly seeded ID3v2.4. `IndependentID3Probe` preserves qualified TXXX identities, exact non-target frames and the entire bytes after the tag. It intentionally rejects other tag versions, compression/unsynchronization and unsupported text encodings; those are coverage limits rather than guessed interpretations.

`NativeProbeContractTests` checks MP4 extended-size/zero-size atoms, malformed lengths and missing freeform identities, and the FLAC/ID3 readers against handcrafted known byte vectors, duplicate comments, truncated lengths and unsupported headers. `ReviewNativeContainerTests` now reuses the shared qualified MP4 parser instead of maintaining a second atom walker; its original native/audio preservation assertions remain active.

## Basic and additional-container matrices

`BasicIntegrityMatrixTests` exercises both Basic entry points independently: 14 ID3 date-array cases across MP3/AAC/WAV/AIFF/TTA/DSF/DSDIFF, six APE-family cases and two FLAC cases. Existing malformed values, duplicates and whitespace must survive an unrelated title edit. Four Ogg Basic cases additionally use independent packet/comment decoding. All cases use fresh fixtures.

`AdditionalContainerLifecycleTests` adds 30 fields × three operations for each APE/WavPack/Musepack fixture (270 cases) and Ogg Vorbis/Opus (180). Native APE Album Artist/Remixer expectations are `ALBUM ARTIST`/`MIXARTIST`, distinct from their Xiph and engine spellings. Independent item/comment readers compare non-target metadata and audio payloads.

`ID3ContainerLifecycleTests` adds 22 fields × three operations × six containers (396 cases): AAC, WAV, AIFF, TTA, DSF and DSDIFF. Its independent reader locates native ID3 tags using container lengths/chunks and compares exact frame payloads and audio bytes. `ASFNativeLifecycleTests` adds seven independent native attributes × three operations (21 cases), including both encoder owners, dates, Content Group and ARTISTS.

The MP4 pair matrix checks 32767/32768/65535 across semantic, Basic, structured and low-level writers (12 cases), validating both unsigned native pair components and Basic readback. A separate regression requires standalone Date and Content Group verification mismatches to be detected. `AuditProbeTests` retains all 24 original regressions/controls.

## Known limits

These are explicit field subsets, not the complete field × format × tag-version cross-product. The systematic lifecycle evidence is 86 MP4 fields, 30 FLAC fields, 30 APE/Xiph fields per tested container, 22 ID3v2.4 fields per tested container and seven ASF attributes. Raw whole-map replacement, all multi-value/domain-grammar combinations, uncommon variants and every native binary structure are not universally covered. Ogg packet probes do not certify CRC/stream synchronization or codec validity. ID3 frame probes intentionally reject unsupported flags/encodings. Generic textual samples test storage; they do not define UUID/ISRC/ReplayGain validation policy. Minimum-platform, sanitizer and device jobs are separate evidence.

## Mixed-framework gate

Use `bash scripts/validate-tests.sh debug` and `bash scripts/validate-tests.sh release`. No filter/skip arguments are accepted. Restricted local environments may explicitly set `TAGLIB_DISABLE_MANIFEST_SANDBOX=1`. Evidence is retained under ignored `.build/test-evidence`.

Both XCTest and Swift Testing must complete and pass. The only permitted skips are the two exact existing optional XCTest class/method identities. Missing framework summaries, any failed named test, unexpected skips, nonzero runner status and output-format changes fail acceptance. Named test evidence is mandatory for all 24 audit regressions/controls, all lifecycle matrices, Basic preservation, pair boundaries and native-probe vectors. Parameterized counts cannot shrink: 258 MP4, 90 FLAC, 66 MP3/ID3, 396 additional ID3-container, 270 APE, 180 Ogg, 21 ASF, 86 wrong-kind and five unavailable-field cases. Suite banners alone never establish execution.

Both configurations compile Swift/C tests and production with warnings as errors. The test target explicitly demotes only `DeprecatedDeclaration` diagnostics because source-compatibility tests must reference obsolete API; those warnings remain visible. Production has no exception. The gate policy has 22 Python regressions, including missing new matrices/oracles and audit functions, case-count shrinkage, exact skip identities and named failure detection. The unchanged privilege rejection test must run; an environment-precondition failure remains a red gate.

CI uses these same Debug/Release gates. No reproduced defect may be deleted, skipped, marked expected failure or hidden by changing a literal expected native identity to match a broken implementation.
