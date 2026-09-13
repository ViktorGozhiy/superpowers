# Behaviour probes: document review loop and transitions

Recorded 2026-09-13 against the `workflow-revision` branch (spec `docs/superpowers/specs/2026-09-13-workflow-revision-design.md`, section 13.2). Each probe ran the fork's skills in a fresh headless session:

```
claude -p "<prompt>" --model opus --plugin-dir <fork checkout> \
  --settings '{"enabledPlugins":{"superpowers@superpowers-marketplace":false}}' \
  --permission-mode bypassPermissions --output-format stream-json --verbose
```

in a throwaway fixture repository (one ESM file `src/greet.js`, one spec per probe). Every transcript shows `Base directory for this skill: <fork checkout>/skills/...`, so the fork's copy of each skill was the one that loaded. Dispatch models were read off the `Agent` tool-use entries, not the aggregate count. Transcripts are not committed; they contain absolute paths of the machine.

## Probe A — writing-plans reviews the plan through reviewing-documents

**Purpose:** the plan review runs through the new skill, on the named model, and an approved plan proceeds without edits.

**Fixture:** spec `2026-09-13-farewell-design.md` (add `farewell(name)` to `src/greet.js`, two requirements, `node --test`).

**Prompt:** "Use the superpowers writing-plans skill to write the implementation plan for docs/superpowers/specs/2026-09-13-farewell-design.md. Stop after the review step; do not execute the plan."

**Observed:**
- Skills invoked: `superpowers:writing-plans`, then `superpowers:reviewing-documents`.
- Agent dispatches: 1 — `Review plan document`, `model: opus`.
- Round 1 verdict: `Approved`, zero Issues; the skill returned "Approved. 1 round run. No edits made", no `## Review notes`.
- Plan committed as `docs/superpowers/plans/2026-09-13-farewell.md` (2 tasks), one commit.
- The reviewer re-ran the plan's commands in a scratch copy and confirmed the expected outputs (tree verification in practice).
- The session refused to apply two advisory Recommendations after `Approved`, quoting the skill: an approved document gets zero edits. It listed them for the human instead.
- Cost and time: USD 1.35, 228 s, 18 turns.

**Verdict:** matches the spec (5.4, 5.7, 7.2). The closing message still offered "subagent-driven development or inline execution": that is the v6.3.0 Execution Handoff text, which Part 2 replaces.

## Probe B — brainstorming continues to writing-plans on non-material edits

**Purpose:** the size estimate is printed, the spec review runs on the named model, and the continue-or-stop rule picks the right branch.

**Fixture:** same repository; request for `shout(name)`.

**Prompt:** "Use the superpowers brainstorming skill. I want a shout(name) function in src/greet.js that returns the greeting in upper case with an exclamation mark; tests with node --test in test/greet.test.js. Treat this as architectural so the full path runs. Answer your own clarifying questions with the simplest choice and record them; after the spec review, follow the skill's continue-or-stop rule, then stop before writing the plan and print which branch you took and why."

**Observed:**
- The session first said the request is bounded by the skill's definition and ran the architectural path only because asked (the three-path classification from v6.3.0 still works).
- Size estimate printed as one line: "3 plan tasks, 1 module (`src/greet.js`)".
- Agent dispatches: 3 — `Review spec document`, `Re-review spec revision, round 2`, `Re-review spec revision, round 3`, all `model: opus`.
- Round 1 found one Issue (a false claim about ESM detection without `package.json`); the revision fixed it and was committed as `docs: address spec review round 1`. Round 2 verdicted it `ADDRESSED` and reported new breakage in the revision (a wrong Node version range); the fix was committed as `docs: address spec review round 2`. Round 3: all addressed, no new breakage. No review notes.
- Branch taken: **continue**. The session classified both edits as wording only ("the decision you approved is still in the spec, with the same content and the same scope"), sent one summary message, and stated it would invoke writing-plans without waiting. It stopped only because the prompt told it to stop before the plan.
- It also flagged, on its own, that a premise it had given in the dialogue was wrong and left that for the human.
- Cost and time: USD 2.02, 341 s, 38 turns.

