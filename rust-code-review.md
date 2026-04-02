---
name: rust-code-review
description: Use when asked to review a Rust codebase, audit Rust code quality, check a Rust project before merge, or perform any Rust code review — including security, performance, naming, documentation, or test coverage analysis
---

# Rust Code Review

Review Rust projects systematically across safety, correctness, style, and maintainability. Work through stages in order — stop and flag Critical issues immediately before continuing.

## Quick Commands

```bash
cargo +nightly fmt -- --check                                        # Format (check only)
cargo +nightly fmt --                                                # Format (apply)
cargo clippy -- -D warnings                                          # Lint (fail on warnings)
cargo test --all                                                     # Full test suite
cargo test --doc                                                     # Doctests only
rg "\.unwrap\(\)|\.expect\(" --type rust --glob '!tests'             # Find prod panics
rg "\.clone\(\)" --type rust                                         # Find unnecessary clones
cargo make install-hooks                                             # Install pre-commit hooks
```

## Review Stages

### Stage 1 — Automated Gates

Run all four commands and paste output verbatim:
1. `cargo +nightly fmt -- --check`
2. `cargo clippy -- -D warnings`
3. `cargo test --all`
4. `cargo test --doc`

Any failure here is **Critical** — do not proceed past Stage 2 until resolved.

### Stage 2 — Panic Audit

Search for `.unwrap()`, `.expect()`, `panic!` outside `tests/`. Every hit is Critical unless provably unreachable. Required rewrites:

```rust
// ❌ Panics
let value = some_option.unwrap();
let config = Config::from_file("config.toml").unwrap();

// ✅ Propagates errors
let value = some_option.ok_or("Expected a value, but found None")?;
let config = Config::from_file("config.toml")
    .map_err(|e| format!("Failed to load config: {}", e))?;
```

### Stage 3 — Naming Conventions

| Context | Convention | Example |
|---|---|---|
| Variables, functions, modules | `snake_case` | `create_user_handler` |
| Structs, enums, traits, types | `PascalCase` | `TransactionStatus` |
| Constants, statics | `SCREAMING_SNAKE_CASE` | `MAX_AUTH_AGE_SECONDS` |

Names must be **descriptive and context-specific**:
- `create_user_handler` — OK
- `create_user_service` — OK
- `create_user` — NO (too generic)
- `create` — NO (no context)

### Stage 4 — Code Quality

- No `mod.rs` files — use `module_name.rs` instead
- `::` only in import statements, not at call sites
- Flag every `.clone()` — justify it or remove it
- No global mutable state
- Functions should stay under ~50 lines; split if longer
- Avoid unnecessary complexity

### Stage 5 — Documentation

All public items (structs, enums, traits, functions, methods, crates, modules) require doc comments. No `//` or `/* */` inline comments explaining behavior — convert to `///` doc comments or delete.

Use `//!` for module/crate-level docs, `///` for all items.

Required sections by item type:

| Section | Required when |
|---|---|
| `# Overview` | Always (first section) |
| `# Examples` | All public functions/methods |
| `# Errors` | Returns `Result` |
| `# Panics` | Can panic (unavoidable only) |
| `# Safety` | Contains `unsafe` |
| `# Performance` | Non-obvious complexity or allocations |

```rust
// ❌ Inline comment — won't surface in IDE hover
// Validates packet header and returns Err if too short
pub fn verify(pkt: &Packet) -> Result<(), VerifyError> { ... }

// ✅ Doc comment — surfaces in hover, linted by CI
/// # Overview
/// Verifies packet header and payload consistency.
///
/// # Errors
/// - `VerifyError::TooShort` when header is smaller than the required minimum.
pub fn verify(pkt: &Packet) -> Result<(), VerifyError> { ... }
```

### Stage 6 — Tests

- Unit tests cover all public functions and error cases
- No `unwrap()`/`expect()` inside tests — use `?` or `assert!(result.is_ok())`
- Integration tests live in `tests/` directory
- All `/// # Examples` compile and pass with `cargo test --doc`

```rust
// Unit test pattern
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_math() -> Result<(), Box<dyn std::error::Error>> {
        assert_eq!(2 + 2, 4);
        Ok(())
    }
}
```

### Stage 7 — Deep Review (full audits only)

Load the relevant methodology files. Use `quick-reference.md` first for targeted ripgrep patterns, then load specific files as needed.

All files at: `/Users/alex/scripts/RUST/RustManifest/code-review-methodology/en/`

| File | Size | Use for |
|---|---|---|
| `quick-reference.md` | 10KB | First stop — cheat sheet, grep patterns, 5-min checklist |
| `security-vulnerabilities.md` | 32KB | Full security audit (auth, crypto, injection, SQL) |
| `performance-issues.md` | 20KB | Allocations, clones, algorithmic complexity, async |
| `code-quality.md` | 18KB | DRY, readability, architecture, test coverage |
| `rust-specific.md` | 27KB | Ownership, lifetimes, traits, unsafe, patterns |
| `examples.md` | 20KB | Real before/after case studies with metrics |

Do not load all files on every review — load only what the scope requires.

## Severity Tiers

**Critical — block merge immediately**
- Panics in production code (`.unwrap()`, `.expect()`, `panic!`)
- Security vulnerabilities (hardcoded secrets, injection, missing auth checks)
- Failing tests or doctests

**Important — fix before merge**
- Clippy warnings (any with `-D warnings`)
- Missing doc comments on public API surface
- `mod.rs` files
- No tests for new public functions
- Missing `Result`/`Option` error handling

**Minor — fix in same PR or follow-up**
- Naming convention violations
- Unjustified `.clone()`
- Inline `//` comments that should be `///`
- Missing `# Examples` in doctests

## Review Output Format

```
## Stage 1 — Automated
[paste command output verbatim]

## Critical
- [file:line] description — required fix

## Important
- [file:line] description — required fix

## Minor
- [file:line] description — suggested fix

## Summary
X critical, Y important, Z minor issues.
Verdict: BLOCK / APPROVE WITH FIXES / APPROVE
```
