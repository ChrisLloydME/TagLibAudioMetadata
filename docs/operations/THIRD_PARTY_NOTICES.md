# Third-party notices

This document identifies third-party components distributed with
`TagLibAudioMetadata`. It is informational rather than legal advice; the
included license texts are authoritative.

## TagLib

| Field | Value |
| --- | --- |
| Version/tag | 2.3.1 / `v2.3.1` |
| Commit | `54ae7d8ac45755e286a5c574280f48d5bef93aef` |
| Upstream | <https://github.com/taglib/taglib> |
| Distributed form | Dynamic `TagLibAudioMetadataTagLib.framework` slices in release `taglib-binary-2.3.1-r2` |
| Source modifications | None |
| Build recipe | `scripts/build-taglib-xcframework.sh` |

TagLib is the audio metadata engine behind `CTagLibBridge`. The repository has
no TagLib source or static fallback. The build verifies an exact clean upstream
checkout and packages macOS, iOS device, and iOS Simulator dynamic slices.

TagLib is dual-licensed. Distributors may choose either LGPL-2.1 or MPL-1.1.
Exact texts are preserved at `ThirdParty/TagLib/COPYING.LGPL` and
`ThirdParty/TagLib/COPYING.MPL` and inside the binary artifact.

Dynamic linking and a separately embedded framework facilitate replacement and
relinking under the LGPL option, but do not remove other notice, source-offer,
reverse-engineering, or distribution obligations. Under the MPL option,
preserve the required notices and make covered source, including modifications,
available as required. This artifact uses unmodified official source.

## utf8cpp

| Field | Value |
| --- | --- |
| Commit | `819011bb01628fe1aa2f1da9f2c842a48fd5680b` |
| Upstream | <https://github.com/nemtrif/utfcpp> |
| Relationship | TagLib 2.3.1 build dependency compiled into the framework |
| License | Boost Software License 1.0 |
| Exact text | `ThirdParty/TagLib/utfcpp-LICENSE` |

utf8cpp is not exposed as a separate SwiftPM product.

## Package-authored code

The Swift facade and Objective-C++ bridge are released under the MIT License in
the repository-root `LICENSE` file.

## Corresponding source

```sh
git clone --branch v2.3.1 --depth 1 https://github.com/taglib/taglib.git
git -C taglib submodule update --init --depth 1 3rdparty/utfcpp
git -C taglib rev-parse HEAD
git -C taglib/3rdparty/utfcpp rev-parse HEAD
```

The printed revisions must match the table above. Applications distributing the
framework remain responsible for the notices and obligations of their selected
TagLib license.