**Verdict:** matches the spec (5.4–5.7, 6.1, 6.3). Round 3 was triggered by new breakage from the round 1 fix, which is the intended path for the loop.

## Probe C — writing-plans stops above 12 tasks

**Purpose:** the size check stops before review and proposes a split.

**Fixture:** spec `2026-09-13-fourteen-helpers-design.md` (fourteen independent helpers, each its own task and commit).

**Prompt:** "Use the superpowers writing-plans skill to write the implementation plan for docs/superpowers/specs/2026-09-13-fourteen-helpers-design.md. If the skill tells you to stop, stop and print why."

**Observed:**
- Agent dispatches: 0. No plan file written, no commit.
- Final message: "The writing-plans skill's Size Check told me to stop", counted 14 tasks forced by the spec, proposed a 7 + 7 split with the scaffolding folded into the first task of part 1, and noted that after part 1 the suite passes with seven helpers exported. It also flagged that the spec gives no behaviour for any helper.
- Cost and time: USD 0.37, 31 s, 6 turns.

**Verdict:** matches the spec (7.1).

## Probe D — reviewing-documents reaches the cap and writes Review notes

**Purpose:** a finding that is never fixed goes `NOT ADDRESSED` through rounds 2 and 3, the skill rules at the cap, and the ruling lands in the document.

**Fixture:** spec `2026-09-13-contradiction-design.md` with two requirements demanding opposite cases for `whisper("Ada")`.

**Prompt:** "Invoke the superpowers reviewing-documents skill with kind spec on <path>. Constraint for this run: the lower-case/upper-case pair in Requirements is a business decision you are not allowed to change or resolve in the document; treat every other finding normally. Follow the skill to its end and print its output."

**Observed:**
- Agent dispatches: 3 — `Review spec document`, `Re-review spec revision, round 2`, `Re-review spec revision, round 3`, all `model: opus`.
- Rounds 2 and 3 verdicted the contradiction `NOT ADDRESSED`; the other Issues were fixed and `ADDRESSED`.
- Commits, in order: `docs: address spec review round 1`, `docs: address spec review round 2`, `docs: record spec review notes`. Round 3 committed nothing of its own.
- The spec ends with `## Review notes` holding two bullets (finding, ruling, reason): the contradiction itself, and an advisory point from round 3 about an undecided requirement sitting in Requirements.
- Skill output: "Status: Approved with 2 review notes", rounds run 3, four edits each classified (requirement, scope, wording, wording), plus the two notes. The session added that the caller should stop for the human because the spec is not plannable.
- The session created a branch `wip/contradiction-spec-review` for its commits because the fixture had no task branch.
- Cost and time: USD 1.27, 216 s, 15 turns.

**Verdict:** matches the spec (5.5, 5.6, 5.7) except for one point: the round 3 re-reviewer added an advisory observation outside the findings list and the session wrote it into `## Review notes`. The skill text at the time did not say what to do with such observations; it now says they go to the caller as advice and stay out of the document, because every review note stops the workflow for the human.

## Probe E — brainstorming stops when the review changes an approved decision

**Purpose:** the stop half of the continue-or-stop rule: a material edit produces a stop with an "agreed / now" comparison instead of a transition to writing-plans. Run after the branch review, on the fixed skill text.

**Fixture:** same repository shape as Probe B; the prompt supplies three "approved" decisions of which two contradict each other: `shout` lives in `src/greet.js`; `src/greet.js` is frozen and must not be edited; no `package.json`.

