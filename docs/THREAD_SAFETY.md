# Thread Safety

## Public contract

`TagLibMetadataManager` and `TagLibMetadataExtractor` may be called from
multiple threads. Every Objective-C++ selector that enters TagLib is serialized
inside the package with one process-wide recursive mutex. Operations on
independent files are safe but their TagLib portions execute one at a time.

Callers must still serialize mutations to the same canonical file path when
write ordering matters. The package's atomic replacement and identity checks
prevent a stale mutation from silently overwriting a changed destination, but
they do not define which concurrent same-file write should win.

This guarantee assumes clients do not independently mutate TagLib's global
hooks through another direct linkage to the same TagLib binary while package
operations are running.

## TagLib 2.1.1 audit

The package binary is built from TagLib commit
`7d86716194777e0294453bfdc9dd170bd033e1f4`. The following process-wide or
function-static mutable state is not internally synchronized by that revision:

| Area | State | Exposure |
| --- | --- | --- |
| MP4/M4A | `MP4::ItemFactory::factory` lazily fills three maps from `const` lookups | Read and write |
| MP3/ID3v2 | `TextIdentificationFrame::involvedPeopleMap()` lazily fills a static map | Read and write |
| MP3/ID3v2 | FrameFactory lazily fills the static `tiplKeys` list | ID3v2.3 conversion |
| WAV/RIFF INFO | `Tag::setProperties()` lazily fills `idForPropertyKey` | Write |
| ASF/WMA | `Tag::setProperties()` lazily fills `reverseKeyMap` | Write |
| Common hooks | Debug listener, FileRef resolver list, and ID3/RIFF string-handler pointers | Configuration and use |

The bridge mutex covers all package read, raw inspection, structured
inspection, write, and erase entry points. It is recursive because raw
inspection validates through the basic reader, and atomic mutations validate a
temporary file by re-entering the reader on the same thread.

## Sanitizer coverage

Run the regression suite with:

```sh
swift test --sanitize=address
swift test --sanitize=thread
```

These commands instrument the Swift and Objective-C++ package targets. The
distributed TagLib XCFramework is a precompiled Release binary, so its internal
instructions are not sanitizer-instrumented. Fully instrumented upstream
diagnosis requires a separate diagnostic TagLib build.
