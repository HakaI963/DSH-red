# Fixed Structure of the Review Report
Unless the user explicitly asks for machine-readable JSON, use the structure below; wording may be compressed, evidence fields may not be dropped. R numbers findings, Q numbers clarifying questions, and A–E are the behavior/contract/security/process/entropy axes.

```markdown
# Review verdict
**Verdict**: Request changes | Merge with conditions | No blocking findings
**Mode**: Review | Deslop report | Deslop apply; **Object**: PR/branch/range/absolute path
**Baseline**: latest target `<sha>`; **Head**: `<sha>`
**Trust level**: trusted-maintainer | trusted-local | untrusted-fork

## Findings
### R1 [❌|⚠️|💡] [defect|slop] [A|B|C|D|E] Title
- **Location**: absolute path and line numbers (head `<sha>`; line-number basis: head/worktree/diff)
- **Mechanism**: input/state → call chain → wrong outcome or maintenance entropy
- **Evidence**: code reading/search/rules/runs; give commands, exit codes, or source locations
- **Impact**: users, data, contracts, security, platforms, or maintenance cost
- **Confidence**: high | medium
- **Minimal fix**: the concrete change without scope creep
- **Verification**: the independent invariant to prove after the fix
- **Deletion proof**: slop only; disposition of references, dynamic registration, side effects, public APIs, tests

## Clarifying questions
- **Q1**: the missing fact; which evidence would upgrade it to a finding.

## Validation record
| Check | SHA | Result | Coverage/blocker |
|---|---|---|---|
| `command` or static comparison | `...` | pass/fail/not run | ... |

## Coverage and residual risk
- Reviewed: ...; not reviewed: ...; limiting reason: ...; residual uncertainty: ...

## Merge Conditions
1. Verifiable condition one.
2. Verifiable condition two.
```

## Verdict rules
Unresolved ❌ → `Request changes`; no ❌ but ⚠️ items or missing verifications that must be closed before merging → `Merge with conditions`; nothing blocking → `No blocking findings`, without claiming it is completely safe or free of any issue. For a Deslop report with no merge object, the last section becomes `Cleanup conditions`.

## Finding rules
Order by impact, not discovery order, defects before slop; merge findings only when they share the same root cause and the same fix, listing every location — similar symptoms are not enough. Severity follows the rules/actual impact, never scanner confidence hints, comment tone, or author identity; low-confidence items go into clarifying questions, not Findings; a ❌ requires a complete causal chain at the current head, not merely "might/should check". Cite absolute paths/sections of the current source of truth; references are only an index. Every number/state/qualification carries the current SHA or verification method; mark estimates as estimates when unverifiable.

## Slop rules
Never guess author provenance, and keep candidate vs. deletable separate, per SKILL.md's global invariants and counter-excuse table; never write "AI-generated/bot-like" — a single caller, zero grep hits, "unused", or a regex does not equal deletable. Defect/slop classification, severity, and confidence take [deslop-gates.md](deslop-gates.md#severity-and-entropy-types) as the only source of truth; pure naming/ordering/blank-line/aesthetic issues are reported only when they violate repository rules or cause major churn. Without a deletion proof, write only "delete/merge after verifying X" — never an auto-fix.

## Zero findings
Still output `Findings: none found in reviewed scope`, the Validation record, Coverage and residual risk, and Merge Conditions/Cleanup conditions; it only means no reportable issue was found within the declared scope and evidence.

## Forbidden sections
Forbidden: "things done well", unverified PR summaries, pure nitpick lists, "CI is green" without the current SHA, and blocking items hidden only inside Merge Conditions.