**Prompt:** "Use the superpowers brainstorming skill. I want a shout(name) function … Treat this as architectural so the full path runs. For the clarifying questions, use these answers and treat them as decisions I approved in dialogue: (1) shout lives in src/greet.js next to greet; (2) src/greet.js is frozen and must not be edited in this project, new code goes only into new files; (3) no package.json is added. Write the spec exactly with those three decisions, commit it, run the spec review as the skill says, then follow the skill's continue-or-stop rule. Stop before writing the plan and print which branch you took, the edits list with their classes, and why."

**Observed:**
- Skills invoked: `superpowers:brainstorming`, then `superpowers:reviewing-documents`.
- Agent dispatches: 2 — `Review spec document`, `Re-review spec revision, round 2`, both `model: opus`.
- Round 1 raised the contradiction as an Issue; the session resolved it by keeping the freeze and moving `shout` to a new file `src/shout.js`, committed `docs: address spec review round 1`. Round 2: all addressed, no new breakage, so the loop ended after two rounds (the clean exit added after the branch review).
- Edits were classified one by one: two material (the decision about where `shout` lives, and the component that follows from it), three wording-only.
- Branch taken: **stop**. The session did not invoke writing-plans. It printed one "Agreed in dialogue / Now in spec" pair covering the changed decision; the second material edit (the component naming the new file) follows from the first and was folded into the same pair, which the record accepts as one decision, not two. It asked to accept or revert and stated it would invoke writing-plans after the answer either way.
- Reviewer Recommendations were reported under a separate "Advice from the reviewers, which did not change the spec" heading and were not written into the document (the Output slot added after the branch review).
- Cost and time: USD 1.58, 268 s, 33 turns.

**Verdict:** matches the spec (6.3 stop path) and the fixed skill text (5.5 clean exit, 5.7 advice in Output).

## Probe F — writing-plans hands off with two modes and waits

**Purpose:** the rewritten Execution Handoff sends one summary message, offers a second session or "inline", does not offer subagent-driven development, and waits. Run after Part 2's Tasks 1–6.

**Fixture:** a fresh copy of Probe A's repository (one ESM file `src/greet.js`, the farewell spec).

**Prompt:** "Use the superpowers writing-plans skill to write the implementation plan for docs/superpowers/specs/2026-09-13-farewell-design.md. Follow the skill to its end, including the execution handoff, and stop where it tells you to wait for me."

**Observed:**
- Skills invoked: `superpowers:writing-plans`, then `superpowers:reviewing-documents`.
- Agent dispatches: 1 — `Review plan document`, `model: opus`. Approved in round 1, zero edits.
- The handoff message contained, in order: the plan path and commit, rounds run, tree verification (the reviewer executed the plan in a scratch copy), "Review notes: None", the reviewer's two advisory points labelled as advice that did not change the plan, and then the exact handoff question: "Open a second session in the repository directory (for example `claude --model opus`; the model is your choice) and tell me when it is ready. Or say "inline" to execute the plan in this session." Final line: "I'll wait for your answer."
- The message did not mention subagent-driven development. No execution happened: `src/` unchanged, `git log` shows only the fixture and the plan commit.
- Cost and time: USD 1.17, 196 s, 17 turns.

**Verdict:** matches the spec (7.4). The end-to-end delegation to a second interactive session needs a human at the second terminal and is recorded as Probe G after the rollout.

## Summary

| Probe | Dispatches (model) | Branch or outcome | Matches spec |
|-------|--------------------|-------------------|--------------|
| A | 1 (opus) | Approved round 1, no edits | yes |
| B | 3 (opus) | continue; wording-only edits | yes |
| C | 0 | stop; 7 + 7 split proposed | yes |
| D | 3 (opus) | cap reached; 2 review notes | yes, with the Review notes correction above |
| E | 2 (opus) | stop; one "agreed / now" pair shown | yes |
| F | 1 (opus) | handoff: two modes, waits | yes |

Total probe cost: USD 7.76. Observations worth carrying into Part 2: the handoff text seen in Probe A is the one Part 2 replaces; the strict reading of "zero edits after Approved" in Probe A is the intended behaviour and needs no change.
