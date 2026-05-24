Implement the Technical Design Doc at {{TDD}} as a single unattended build.

Load context: read {{TDD}} in full; read docs/PRD.md for the requirements it
references; read the accepted ADRs it lists under "ADR constraints" (full
bodies) plus docs/adr/INDEX.md for anything else relevant. Use the `explore`
subagent for broader investigation so reading stays out of context.

Build discipline:
- Implement in the sequence the TDD specifies, one step at a time.
- Write tests ALONGSIDE the code via the `test-writer` subagent; run them.
- After each step run the relevant tests and the typecheck; fix failures at the
  ROOT CAUSE — never suppress errors, never weaken assertions to go green.
- The format-and-lint hook runs on each edit; resolve anything it reports.
- Stay within accepted-ADR constraints. If forced to break one, STOP and record
  the blocker in your final message instead of proceeding.

Review: run the review workflow — fan out to the `security-reviewer` and
`code-reviewer` subagents (isolated context keeps it unbiased) and address
findings.

Close:
- Run the full test suite and typecheck; confirm green.
- Keep docs in sync IN THIS COMMIT — not a later sweep. Grep for every concept
  this feature changed (renamed types, dropped tools, swapped dependencies,
  revised flows). For each hit in a doc decide if it is now wrong and fix it:
  evergreen docs (README/ARCHITECTURE/INSTALL/CONTRIBUTING/CLAUDE/behavior spec)
  are edited in place; an `accepted` ADR or design doc whose SUBSTANCE is now
  wrong gets a superseding doc, not a rewrite. Small doc fixes ride in the
  feature commit; substantial doc work is a second commit in the same branch.
  Do not finish with known-stale docs.
- Commit with a descriptive message referencing the TDD and the PRD requirement
  numbers. Do NOT open a PR — the runner manages branches and PRs.
- Flip this TDD's frontmatter `Status:` from `ready` to `implemented`, and
  commit that change too.
- End your final message with exactly `BATCH_RESULT: OK` on success, or
  `BATCH_RESULT: FAIL <reason>` if you could not complete it.
