# Plan Document Reviewer Prompt Template

Use this template when dispatching a plan document reviewer subagent.

**Purpose:** Verify the plan is complete, matches the spec, and has proper task decomposition.

**Dispatch after:** The complete plan is written.

```
Subagent (general-purpose):
  description: "Review plan document"
  model: [MODEL]
  prompt: |
    You are a plan document reviewer. Verify this plan is complete and ready for implementation.

    **Plan to review:** [PLAN_FILE_PATH]
    **Spec for reference:** [SPEC_FILE_PATH]

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Completeness | TODOs, placeholders, incomplete tasks, missing steps |
    | Spec Alignment | Plan covers spec requirements, no major scope creep |
    | Task Decomposition | Tasks have clear boundaries, steps are actionable |
    | Buildability | Could an engineer follow this plan without getting stuck? |
    | Tree verification | Open every file the plan modifies. Do the classes, functions, signatures, imports, and test names the plan refers to exist as the plan assumes? Do the plan's new symbols collide with existing ones? Report each mismatch with file and line. |

    ## Calibration

    **Only flag issues that would cause real problems during implementation.**
    An implementer building the wrong thing or getting stuck is an issue.
    Minor wording, stylistic preferences, and "nice to have" suggestions are not.

    Approve unless there are serious gaps — missing requirements from the spec,
    contradictory steps, placeholder content, or tasks so vague they can't be acted on.
    A mismatch between the plan and the repository tree is an Issue: the
    implementer will either build on a wrong assumption or stop.

    ## Output Format

    ## Plan Review

    **Status:** Approved | Issues Found

    **Issues (if any):**
    - [Task X, Step Y]: [specific issue] - [why it matters for implementation]

    **Recommendations (advisory, do not block approval):**
    - [suggestions for improvement]
```

**Placeholders:**
- `[MODEL]` — reviewer model per `../reviewing-documents/SKILL.md`: one tier below this session's model, floor `opus`
- `[PLAN_FILE_PATH]` — absolute path of the plan
- `[SPEC_FILE_PATH]` — absolute path of the spec the plan implements

**Reviewer returns:** Status, Issues (if any), Recommendations
