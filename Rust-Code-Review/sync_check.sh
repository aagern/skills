#!/usr/bin/env bash
# Checks that every copy of the rust-review skill still covers the same substance.
#
# There are three copies, and they are not all the same kind of thing:
#
#   repo      this directory — the authored source, written for a local model
#   claude    ~/.claude/skills/rust-code-review — a variant, worded for Claude Code
#   opencode  ~/.config/opencode/skill/rust-review — a DEPLOYED COPY of repo
#
# repo and claude are deliberately not identical: the tooling wording differs
# because the readers differ. What must not drift between them is the rule
# inventory — if a rule is worth stating to one reader it is worth stating to
# the other.
#
# opencode is different: it is a deployment, so it must be byte-identical to
# repo. OpenCode does not follow symlinks, so the files are copied, which means
# a stale deployment is possible and is what this script catches.
#
# Each entry below is a rule and a grep pattern that must match in every copy.
# Add an entry whenever any skill grows a new rule.
#
# Usage: ./sync_check.sh [repo/SKILL.md] [claude/SKILL.md] [opencode/SKILL.md]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_SKILL="${1:-$HERE/SKILL.md}"
CLAUDE_SKILL="${2:-$HOME/.claude/skills/rust-code-review/SKILL.md}"
OPENCODE_SKILL="${3:-$HOME/.config/opencode/skill/rust-review/SKILL.md}"

NAMES="repo claude opencode"
FILES="$REPO_SKILL
$CLAUDE_SKILL
$OPENCODE_SKILL"

missing_file=0
while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [ ! -r "$f" ]; then
        echo "cannot read $f" >&2
        missing_file=1
    fi
done <<< "$FILES"
if [ "$missing_file" -ne 0 ]; then
    echo "pass the three SKILL.md paths as arguments if they live elsewhere" >&2
    exit 2
fi

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
flat_repo=$(tr '\n' ' ' < "$REPO_SKILL" | tr -s ' ')
flat_claude=$(tr '\n' ' ' < "$CLAUDE_SKILL" | tr -s ' ')
flat_opencode=$(tr '\n' ' ' < "$OPENCODE_SKILL" | tr -s ' ')

fail=0
rule_count=0
while IFS=$'\t' read -r label pattern; do
    [ -z "${label:-}" ] && continue
    rule_count=$(( rule_count + 1 ))
    missing=""
    grep -Eq -- "$pattern" <<< "$flat_repo"     || missing="$missing repo"
    grep -Eq -- "$pattern" <<< "$flat_claude"   || missing="$missing claude"
    grep -Eq -- "$pattern" <<< "$flat_opencode" || missing="$missing opencode"

    case "$missing" in
        "")
            printf 'ok    %s\n' "$label" ;;
        " repo claude opencode")
            printf 'GONE  %s — in no copy; drop the rule here or restate it\n' "$label"
            fail=1 ;;
        *)
            printf 'DRIFT %s — missing from:%s\n' "$label" "$missing"
            fail=1 ;;
    esac
done <<< "$RULES"

# The OpenCode copy is a deployment of the repo file, not a variant, so any
# textual difference means the deployment is stale. Checked for the rules file
# too: the rules are the law, and a stale law is worse than a stale procedure.
echo
deploy_fail=0
check_deployed() {
    local src="$1" dst="$2" what="$3"
    if [ ! -r "$dst" ]; then
        printf 'STALE %s — not deployed to OpenCode (%s)\n' "$what" "$dst"
        deploy_fail=1; return
    fi
    if cmp -s "$src" "$dst"; then
        printf 'ok    %s deployed to OpenCode is identical\n' "$what"
    else
        printf 'STALE %s — OpenCode copy differs from the repo source\n' "$what"
        printf '      re-copy: cp %s %s\n' "$src" "$dst"
        deploy_fail=1
    fi
}
OPENCODE_DIR="$(dirname "$OPENCODE_SKILL")"
REPO_DIR="$(dirname "$REPO_SKILL")"
check_deployed "$REPO_SKILL"             "$OPENCODE_SKILL"              "SKILL.md"
check_deployed "$REPO_DIR/Rust_rules.md" "$OPENCODE_DIR/Rust_rules.md"  "Rust_rules.md"
[ "$deploy_fail" -ne 0 ] && fail=1

echo
if [ "$fail" -eq 0 ]; then
    echo "in sync: $rule_count rules present in all three copies, deployment current"
else
    echo "drift detected — reconcile the copies, then re-run"
fi
exit "$fail"
