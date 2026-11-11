# Capabilities and field support

This guide explains how to discover what the package declares for a format or field, and where those declarations stop. The generated matrix is in [Formats](../reference/FORMATS.md); field mappings are in the [field reference](../reference/FIELDS.md).

## Query a declared family

`capability(forExtension:)` does not open a file:

```swift
import TagLibAudioMetadata

if let capability = TagLibMetadataManager.capability(forExtension: "m4a") {
    print(capability.identifier)                 // "mp4"
    print(capability.extensions)                 // aliases in registry order
    print(capability.supportLevel)               // evidence for "m4a"
    print(capability.supportLevel(forExtension: "mp4"))
    print(capability.canWriteArtwork)
}
```

Extension matching is case-insensitive. A missing extension returns `nil`; `isReadableExtension` and `isWritableExtension` are Boolean shorthand. `readableExtensions` and `writableExtensions` derive extension lists from the registry.

Use declared capability for format discovery when no file exists yet. It does not validate that the user selected a well-formed audio file.

## Validate a concrete file

```swift
let capability = try TagLibMetadataManager.probeFile(at: url)
print(capability.supportLevel)
print(capability.structuredWriteSupport)
print(capability.writeSupport(for: .artwork))
```

`probeFile` parses the concrete file with the selected parser before returning the declared family capability. It does **not** test POSIX write permission, ACLs, disk space, sandbox access, an external process's lock, or hardware durability. Attempt a write or check those separately when editability depends on them.

## Interpret the capability fields

| Field | Meaning |
| --- | --- |
| `identifier` | Stable family identifier such as `mp4`, `flac`, or `mpeg-id3`. |
| `displayName`, `codecName` | Human-readable family and codec names. |
| `primaryExtension`, `extensions` | Primary extension and all registered aliases, lowercase. |
| `containers` | Declared container surfaces: `tag`, `propertyMap`, `id3v1`, `id3v2`, `ape`, `mp4`, `xiph`, `asf`, `riffInfo`. |
| `isReadable`, `isWritable` | Declared operation availability. |
| `canReadArtwork`, `canWriteArtwork` | Artwork availability. `canWriteArtwork` is false for a read-only family. |
| `preservesMultiValueProperties` | Family-level repeated-value support, not a per-field guarantee. |
| `structuredReadSupport`, `structuredWriteSupport` | Non-artwork structured inspection/mutation level. A `.propertyMap` level can still support structured artwork. |
| `supportLevel` | Evidence level for the requested extension, or the primary extension for `formatCapabilities`. |
| `extensionSupportLevels` | Per-extension evidence levels. |
| `readableFields`, `writableFields` | Optional explicit allowlists; `nil` means infer from schema mappings. Currently used by tracker formats. |
| `metadataFieldFormats` | Formats derived from `containers`: always includes `.tagLibPropertyMap`; adds `.id3v2`, `.mp4`, `.xiph`, `.ape`, and `.asf` when present; adds `.flac` for the FLAC identifier. It does not derive `.riffInfo` or `.matroska`. |

### Evidence levels

| Level | Meaning |
| --- | --- |
| `fixtureCovered` | The repository has a fixture and regression coverage for the extension. Not every field or variant is tested. |
| `experimental` | A save path exists, but container behavior is incomplete. |
| `upstreamSupported` | TagLib exposes the format; this package has no round-trip fixture. Treat it as unverified. |
| `readOnly` | Readable, with no save path. |
| `unsupported` | No parser or field mapping. |
| `verified` | Deprecated spelling; never returned. Use `fixtureCovered` or a concrete probe. |

A configured label is not a release verdict. The lifecycle matrices and gate evidence are described in [Mapping test acceptance](../operations/MAPPING_TEST_STRATEGY.md); the latest observed state is in [Status](../operations/STATUS.md).

## Field-level queries

```swift
let capability = try TagLibMetadataManager.probeFile(at: url)

print(capability.readSupport(for: .year))
print(capability.writeSupport(for: .standaloneDate))
print(capability.writeSupport(for: .artwork))
```

`readSupport` and `writeSupport` combine family flags, schema mappings, optional field allowlists, and artwork flags. `writeSupport` also respects schema-level write withholding and requires a writable native target when the format declares a concrete native family. A PropertyMap alias cannot override a read-only or unavailable native target. Semantic write capability follows the primary write family; secondary readable tags such as ID3 on FLAC or APE on MPEG do not select the semantic write destination. Formats exposing only PropertyMap retain mapping and allowlist checks, including tracker title/name fields. These are declared checks, not a guarantee that a typed write will succeed:

- `.rate` has a readable MP4 mapping but no preferred write target; `writeSupport(for: .rate)` returns `.unsupported`, and the typed patch rejects it without mutation.
- RIFF INFO is not in `metadataFieldFormats`, so a field that exists only as RIFF INFO needs the raw/structured path.
- Native width, tag version, container state, and preservation conflicts can still reject a specific file. For example, an ID3v2 capability may reflect the verified v2.4 codec while a concrete ID3v2.3 tag is read-only for independent dates; inspect `StructuredMetadata.id3v2MajorVersion` before offering that edit.

For a precise answer, inspect the schema:

```swift
if let schema = MetadataFieldRegistry.schema(for: .catalogNumber) {
    print(schema.writeUnsupportedReason ?? "no schema-level withholding")
    print(schema.capability(for: .mp4))       // native / conventionalExtension / readOnly / unsupported
    print(schema.writeTarget(for: .mp4)?.nativeIdentity ?? "no preferred MP4 write target")
}
```

`MetadataFieldRegistry.schemas(storableIn:)` returns canonical schemas that pass a capability preflight. It excludes read-only capabilities and non-canonical aliases. It is a filter, not a per-file guarantee.

## Browse the declarations

```swift
let all = TagLibMetadataManager.formatCapabilities
let basicFields = MetadataFieldRegistry.allSchemas.filter { $0.category == .basic }
let id3Fields = MetadataFieldRegistry.schemas(withMappingsFor: .id3v2)
let writable = MetadataFieldRegistry.schemas(storableIn: capability)
```

The generated [Format matrix](../reference/FORMATS.md) lists every family, extension alias, declared container, structured support level, evidence label, and explicit allowlist. The [field reference](../reference/FIELDS.md) lists semantic keys, native targets, and typed-patch policy.

## Related references

- [Formats](../reference/FORMATS.md) — generated capability matrix and container limits.
- [Field reference](../reference/FIELDS.md) — schema and native targets.
- [Writing metadata](WRITING.md) — how validation uses these declarations.
- [Manager API](../reference/API.md) — capability signatures.
