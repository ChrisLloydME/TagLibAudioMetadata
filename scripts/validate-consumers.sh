#!/usr/bin/env bash
# Strengthened package-owned public consumers: real writes through the declared
# products and independent native assertions, with no @testable access.
set -euo pipefail
cd "$(dirname "$0")/.."
FIXTURES="$PWD/Tests/TagLibAudioMetadataTests/Audio"
OPTIONS=(--disable-sandbox --disable-keychain --disable-netrc
  -Xswiftc -warnings-as-errors -Xcc -Werror)
swift run --package-path IntegrationTests/Consumer "${OPTIONS[@]}" \
  TagLibAudioMetadataConsumer "$FIXTURES/testAudioFile.m4a"
swift run --package-path IntegrationTests/Consumer "${OPTIONS[@]}" \
  TagLibAudioMetadataLowLevelConsumer "$FIXTURES/testAudioFile.mp3"
