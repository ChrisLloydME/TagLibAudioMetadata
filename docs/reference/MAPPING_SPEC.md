# Native mapping contract

Contract ID: `AM-TLAM-MAPPING-2.2`. Decision date: `2026-11-09`. This page describes the package-side mapping contract introduced in `0.7.0`. `0.7.1` added date/ownership corrections; `0.7.2` finalized the native read/write/verification consistency repairs; `0.7.3` adds native-owner state preservation without changing the contract ID or registered target layouts. See [Migration](../operations/MIGRATION.md) for release-specific changes.

The package-side source of truth is code:

- `Sources/TagLibAudioMetadata/MetadataFieldSchema.swift` owns the public field keys, categories, property aliases, and typed-patch policy.
- `Sources/TagLibAudioMetadata/MetadataMappingCatalog.swift` owns the exact semantic-to-native target table.
- `Sources/TagLibAudioMetadata/MetadataNativePlanning.swift` translates a validated patch value to the selected native mechanism.
- The bridge owns the concrete codecs, container dispatch, and verification paths.

The [generated mapping matrix](MAPPING_MATRIX.md) is a view of the Swift catalog. Markdown is never parsed to generate production mapping code. The Objective-C++ bridge has a parallel ordered table for its own projections, checked by cross-language parity tests; where the bridge table and Swift catalog differ, the Swift catalog and the version-specific codec tests determine typed-write behavior.

## 1. Scope and precedence

This contract applies to package APIs and native metadata targets. Application edit intent, presentation labels, import/export profiles, and cross-repository synchronization are outside this repository. The package exposes semantic operations; the application chooses when to call them.

Resolve a write in this order:

1. The exact native target declared by `MetadataMappingCatalog` for the field, family, and tag version.
2. The field schema's preferred write target and patch constraints.
3. An explicitly registered conventional extension, when the native slot is absent or unavailable.
4. Reject the operation with a typed validation error. Never invent a private field or fall back to a different semantic target after a verification failure.

A canonical semantic key is a stable package identity. It does not force TagLib's `PropertyMap` projection to use the same spelling, and a raw key is not automatically a semantic field. `MetadataFieldRegistry.schema(forPropertyMapKey:)` owns that translation.

## 2. Identities and registry

The registry distinguishes:

- **Semantic key** — `MetadataFieldKey`, stable in Swift source.
- **Native target** — exact ID3 frame, MP4 atom or freeform description, Xiph/APE text key, ASF attribute, RIFF INFO key, or Matroska tag with target level.
- **Display and import aliases** — `propertyMapKeys`, labels, and application-facing names. Aliases do not create additional stored fields.

`MetadataFieldSchema.nativeTargets` is the explicit target list. `MetadataFieldSchema.mappings` is a compatibility projection derived from those targets and must not be hand-maintained. Exactly one target per field and family is the preferred write location, except for the two components of one native number pair. A previous-version or read-only alias can be registered without becoming a write target.

Capability state is separate from existence:

| State | Meaning |
| --- | --- |
| `native` | A preferred target is a native slot for the family. |
| `conventionalExtension` | A preferred target is a declared freeform/user-text/extension convention, not a standard slot. |
| `readOnly` | A target is readable or preservable, but no verified typed write is advertised. |
| `unsupported` | No target for this family, or a gated family such as Matroska. |
| `ambiguous` | Evidence does not establish a single safe target. |

A registered location never proves round-trip behavior. Native codec tests, verification, and container-specific fixtures remain the evidence.

## 3. Dates are independent

YEAR, DATE, RELEASEDATE, and ORIGINALDATE are independent stored fields and independent edit intents. No field is synthesized from, reconciled with, truncated to, or automatically cleared because another changes.

