---
name: rust-review
description: Review and refactor Rust code against this project's quality rules — panics, error handling, docs, tests, clones, allocations, naming, security. Use this skill whenever asked to review Rust code, audit a crate, check a Rust project before commit or merge, clean up or refactor Rust, or whenever you are about to hand Rust code back to the user. Also use it when a cargo build, clippy run, or test run needs interpreting.
---

# Rust review and refactor

Full rules: `Rust_rules.md` next to this file. This skill is the working
procedure; the rules file is the law. Read the relevant section of
`Rust_rules.md` when a finding needs justification.

A second copy of this procedure lives at
`~/.claude/skills/rust-code-review/SKILL.md`, written for Claude Code. The two
must stay in step on substance — only the tooling wording differs. After editing
either, run `./sync_check.sh` in this folder.

## How to work (read this first)

You are reviewing real code someone will ship. Three habits matter more than
breadth:

1. **Run the command, then report.** Never write "tests pass" or "no clippy
   warnings" from reading the code. Run it and paste the output. A review built
   on guesses is worse than no review, because it hides the defects it claims to
   have checked.
2. **One change at a time.** Make a fix, run `cargo test`, then make the next.
   Batched edits that fail leave you unable to tell which one broke.
3. **Say what you did not check.** An honest gap ("did not audit async
   cancellation") is useful. A silent gap is a lie by omission.

Judgement beats volume: three real defects with file:line and a fix beat twenty
style nits.

## Stage 0 — Orient

```bash
cd <crate-root>
cat Cargo.toml                 # deps, edition, features
ls src tests benches 2>/dev/null
wc -l src/*.rs tests/*.rs 2>/dev/null
```

Read every file you intend to review. A crate under ~1000 lines: read all of it
before judging anything. Reviewing a function without its callers produces
confident nonsense.

Note which dependency features are actually used. A feature enabled in
`Cargo.toml` that no code touches is a finding: it costs build time and attack
surface for nothing.

## Stage 1 — Automated gates

Run all four. Paste output verbatim. Any failure is **Critical** and blocks the
rest of the review until fixed or explained.

```bash
cargo fmt --check              # or: cargo +nightly fmt -- --check
cargo clippy --all-targets -- -D warnings
cargo test --all
cargo test --doc
```

If `cargo clippy` is missing: `rustup component add clippy`. If the crate needs
nightly rustfmt features, use the `+nightly` form.

## Stage 2 — Panic audit

```bash
rg -n "\.unwrap\(\)|\.expect\(|panic!|unreachable!|todo!|unimplemented!" src/
rg -n "\.unwrap\(\)|\.expect\(" tests/
```

In `src/`, every hit is Critical unless the panic is provably unreachable *and*
carries a message saying why. `.unwrap()` is never acceptable in library code;
`.expect("…")` only for an invariant that cannot fail, with the reason in the
message.

The question that decides it: **is this value configuration or an invariant?**
An API key, a path, a parsed file — configuration, so it belongs in a `Result`.
A slice index you just bounds-checked — an invariant, so `expect` with the
reason is honest.

```rust
// Panics on a missing key — the caller cannot react
let value = map.get("k").unwrap();

// Propagates — the caller decides
let value = map.get("k").ok_or(ConfigError::MissingKey("k"))?;
```

In tests, prefer `?` with `-> Result<(), Box<dyn std::error::Error>>` over
`unwrap()`, so a failure prints the error instead of a bare panic line.

## Stage 3 — Error handling

| Rule | Why it matters |
|---|---|
| Library errors are custom types via `thiserror` | A caller can match on the variant; a `String` forces string parsing |
| Application errors use `anyhow` with `.context(…)` | Context turns "file not found" into "reading config.toml: file not found" |
| Fallible functions return `Result<T, E>`, never a sentinel | `-1` and `""` get silently used as data |
| Errors propagate with `?` | Manual match-and-rewrap buries the happy path |

Flag any `Box<dyn Error>` in a public library signature: it erases the error
type, so callers cannot handle specific failures.

## Stage 4 — Code quality

```bash
rg -n "\.clone\(\)" src/           # justify or remove each
rg -n "to_string\(\)|String::from|format!" src/   # allocation in hot paths?
rg -n "static mut|lazy_static|once_cell" src/     # global mutable state
find src -name "mod.rs"            # should be module_name.rs instead
```

- Every `.clone()` needs a reason. Cloning an `Arc` or a `reqwest::Client` is
  cheap and correct; cloning a `String` or `Vec` per request is a defect.
- Prefer `&str` over `String`, `&[T]` over `Vec<T>` in parameters. Use
  `Cow<'_, str>` when ownership is conditional.
- `Vec::with_capacity(n)` when the size is known.
- Any network client needs a timeout. A client built with defaults hangs
  forever on a wedged peer, which in an unattended service is a silent stall
  instead of a visible error. Set both a connect timeout and a request ceiling.
- Unbounded buffering — whole request bodies, unbounded channels — is a memory
  risk under concurrency. Name it even when you do not fix it.
- No `mod.rs` files; use `module_name.rs` instead.
- Functions over ~50 lines or with more than 5 parameters: split, or group the
  parameters into a struct.
- Return early instead of nesting; use iterators where they read better than a
  loop, and a plain loop where an iterator chain would not.
- No wildcard imports outside preludes and `use super::*` in test modules.

## Stage 5 — Naming

| Context | Convention |
|---|---|
| variables, functions, modules | `snake_case` |
| structs, enums, traits | `PascalCase` |
| constants, statics | `SCREAMING_SNAKE_CASE` |

Names carry context: `create_user_handler`, not `create`. Reject single-letter
names outside short closures and loop counters.

## Stage 6 — Documentation

Every public item needs a doc comment. Convert explanatory `//` comments on
public items into `///` — an inline comment never reaches IDE hover or
`cargo doc`.

Required sections: `# Errors` when returning `Result`, `# Panics` when it can
panic, `# Safety` for `unsafe`, `# Examples` for public functions,
`# Performance` for non-obvious cost.

Delete comments that restate the code. `// increment i` next to `i += 1` costs
the reader time and earns nothing. Keep comments that explain *why* — a
workaround, a protocol quirk, an ordering constraint.

The audience here is a Python expert and Rust novice: comment the Rust-specific
reasoning (why `?`, why this lifetime, what the borrow checker is enforcing,
why an iterator chain over a loop), not the obvious.

## Stage 7 — Tests

```bash
cargo test --all -- --nocapture
rg -n "#\[test\]|#\[tokio::test\]" -c src/ tests/
```

- Every public function and every error path has a test.
- External dependencies (HTTP, DB, filesystem) are mocked or served by a local
  fixture, so the suite runs offline and in parallel.
- Arrange-Act-Assert, one behaviour per test, descriptive test names.
- No commented-out tests. Delete them or fix them.

## Stage 8 — Security

```bash
rg -ni "api[_-]?key|secret|token|password|bearer " src/ tests/
rg -n "unsafe" src/
```

Hardcoded credentials are Critical. Secrets come from the environment or a
config file outside the repo; `.env` belongs in `.gitignore`. Never log a
secret — check what `error!`/`debug!` calls interpolate. `unsafe` needs a
`# Safety` comment stating the invariant the caller must uphold.

A struct holding a token should **not** derive `Debug`, even though the rules
ask to derive it: a derived `Debug` is how secrets reach log files. State the
deviation and the reason rather than following the rule blindly.

## Severity tiers

**Critical — block**: panics in production paths, hardcoded secrets, failing
tests or doctests, `unsafe` without justification, data loss or corruption.

**Important — fix before merge**: clippy warnings, missing docs on public API,
missing error handling, untested public functions, unjustified allocation in a
hot path.

**Minor — same PR or follow-up**: naming, redundant comments, cosmetic clones,
missing `# Examples`.

## Output format

```
## Stage 1 — Automated gates
[verbatim command output]

## Critical
- src/lib.rs:42  <defect> — <required fix>

## Important
- src/main.rs:17  <defect> — <required fix>

## Minor
- src/lib.rs:88  <defect> — <suggested fix>

## Not checked
- <area and why>

## Summary
X critical, Y important, Z minor.
Verdict: BLOCK / APPROVE WITH FIXES / APPROVE
```

## Refactor mode

When asked to fix rather than only report:

1. Review first. You cannot fix safely what you have not read.
2. Fix Critical, then Important, then Minor. Stop at any point the user's scope
   ends.
3. After each fix: `cargo test --all`. If it fails, fix or revert before moving
   on.
4. Behaviour-preserving changes only, unless the user asked for a behaviour
   change. A refactor that quietly alters an error path is a new bug.
5. When a fix needs a new test, write the test first and watch it fail — that is
   the only proof the test tests anything.
6. Close with the full gate suite from Stage 1 and paste the output.
7. If the crate runs as a service (launchd agent, systemd unit), a passing
   `cargo build` does not mean the running process changed. Rebuild in release,
   restart the service, and probe it.

Two edit traps worth avoiding, both seen in practice:

- `cargo fmt` rewrites files, which invalidates any exact-string patch you had
  prepared. Re-read a file after formatting it, before the next edit.
- A find-and-replace that silently matches nothing leaves the file unchanged and
  the build stale, and you will report a fix you never made. Confirm each edit
  landed, or fail loudly when the pattern misses.

Report what changed as a table: file, what, why. Do not paste whole files back
at the user; they have the diff. Own any defect you introduced during the
refactor in the same table rather than leaving it for the user to find.

## Before handing back

```bash
cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test --all && cargo test --doc
```

All four green, every public item documented, no commented-out code, no debug
`println!`/`dbg!`, no credentials. If something is still broken, say so plainly
instead of burying it.

## Deeper material

`Rust_rules.md` (same folder) holds the full rule set: preferred crates, perf
and benchmarking rules, concurrency, WASM and PyO3 specifics.

For a full audit, the methodology library at `github.com/aagern/skills` goes
further — fetch only the file the scope needs:

```bash
curl -sO https://raw.githubusercontent.com/aagern/skills/main/methodology_files/quick-reference.md
```

| File | Use for |
|---|---|
| `quick-reference.md` | Cheat sheet, grep patterns, 5-minute checklist |
| `security-vulnerabilities.md` | Auth, crypto, injection |
| `performance-issues.md` | Allocations, clones, complexity, async |
| `code-quality.md` | DRY, architecture, coverage |
| `rust-specific.md` | Ownership, lifetimes, traits, unsafe |
| `examples.md` | Before/after case studies |
