---
name: prd-author
description: Explore a problem space and produce or update the Product Requirements Document (the "what" and "why"). Persists to docs/PRD.md. Invoke with /prd-author. Run in its own session.
disable-model-invocation: true
---

# PRD authoring

Produce or update `docs/PRD.md` — the product intent of record. The PRD is the
WHAT and WHY. It contains no HOW: no architecture, no tech choices, no
implementation detail (those belong in a TDD).

Run this in its own session. If `docs/PRD.md` already exists you are UPDATING
it — read it first and preserve requirements still valid; note what changed.

## Process

1. Explore the problem space. Establish what exists, who the users are, and
   what success looks like.
2. Interview the user with the AskUserQuestion tool. Surface scope, non-goals,
   constraints, and edge cases the user hasn't stated. Skip obvious questions;
   dig into ambiguity and conflicting goals.
3. Keep interviewing until the requirements are unambiguous and testable.
4. Write `docs/PRD.md` from the template. Mark anything unresolved under Open
   questions rather than inventing an answer.

## Template

```
# Product Requirements: <project or feature>

## Problem & context
## Users & goals
## Requirements        (numbered, each independently testable)
## Non-goals
## Constraints & assumptions
## Open questions
```

Keep it the WHAT. The HOW is `/tdd-author`'s job. Do not start designing.

## Git (phase gate)
Unless the user says "skip git":
- Work on a branch `docs/prd/<change-slug>` off `main`.
- Commit `docs/PRD.md` with a message like "PRD: <summary of change>".
- Open a PR with `gh pr create --fill` (base `main`). Do NOT merge — the merge
  is the human approval gate.
- Tell the user to merge the PRD PR before running `/tdd-author`, so design
  builds on approved requirements. (The PRD commit history is also what
  `/tdd-author` diffs to scope the design work.)
