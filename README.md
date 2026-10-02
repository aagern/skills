## Skills for Ai

### rust-code-review.md
Based on: 
* [RustManifest](https://github.com/RAprogramm/RustManifest)
* [Code Review Methodology](https://github.com/RAprogramm/RustManifest/blob/main/code-review-methodology/en/INDEX.md) 

### Rust-Code-Review/
Review procedure (`SKILL.md`) plus the full rule set it enforces (`Rust_rules.md`).
Based on:
* [minimaxir/AGENTS.md](https://gist.github.com/minimaxir/86de3cc8f628079d8337e70924b3411d)

`sync_check.sh` guards against drift between two copies of this procedure: the
`SKILL.md` here, written for a local model, and a second copy adapted for a
different agent harness. The two are deliberately not identical — tool names and
command wording differ with the audience — so they cannot be kept in step by
diffing them. The script instead holds the rule inventory as label-and-pattern
pairs and asserts every rule appears in both files, reporting `DRIFT` when one
side gained a rule the other lacks and `GONE` when a rule has vanished from both
and should be dropped from the list. It takes the two `SKILL.md` paths as
optional arguments, defaulting to this folder and
`~/.claude/skills/rust-code-review/SKILL.md`, and exits non-zero on drift, so it
works as a pre-commit hook.
