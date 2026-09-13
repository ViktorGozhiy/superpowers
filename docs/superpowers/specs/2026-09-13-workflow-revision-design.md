# Workflow Revision: Document Review Loop, Automatic Spec-to-Plan Transition, Delegated Execution

**Date:** 2026-09-13
**Status:** Approved in dialogue, pending spec review
**Base:** superpowers v6.3.0

## 1. Motivation

The upstream workflow (brainstorming → spec → writing-plans → plan → execution) works, but on large production repositories three things cost more than they should:

1. **Self-review misses defects that a fresh reader catches.** Upstream replaced the reviewer-subagent loop with an inline checklist in v5.0.6 because its evals showed no quality difference and ~25 minutes of overhead. On large codebases the fresh reader still finds real defects: in one measured run the second plan review round found a compile break in a test class the plan did not list, a commit-sequencing gap that would leave an integration test red for one task, and three code mutations the planned tests would not catch. This revision restores the loop and makes it cheaper than the pre-5.0.6 version.
2. **Unnecessary stops.** After the spec review the workflow always asks the human to re-read the spec. The human already approved every design section in dialogue; re-reading the whole document repeats that work. Only changes to what was agreed need a stop.
3. **Execution pollutes the planning context.** Subagent-driven development keeps the controller in the same session as the dialogue; a 10–12 task plan with per-task review fills more than half the context window. A measured run showed that when the plan is literal (carries the code, verified against the tree), a separate executor session on a cheaper model reproduced the plan block for block in 35 minutes with zero implementation subagents, and the planning session stayed clean for validation. The remaining weakness of that run was the headless launch: no live progress, and a harness ceiling killed the run while background tasks were pending. This revision moves the executor into a second interactive session.

A secondary goal is cost: the planning session runs on the most capable model, and every subagent that inherits that model spends the same budget. Reviewers get an explicit mid-tier model.

## 2. Goals

- Spec and plan are reviewed by fresh subagents on an explicit mid-tier model, with a bounded loop.
- The spec → plan transition happens without a stop when the review changed nothing the human agreed to.
- Execution is delegated by default to a second interactive session that the human opens and watches; the planning session briefs it, waits, validates the result, and finishes the branch.
- Inline execution stays available on explicit request and ends with the same whole-branch review.
- Tasks that would not fit one context window are split before the spec is written.
- Edits to upstream files are confined to closed blocks so that future rebases conflict in predictable places.

## 3. Non-goals

- No change to subagent-driven-development, requesting-code-review, test-driven-development, systematic-debugging, or any skill not named below. SDD stays in the repository as a tool an executor session may choose; it leaves the writing-plans handoff.
- No agent-teams feature. Cross-session messaging (a documented, default-on Claude Code feature) is enough for one executor that reports at the end.
- No project-specific mechanics (line-length rules, formatter behaviour) in the reviewer prompts. Those belong to the project's instructions file, which reviewers and executors read.
- No blanket rewrite of imperative wording across the skill library. Only the blocks this revision replaces are rewritten in positive, motivated form.
- No harness bans or user-specific policy (for example, a ban on a harness-level orchestrator) inside the skills. Those live in the user's own instructions file.

## 4. Change map

| Path | Change |
|------|--------|
| `skills/reviewing-documents/SKILL.md` | New. Shared review loop for spec and plan documents. |
| `skills/reviewing-documents/re-review-prompt.md` | New. Scoped re-review of fixes to a document. |
| `skills/delegating-execution/SKILL.md` | New. Planning-session side of delegated execution. |
| `skills/delegating-execution/brief-template.md` | New. Executor brief and report contract. |
| `skills/brainstorming/SKILL.md` | Architectural path: task-count estimate after clarifying questions; steps 7–8 replaced by the review skill and the automatic transition rule. |
| `skills/brainstorming/spec-document-reviewer-prompt.md` | Unchanged content; the dispatch example names the model. |
| `skills/writing-plans/SKILL.md` | Self-Review replaced by the review skill; task-count check; plan header no longer recommends SDD; Execution Handoff rewritten for two modes. |
| `skills/writing-plans/plan-document-reviewer-prompt.md` | New check: verify referenced files and symbols against the repository tree. Dispatch example names the model. |
| `skills/executing-plans/SKILL.md` | Remove the "use SDD instead" note; add the whole-branch review before finishing. |
| `README.md` | Short section describing how this fork differs from upstream. |

Everything else in the repository is unchanged.

## 5. Skill: `reviewing-documents`

### 5.1 Purpose

