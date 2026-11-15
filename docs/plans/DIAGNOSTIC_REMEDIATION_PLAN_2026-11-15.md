# Public write-contract diagnostic: adjudication and remediation plan

Date: 2026-11-15 (Asia/Shanghai). Reviewed production baseline: `903fa69e66d892542bae277310baadf90c1e1b3e` (`main`, merge of PR 23). Mapping contract: `AM-TLAM-MAPPING-2.2`. This is an implementation plan, not evidence that its future repairs have already passed.

## 1. Decision and evidence boundary

The diagnostic identifies genuine gaps in public low-level write validation, model ownership, legal legacy-tag reading and capability projections. It also conflates some engine aliases, edited-field cleanup and declared-but-disabled registrations with defects. Do not implement its recommendations verbatim.

The assessor read the supplied REPORT.md, findings.json, coverage.csv and source-range-ledger.csv, checked every ledger hash against the current 45 implementation files (45 matches, zero mismatches), examined the implicated implementation, contracts and existing regression tests, and read the supplied probe logs. The merge has no tree diff from `ac0b9c9`. This assessment did not run new runtime probes or repeat the full suite. Reproductions below are attributed to the diagnostic unless explicitly described as existing committed tests.

A complete source-review ledger and OCR token consumption are not runtime coverage or proof that all write surfaces are safe. The diagnostic's red gate is a valid result for its restricted environment; it does not invalidate the earlier accepted host runs on the identical source. Conversely, those accepted runs do not refute the newly reproduced defects. New regressions must enter the canonical gate.

## 2. Finding-by-finding adjudication

