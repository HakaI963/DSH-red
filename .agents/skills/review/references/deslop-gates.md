# dsh-Go Cleanup Criteria and Classification

This file defines the types, severity, confidence, and deletion proofs for review findings; the [report format](report-contract.md) governs presentation and the final verdict. Repository constraints still follow [AGENTS.md](../../../../AGENTS.md) and [CONTRIBUTING.md](../../../../CONTRIBUTING.md); do not copy or invent runtime, protocol, or generated-artifact rules here.

## First decide whether it is worth reporting

1. **Candidate**: duplicated code, a single caller, an empty catch, a fallback, a stale comment, or a scanner warning only says "needs checking" — it cannot be judged wrong or deleted outright.
2. **Finding**: points to a currently reachable wrong outcome, contract violation, or concrete maintenance cost, and can be located in the current change; it cannot rest on author style, line counts, or "might be a problem later".
3. **Modifiable item**: beyond being a finding, proves that deleting or merging loses no behavior, ownership boundary, compatibility, or regression coverage. Without that proof, only report or ask — never clean up automatically.

## Severity and entropy types

| Class | Basis | Review axis |
|---|---|---|
| defect | Already concrete wrong behavior, or violates a public contract, security, or a hard repository rule; even if it superficially looks like a redundancy, comment, or test issue, classify by actual impact | A–D |
| slop | No proven behavioral defect, but double maintenance, no-benefit state/exception boundaries, misleading docs, or review cost unrelated to the topic | E |
| Pure preference | Only naming, blank lines, ordering, or a personally more elegant style, without violating an explicit repository rule | Do not report |

- **❌ Blocking**: the current change introduces a provable substantive error, security problem, or hard-rule violation; it cannot be accepted by hiding the risk or editing test expectations.
- **⚠️ Needs closure**: clear impact, or required verification still missing; before merging it must be fixed, evidenced, or the maintainer must explicitly accept the concrete residual risk. Never use it to dress up a purely speculative defect.
- **💡 Optional improvement**: evidence is sufficient but the impact is limited to minor maintenance cost; it must not masquerade as a merge blocker.

Confidence is independent of severity: **high** means the causal chain, location, and impact all have direct evidence; **medium** means the mechanism is certain but the impact scope is still qualified. Items with only guesswork, unknown callers, or missing key premises go into clarifying questions, not published as low-confidence findings. High confidence does not equal high severity.

## Proofs before deleting or merging

Always check static references, string/dynamic registration, public APIs, module side effects, generation sources, test fixtures, and platform branches. "No search matches" must not be treated as "no callers".

| Candidate | Evidence required |
|---|---|
| Unused symbol or dead path | Check real entry points: Dart exports, JS package exports, Cordis services/events, Riverpod providers, platform channels, plugin protocols, generators; unknown public consumers must not be deleted outright |
| Duplicate helper | Compare input boundaries, error semantics, return values, lifecycles, platform differences, and side effects; identify the authoritative implementation first, then migrate callers; textual similarity does not mean semantic equivalence |
| Single-caller wrapper | Prove it carries no resource ownership, third-party adaptation, version compatibility, platform isolation, or test-substitution boundary; one call site is not evidence of redundancy |
| catch / fallback / defensive branch | Prove it swallows real errors, fakes success, hides contract drift, or fully overlaps an existing check with no independently reachable path; resource cleanup, legacy-host compatibility, and disconnect/async state isolation must not be deleted just because there are many branches |
| Comment or doc | Prove it contradicts the current implementation, entry point, or command; keep short notes explaining invariants, compatibility reasons, and platform limits |
| Test or snapshot | Prove deletion loses no independent invariant or platform coverage; per the [verification map](verification-map.md#anti-false-green-checks), check the bad baseline and the independent decision basis — never mask a failure by updating a golden or loosening an assertion |
| Unrelated change | Point out its irrelevance to the current goal and the added review/rollback cost; prefer splitting it out, and never use it as an excuse to widen the cleanup scope |

## DSH Go boundaries

- Protect user input and session facts, request idempotence, and resource ownership first, then consider reducing code; never turn engine facts into client-side guesses in the name of slimming.
- The Flutter native UI, the pure Dart client, the bridge, and the patched runtime have different responsibilities; cross-side verification follows the [contract gates](contract-gates.md) — do not mistake architectural layering for duplicate implementation.
- Tests start from focused regressions; whether to widen is decided by change risk and evidence; CPU, temperature, and the available toolchain on a phone are real limits — record stops and non-runs truthfully.
- This file does not depend on another project checkout, a global skill directory, or external scanning scripts. When deploying the repository, keep the whole `.agents/skills/review/` directory, loaded by a Coding Agent that supports project skill directories.

Execution order and authorization boundaries follow "Phase 6" of [SKILL.md](../SKILL.md); do not build a separate cleanup process. Without authorization for the current action, never modify files, publish comments, or commit code automatically.
