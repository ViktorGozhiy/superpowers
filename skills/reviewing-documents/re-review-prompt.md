# Document Re-Review Prompt Template

Use this template for rounds 2 and 3 of the reviewing-documents loop. The re-reviewer verifies that the previous round's findings were addressed and that the revision broke nothing. It is not a fresh review: the full review already happened in round 1.

**Purpose:** Verdict each finding from the previous round and inspect the revision diff for new breakage.

```
Subagent (general-purpose):
  description: "Re-review <spec|plan> revision, round <R>"
  model: [MODEL — one tier below this session's model, floor opus; see SKILL.md in this directory]
  prompt: |
    You are re-reviewing a revision of a design spec or an implementation plan.
    A previous reviewer raised the findings below; the author revised the
    document. Verdict each finding and inspect the revision diff. That is the
    whole job: a fresh full read would find a fresh set of taste findings and
    the loop would never converge, so stay on the findings and on the diff.

    **Document:** [DOCUMENT]
    **Revision diff (read this file first):** [DIFF_FILE]

    ## Findings under verification

    [FINDINGS]

    ## Scope

    Your scope is the findings list and the revision diff. Read the document
    around each finding to judge whether the specific defect no longer
    exists; "attempted" is not addressed. Read the diff for contradictions
    or placeholders the revision itself introduced. Text the revision did
    not touch is out of scope: do not report new findings from it.

    ## Output format

    Begin directly with the first verdict. No preamble.

    ## <Spec|Plan> Re-Review

    For each finding, in order, one line:
    `N. ADDRESSED — <where and how>` or `N. NOT ADDRESSED — <what is still missing>`

    **New breakage:** contradictions or placeholders introduced by the diff,
    each with the section it appears in — or `none`.

    **Verdict:** `All findings addressed` or `Open findings remain`
```

**Placeholders:**
- `[MODEL]` — reviewer model per `SKILL.md` in this directory; the floor is `opus`
- `[FINDINGS]` — the `Issues` from the previous round, copied verbatim, numbered
- `[DOCUMENT]` — absolute path of the spec or plan
- `[DIFF_FILE]` — path of the file holding `git diff <commit the previous round reviewed> HEAD -- <document>`

**Re-reviewer returns:** per-finding verdicts, new breakage, and a round verdict.
