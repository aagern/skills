#!/usr/bin/env bash
# Runs the creative-stream test scenarios on local models through OpenCode.
#
# usage: bash run_local.sh <red|green> <outdir> [scenario letters...]
#   red    no skill: the baseline the skill must improve on
#   green  the skill files (../SKILL.md, lenses.md, note-template.md) are
#          injected into the prompt, as if the skill tool had returned them
#
# Score each reply by hand against rubric.md. Environment overrides:
#   MODELS     model list (provider/model, space separated)
#   SKILL_DIR  skill to inject in green mode (default: the folder above tests/);
#              every top-level *.md in it is injected
#   REPS       runs per scenario per model (default 1)
#   LIMIT      seconds before a run is killed (default 300)
# Runs one model at a time: two oMLX models at once trip its memory guard.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="${SKILL_DIR:-$(dirname "$HERE")}"
NAME="$(basename "$SKILL")"
REPS="${REPS:-1}"
LIMIT="${LIMIT:-300}"   # seconds per run; macOS has no timeout(1), perl alarm stands in
MODE="$1"; OUT="$2"; shift 2
[ "$#" -eq 0 ] && set -- A B C D E F
MODELS="${MODELS:-omlx/Qwen3.8-27B-oQ4e-mtp omlx/gemma-4-26B-A4B-it-qat-4bit}"
mkdir -p "$OUT"
WORK="$(mktemp -d)"   # empty working dir: no project files, no project skills

preamble() {
    local f   # must not clobber the caller's scenario path
    if [ "$MODE" = red ]; then
        cat "$HERE/scenarios/_preamble.md"
        return
    fi
    sed '/^The conversation so far follows\./d' "$HERE/scenarios/_preamble.md"
    echo
    echo "The $NAME skill is loaded for this session. Its files follow; follow them."
    # Supporting files first, SKILL.md last: the skill text sits right before
    # the conversation, as it does when the skill tool has just returned it.
    for f in $(ls "$SKILL"/*.md | grep -v "/SKILL.md$") "$SKILL"/SKILL.md; do
        echo; echo "===== $NAME/$(basename "$f") ====="; cat "$f"
    done
    echo; echo "===== end of skill ====="; echo
    echo "The conversation so far follows."
}

for m in $MODELS; do
    short=$(basename "$m" | cut -d- -f1)
    for s in "$@"; do
        f=$(ls "$HERE"/scenarios/"$s"-*.md)
        msg="$(preamble; cat "$f")"
        for r in $(seq 1 "$REPS"); do
            start=$(date +%s)
            # stdin from /dev/null: with an open stdin, opencode run waits forever
            (cd "$WORK" && perl -e 'alarm shift; exec @ARGV' "$LIMIT" opencode run --pure -m "$m" "$msg" < /dev/null) > "$OUT/$short-$s-$r.txt" 2> "$OUT/$short-$s-$r.err"
            echo "$short $s rep$r exit=$? $(( $(date +%s) - start ))s" >> "$OUT/_log.txt"
        done
    done
done
echo "DONE $MODELS" >> "$OUT/_log.txt"
rm -rf "$WORK"
