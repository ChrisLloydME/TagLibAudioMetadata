# Installation and binary distribution

The root package consumes an immutable, checksum-pinned TagLib 2.3.1 dynamic
XCFramework. It has no source, static, Homebrew, or system-library fallback.

## Add the package

Depend on the Swift facade for normal application code:

```swift
.package(
    url: "https://github.com/ChrisLloydME/TagLibAudioMetadata.git",
    from: "0.4.5"
)

.product(name: "TagLibAudioMetadata", package: "TagLibAudioMetadata")
```

Advanced targets that directly use `TagLibMetadataExtractor` or
`TagLibAudioMetadata` should declare the low-level product explicitly:

```swift
.product(name: "TagLibAudioMetadataLowLevel", package: "TagLibAudioMetadata")
```

Then use `import CTagLibBridge`. The facade's bridge re-export is retained only
for compatibility and may be removed in a future major version.

## Binary identity

| Field | Value |
| --- | --- |
| Upstream | TagLib `v2.3.1` |
| Commit | `54ae7d8ac45755e286a5c574280f48d5bef93aef` |
| utf8cpp commit | `819011bb01628fe1aa2f1da9f2c842a48fd5680b` |
| Release | `taglib-binary-2.3.1-r2` |
| Asset | `TagLibAudioMetadataTagLib-2.3.1-apple-dynamic.xcframework.zip` |
| SwiftPM checksum | `d7a36b2492266a17fcd97bd776cd841d9fc85275270bc0c3cb9621395b3178c7` |
| Framework | `TagLibAudioMetadataTagLib.framework` |
| Install name | `@rpath/TagLibAudioMetadataTagLib.framework/TagLibAudioMetadataTagLib` |
| Bundle identifier | `com.chrislloyd.taglibaudiometadata.taglib` |

The asset contains the TagLib and utf8cpp license texts and generated headers.
SwiftPM validates the entire ZIP against the manifest checksum before use.

## Supported slices

| Destination | Architectures | Minimum OS |
| --- | --- | --- |
| macOS | `arm64`, `x86_64` | 13.0 |
| iOS device | `arm64` | 16.0 |
| iOS Simulator | `arm64`, `x86_64` | 16.0 |

## Embedding and signing

The selected slice is a dynamic framework. SwiftPM supplies it to the linker,
but the final app or archive must embed and sign
`TagLibAudioMetadataTagLib.framework`. In Xcode, inspect the application
target's Frameworks, Libraries, and Embedded Content and select **Embed & Sign**
when Xcode has not inferred it.

Validate an archive or app, not only a package test bundle:

```sh
otool -L /path/to/executable
codesign --verify --deep --strict /path/to/App.app
```

The executable should reference the namespaced install name above. A generic
`@rpath/TagLib.framework/TagLib` indicates that an old or conflicting artifact
was linked.

## Network and offline builds

The release asset is public. For command-line environments where SwiftPM tries
stored GitHub credentials, use:

```sh
swift build --disable-keychain --disable-netrc
```

After SwiftPM has cached the verified artifact, ordinary offline builds can use
that cache. For controlled offline distribution, mirror the exact ZIP and
update the URL only if the mirrored bytes retain the manifest checksum; any
byte change needs a new checksum and immutable release revision.

## Rebuild and publish

The single source of binary identity is
`scripts/taglib-binary-version.env`. Rebuild all slices from an unmodified exact
checkout with:

```sh
scripts/build-taglib-xcframework.sh --replace
```

Or reuse an already verified checkout:

```sh
scripts/build-taglib-xcframework.sh \
  --source-dir /path/to/taglib-v2.3.1 \
  --replace
```

The script fixes source revisions, build options, deployment targets, and
architectures and rejects source-tree modifications. Toolchain metadata and ZIP
timestamps mean rebuilds are reproducible by source/configuration, not promised
byte-for-byte. Publish a new release revision, calculate its SwiftPM checksum,
then update `Package.swift`; never replace an existing asset in place.

The `Binary Release` workflow validates the tag/commit relationship, artifact
layout, licenses, slices, deployment targets, module map, install names, and
bundle identity before publication.

## Diagnostics

- Resolution failure: confirm the public release URL is reachable and retry
  with `--disable-keychain --disable-netrc`.
- Checksum mismatch: clear the affected SwiftPM artifact cache and confirm the
  manifest points at the immutable release asset. Do not bypass verification.
- Link collision or duplicate symbols: inspect `otool -L` and the process image
  list for another TagLib. The namespaced framework prevents filename and
  install-name collisions, but not C++ symbol interposition between different
  TagLib implementations.
- Launch-time library error: ensure the namespaced framework is embedded,
  signed, and reachable through the app's `LC_RPATH` entries.
- Missing low-level module: add the `TagLibAudioMetadataLowLevel` product and
  `import CTagLibBridge`; do not depend on an implementation target by name.