- `.year` is the canonical YEAR identity.
- `.date` is a legacy YEAR-slot spelling retained for source compatibility. It writes the same native target as `.year`; supplying both in one `MetadataPatch` throws `MetadataPatchValidationError.conflictingYearRepresentations`.
- `.standaloneDate` is the independent DATE identity. `BasicMetadata.date` carries this standalone DATE projection; it is not the typed `.date` legacy YEAR alias.
- `.releaseDate` is RELEASEDATE.
- `.originalReleaseDate` is ORIGINALDATE.

MP4 uses `©day` for YEAR. DATE and RELEASEDATE use explicit `DATE` and `RELEASEDATE` freeform extensions. The registry records version-appropriate ID3 locations (`TYER`/`TDRC`, `TDAT`/`TXXX(DATE)`, `TDRL`, `TORY`/`TDOR`). ID3v2.4 writes use the verified codecs. Independent date writes on existing ID3v2.3 tags are currently read-only: typed patches and Basic date edits reject before mutation. `StructuredMetadata.id3v2MajorVersion` exposes the observed primary version for concrete-file capability UI; it is not a version-conversion request. Xiph/APE use the declared text keys. ASF uses its registered attributes. RIFF INFO has no independent DATE target.

YEAR may contain complete stored date text. Read it as-is; never take the first four characters. `replaceBasicMetadata` and `updateBasicMetadata` validate YEAR text with `isRepresentableYearText`; the typed patch path does not run that Basic-specific validator. `MetadataValidationError.invalidYearText` is the Basic rejection.

No automatic fallback supplies one date field from another. When two requested fields cannot coexist in a layout, reject that operation before mutation.

## 4. Numbers, totals, and legacy recovery

Native pairs are authoritative:

| Family | Number/total representation |
| --- | --- |
| ID3v2.3/2.4 | Combined `TRCK` / `TPOS`; movement uses `MVIN`. |
| MP4 | Native `trkn` / `disk` integer pairs; movement number/count use independent `©mvi` / `©mvc` integer atoms. |
| Xiph | Separate `TRACKNUMBER`/`TRACKTOTAL` and `DISCNUMBER`/`DISCTOTAL`. |
| APE-family | Separate `TRACK`/`TRACKTOTAL` and `DISC`/`DISCTOTAL`. |
| ASF | `WM/TrackNumber` and `WM/PartOfSet` text pairs. |
| RIFF INFO | `ITRK`; no typed total target in this profile. |

Track and disc components begin at one; BPM and movement numbering begin at zero. MP4 track/disc components accept unsigned 16-bit values through `65535`; MP4 movement atoms accept `0...32767` and reject larger values before staging. Removing a first component while retaining a total is supported on MP4 (`0/total` sentinel), ID3-backed formats (`/total` text), and separate-key Xiph/APE layouts. ASF rejects a number-zero-plus-total pair; remove both components instead.

`numberingInventory(at:)` reports native components, legacy standalone aliases, and both private MP4 formatting namespaces with exact values and identities. States:

- `native` — one consistent native value;
- `recoveredLegacy` — a sole valid legacy candidate;
- `ambiguous` — multiple disagreeing or malformed candidates;
- `invalid` — candidates exist but cannot be parsed safely;
- `absent` — no value.

`planNumberNormalization(at:policy:groups:)` captures the file version and returns an immutable plan. `applyNumberNormalization(_:to:)` requires the same version, writes the native pair first, retires only the selected aliases and private identities, and verifies persistence and removal. Untouched groups are not resolved or cleaned. `.useNative` cannot discard malformed or multi-valued native data; `.useLegacy` falls back to a native component only when there are no legacy candidates, otherwise the ambiguity must be resolved with `.replace(number:total:)`.

No default write surface creates or renames `AUDIOMATOR_*_TEXT` or `TAGLIBAUDIOMETADATA_*_TEXT` MP4 atoms. They remain readable and are preserved until an explicit normalization plan retires selected identities. Custom-field writes are not a cleanup mechanism; avoid package-reserved names in custom data.

## 5. Explicit advisory

`ExplicitAdvisory` has four semantic states:

