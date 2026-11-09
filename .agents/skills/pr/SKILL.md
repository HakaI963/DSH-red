---
name: pr
description: Open or update an internal pull request in ccch1mneyyy/dsh-Go, including writing or rewriting its description. Use for every PR the maintainer creates or edits here, and for /pr. External pull requests are not accepted (see AGENTS.md).
---

Ship the current change as an internal pull request a reviewer can understand from the description alone: why it exists, the shape of the implementation, and what was actually verified. External PRs are never accepted; this skill is only for the maintainer's own branches.

1. One topic per PR. Make sure the change has a clear goal; do not automatically package an implementation as a PR just because some issue exists. Link the issue (if any).
2. Commit and push the branch with itself as its own upstream; never push `main`. Write commit messages as `type(scope): summary` (conventional commits, in Chinese or English consistent with the surroundings). Only stage explicit paths.
3. Read the full diff and the related code, confirming you can explain ownership and behavior; collect the verifications you actually ran.
4. Write the body with the in-repo [PR template](../../../.github/PULL_REQUEST_TEMPLATE.md):
   - **Why the change**: one sentence.
   - **Special things to note**: 1–3 reminders for the reviewer; checks that were NOT run also go here.
   - **Change outline**: the fewest possible diagrams (file tree / call chain / key shapes), one sentence per diagram; no file-by-file running account.
   - **Verification**: the commands actually executed and their results; clearly distinguish real device vs. desktop.
   Write the body in Chinese, one person talking to another.
5. Publish with `gh pr create --body-file` / `gh pr edit --body-file`, then confirm the rendered result with `gh pr view`; report the PR URL, linked issues, and CI status.
