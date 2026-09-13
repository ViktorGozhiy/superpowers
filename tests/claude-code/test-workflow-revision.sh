#!/usr/bin/env bash
# Structural checks for the workflow revision: the reviewing-documents skill
# exists and is referenced, its cross-directory references resolve, the
# brainstorming graph parses, and the inline self-review blocks are gone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS="$REPO_ROOT/skills"

REVIEWING_SKILL="$SKILLS/reviewing-documents/SKILL.md"
RE_REVIEW_PROMPT="$SKILLS/reviewing-documents/re-review-prompt.md"
BRAINSTORMING="$SKILLS/brainstorming/SKILL.md"
WRITING_PLANS="$SKILLS/writing-plans/SKILL.md"
SPEC_PROMPT="$SKILLS/brainstorming/spec-document-reviewer-prompt.md"
PLAN_PROMPT="$SKILLS/writing-plans/plan-document-reviewer-prompt.md"
DELEGATING_SKILL="$SKILLS/delegating-execution/SKILL.md"
BRIEF_TEMPLATE="$SKILLS/delegating-execution/brief-template.md"
EXECUTING_PLANS="$SKILLS/executing-plans/SKILL.md"
README="$REPO_ROOT/README.md"

failures=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; shift; for line in "$@"; do echo "    $line"; done; failures=$((failures + 1)); }

assert_file() {
    if [ -f "$1" ]; then pass "$2"; else fail "$2" "missing file: $1"; fi
}

assert_contains() {
    local file="$1" pattern="$2" label="$3"
    if [ -f "$file" ] && grep -Fq -- "$pattern" "$file"; then pass "$label"
    else fail "$label" "expected to find: $pattern" "in file: $file"; fi
}

assert_not_contains() {
    local file="$1" pattern="$2" label="$3"
    if [ -f "$file" ] && grep -Fq -- "$pattern" "$file"; then
        fail "$label" "did not expect to find: $pattern" "in file: $file"
    else pass "$label"; fi
}

# Every `superpowers:<name>` reference in a file names an existing skill directory.
assert_skill_refs_resolve() {
    local file="$1" label="$2" ok=1
    [ -f "$file" ] || { fail "$label" "missing file: $file"; return; }
    while IFS= read -r name; do
        if [ ! -d "$SKILLS/$name" ]; then ok=0; echo "    unresolved skill reference: superpowers:$name"; fi
    done < <(grep -o 'superpowers:[a-z-]*' "$file" | sed 's/superpowers://' | sort -u)
    if [ "$ok" -eq 1 ]; then pass "$label"; else fail "$label" "in file: $file"; fi
}

# Every relative `.md` path in backticks resolves from the file's directory.
assert_md_refs_resolve() {
    local file="$1" label="$2" ok=1 dir
    [ -f "$file" ] || { fail "$label" "missing file: $file"; return; }
    dir="$(dirname "$file")"
    while IFS= read -r ref; do
        if [ ! -f "$dir/$ref" ]; then ok=0; echo "    unresolved path: $ref"; fi
    done < <(grep -o '`[./A-Za-z-]*\.md`' "$file" | tr -d '`' | sort -u)
    if [ "$ok" -eq 1 ]; then pass "$label"; else fail "$label" "in file: $file"; fi
}

echo "=== Workflow Revision Structural Test ==="
echo ""

echo "-- reviewing-documents skill"
assert_file "$REVIEWING_SKILL" "reviewing-documents/SKILL.md exists"
assert_file "$RE_REVIEW_PROMPT" "reviewing-documents/re-review-prompt.md exists"
assert_contains "$REVIEWING_SKILL" "name: reviewing-documents" "frontmatter name"
assert_contains "$REVIEWING_SKILL" "description: Use when" "description starts with Use when"
assert_md_refs_resolve "$REVIEWING_SKILL" "reviewing-documents references resolve"
assert_contains "$RE_REVIEW_PROMPT" "[DIFF_FILE]" "re-review prompt takes a diff file"
assert_contains "$RE_REVIEW_PROMPT" "NOT ADDRESSED" "re-review prompt returns per-finding verdicts"
assert_md_refs_resolve "$RE_REVIEW_PROMPT" "re-review prompt references resolve"
assert_contains "$REVIEWING_SKILL" "Three rounds" "round cap is three"
assert_contains "$REVIEWING_SKILL" "floor" "model floor is stated"
assert_contains "$REVIEWING_SKILL" "## Review notes" "review notes heading is named"

