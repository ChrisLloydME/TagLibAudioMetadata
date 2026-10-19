# <Record title>

| Field | Value |
| --- | --- |
| Record ID | `AUD-YYYY-MM-DD-short-slug` |
| Type | Audit / review / remediation / verification / migration / maintenance / incident / documentation |
| Date | `YYYY-MM-DD` |
| Status | Final |
| Examined revision | `<commit/tag/range>` |
| Branch | `<branch or not applicable>` |
| Environment | `<OS, Xcode, Swift, dependency versions>` |
| Supersedes | `none` |
| Superseded by | `none` |
| Related records | `none` |
| Scope | <What was examined and what was deliberately excluded.> |

## Summary

<Verdict, confidence, and the most important findings. State whether the record is current for its revision only.>

## Scope and revision

<Repository, branch, commit, tags, working-tree state, and exclusions.>

## Method

<Source inspection, runtime probes, tests, external tools, and independent oracles. Name what was not used.>

## Findings

### F-01 — <Short title>

- **Severity:** High / Medium / Low / Informational
- **Confidence:** Confirmed / Unverified
- **Status:** Open / Fixed / Bounded / Not a defect
- **Evidence:** <commands, source paths, test names, external output>
- **Impact:** <what a caller or maintainer should understand>

## Repairs or recommendations

<What changed, or what should change. Do not claim a recommendation was implemented. Reference commits and tests.>

## Verification

| Check | Result | Counts / limits |
| --- | --- | --- |
| <command or check> | <pass/fail/not run> | <environment and scope> |

## Remaining limitations

<Unverified behavior, accepted boundaries, and follow-up work. Do not imply completeness.>

## References

- Commits: `<hash>` <subject>
- Tests: `<path>` / `<function>`
- Current documentation: <links>
- Related records: <links>
