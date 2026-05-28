# TDD 9004: TBD only inside a fence

Status: draft
PRD refs: FR-99
PRD-rev: deadbee
ADR constraints: 0003

## Approach

The only occurrence of TBD-as-literal in this TDD is inside a fenced code
block and inside angle-brackets template metasyntax. Neither should fire a
finding.

```text
example placeholder: TBD
```

The template metasyntax form: <TBD>

## Verification plan

Observe the placeholder lint emits zero findings against this fixture.

## Requirement traceability

| PRD | Design element |
|---|---|
| FR-99 | the only component |

## Dependencies considered

None.