echo ""
echo "-- reviewer prompt templates"
assert_contains "$SPEC_PROMPT" "model:" "spec reviewer dispatch names a model"
assert_contains "$PLAN_PROMPT" "model:" "plan reviewer dispatch names a model"
assert_contains "$PLAN_PROMPT" "Tree verification" "plan reviewer checks the plan against the tree"
assert_md_refs_resolve "$SPEC_PROMPT" "spec reviewer template references resolve"
assert_md_refs_resolve "$PLAN_PROMPT" "plan reviewer template references resolve"

echo ""
echo "-- brainstorming"
assert_skill_refs_resolve "$BRAINSTORMING" "brainstorming skill references resolve"
assert_contains "$BRAINSTORMING" "superpowers:reviewing-documents" "brainstorming invokes reviewing-documents"
assert_not_contains "$BRAINSTORMING" "Spec self-review" "brainstorming checklist has no inline self-review step"
assert_not_contains "$BRAINSTORMING" "Spec Self-Review" "brainstorming prose has no inline self-review block"
assert_contains "$BRAINSTORMING" "12 tasks" "brainstorming states the task-count threshold"
# render-graphs.js exits 0 even when dot rejects a graph, so feed the block to dot directly.
assert_graph_parses() {
    local file="$1" label="$2" graph_file
    [ -f "$file" ] || { fail "$label" "missing file: $file"; return; }
    if ! command -v dot >/dev/null 2>&1; then echo "  [SKIP] $label (graphviz not installed)"; return; fi
    graph_file="$(mktemp)"
    awk '/^```dot$/{on=1; next} /^```$/{on=0} on' "$file" > "$graph_file"
    if [ -s "$graph_file" ] && dot -Tsvg -o /dev/null "$graph_file" 2>/dev/null; then
        pass "$label"
    else
        fail "$label" "dot rejected the graph extracted from $file"
    fi
    rm -f "$graph_file"
}
assert_graph_parses "$BRAINSTORMING" "brainstorming graph parses"
assert_graph_parses "$REVIEWING_SKILL" "reviewing-documents graph parses"

echo ""
echo "-- delegating-execution skill"
assert_file "$DELEGATING_SKILL" "delegating-execution/SKILL.md exists"
assert_file "$BRIEF_TEMPLATE" "delegating-execution/brief-template.md exists"
assert_contains "$DELEGATING_SKILL" "name: delegating-execution" "delegating frontmatter name"
assert_contains "$DELEGATING_SKILL" "description: Use when" "delegating description starts with Use when"
assert_skill_refs_resolve "$DELEGATING_SKILL" "delegating-execution skill references resolve"
assert_md_refs_resolve "$DELEGATING_SKILL" "delegating-execution references resolve"
assert_contains "$DELEGATING_SKILL" "notify_when_idle" "delegating-execution subscribes to the idle notice"
assert_contains "$DELEGATING_SKILL" "ListAgents" "delegating-execution discovers sessions with ListAgents"
assert_contains "$DELEGATING_SKILL" "docs/superpowers/briefs/" "delegating-execution names the brief location"
assert_contains "$BRIEF_TEMPLATE" "[PLANNING_SESSION]" "brief template carries the planning session name"
assert_contains "$BRIEF_TEMPLATE" "[REPORT_PATH]" "brief template carries the report path"
assert_graph_parses "$DELEGATING_SKILL" "delegating-execution graph parses"

echo ""
echo "-- writing-plans"
assert_skill_refs_resolve "$WRITING_PLANS" "writing-plans skill references resolve"
assert_contains "$WRITING_PLANS" "superpowers:reviewing-documents" "writing-plans invokes reviewing-documents"
assert_not_contains "$WRITING_PLANS" "## Self-Review" "writing-plans has no inline self-review section"
assert_not_contains "$WRITING_PLANS" "subagent-driven-development (recommended)" "plan header no longer recommends SDD"
assert_contains "$WRITING_PLANS" "12 tasks" "writing-plans states the task-count threshold"
assert_not_contains "$WRITING_PLANS" "Subagent-Driven (recommended)" "handoff no longer offers subagent-driven development"
assert_contains "$WRITING_PLANS" "superpowers:delegating-execution" "handoff routes to delegating-execution"
assert_contains "$WRITING_PLANS" "superpowers:executing-plans" "handoff keeps inline execution"

echo ""
echo "-- executing-plans and README"
assert_skill_refs_resolve "$EXECUTING_PLANS" "executing-plans skill references resolve"
assert_not_contains "$EXECUTING_PLANS" "instead of this skill" "executing-plans no longer defers to subagent-driven development"
assert_contains "$EXECUTING_PLANS" "superpowers:requesting-code-review" "executing-plans runs the whole-branch review"
assert_contains "$README" "## About this fork" "README describes the fork"
assert_contains "$README" "**reviewing-documents**" "README lists reviewing-documents"
assert_contains "$README" "**delegating-execution**" "README lists delegating-execution"

echo ""
if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
