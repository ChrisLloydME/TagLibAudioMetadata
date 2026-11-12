# Native owner state coverage — 2026-11-11

Branch: `codex/metadata-state-coverage-repairs`, based on published 0.7.2 (`5e6f604b0e9df244f4b69608261407d2ab758788`). This is an unreleased candidate. Publication remains maintainer-owned.

## Root cause

The old semantic matrices exercised standard scalar values with one target field and a fixed sibling seed. Comment/Lyrics were classified as specialized rather than included in the MP4 matrix. They entered PropertyMap before container routing. Engine DATE conflates several native projections, so replay could create a missing YEAR, overwrite another date, or fail verification. Low-level readers independently reintroduced projection-derived dates. Writer-specific preservation was not exercised across all public entry points.

New package-only matrices reproduced the app-reported MP4 failure and additional ID3/Xiph/ASF state failures without importing or launching AudioMator. The early cross-writer run reported 248 issues; after the first repair 24 Xiph low-level Year projection failures remained. No expected-failure annotation, skipped reproduction or weakened native expectation was added.

## Repairs

- Native MP4 Comment/Lyrics routing; shared native-date retention for engine replay across raw, semantic-custom and structured paths.
- Lossless native ID3 date retention with explicit ownership and RAII; detached frame pointers are held in `std::vector`, not an owning TagLib FrameList copy.
- Native-owner low-level date extraction, unchanged unknown-array retention, structured MP4 exact text, custom-name spelling retention and independent Artist/ARTISTS.
- ASF native absence verification and distinct raw YEAR/DATE comparison; unchanged whole-map arrays retain their exact values.

## Required evidence

See [matrix inventory](../../operations/MAPPING_TEST_STRATEGY.md#sparse-state-and-write-surface-acceptance). The new state matrices have 8,282 parameterized cases. Existing field/lifecycle, malformed probe, rejection, artwork, numbering, version/conflict, atomicity, privilege and concurrency tests remain mandatory.

Final full-gate results are recorded below after execution. Focused probes are diagnostic evidence, never full release acceptance. `TAGLIB_DISABLE_MANIFEST_SANDBOX=1` and expanded filesystem access are required on this host for manifest/module caches and privilege prerequisites.

## Limits

This does not certify arbitrary media, every tag version/encoding, every raw native collection, or an embedding application. Existing ID3v2.3 independent-date writes remain unsupported. The low-level model is scalar; native-array preservation claims are limited to explicitly covered unchanged projections. No sanitizer/device/minimum-OS/external-decoder run is implied.

## Final validation

Both final gates passed on the final production/test source tree:

| Command/check | Result | Evidence |
| --- | --- | --- |
| `TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh debug` | accepted; 158 XCTest (156 pass, two original optional skips), 179 Swift Testing declarations in 41 suites; zero failures | `.build/test-evidence/debug-20261111-215923-92576/summary.json` and `tests.log` |
| Same gate in `release` | accepted; same declaration/skip counts, zero failures | `.build/test-evidence/release-20261111-220146-92815/summary.json` and `tests.log` |
| `python3 -m unittest discover -s scripts/tests` | 24 policy tests passed | Includes shrunk/deleted state matrices and declaration-floor rejection |
| `python3 scripts/check-docs.py` | 53 Markdown files passed | Generated API reference checked against current source |
| Facade independent consumer | passed; 37 readable extensions | `swift run --disable-sandbox --disable-keychain --disable-netrc --package-path IntegrationTests/Consumer TagLibAudioMetadataConsumer` |
| Low-level independent consumer | passed | Same command with `TagLibAudioMetadataLowLevelConsumer` |
| Complete gate parser applied to the real filtered ASF log | `accepted: false` as required | Missing frameworks/required matrices cannot be waived by a zero focused-run status |

Both full gates compiled production and tests with Swift/C warnings as errors. The intentional deprecated-API test exception remains unchanged. The mandatory privilege rejection test passed with expanded filesystem access. All 8,282 new state cases and existing required matrices have named execution evidence; no production test was skipped to make the candidate pass.

The additional ASF custom-field route has independent set/replace/remove tests across eight date masks, including existing mixed-case aliases. ASF native absence is authoritative in both low-level reads and semantic verification. Its independent Content Description parser has a literal wire vector and rejects malformed lengths/truncation/trailing data.

No commit, tag, push, TagLib XCFramework rebuild or publication was performed. The accepted candidate is a dirty working tree on the named branch; the published 0.7.2 tag does not contain these repairs.

The final runs include independent seed preconditions: each date mask's actual native presence and literal values are checked before mutation, and the all-owner MP4 matrix decodes every seeded sibling's value. Incorrect/missing fixture setup cannot turn multiple declared states into the same passing input. `summary.json` records actual/minimum named case counts and suite totals; the nine new state matrices sum to 8,282 observed executions per configuration.

## Addendum — repository state after validation

This record was written while the validated evidence was still an uncommitted working tree. The repair branch has since been committed, with `52dd4f2` recording this document and the preceding commits carrying the production and test changes, and pushed to `origin/metadataStateCoverageRepairs`. No version bump, tag, release, binary rebuild, or publication was performed. The phrase "dirty working tree" above describes the validation-time state, not the current branch state; the evidence and limits in this record are unchanged.

## Addendum — 0.7.3 release inclusion

The repair branch was merged into `main` as `e9337f2` for the `0.7.3` release. The `0.7.3` release includes these state-coverage repairs and the final documentation. Tag creation and publication remain maintainer-owned and are not part of this record.
