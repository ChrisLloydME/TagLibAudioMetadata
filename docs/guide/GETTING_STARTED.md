# Getting started

`TagLibAudioMetadata` reads, edits, verifies, and erases audio metadata on macOS and iOS. A Swift facade wraps an Objective-C++ bridge to a checksum-pinned TagLib 2.3.1 XCFramework. This guide takes you from package resolution to a first read and a first verified patch.

Version `0.7.2` is the current release. Mapping contract 2.2 was introduced in `0.7.0`; `0.7.1` added date/ownership corrections, and `0.7.2` finalizes the audit and native-mapping repairs. Use the [migration guide](../operations/MIGRATION.md) when upgrading from `0.7.1` or earlier.

## Requirements

| Requirement | Value |
| --- | --- |
| Swift tools | 6.4 |
| macOS | 13.0 or later |
| iOS | 16.0 or later |
| C++ standard | GNU C++20, configured by `Package.swift` |
| Network | Required on first resolution to fetch the pinned binary release |

The TagLib binary is a dynamic framework. The final app or archive must embed and sign `TagLibAudioMetadataTagLib.framework` and resolve `@rpath/TagLibAudioMetadataTagLib.framework/TagLibAudioMetadataTagLib`. See [Installation](../operations/INSTALLATION.md).

## Add the package

```swift
dependencies: [
    .package(
        url: "https://github.com/ChrisLloydME/TagLibAudioMetadata.git",
        from: "0.7.2"
    )
]
```

Most targets need only the facade product:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "TagLibAudioMetadata", package: "TagLibAudioMetadata")
    ]
)
```

If your code names `TagLibAudioMetadata`, `TagLibMetadataExtractor`, `TagLibExplicitAdvisory`, or `TagLibMetadataExtractionOptions`, also declare the low-level product and import its module:

```swift
.product(name: "TagLibAudioMetadataLowLevel", package: "TagLibAudioMetadata")
```

```swift
import CTagLibBridge
```

The facade does not re-export bridge declarations. `CTagLibBridgeInternalAPI` is a package-internal target and is not a supported dependency.

## Read one coherent snapshot

Use a snapshot when the editor needs the normalized fields, raw `PropertyMap`, and structured container view from one observed revision:

```swift
import TagLibAudioMetadata

let url = URL(fileURLWithPath: "/path/to/song.flac")
let snapshot = try TagLibMetadataManager.readSnapshot(from: url)

print(snapshot.basic.title)
print(snapshot.raw.properties)
print(snapshot.structured.artwork)
```

`readSnapshot` rejects a file that changes during extraction. It is a semantic snapshot, not a byte-exact native archive: opaque native records may be summarized, and leaving them out of a write does not promise byte-for-byte reconstruction.

If you only need common fields and a version token, use `readBasicSnapshot`. It returns Basic metadata and a `MetadataFileVersion`; it does not return the structured model, although it still derives it internally for exact native dates and MP4 atom identities.

```swift
let focused = try TagLibMetadataManager.readBasicSnapshot(from: url)
let version = focused.fileVersion
```

## Apply a verified patch

`MetadataPatch` is omission-safe: only fields present in the patch change.

```swift
let patch = MetadataPatch(
    fields: [
        .title: .text("New Title"),
        .track: .integer(1),
        .trackTotal: .integer(12)
    ],
    customFields: ["APP_WORKFLOW": .values(["Focused", "Calm"])],
    explicitAdvisory: .clean,
    artwork: .unchanged
)

let result = try TagLibMetadataManager.applyMetadataPatch(
    patch,
    to: url,
    expectedVersion: snapshot.fileVersion
)

print(result.commitStatus)
for warning in result.warnings {
    print(warning)
}
```

Rules worth knowing before the first write:

- Fields absent from the patch are unchanged; `.remove` is the explicit deletion request.
- `.text("")`, `.values([])`, and empty array elements are validation errors, not deletion aliases.
- Do not mix typed track/disc fields with `numberText` in one patch.
- Verification mismatches throw before commit; a successful result carries only residual container advisories.
- `.year` is the canonical YEAR field. `.date` is a legacy YEAR spelling that writes the same slot where writable; do not supply both.
- `.standaloneDate`, `.releaseDate`, and `.originalReleaseDate` are independent fields. `BasicMetadata.date` carries the standalone DATE projection, not the typed `.date` legacy YEAR alias.
- Existing ID3v2.3 tags reject independent date edits. Inspect `StructuredMetadata.id3v2MajorVersion` before enabling those controls.

See [Writing metadata](WRITING.md) for the complete patch, raw, Basic, structured, and erase surface.

## Check capabilities before enabling controls

```swift
let capability = try TagLibMetadataManager.probeFile(at: url)
print(capability.supportLevel)
print(capability.writeSupport(for: .artwork))
```

`probeFile` validates readability with the selected parser; it does not test POSIX write permission, ACLs, disk space, or sandbox access. Use `capability(forExtension:)` for declared-format discovery when no file exists yet. `writeSupport` is a declared capability, not a typed-write promise; inspect the field schema and the format limits when a control depends on a particular field. See [Capabilities](CAPABILITIES.md).

## Choose the next document

| Task | Start here |
| --- | --- |
| Read Basic, raw, or structured metadata | [Reading metadata](READING.md) |
| Apply typed, raw, Basic, or structured writes | [Writing metadata](WRITING.md) |
| Decide whether a format or field is supported | [Capabilities](CAPABILITIES.md), [Formats](../reference/FORMATS.md) |
| Understand preservation and verification | [Write semantics](../explanation/PRESERVATION.md) |
| Understand staging, durability, and locking | [Transactions](../explanation/TRANSACTIONS.md) |
| Distinguish metadata-only conflicts from replaced audio | [Audio-content continuity](../explanation/AUDIO_CONTENT_CONTINUITY.md) |
| Look up signatures or value types | [Manager API](../reference/API.md), [Model reference](../reference/MODELS.md) |
| Look up a field key or native target | [Field reference](../reference/FIELDS.md) |
| Install, embed, and sign the framework | [Installation](../operations/INSTALLATION.md) |
