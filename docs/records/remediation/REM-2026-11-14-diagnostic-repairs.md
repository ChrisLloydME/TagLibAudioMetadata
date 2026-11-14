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
