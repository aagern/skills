#!/usr/bin/env bash
# Checks that the two rust-review skill files still cover the same substance.
#
# They are deliberately not identical: one is written for a local model under
# OpenCode, the other for Claude Code, so the tooling wording differs. What must
# not drift is the rule inventory — if a rule is worth stating to one reader it
# is worth stating to the other.
#
# Each entry below is a rule and a grep pattern that must match in both files.
# Add an entry whenever either skill grows a new rule.
set -uo pipefail

# This file's own directory holds the OpenCode-facing skill. The Claude Code
# copy lives in the user's profile; override either with an argument when they
# sit somewhere else:
#   ./sync_check.sh [path/to/openhandle/SKILL.md] [path/to/claude/SKILL.md]
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_SKILL="${1:-$HERE/SKILL.md}"
CLAUDE_SKILL="${2:-$HOME/.claude/skills/rust-code-review/SKILL.md}"

for f in "$LOCAL_SKILL" "$CLAUDE_SKILL"; do
    if [ ! -r "$f" ]; then
        echo "cannot read $f" >&2
        echo "pass the two SKILL.md paths as arguments if they live elsewhere" >&2
        exit 2
    fi
done

# rule label <TAB> grep -E pattern
RULES=$(cat <<'RULES'
run the command before reporting	[Rr]un the command|[Ee]vidence before assertions
test first for behaviour changes	[Tt]est first|watch it fail
read the whole crate first	read all of it|read every source file
unused cargo features are a finding	features are actually used|features are actually used
panic audit	unwrap\(\)
configuration vs invariant	configuration or an invariant
thiserror for library errors	thiserror
anyhow with context for binaries	anyhow
no Box<dyn Error> in public signatures	Box<dyn Error>
justify every clone	clone\(\)
borrow over own in parameters	&str|Cow
network clients need timeouts	needs a timeout
unbounded buffering is a memory risk	[Uu]nbounded buffering
no mod.rs	mod\.rs
function size and parameter limits	50 lines
naming conventions	snake_case
docs on every public item	# Errors|///
examples compile as doctests	# Examples
tests return Result not unwrap	Box<dyn (std::error::)?Error>
secrets never hardcoded or logged	[Hh]ardcoded credentials
no Debug derive on secret holders	derive .Debug|not. derive
severity tiers	Critical|Important
not-checked section	[Nn]ot checked
refactor fixes by severity	Critical, then Important
restart services after rebuild	restart the service
confirm each edit landed	fail loudly|silently (non-)?match|Confirm each edit
rules file is the source of truth	Rust_rules\.md
methodology library pointer	methodology_files
cross-link to the other skill	rust-code-review/SKILL\.md|OpenCode
RULES
)

# Flatten each file to one line so a wrapped phrase still matches.
flat_local=$(tr '\n' ' ' < "$LOCAL_SKILL" | tr -s ' ')
flat_claude=$(tr '\n' ' ' < "$CLAUDE_SKILL" | tr -s ' ')

fail=0
while IFS=$'\t' read -r label pattern; do
    [ -z "${label:-}" ] && continue
    in_local=0; in_claude=0
    grep -Eq -- "$pattern" <<< "$flat_local" && in_local=1
    grep -Eq -- "$pattern" <<< "$flat_claude" && in_claude=1
    if [ "$in_local" -eq 1 ] && [ "$in_claude" -eq 1 ]; then
        printf 'ok    %s\n' "$label"
    elif [ "$in_local" -eq 1 ]; then
        printf 'DRIFT %s — missing from the Claude Code skill\n' "$label"; fail=1
    elif [ "$in_claude" -eq 1 ]; then
        printf 'DRIFT %s — missing from the OpenCode skill\n' "$label"; fail=1
    else
        printf 'GONE  %s — in neither file; drop the rule here or restate it\n' "$label"; fail=1
    fi
done <<< "$RULES"

echo
if [ "$fail" -eq 0 ]; then
    echo "in sync: $(grep -c . <<< "$RULES") rules present in both files"
else
    echo "drift detected — reconcile the files, then re-run"
fi
exit "$fail"
