# TagLibBinaryPackage

This is the isolated Swift Package boundary for the prebuilt dynamic TagLib
dependency used by `TagLibAudioMetadata`.

- Product: `TagLibBinary`
- Binary target / Clang module: `TagLib`
- Artifact: `Artifacts/TagLib.xcframework`
- Upstream source: unmodified TagLib `v2.1.1`
- Upstream commit: `7d86716194777e0294453bfdc9dd170bd033e1f4`
- utf8cpp submodule commit: `df857efc5bbc2aa84012d865f7d7e9cccdc08562`
- Platforms: macOS 13+ and iOS 16+ (device and Simulator)
- License texts: `Licenses/`

Rebuild the artifact from the repository root:

```sh
scripts/build-taglib-xcframework.sh --replace
```

The build script clones and verifies the exact upstream commits, builds
dynamic frameworks with CMake, adds only framework packaging metadata, and
creates the XCFramework. It does not patch TagLib source files and does not use
Homebrew or a system-installed TagLib.

The package is mounted by the repository root `Package.swift`; applications
normally depend only on the root `TagLibAudioMetadata` product. See
`../../docs/INSTALLATION.md` for embedding, signing, offline use, diagnostics,
and the upgrade procedure.
