# TagLib 2.1.1 binary configuration

| Setting | Value |
| --- | --- |
| TagLib tag | `v2.1.1` |
| TagLib commit | `7d86716194777e0294453bfdc9dd170bd033e1f4` |
| utf8cpp commit | `df857efc5bbc2aa84012d865f7d7e9cccdc08562` |
| Library type | Dynamic framework (`BUILD_FRAMEWORK=ON`, `BUILD_SHARED_LIBS=ON`) |
| Build type | `Release` |
| C++ visibility | Hidden, with TagLib export annotations |
| zlib | Enabled; linked to the Apple SDK system zlib |
| C bindings / examples / tests | Disabled for the distributed artifact |
| Formats | All TagLib 2.1.1 defaults enabled |
| macOS | 13.0+, `arm64` and `x86_64` |
| iOS device | 16.0+, `arm64` |
| iOS Simulator | 16.0+, `arm64` and `x86_64` |
| Framework identifier | `org.taglib.TagLib` |
| Install name | `@rpath/TagLib.framework/TagLib` |
| Reference toolchain | Xcode 26.6 (17F113), Apple Clang 21.0.0, CMake 4.4.0, Ninja 1.13.2 |

The committed framework bundle metadata and module map are packaging files,
not modifications to the TagLib source tree. Headers and binaries in each
XCFramework slice are produced by the same CMake invocation and configuration.
`CHECKSUMS.txt` records every committed artifact file. Toolchain and SDK changes
can change output bytes and must be reviewed even when the pinned source and
options are unchanged.