| Diagnostic ID | Decision | Authorized treatment |
| --- | --- | --- |
| F-01 | Primarily an intentional edited-pair cleanup policy plus misleading comments. The reproduced TRACKTOTAL alias is an ordinary compatibility alias, not either private formatting namespace. Numeric total 12 is migrated before retirement; existing `mp4OrphanTotalIsWrittenIntoNativePairBeforeAliasRetirement` explicitly requires this. | Keep ordinary alias retirement for the explicitly edited track/disc group, after resolving/recovering its values. Preserve untouched groups and both private `*_TEXT` namespaces. Correct comments that imply all legacy atoms require normalization. Test all these boundaries; repair any demonstrated private-atom deletion, but do not preserve stale ordinary aliases globally. |
| F-02 | Documentation defect; Basic MP4-exclusive writes are intended. Basic now diffs through the typed planner. | Update README, WRITING, PRESERVATION verification tables/non-guarantees and other current guidance. Retain capability preflight and `.rate` read-only. Do not regress the implementation to satisfy old text. |
| F-03 | Contract ambiguity, not a confirmed date-validation failure. `isRepresentableYearText` is a Basic-specific prefix/representability filter, not a complete calendar grammar. | Document and freeze the current policy. Do not add stricter calendar parsing, derive Year from dates, convert fields, or rewrite existing malformed values. A future grammar change requires a separate explicit decision. |
| F-04 | Unverified defensive warning gap; no demonstrated reachable raw-only failure. Erase remains best effort. | Do not claim data loss or redesign erase. Optional small private warning-classification seam may report unavailable raw evidence; if implemented, test behavior deterministically. No source-string assertion masquerading as a runtime reproduction, no new public injection API. |
| F-05 | Real read-availability defect for legal v2.3 status bits, supported by diagnostic reproduction and source. Compression/encryption without a verified decoder is a separate intentional rejection. DSDIFF PROP/other offset variants are not reproduced. | Accept legal status bits without treating them as payload transforms. Implement grouping only with correct bounds/offset handling. Keep fail-closed behavior for undecodable payloads. Reproduce container-location variants before extending the locator; never scan arbitrary bytes for ID3 magic. |
| F-06 | Real public write-preservation defect. Whole-model replacement owns its representable scalar fields, not every schema-known field in existence. Diagnostic reproduced FLAC PERFORMER loss. | Preserve known-but-unmodeled owners and unknown owners; keep explicit replacement semantics for modeled fields. Cover both the facade low-level wrapper and exported bridge product. Do not merely relabel silent loss as full replacement. |
| F-07 | Real validation defects: committed pair truncation, ASF case/type coercion and discarded collections. Raw/low-level flexibility does not authorize false success. | Validate native encoding, bounds, payload types and collection/destination compatibility before mutation. Share normalized type dispatch with application. Invalid payloads must reject atomically; optional facade verification must not be the only protection. |
| F-08 | Real source-supported allocation hazard. A crash was not reproduced and must not be induced on the developer host. | Bound API-generated padding before any formatter/allocation; reject rather than clamp. Add safe boundary and subprocess/error-path coverage after the bound exists. |
| F-09 | Real alias-removal defect; mixed-case expected description is compared with an uppercased actual description. | Normalize comparison identities on both sides. Retire only recognized aliases of the explicitly edited owner, preserve unrelated TXXX/UFID owners, and verify the canonical MusicBrainz identifier natively. |
| F-10 | Real source-supported version-preservation hazard, not yet a reproduced committed public corruption. Current facade date guards can roll back conversion. | First build concrete v2.3 WAV/AIFF cases. Preserve the observed save version on every relevant path, or reject safely if the pinned engine cannot preserve it. Retain the direct-v2.3 write restriction and all facade date guards. |
| F-11 | Strong source-supported key-identity defect; requires a baseline reproduction. It concerns prefixless PropertyMap keys versus native inner descriptions. The cited in-place delta method is internal, not an exported public low-level method. | Test public RawMetadataPatch and public raw writers separately. Fix canonical-key/native-item matching on affected paths. Do not promise direct callers of internal-only APIs or add an exported bypass. Reject native `----:` keys in raw APIs as before. |
| F-12 | By design for these recognized aliases. `ExtractASFCustomAttributes` recognizes these names as semantic fallbacks; `CleanRoomNativeAliasTests.asfCommonFieldEditsRemoveStaleCustomAliasesAndPreserveOtherAttributes` deliberately requires removal on explicit owner edits. | Preserve this policy. Document it and expand independence tests if needed. Preserve unrelated attributes and unchanged owners; structured access does not make a registered alias an unrelated semantic field. Do not implement the report's blanket preservation recommendation. |
| F-13 | Real capability/planner disagreement for XM tracker name. An advertised supported operation must be reachable. | Prefer a narrowly allowlisted property-map-only XM route backed by native-byte evidence. Otherwise explicitly downgrade that field's capability/docs. Do not activate a generic fallback for ID3/MP4/ASF or all tracker fields. |
| F-14 | Mixed. Several metadata projections are defective; others are distinct namespaces or intentional capability gates. | Implement the sub-decisions below, not a blanket mapping rewrite. |
| F-15 | Real preflight gap, with successful rollback in the supplied reproduction. This is not committed numeric corruption. | Parse and resolve numberText under the captured version, validate destination bounds/total-only support before staging, and keep bridge checks too. Use typed validation errors rather than late readback mismatch. |

### F-14 sub-decisions

