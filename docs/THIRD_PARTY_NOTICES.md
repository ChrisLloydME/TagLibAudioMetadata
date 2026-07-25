# Third-party notices

This document identifies the third-party components distributed with the
`TagLibAudioMetadata` Swift Package. It is informational and is not legal
advice; the included license texts are authoritative.

## TagLib

| Field | Value |
| --- | --- |
| Version | 2.1.1 |
| Tag | `v2.1.1` |
| Commit | `7d86716194777e0294453bfdc9dd170bd033e1f4` |
| Upstream | <https://github.com/taglib/taglib> |
| Distributed form | Dynamic `TagLib.framework` slices in release asset `taglib-binary-2.1.1-r1` |
| Source modifications | None |
| Build recipe | `scripts/build-taglib-xcframework.sh` |

TagLib is the audio metadata engine used behind `CTagLibBridge`. The repository
does not compile or retain a TagLib source fallback. The build script fetches
the exact upstream revision, rejects a modified source tree, and creates the
macOS and iOS dynamic framework slices.

TagLib is dual-licensed; distributors may choose either:

- GNU Lesser General Public License version 2.1 (LGPL-2.1). Exact text:
  `ThirdParty/TagLib/COPYING.LGPL`.
- Mozilla Public License version 1.1 (MPL-1.1). Exact text:
  `ThirdParty/TagLib/COPYING.MPL`.

### Distribution notes

Under the LGPL-2.1 option, preserve notices and the license text, provide or
offer the corresponding source as required, and do not prohibit lawful reverse
engineering for modification/debugging of the library. Dynamic linking and a
separately embedded `TagLib.framework` support replacement/relinking more
directly than a static copy, but do not remove other license obligations.

Under the MPL-1.1 option, preserve required notices and make covered source
files, including any modifications to them, available under the MPL terms. This
artifact is built from unmodified official source.

Applications are responsible for including the chosen license notices in their
distribution and for satisfying the chosen license. Consult counsel for the
requirements of a specific distribution model or jurisdiction.

## utf8cpp

| Field | Value |
| --- | --- |
| Component | utf8cpp |
| Commit | `df857efc5bbc2aa84012d865f7d7e9cccdc08562` |
| Upstream | <https://github.com/nemtrif/utfcpp> |
| Relationship | TagLib 2.1.1 submodule used while compiling the framework |
| License | Boost Software License 1.0 |
| Exact text | `ThirdParty/TagLib/utfcpp-LICENSE` |

utf8cpp is compiled as part of the TagLib implementation; it is not exposed as
a separate SwiftPM product.

## TagLibAudioMetadata bridge and Swift facade

The Swift and Objective-C++ code authored for this package is released under
the MIT License. The exact text is in the repository-root `LICENSE` file.

## Component summary

| Component | Version/revision | License | Distributed location |
| --- | --- | --- | --- |
| TagLib | 2.1.1 / `7d867161…` | LGPL-2.1 or MPL-1.1 | Dynamic XCFramework |
| utf8cpp | `df857efc…` | Boost Software License 1.0 | Compiled into TagLib framework |
| TagLibAudioMetadata | Repository version | MIT | Swift facade and Objective-C++ bridge |

The exact corresponding upstream source can be obtained with:

```sh
git clone --branch v2.1.1 --depth 1 https://github.com/taglib/taglib.git
git -C taglib submodule update --init --depth 1 3rdparty/utfcpp
git -C taglib rev-parse HEAD
git -C taglib/3rdparty/utfcpp rev-parse HEAD
```

The build script verifies both printed revisions before producing an artifact.
