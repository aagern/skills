## Skills for Ai

### rust-code-review.md
Based on: 
* [RustManifest](https://github.com/RAprogramm/RustManifest)
* [Code Review Methodology](https://github.com/RAprogramm/RustManifest/blob/main/code-review-methodology/en/INDEX.md) 

### Rust-Code-Review/
Review procedure (`SKILL.md`) plus the full rule set it enforces (`Rust_rules.md`).
Based on:
* [minimaxir/AGENTS.md](https://gist.github.com/minimaxir/86de3cc8f628079d8337e70924b3411d)

`sync_check.sh` guards against drift between three copies of this procedure,
which are not all the same kind of thing:

| Copy | Path | Kind |
|---|---|---|
| `repo` | `Rust-Code-Review/` here | the authored source, written for a local model |
| `claude` | `~/.claude/skills/rust-code-review/` | a **variant**, worded for Claude Code |
| `opencode` | `~/.config/opencode/skill/rust-review/` | a **deployed copy** of `repo` |

`repo` and `claude` are deliberately not identical — tool names and command
wording differ with the audience — so they cannot be kept in step by diffing
them. The script instead holds the rule inventory as label-and-pattern pairs and
asserts every rule appears in all three copies, reporting `DRIFT` with the names
of the copies that lack it, and `GONE` when a rule has vanished from every copy
and should be dropped from the list.

`opencode` is a different case: it is a deployment, not a variant, so it must be
byte-identical to `repo`. OpenCode does not follow symlinks, so the files are
copied, which makes a stale deployment possible — the script therefore also
`cmp`s both `SKILL.md` and `Rust_rules.md` against the repo source and reports
`STALE` with the `cp` command needed to fix it. The rules file is checked because
the rules are the law, and a stale law is worse than a stale procedure.

It takes the three `SKILL.md` paths as optional arguments, defaulting to this
folder, `~/.claude/skills/rust-code-review/SKILL.md` and
`~/.config/opencode/skill/rust-review/SKILL.md`. `Rust_rules.md` is resolved
beside whichever `repo` and `opencode` paths are in use. Exit codes: `0` in sync,
`1` drift or stale deployment, `2` a path could not be read — so it works as a
pre-commit hook.

### Creative-Stream/
A dialogue skill for working through a stream of raw ideas: capture them
without judging, probe each one through a different lens per question (at most
five, then it asks whether to move on), cross the ideas against each other,
weigh each on a fixed card (YAGNI, ready-made alternatives, what it takes,
cost in time, tokens and money, the case against it, a proposed verdict, and a
SMART goal for each pursued idea), and keep the result in an Obsidian note in
`_notes/` that a later session can resume from. Every claim carries a label:
said by the user, recalled from memory, fetched from a source, assumed, or
open. It asks before every web search. After the report it offers to start an
OpenSpec project in `_scratch/` from the pursued idea.

Built from two Orchestra Research skills,
[creative-thinking-for-research](https://www.skills.sh/orchestra-research/ai-research-skills/creative-thinking-for-research)
and
[brainstorming-research-ideas](https://www.skills.sh/orchestra-research/ai-research-skills/brainstorming-research-ideas),
whose lenses are merged in `lenses.md` and retuned for presales, teaching,
multimedia and Rust tooling.

Live copy: `~/.claude/skills/creative-stream/`. OpenCode reads that directory
too, so one copy serves both harnesses.

`tests/` holds the six scenarios the skill was built against (capture, probe
cap, unverified claim, resume, write-up, weigh), `rubric.md` to score replies
by hand, and `run_local.sh` to run them through OpenCode on the local models,
with (`green`) or without (`red`) the skill. The skill passes all six on
Claude and on Qwen3.8-27B.