| Probe result | Interpretation and required action |
| --- | --- |
| `schema(forPropertyMapKey: "DATE") == .year` | Intentional engine alias at this API. Semantic DATE resolves through `canonicalSchema(forSemanticKey:)` to `.standaloneDate`; native DATE can be a different owner by family. Preserve these distinct namespaces. If native attribution needs an API, require family/context; do not globally remap engine DATE or merge Year and standalone Date. |
| Native MP4 `----:com.apple.iTunes:PRODUCER` unresolved by a PropertyMap-key lookup | Wrong lookup namespace, not proof of a missing native target. Do not make all raw-key APIs accept native atoms. Test/document the distinction; use explicit native targets for attribution. |
| XM `schemas(storableIn:)` empty despite writable descriptor fields | Real inconsistency, coupled to F-13. Make storable enumeration use the same destination-aware policy as executable writes; do not enable every generic PropertyMap spelling. |
| Role-qualified fields advertise scalar/array patch kinds although all such writes reject | Real API-contract mismatch. Withhold those high-level value kinds while the role codec remains unavailable. Preserve inspection/raw/native access; do not invent a role parser. |
| MP4 trackTotal/discTotal described as scalar atom/integer | Real target-description defect. Native storage is the second component of `trkn`/`disk` intPair; correct storage/shape and regenerate references without changing the on-disk target. |
| Aggregate capability returns native when only some destinations support native storage | Existing best-available summary, not a portability guarantee. The “lowest” comment is wrong. Document best-available semantics consistently in both implementations; destination-aware capability remains mandatory. Do not change it to the minimum over every family, which would make most fields unsupported. |
| `<explicit key>` lookup fails and `.custom.nativeTargets` is empty | Real normalization defect: dictionary construction preserves placeholder case but lookup uppercases it. Normalize construction and lookup consistently, including registry semantic lookup. Preserve the placeholder as a template, never a literal stored key. Assert every published semantic key round-trips and the custom template retains its registered targets. |
| `hasMappingFor(.tagLibPropertyMap)` false while mappings lists an engine projection | Registration versus native capability, not automatic write support. Clarify the helper semantics; do not use generic engine keys to bypass concrete format policy. |
| Matroska entries listed while capability/hasMapping is unsupported | Intended target-only registrations without a verified codec. Preserve unsupported writes and document registration versus availability. Never activate MKV writes to make two differently scoped queries return the same result. |

## 3. Non-negotiable design constraints

1. YEAR, standalone DATE, RELEASEDATE and ORIGINALDATE are independent text owners/intents. `YEAR=2004` and `RELEASEDATE=2017-06-09` are valid simultaneously. No synthesis, truncation, fallback filling or cross-field cleanup.
2. Concrete v2.3 independent date writes remain read-only. Legal readable status flags do not grant permission to rewrite read-only date frames. Unsupported compressed/encrypted layouts fail safely rather than falling back to synthesized TDRC.
3. Private `AUDIOMATOR_*_TEXT` and `TAGLIBAUDIOMETADATA_*_TEXT` identities survive ordinary writes and are never created/renamed. Only the captured-version explicit normalization plan may retire selected private identities. Ordinary aliases of a touched pair may retire after recovery; untouched groups remain untouched.
4. Canonical advisory states remain 0 = not explicit, 1 = explicit, 2 = clean, absent = unset. Preserve unknown raw codes on unrelated edits and keep absent distinct from zero/false.
5. Keep copy/verify/flush/identity-check/rename/directory-sync ordering, same-file coordination, symlink/hardlink/privilege checks, audio guards and durability reporting. No retry, raw fallback or clearing expectedVersion after failure.
6. The low-level product is a public contract. It may omit semantic verification, but must reject incompatible inputs and preserve owners outside its declared write set. Internal in-place APIs must remain internal.
7. This task is package-only. No sibling app, external source checkout or user-library access; never mutate original repository fixtures. Normal build-system artifact/cache use and reading the pinned binary's supplied public headers are allowed. Do not change binary URL/checksum, platforms/products, release version, signing, publication or dependency pins. Use neutral terminology; do not introduce external editor branding.

## 4. Implementation sequence and phase exit criteria

### Phase 0 — Branch, baseline and regression ledger

Create a new repair branch named `codex/public-write-contract-repairs-20261115` from the documentation handoff branch containing this plan. Never edit main, reset the checkout or rewrite history. If that name already exists, use a new suffixed branch unless it is clearly the authorized current repair branch. Preserve user changes; branch creation must succeed before implementation.

Record HEAD, tracked/untracked state, toolchain and production baseline. Read current mapping, preservation, transaction, architecture, testing and migration contracts. Reconcile their stale passages using the adjudications above. Read the public bridge header and actual product boundary. Do not follow the old historical mapping assignment as new instructions.

Do not replace implementation with another broad OCR/model-assisted diagnostic campaign. Use targeted source inspection and regressions. Create one tracked remediation record and a test ledger with: finding/subfinding, public entry point, format/version, exact seed, operation, oracle, baseline result, final result and limitation. Carry the dispositions for all 15 IDs. This plan is sufficient to start; external Downloads/temp artifacts are optional evidence, not required dependencies.

