# Independent diagnostic adjudication and repairs

Baseline: `07f1bc9`; branch `codex/diagnostic-native-owner-repairs`. The supplied diagnostic is evidence, not instructions to install its assertions of defective behavior as passing tests.

## Adjudication

- D-01/02/05 are genuine legacy-date fidelity defects. Literal v2.3 owners must be read before engine normalization, unrelated Basic edits must preserve them, and low-level replacements must not silently rewrite them.
- D-03/04/06/07/08/11 are real behavior/verification or native-ownership defects. Basic nil artwork must clear it, version-selected frames need corresponding verification, and write entry points must agree on owners.
- D-09 is explicit documented intent: a typed patch requests a write even when the value compares equal; v2.3 date writes remain read-only. Basic replacement determines differences first. No relaxation is authorized.
- D-10 is a scalar projection limitation, not proven loss: structured date owners remain available. Existing differing owners must survive unrelated edits. No implicit conflict reconciliation is introduced.
- D-12 is an unnecessary rewrite, not reproduced metadata loss; optimize separately without weakening version/validity checks.
- R-01/05/07 expose actual architecture gaps and motivate common planning and capability preflight. R-02 is a real missing staged-readability safeguard; enforce it even without semantic expectations.
- R-03 omits the ctime comparison: normal chmod/ACL changes already alter ctime. Not a demonstrated missed mutation.
- R-04 is intentional fail-closed preservation, R-06 is declared-format versus observed-file capability, R-08 is the documented process-local concurrency boundary, and R-09 is architectural duplication rather than a reproduced transaction defect. None justifies weakening verification.
- G-01 is an environment precondition, not permission to mark the gate green or skip mandatory privilege rejection. Run the same test with the necessary filesystem access.
- G-02 through G-07 identify real missing regression/entry-point coverage. G-08 is a bounded evidence identity limitation requiring separate gate hardening. G-09/10 describe unexecuted scope/intentional opt-ins, not proof that earlier recorded independent runs did not occur.

## First focused results

Five new correct-behavior regressions pass: hand-built TYER/TDAT/TORY independence and Basic title preservation; Basic artwork clear across MP3/MP4/FLAC/ASF; native Movement and Release Type/Status parity; typed ASF advisory; version-selected text verification. Also passed 93 existing XCTest and 24 audit Swift Testing checks, and the capability/contract checks. Full acceptance remains pending. Frame ordering between distinct IDs may normalize; date owner identities and values are compared independently of cross-ID ordering.

## Root-cause consolidation

Basic replacement now computes explicit differences against a full versioned snapshot and uses the Typed Patch planner. Removed the obsolete native read-model replay/preservation layer. This also gives Basic the real MP4-exclusive targets instead of silently ignoring those fields. Empty artwork clears, unchanged arrays/native owners remain omitted, and unknown advisory provenance is preserved. A combined-field regression exposed two additional number-text bugs: native pairs must be emitted after PropertyMap mutations, and an explicit empty text must not recover an old total. Both are fixed and the seven-format regression tests set and clear the pairs. Existing focused suites pass (85 XCTest plus audit/diagnostic Swift Testing); 34 policy tests pass. Eleven diagnostic regressions are mandatory, plus the frozen required-test source/suite inventory rejects duplicate or moved names. Full gates remain pending.

## Full-gate follow-up and native extraction boundary

The first full Debug run correctly rejected the candidate. It exposed MIME-only edits losing picture descriptions, total-only requests being overridden by stale empty number text, and legacy ID3 TXXX aliases surviving removal. These were repaired with exact picture metadata retention, numeric/text intent consistency and alias-group removal in the shared planner. A former DSD test required a rejection solely because the old Basic replay path could not preserve comment/lyric collections. Its replacement is stronger: the now-successful Basic title edit must preserve COMM/USLT/APIC/opaque frames and audio bytes independently; unsupported collection replacement still rejects.

Literal v2.3 date reading now lives once in the native unified extractor, covering direct bridge and facade views, including all 32 extraction masks. The Swift implementation was moved to test-only independent byte evidence. Hand-built tags cover experimental, extended-header and actual FF unsynchronization cases. Unknown compressed/encrypted date representations reject explicitly. Native Basic bridge replacements of v2.3 remain unsupported; native structured date edits validate legacy widths/TDAT DDMM in the facade. Complete false-success or skipped-verification behavior is not used as a workaround.

Current mandatory declaration floors are 168 XCTest and 198 Swift Testing; policy coverage is 34 tests. The native owner parity vector freezes 15 low-level MP4 fields, legacy flags require four parameterized cases, and combined numeric/text set-clear requires seven formats. A source/suite manifest rejects test moves, duplicate names and commented/string stand-ins before name-based runtime evidence can be accepted. The plain Swift Testing log still lacks per-line suite identities; this source-bound evidence is not a signature proving an arbitrary externally supplied log genuine.

## Consumer and final parity follow-up

The full Debug candidate `c552eea` passed 168 XCTest (two original opt-in skips) and 198 Swift Testing declarations in 43 suites. The AudioMator run executed all 580 tests; one existing test asserted the old synthesized YEAR/empty DATE behavior. On a dedicated app branch those assertions now require literal YEAR 2004 and TDAT 0304; readonly-date rejection and unchanged bytes remain asserted. No production app code changed. Final integration will be rerun.

A final low-level parity check also covers FLAC RELEASETYPE/RELEASESTATUS/MOVEMENTNAME, and ASF advisory clearing retires recognized case variants. The frozen test manifest must contain exactly every required Swift Testing name, not just its existing entries; policy coverage is now 35 regressions.