Review a design spec or an implementation plan with fresh subagents until it is approved or the round cap is reached, then report what changed. Called by brainstorming (spec) and writing-plans (plan). Not invoked directly by the human.

### 5.2 Inputs

- `document`: absolute path of the spec or plan.
- `kind`: `spec` or `plan`.
- `spec` (plans only): absolute path of the spec the plan implements.

The document is already committed when the skill starts.

### 5.3 Model

Every reviewer dispatch names its model explicitly. Default: one tier below the model the planning session runs on. In Claude Code at the time of writing that is `model: opus` when the session runs on Fable, and it stays `opus` for a session that already runs on Opus. The skill states this default in one sentence and explains why: an unnamed model inherits the session's model, which is usually the most expensive one.

### 5.4 Round 1: full review

Dispatch a fresh `general-purpose` subagent with the existing reviewer template (`spec-document-reviewer-prompt.md` or `plan-document-reviewer-prompt.md`). The template's Calibration section already separates blocking `Issues` from advisory `Recommendations`.

Handle the report:

- `Status: Approved` → go to 5.7 with zero edits.
- `Status: Issues Found` → fix every Issue in the document. Apply a Recommendation only if it clearly improves the document, and only in this revision: Recommendations never start a round on their own.

### 5.5 Rounds 2 and 3: scoped re-review

After a revision, dispatch a fresh subagent with `re-review-prompt.md`. Its inputs are:

