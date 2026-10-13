#!/usr/bin/env bash
# Runs the creative-stream test scenarios on local models through OpenCode.
#
# usage: bash run_local.sh <red|green> <outdir> [scenario letters...]
#   red    no skill: the baseline the skill must improve on
#   green  the skill files (../SKILL.md, lenses.md, note-template.md) are
#          injected into the prompt, as if the skill tool had returned them
#
# Score each reply by hand against rubric.md. MODELS overrides the model list.
# Runs one model at a time: two oMLX models at once trip its memory guard.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(dirname "$HERE")"
MODE="$1"; OUT="$2"; shift 2
[ "$#" -eq 0 ] && set -- A B C D E F
MODELS="${MODELS:-omlx/Qwen3.8-27B-oQ4e-mtp omlx/gemma-4-26B-A4B-it-qat-4bit}"
mkdir -p "$OUT"
WORK="$(mktemp -d)"   # empty working dir: no project files, no project skills

preamble() {
    if [ "$MODE" = red ]; then
        cat "$HERE/scenarios/_preamble.md"
        return
    fi
    sed '/^The conversation so far follows\./d' "$HERE/scenarios/_preamble.md"
    echo
    echo "The creative-stream skill is loaded for this session. Its files follow; follow them."
    for f in SKILL.md lenses.md note-template.md; do
        echo; echo "===== creative-stream/$f ====="; cat "$SKILL/$f"
    done
    echo; echo "===== end of skill ====="; echo
    echo "The conversation so far follows."
}

for m in $MODELS; do
    short=$(basename "$m" | cut -d- -f1)
    for s in "$@"; do
        f=$(ls "$HERE"/scenarios/"$s"-*.md)
        msg="$(preamble; cat "$f")"
        start=$(date +%s)
        (cd "$WORK" && opencode run --pure -m "$m" "$msg") > "$OUT/$short-$s.txt" 2> "$OUT/$short-$s.err"
        echo "$short $s exit=$? $(( $(date +%s) - start ))s" >> "$OUT/_log.txt"
    done
done
echo "DONE $MODELS" >> "$OUT/_log.txt"
rm -rf "$WORK"