| State | Meaning | MP4 `rtng` | Text surfaces |
| --- | --- | --- | --- |
| `unspecified` | No representation | absent | absent |
| `notExplicit` | Present, not explicit | `0` | `"0"` |
| `explicit` | Explicit | `1` | `"1"` |
| `clean` | Clean | `2` | `"2"` |

Zero is a present value, not absence. Unknown existing codes are retained in `explicitAdvisoryRawValue` with `.unspecified` semantics and are not recoded during an unrelated save. An explicit replacement to one of the four states is allowed and verified.

The Boolean `explicitContent` / `isExplicit` projection is lossy. `isExplicit = false` records `.clean`; it does not mean absence or `.notExplicit`.

## 6. MP4-exclusive and gated Matroska identities

The registry includes the MP4-exclusive identities for director, account, composer/country IDs, gapless, HD video, owner, rating, show movement, store description, TV episode/network/season/show/sort, and media kind. Store IDs, TV numbers, and Boolean atoms are exact native values; unknown media-kind codes round-trip.

Movement Number and Count use independent `©mvi` and `©mvc` integer atoms; they are not components of a shared track/disc pair. The native range is `0...32767`, while MP4 track/disc components retain the unsigned 16-bit range through 65535. Content Group, Grouping and Work are independent native owners, and Encoded By and Encoder Settings are independent native owners; verification checks the exact untouched sibling rather than a fallback projection.

`.rate` is registered read-only for typed writes: the atom is readable and preserved, but no verified native rating type or scale is available. `.itunesMediaType` (`stik`) round-trips as an integer; the package does not bind a label vocabulary to numeric codes.

Two Matroska registrations exist for `tvEpisode` and `tvSeason` (`PART_NUMBER@TargetTypeValue=50/60`). They report `.unsupported` and have no preferred write target until a verified native codec and fixture coverage exist. They are target registrations, not advertised MKV support.

## 7. Aliases, custom fields, and preservation

Read-side aliases are compatibility candidates, not write fan-out instructions. The exact native target is written; recognized old aliases are retired only for an explicitly changed field. Untouched physical spellings are preserved where the container permits it.

Raw APIs use prefixless TagLib `PropertyMap` keys. Native MP4 `----:` atom keys are rejected by raw APIs and must use `StructuredMetadata.mp4Atoms`. `RawMetadataPatch` is a delta over the visible PropertyMap; it verifies the complete visible map and is not an oracle for opaque native data.

Custom fields are arbitrary keys, but schema-known names are rejected from `MetadataPatch.customFields` so one semantic field cannot be written through two representations. The current bridge still permits reserved hidden formatting names through low-level custom-field writes; clients must not use them.

On MP4, a custom field that already exists as a freeform atom and whose scalar projection is unchanged retains its original name spelling and native value array. Changed MP4 freeform names reconcile their case aliases. On ASF, a semantic custom field is a native Unicode attribute rather than a PropertyMap-only key; only the edited field's case aliases are reconciled. These rules preserve state that a scalar read/modify/write cannot represent.

Semantic `.comment` and `.lyrics` use their native container owner: qualified ID3 collections on ID3-backed formats and the ordinary MP4 `©cmt`/`©lyr` atoms on MP4. The structured `comments`/`lyrics` collections are a separate API surface and are not a substitute for those typed fields.

## 8. Format behavior and evidence

The package exposes ID3v2, MP4, Xiph, APE, ASF, RIFF INFO, and fallback PropertyMap surfaces according to the selected format family. Container dispatch and the declared support matrix are in [Formats](FORMATS.md) and [Bridge reference](BRIDGE.md).

Evidence is layered:

- **fixtureCovered** — the repository has a fixture and regression tests for a declared family/extension; not every field or variant is proven.
- **experimental** — a save path exists but container behavior is incomplete.
- **upstreamSupported** — TagLib exposes the format; this package has no round-trip fixture.
- **readOnly** — no save path.