- the list of Issues from the previous round, verbatim;
- the document path;
- the diff of the document since the previous review (`git diff <sha-at-previous-review> -- <document>`, written to a file in the session's scratch directory; the path is passed, not the diff text).

The re-reviewer returns, per Issue, `ADDRESSED` or `NOT ADDRESSED` with a one-line reason, plus `New breakage` for contradictions or placeholders that the revision itself introduced. It does not re-read the untouched text for new findings; that is the point of a scoped re-review, and the prompt says so with the reason (a fresh full read finds a fresh set of taste findings every time and the loop never converges).

Open Issues after a re-review are fixed and re-reviewed again, up to round 3.

### 5.6 Round cap and adjudication

The cap is three rounds (one full review plus two scoped re-reviews). If Issues remain open after round 3, the controller rules on each one:

- fix it now, if the fix is small and clearly right; or
- leave it, with a recorded reason.

Every ruling is written into the document under a final heading `## Review notes`, one bullet per finding: the finding, the ruling, and why. The section travels with the document to the human and to the executor session. A finding never disappears silently.

### 5.7 Commit and output

All edits made during the loop are committed once, after the loop, with a message such as `docs: address spec review findings` or `docs: address plan review findings`.

The skill returns to its caller, in prose:

- final status (`Approved` or `Approved with N review notes`);
- number of rounds;
- the list of edits made, one line each, each line saying what changed and whether it changes a decision, a requirement, scope, or only wording;
- the list of review notes, if any.

### 5.8 Wording

The skill explains why the loop exists instead of ordering it: a fresh reviewer reads the document without the history of writing it and therefore notices what the author treats as obvious. Verification-style imperatives (`MUST`, `Do NOT rely on`) are not used in the new text; each rule carries its reason in the same sentence.

## 6. Brainstorming changes (architectural path only)

The spike and bounded paths are unchanged.

### 6.1 Size estimate after clarifying questions

Between "Ask clarifying questions" and "Propose 2-3 approaches", the controller states one line: the estimated number of plan tasks (using writing-plans' task right-sizing rules) and the number of services or modules touched. The line is always printed so the human can correct it.

If the estimate exceeds **12 tasks**, or touches more than one independently deployed service, the controller proposes a split: an ordered list of sub-projects, the dependencies between them, and a statement that each gets its own spec, plan, and session. Brainstorming then continues for the first sub-project. This extends the existing "decompose multiple independent subsystems" guidance; that text stays.

### 6.2 Steps 7 and 8 replaced

Current steps 7 (spec self-review) and 8 (user reviews written spec) become:

7. **Review the spec** — invoke `superpowers:reviewing-documents` with `kind: spec`.
8. **Transition** — classify the review's edits and either continue or stop (6.3).

The checklist, the process-flow graph, and the "After the Design" prose are updated together, because agents follow the graph and the checklist more reliably than the prose.

### 6.3 Automatic transition rule

The record of agreed decisions is the set of design sections the human approved in dialogue. Each edit reported by the review skill is classified:

- **Non-material:** wording, clarification, a missing detail filled in, an internal contradiction resolved. No approved decision changed.
- **Material:** an approved decision changed; a requirement was added that was not discussed; something agreed was removed; scope changed. Every review note (a finding left open at the cap) is material, because it is a decision taken on the human's behalf.

Then:

- **All edits non-material** → one message: spec path, number of rounds, one line per edit. The controller invokes writing-plans immediately, without waiting for a reply. The human can interrupt at any point.
- **Any material edit** → stop. The controller shows only the material items, each as "agreed in dialogue: … / now in spec: …", and asks whether to accept or revert. It does not ask the human to re-read the document. After the answer it invokes writing-plans.

## 7. Writing-plans changes

### 7.1 Task-count check

After the plan is written and before review: if it has more than 12 tasks, the controller stops and proposes a split point at which the first part leaves the code in a working, tested state. The human decides to split or continue.

### 7.2 Review

The "Self-Review" section is replaced by: invoke `superpowers:reviewing-documents` with `kind: plan` and the spec path. The "No Placeholders" section stays; it is the plan author's checklist while writing.

### 7.3 Plan header

The "For agentic workers" line becomes neutral: execute with `superpowers:executing-plans`, or `superpowers:subagent-driven-development` when tasks need a per-task review gate; TDD applies in both. The `Spec:` pointer and Global Constraints block are unchanged.

### 7.4 Execution handoff

After the review, the controller sends one message containing: plan path; rounds; whether the plan reviewer verified the plan against the tree; review notes, if any. Then:

> Open a second session in the repository directory (`claude --model opus`) and tell me when it is ready. Or say "inline" to execute the plan in this session.

The controller waits.

- Human reports the session is ready → invoke `superpowers:delegating-execution`.
- Human says inline → invoke `superpowers:executing-plans`.

Subagent-driven development is not offered here. The plan header still names it so that an executor session can choose it.

## 8. Skill: `delegating-execution`

### 8.1 Preconditions

- The plan and spec are committed on the feature branch.
- A second interactive session is running in the repository directory. The human opened it and chose its model; the planning session does not control the executor's model.

### 8.2 Brief

The controller writes `docs/superpowers/briefs/YYYY-MM-DD-<topic>-brief.md` from `brief-template.md` and commits it. The brief contains:

- paths of the plan, the spec, and the acceptance criteria (a section of the spec or an issue reference);
- **method:** the executor chooses inline, subagents, or a mix. One hint: when the plan carries the code and was verified against the tree, transcription with tests is enough and per-task review adds little; when the plan is descriptive, `superpowers:subagent-driven-development` gives each task its own review;
- **non-negotiables:** TDD; one green commit per task; the project's quality gates and instructions file; reviewers that the executor dispatches work in a git worktree, never in the shared tree;
- **hard limits:** no push, no PR, no edits outside the plan's file map unless the code forces it, no destructive operations, no other branches;
- **deviations:** when the code disagrees with the plan, the executor follows the code, records the deviation and its reason in the report, and continues;
- **report contract:** `docs/superpowers/briefs/YYYY-MM-DD-<topic>-report.md` with start and end times, method chosen, subagent count, per-task commits, deviations, test evidence (commands and results), open questions;
- **completion signal:** the executor's last action is a message to the planning session (named in the brief) saying the work is done and naming the report path.

### 8.3 Handing over

1. List reachable sessions. Choose the most recently started idle session whose name matches the repository directory. If more than one qualifies, ask the human which one.
2. Send the executor one paragraph: read the brief at `<path>` first; it is the requirements; report back as the brief describes.
3. Where the harness offers a one-shot notification when another session goes idle, subscribe to it for the executor session. The executor's completion message is the primary signal; the idle notification is the fallback for a run that ends without reporting.
4. Do not touch the working tree while the executor runs. The human watches the executor's terminal.

### 8.4 Validation

On the completion message:

1. Read the report. Check that every task has a commit and that deviations are explained.
2. Run the project's full verification (build and tests) from the planning session, or via one subagent that reports only the summary.
3. Dispatch a whole-branch review: `superpowers:requesting-code-review` with `code-reviewer.md`, on the same explicit mid-tier model as document reviews, with the branch diff from `git merge-base main HEAD` to `HEAD` written to a file, plus the plan's and report's paths and any review notes.
4. If the review returns Critical or Important findings, send the complete list to the executor session in one message: its context is intact and it fixes cheaper than the planning session would. Then run one scoped re-review of the fix range with `subagent-driven-development/re-review-prompt.md` (the code counterpart of the document re-review). One fix round only; residual findings are adjudicated and recorded in the report under `## Validation notes`.
5. Invoke `superpowers:finishing-a-development-branch` from the planning session, which holds the dialogue context.

### 8.5 Failure handling

If the idle notification arrives without a completion message, or the executor reports `BLOCKED`, the controller reads `git log` and the partial report, summarises the state to the human, and asks: relaunch the executor with the remaining tasks, or finish inline.

## 9. Executing-plans changes

- Remove the note that recommends subagent-driven-development when subagents are available; the handoff decides the mode now.
- Before "Complete Development", add: dispatch a whole-branch review via `superpowers:requesting-code-review` on an explicit mid-tier model, fix Critical and Important findings, then proceed to finishing-a-development-branch. This makes the final fresh-context review common to both execution modes.

## 10. Reviewer prompt changes

### 10.1 `plan-document-reviewer-prompt.md`

Add one row to "What to Check":

| Category | What to Look For |
|----------|------------------|
| Tree verification | Open every file the plan modifies. Do the referenced classes, functions, signatures, imports, and test names exist as the plan assumes? Do the plan's new symbols collide with existing ones? Report each mismatch with file and line. |

The Calibration section gains one sentence: a mismatch between the plan and the tree is an Issue, because the implementer will either build on a wrong assumption or stop.

The dispatch example names `model` explicitly.

### 10.2 `spec-document-reviewer-prompt.md`

Content unchanged. The dispatch example names `model` explicitly.

### 10.3 `reviewing-documents/re-review-prompt.md` (new)

Inputs: findings list, document path, diff file path. Output per finding: `ADDRESSED` / `NOT ADDRESSED` + reason; `New breakage:` list or `none`. Scope statement with reason as in 5.5. Calibration: only contradictions and placeholders introduced by the diff count as new breakage.

## 11. README

A section "About this fork" after the introduction: three to five sentences naming the three changes (fresh-subagent document review with a three-round cap, automatic spec-to-plan transition, delegated execution to a second session), the `team-design` branch as an archived experiment, and a pointer to this spec. No personal data beyond the GitHub account name already in the repository URL.

## 12. Parameters

| Parameter | Value | Where set |
|-----------|-------|-----------|
| Review round cap | 3 | `reviewing-documents/SKILL.md` |
| Reviewer model | one tier below the planning session's model; `opus` in Claude Code | `reviewing-documents/SKILL.md`, both reviewer prompts, `delegating-execution/SKILL.md` |
| Task-count threshold | 12 | `brainstorming/SKILL.md`, `writing-plans/SKILL.md` |
| Brief and report location | `docs/superpowers/briefs/` | `delegating-execution/SKILL.md` |
| Default execution mode | delegated; inline on request | `writing-plans/SKILL.md` |

## 13. Testing

Skill text cannot be unit-tested for behaviour by string presence, and upstream's behaviour evals live in a separate repository. Verification for this revision:

1. **Structural checks (scripted, in `tests/claude-code/test-workflow-revision.sh`):** every file path referenced from the changed skills exists; every `superpowers:<skill>` reference names an existing skill directory; both `dot` graphs in brainstorming and writing-plans parse with `skills/writing-skills/render-graphs.js`; the `writing-plans` handoff text no longer contains a subagent-driven option; the plan header template no longer marks SDD as recommended.
2. **Behaviour probes (manual, recorded in the plan):** following `superpowers:writing-skills`, one probe per changed skill with a fresh subagent and a small fixture repository:
   - brainstorming architectural path on a fixture whose spec review yields only wording fixes: the transcript shows a reviewer dispatch naming the model, and writing-plans invoked without a question to the human;
   - the same path where the reviewer's Issue changes an approved decision: the transcript shows a stop with an "agreed / now" comparison;
   - writing-plans on a fixture plan with 13 tasks: the transcript shows the split proposal before review;
   - reviewing-documents with an Issue that the revision does not fix: round 2 reports `NOT ADDRESSED`, round 3 the same, and the document gains a `## Review notes` section;
   - delegating-execution against a second local session on a fixture repository: brief committed, message sent, report received, whole-branch review dispatched on the named model, finishing skill invoked from the planning session.
3. **Personal-data check before every push:** `git log --format='%an %ae %cn %ce' origin/main..HEAD` shows only the GitHub noreply address, and a case-insensitive grep of the tree for the author's surname and employer domains is empty.

## 14. Rollout

1. Publish the branch, open a PR against `main` of the fork, merge.
2. In the fork, `.claude-plugin/marketplace.json` already uses `"source": "./"`, so the marketplace `superpowers-dev` installs from the fork as is. Reinstall `superpowers` from `superpowers-dev` instead of `superpowers-marketplace`; this replaces the locally edited 5.1.0 cache.
3. Outside the repository: one line in the user's global instructions file about harness-level orchestrators. Not part of this fork.
