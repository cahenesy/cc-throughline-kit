# cc-greenfield-kit

A deliberately minimal Claude Code plugin for building complex greenfield
systems. It packages the project-*invariant* layer (install once, cached under
`~/.claude/plugins/cache/` so it follows you everywhere) and a persistent
**PRD → TDD → ADR** design-doc pipeline with a build/review loop. Project-
*specific* artifacts are generated per project by the skills below.

## What's inside

```
cc-greenfield-kit/
├── .claude-plugin/{plugin.json, marketplace.json}
├── agents/
│   ├── explore.md            # read-only investigation (Sonnet)
│   ├── test-writer.md        # focused test authoring (Sonnet)
│   ├── security-reviewer.md  # security review (Opus)
│   └── code-reviewer.md      # correctness/consistency review (Opus)
├── skills/
│   ├── bootstrap-project/    # /bootstrap-project — toolchain + docs scaffold
│   ├── prd-author/           # /prd-author  — the WHAT  → docs/PRD.md
│   ├── tdd-author/           # /tdd-author  — the HOW   → docs/tdd/NNNN-*
│   ├── adr-new/              # /adr-new     — durable decisions → docs/adr/
│   ├── implement/            # /implement   — build all ready TDDs, detached
│   └── review/               # /review      — unbiased subagent review
├── scripts/
│   ├── implement.sh          # detached runner (fresh claude -p per TDD)
│   └── build-prompt.md       # per-feature build discipline
└── hooks/{hooks.json, format-and-lint.sh}
```

## Pipeline

| Skill              | Produces / does          | Notes                                              |
|--------------------|--------------------------|----------------------------------------------------|
| `/bootstrap-project` | toolchain + `docs/` tree | greenfield: linter, formatter, test, git, scaffold |
| `/prd-author`      | `docs/PRD.md`            | the WHAT. Explore + interview. Own session.        |
| `/tdd-author`      | `docs/tdd/NNNN-*`        | the HOW. Runs ONCE/PRD update: diffs PRD vs prev + |
|                    |                          | existing TDDs to decide how many TDDs to write;    |
|                    |                          | challenges PRD; recommends ADR actions.            |
| `/adr-new`         | `docs/adr/NNNN-*`        | append-only, status-gated supersession.            |
| `/implement`       | code + tests + PR(s)     | builds ALL `ready` TDDs (1 or many), always        |
|                    |                          | detached; flips each to `implemented`; opens PRs.  |
| `/review`          | consolidated findings    | fans out to security + code reviewer subagents.    |

Wired-in properties: ADR index always loaded, full bodies on demand by Scope;
only `accepted` ADRs bind new TDDs; superseded ADRs drop out of context;
`/tdd-author` proposes ADR actions for approval rather than asking; `/implement`
writes tests as it goes and auto-runs review in isolated (unbiased) context.

## Context hygiene

Skills run inside the session context, so a skill cannot `/clear` itself.
Autonomous work (investigation, test-writing, implementation review) is pushed
into **subagents**, which run in their own context windows and report back
summaries — so the main session stays clean WITHOUT a manual clear. The
interview stages (`/prd-author`, `/tdd-author`) are interactive and can't run in
a subagent, so run each in its own fresh session and `/clear` between them.

## Install (once per machine)

```
chmod +x hooks/format-and-lint.sh         # before pushing
# push this dir to a private GitHub repo, then:
/plugin marketplace add <your-org>/cc-greenfield-kit
/plugin install greenfield@cc-greenfield-kit
```

## Caveat

Plugin/marketplace JSON schemas and `/plugin` syntax evolve. Run
`claude plugin validate .` and confirm the current commands against the docs.