Exit: source identity recorded; no production edits yet; candidate regression list and expected correct behavior established. Run the baseline gate if feasible, but an environment precondition must not stop independent implementation work.

### Phase 1 — Public low-level validation (F-07, F-08, F-15)

Inspect `TLStructuredMutation.inc`, `TLBasicBridgeOperations.inc`, `TLRawBridgeOperations.inc`, `MetadataSnapshotPatch.swift` and their validators. Use small shared validators/plans where bridge entry points share representation; do not create another handwritten mapping authority.

- For reserved MP4 atoms validate compatible encoding and exact ranges. At minimum `trkn`/`disk` use unsigned 16-bit components 0...65535; movement atoms use 0...32767; byte/bool/native integer targets use their real encodings. Reject fractional/negative/overflowing input where not representable. Do not silently cast or clamp. Unknown atoms may use documented explicit types; a known native atom cannot change codec by changing `type`.
- ASF type tokens must be canonicalized once for both validation and dispatch, or noncanonical tokens must reject. `"String"` must never validate as text and execute as integer. Unknown types reject; unsupported GUID writes stay unsupported. Check actual numeric widths and incompatible value objects.
- Reject populated or explicit-clear collections the destination does not implement; do not silently discard them. A mixed valid+invalid payload must commit neither part.
- Introduce one documented maximum generated padding width of 64 characters. Check it before formatting or staging, including indirect formatter callers; use no silent clamp. Existing metadata reads are not invalid merely because a stored string is longer. Explicit edits needing unsupported generated width fail safely. Test 0, 1, 3, 64, 65, INT_MAX and negative input. Do not execute an unbounded baseline formatter with huge input.
- Resolve numberText with the same captured-version snapshot/inventory as typed numbers. Validate both components before staging: MP4 overflow 70000 -> integerOutOfRange; ASF `0/5` -> unsupportedPartialPairRemoval. Test number-only input with recovered/ambiguous totals, clearing, mixed per-pair input and native normalization. Keep unsigned 32768/65535 valid.
- Pure validation runs before staging; destination/version assumptions are rechecked on the actual staged file where necessary. Do not weaken validation in internal entry points reachable through the facade.

Exit: public direct bridge calls reject invalid payloads without changing bytes; valid boundary values round-trip natively. Facade verification disabled/low-level `.none` cases remain safe. Prove no staging for preflight errors using a narrow existing transaction observer or private test seam; unchanged original bytes alone proves rollback, not preflight timing.

### Phase 2 — Write ownership and identity (F-06, F-09, F-11)

Inspect `PreservedUnknownPropertyMapEntries`, `BuildGenericPropertyMap`, MP4 native item preservation and ASF native passes. Derive the full-model writer's owned fields from its actual modeled setters/bridge descriptors. Separate “known in the global registry” from “owned by this API.” Preserve everything outside the latter set, including schema-known roles and MP4-exclusive atoms. Omitted/nil modeled fields retain the documented full-replacement semantics; do not turn the entire API into a merge. Respect qualified keys, arrays, duplicates, whitespace, absent owners and opaque items where representable. A custom dictionary must not bypass known-key collision checks.

For F-09 normalize alias identity on both sides; write/update/remove must produce the canonical UFID where supported while preserving independent UFID owners/TXXX entries.

For F-11 first reproduce canonical RELEASETYPE and at least one MUSICBRAINZ_* freeform set/remove through the public raw delta. Match edited canonical keys and aliases to exact native items using existing mapping descriptors, not only `description.uppercased()`. Reconcile edited aliases once; retain untouched native names/arrays. Test set/remove with an existing atom and absent atom, canonical key distinct from inner name, case variants, and unrelated native DATE/Year owners. Test each exported public raw surface separately; do not call an internal method and describe it as a public-product reproduction.

Exit: title-only full-model FLAC writes preserve independently seeded PERFORMER arrays; representative unmodeled MP4 owners survive; modeled field clearing still works. Canonical raw edits persist without disturbing unrelated freeforms. Include direct bridge and wrapper entry points with native/audio preservation assertions.