A capability label is not a release verdict. Cross-tool conformance, minimum-OS runtime, device runtime, sanitizers, and application adoption are separate evidence. See [Testing](../operations/TESTING.md), [Mapping test acceptance](../operations/MAPPING_TEST_STRATEGY.md), and [Status](../operations/STATUS.md).

## 9. Implementation boundaries

Implemented in the current source tree:

- the explicit native target registry and generated field reference;
- independent YEAR/DATE/RELEASEDATE/ORIGINALDATE targets, with existing ID3v2.3 tags read-only for independent date writes;
- native number pairs, independent MP4 movement atoms, inventory states, and explicit normalization plans;
- four-state advisory storage with raw unknown-code preservation;
- the MP4-exclusive typed fields, with `.rate` read-only;
- gated Matroska target registrations with no advertised write support;
- native-owner preservation across PropertyMap replay on MP4 and ID3-backed files, independent low-level YEAR/DATE reads, exact untouched MP4 custom-field spelling/arrays, and native ASF custom attributes (added in `0.7.3`).

Known boundaries:

- `.rate` typed writes are withheld.
- Matroska `tvEpisode`/`tvSeason` writes are not implemented.
- The bridge and Swift catalog are separate representations; parity tests guard them.
- `replaceBasicMetadata` does not write the MP4-exclusive Basic properties; use `MetadataPatch` for those fields.
- Extension-level capability cannot identify a concrete tag version; inspect `StructuredMetadata.id3v2MajorVersion` before offering ID3 date edits.
- ASF has no verified total-only number representation.
- Cross-tool fixtures for YEAR/DATE/RELEASEDATE independence are limited to the formats covered by [mapping test acceptance](../operations/MAPPING_TEST_STRATEGY.md).

The generated matrix lists every profile and exact target. Any normative change must update the Swift catalog, the bridge codec where applicable, the field reference, the matrix, and the relevant tests together.

## Conformance repairs after 0.7.0

### 0.7.2 release

Version `0.7.2` separates native Xiph/APE YEAR and DATE ownership from engine aliases in reads, semantic writes, raw replacement/delta, and generic map replay. Untouched native date arrays and malformed values are verified without collapsing them. ID3/MP4 date preservation is checked against native frames/atoms; a changed engine DATE projection does not authorize changing an unedited native owner. Encoded By and Encoder Settings are independent, MP4 movement uses `©mvi`/`©mvc`, and MP4 Content Group/Grouping/Work are verified separately. The existing native layouts and contract ID were unchanged.

FLAC scalar comments use the Xiph verification path even when a secondary ID3 surface is supported. Qualified MusicBrainz recording identifiers use the UFID owner codec. Semantic write capability follows the primary write family; secondary readable tags do not authorize semantic writes.

ID3v2.3 date targets are registered read-only until a verified native codec exists. These changes do not establish an ID3v2.3 TDAT/TDRL codec, arbitrary unknown-advisory assignment, MKV writes, or a RATE scale. Unknown advisory preservation and typed known-state edits remain distinct from assigning a new unknown native code.

### 0.7.3 release

Version `0.7.3` extends the same contract without new native identifiers. It preserves untouched MP4 item and ID3 frame date owners, including native absence, during raw, semantic-custom and structured PropertyMap replay; reads independent YEAR/DATE values from native owners in the low-level model on MP4, ID3, Xiph and APE; retains unchanged MP4 custom-field name spelling and arrays; routes MP4 `.comment`/`.lyrics` through `©cmt`/`©lyr`; and verifies ASF native absence and custom attributes. None of this makes an existing ID3v2.3 tag writable for independent date edits.

## Related references

- [Native mapping matrix](MAPPING_MATRIX.md) — generated from `MetadataMappingCatalog.swift`.
- [Field reference](FIELDS.md) — public field semantics and typed-patch policy.
- [Formats](FORMATS.md) — declared capability and container limits.
- [Write semantics](../explanation/PRESERVATION.md) — preservation and verification.
- [Migration](../operations/MIGRATION.md) — changes from the tagged releases.
