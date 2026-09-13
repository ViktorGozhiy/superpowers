# Execution Brief Template

The planning session fills this template into `docs/superpowers/briefs/[DATE]-[TOPIC]-brief.md`, commits it, and points the executor session at it. The brief is the executor's requirements; the plan and the spec are what it builds from.

**Placeholders:**
- `[TOPIC]`, `[DATE]` — same as the plan's file name
- `[BRANCH]` — the feature branch the executor works on
- `[PLAN_PATH]`, `[SPEC_PATH]` — absolute paths
- `[ACCEPTANCE]` — where the acceptance criteria live (a spec section, an issue reference)
- `[PROJECT_CHECKS]` — the project's quality gates, one line each (build, tests, lint, formatter), taken from the project's instructions file
- `[REPORT_PATH]` — `docs/superpowers/briefs/[DATE]-[TOPIC]-report.md`
- `[PLANNING_SESSION]` — the planning session's own name as printed at the top of `ListAgents`
- `[PLAN_LITERAL]` — `yes` when the plan carries the code and its review verified it against the tree, otherwise `no`

```markdown
# Execution brief: [TOPIC]

Read this file first; it is your requirements. Then read the plan and the spec.

## What to build

- Plan: `[PLAN_PATH]`
- Spec: `[SPEC_PATH]` (the plan argues from it; conflicts inside the plan resolve against the spec)
- Acceptance criteria: [ACCEPTANCE]
- Branch: `[BRANCH]`. Work here; every commit lands on this branch.

## Method

Choose the method that is most effective for you: inline with
`superpowers:executing-plans`, subagents with `superpowers:subagent-driven-development`,
or a mix. Plan is literal (code present, verified against the tree): [PLAN_LITERAL].
When it is, transcription plus tests is enough and a review per task adds little.
When it is not, subagent-driven development gives each task its own review gate.
Whichever you use, stop after the last plan task's commit: the whole-branch review
and finishing-a-development-branch belong to the planning session (see Hard limits),
so skip those steps of the skill you chose.

## Non-negotiables

- superpowers:test-driven-development on every task: the failing test comes first.
- One green commit per plan task, in plan order, with the plan's commit message.
- The project's checks pass before each commit:
  [PROJECT_CHECKS]
- Follow the project's instructions file for conventions and mechanics.
- Any reviewer you dispatch works in a git worktree, never in this working tree:
  a reviewer that edits files here races your own build.

## Hard limits

- No push, no pull request, no merge.
- No edits outside the plan's file map unless the code forces it; record every such edit under Deviations.
- No destructive operations: no history rewrites, no resets that drop work, no deletions the plan does not name.
- No other branches; no changes to the planning documents.
- No whole-branch review and no finishing-a-development-branch from this session: the planning session runs both after your report, and a second review here would pay for the same reading twice.

## When the code disagrees with the plan

Follow the code, record the deviation and its reason in the report, and continue.
Stop only for a defect that leaves every path forward a guess; then write the report
with what you know and send the blocked signal below.

## Report

Write `[REPORT_PATH]` as you go and finish it before you signal. Sections:

- **Timing:** start and end time, wall clock.
- **Method:** inline, subagents, or mix; number of subagents dispatched and their models.
- **Tasks:** one line per plan task: task number, commit hash, one-line test summary.
- **Deviations:** every departure from the plan, with the reason.
- **Evidence:** the commands you ran for the project's checks and their final lines.
- **Open questions:** anything the planning session has to decide.

Commit the report yourself as the last commit, `docs: add execution report for [TOPIC]`. It is the one commit expected beyond the one per plan task, so the planning session finds the report in git and not only on disk.

## Completion signal

Your last action: send one message to the session named `[PLANNING_SESSION]`
with `SendMessage`. First line, exactly one of:

- `Execution done: [REPORT_PATH]`
- `Execution blocked: [REPORT_PATH]`

The planning session validates the branch after your message; it may send you
findings to fix, so stay available until it says the work is finished.
```