### Phase 3 — Literal legacy evidence and save versions (F-05, F-10)

Use hand-built tags/chunks on copied repository fixtures. For F-05 test TYER/TDAT/TORY with legal status bits 0x20/0x40/0x80, combined legal status bits, normal payloads and group-identifier format handling. Separate status bits from compression/encryption/grouping format bits. Validate offsets and reserved bits precisely. Unsupported payload transforms still reject without invented dates. Exercise selective extraction masks and ensure unrelated reads do not mutate bytes.

For DSDIFF PROP-child ID3 and nonzero locations, establish that the pinned parser actually exposes that tag/version, then implement bounded container-aware traversal within declared chunk sizes. Also test truncation, oversize chunks and non-tag ID3-like bytes. Do not assume every arbitrary offset is a supported layout. Handle unverified variants as explicit bounded limitations, not completed fixes.

For F-10 generate valid WAV and AIFF containing v2.3 TYER+TDAT/TORY (also standalone TDAT), perform a supported non-date text/artwork edit through facade APIs, and inspect the native header/version and frames. Audit *all* relevant save calls, including generic raw deltas, structured writes, number/advisory routes and helper saves. Pass the observed version explicitly rather than accepting a v4 default. Existing v4 tags stay v4; tag creation policy remains unchanged. Do not remove direct bridge v2.3 restrictions or the central staged-date guard. If a layout cannot preserve independent owners, reject without committing instead of converting it.

Exit: legal status-tag reads succeed literally; unsupported transforms fail safely. Supported unrelated v2.3 WAV/AIFF edits preserve version/date owners, or a precisely bounded unsupported layout rejects unchanged. Protected frame semantics/flags must not be silently discarded on mutation.

### Phase 4 — Executable capability and schema projections (F-13, real F-14 parts)

Use one policy for writeSupport, storable enumeration and planner reachability. Property-map-only tracker handling must be explicitly allowlisted by destination/field. Prefer supporting XM tracker name through that declared route if native header tests prove it; never fake an MP4/ID3 target or enable arbitrary tracker fields. Check fixed-width tracker padding/truncation policy and samples/non-target header preservation with a small independent reader. Otherwise downgrade the advertised field and document why.

Normalize semantic dictionary keys at construction and lookup so every published key, including the dynamic custom template, resolves. Correct both MP4 total target descriptors to intPair + total component. Align role accepted value kinds with the unavailable typed role codec. Retain engine DATE alias, native-key namespace boundaries, best-available aggregate semantics and unsupported Matroska codec gates. Document registration versus implementation availability; do not blindly force all query results to agree.

Exit: native target descriptors match actual bytes; every advertised tested operation is executable or explicitly downgraded. No new duplicate preferred owners or lost custom template targets. Destination-specific unsupported/read-only behavior remains enforced.

### Phase 5 — Documentation and bounded warning work (F-01..F-04, F-12)

Update current docs consistently; retain historical records unchanged and add a superseding record where appropriate. Explicitly distinguish private provenance retirement, ordinary edited-owner alias cleanup, engine keys, semantic identities and native identities. Explain why ASF common aliases retire only on an explicit corresponding edit. Correct Basic MP4-exclusive behavior and misleading aggregate-capability wording. Describe YEAR's existing Basic prefix filter without inventing a date grammar or changing typed writes. Fix the stale “do not combine numberText and typed numbers” statement to describe per-pair compatibility if touched by this work.

F-04 is optional warning hardening, not a mandatory reproduced defect. If implementing it, use a small private result classifier fed by a deterministic failed raw-read test, retain best-effort erase semantics and report limited evidence as a warning. Do not promise removal of every native structure or add public fault-injection controls.

Exit: all current public docs agree with the implemented/retained contract; all 15 findings have a final evidence-qualified disposition.

### Phase 6 — Regression gate and acceptance

New tests must cover the actual failing public surfaces, not exclusively typed patches. Use fresh copies per operation. Validate seeds through test-owned byte readers before invoking the writer. Check expected native owners/types/arrays, untouched siblings, and audio/sample payload where a bounded independent oracle exists. Structured/package readback alone is not independent evidence.

Add exact required runtime names and parameterized minima to `scripts/summarize-test-run.py` and its policy fixtures, plus the required Swift Testing source inventory when applicable. Do not freeze guessed counts: run discovery, retain old floors (181 XCTest and 198 Swift Testing) and raise them to include new declarations/cases. Required new evidence includes: direct bridge invalid-payload rejection, full-model unowned-owner preservation, legal status flag reading, MusicBrainz alias lifecycle, version-preserving container writes, canonical MP4 raw updates, XM/capability coherence and preflight number bounds. Tamper tests must reject missing named methods, reduced cases, hidden failures and unexpected skips. Suite banners or an unchanged total do not establish coverage.

Run available checks with the stable installed Xcode toolchain:

```sh
python3 -m unittest discover -s scripts/tests
python3 scripts/check-docs.py
TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh debug
TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh release
swift run --package-path IntegrationTests/Consumer --disable-sandbox --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror TagLibAudioMetadataConsumer
swift run --package-path IntegrationTests/Consumer --disable-sandbox --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror TagLibAudioMetadataLowLevelConsumer
```

Run focused ASan and TSan on the changed write/parser/transaction paths; state that the precompiled engine is not instrumented. Run the existing minimum-platform compile checks, particularly macOS 13 and iOS 16, if the environment has the tools. Do not invent CI/device results. ACP/Xcode tools may run builds/tests and collect diagnostics; discover actual tool names. If shell/Git/Python tools are absent, use available Xcode equivalents for feasible checks and report canonical script gates as not executed, not accepted by inference.

The privilege precondition stays mandatory. A filesystem restriction is a blocked run, not an implementation defect and not a reason to skip it. Obtain an authorized capable environment or leave formal acceptance pending with the exact diagnostic. Similarly, no formal accepted gate if Xcode output cannot satisfy the unchanged evidence parser; preserve the native result bundle and explain the missing canonical evidence.

## 5. Completion criteria and final handoff

- A new branch exists; coherent incremental commits contain the implementation, meaningful regressions and matching current docs. No main edits, reset, push, PR, merge, tag or release.
- Each mandatory repair above is implemented, with baseline evidence (safe where necessary), final independent assertions and exact public entry-point coverage. F-10/F-11 cannot remain merely source claims without an attempted deterministic reproduction and documented outcome. F-05 container-location hypotheses are separate from the confirmed status-bit case.
- Retained-by-design behavior is tested/documented, not “fixed” by widening capabilities, retaining stale aliases, adding fallback writes or suppressing verification.
- Full Debug and Release canonical gates must be accepted for a formal ready verdict. Otherwise finish independent repairs and report the exact remaining environment/tool blocker without claiming ready.
- Final record names tested commit/diff, commands, results/counts, case counts, evidence paths, skips, unsupported layouts and unexecuted platform scope. Do not describe the whole package as universally safe.
- Report package API/migration changes to the application maintainer in English. The repair agent must not access or validate the application repository.

## 6. Primary references checked for this assessment

- [ID3v2.3 specification, frame-header flags and payload transforms](https://id3.org/id3v2.3.0): status bits are not the same thing as compression/encryption/grouping format flags. In particular, read-only does not make a plain text frame undecodable.
- [TagLib WAV save API](https://taglib.org/api/classTagLib_1_1RIFF_1_1WAV_1_1File.html) and [AIFF save API](https://taglib.org/api/classTagLib_1_1RIFF_1_1AIFF_1_1File.html): verify overload/default behavior against the package's pinned 2.3.1-r2 headers before changing calls.
- Current package mapping/preservation/transaction/testing contracts and `CleanRoomNativeAliasTests`, `LegacyNumberingRecoveryTests`, `RemediationPreservationTests`, `MappingContractCoverageTests`.

For the executable handoff, use [the startup prompt](DIAGNOSTIC_REMEDIATION_AGENT_PROMPT_2026-11-15.md).
