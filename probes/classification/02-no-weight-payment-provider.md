# Probe: Undeclared weight on payment-provider work

**Subject:** classification
**Coverage:** Catches under-classification when no weight is declared on high-stakes work. The orchestrator must surface that this trips two auto-escalation symptom classes and propose Critical, not silently default to Standard.

## Input prompt

> Add support for a new payment provider.

## Expected

- **Kind:** product
- **Weight:** Critical (orchestrator proposes; user confirms)
- **Auto-escalation:** triggered — cite both `changes to authentication, authorisation, or sensitive-data handling` and `new external dependencies (third-party packages, services, APIs, libraries)`
- **Team:** lead-architect, challenger-architect, spec-to-test, developer, verification, code-reviewer, qa, doc-writer, plus qa (post-release pass) and user (sign-off)
- **Order/notes:** Critical Mode runs the full team — no subtractions, no substitutions on the core gates. Co-Approval Rule applies (both Lead and Challenger must return `approved: true`).

## Pass criterion

Orchestrator names both symptom-class strings verbatim, recommends Critical (or escalates to it after the user confirms a lighter weight), and lists the full Critical-tier team including the post-release qa pass and user sign-off.

## Failure modes this catches

- Orchestrator defaults to Standard silently because the user did not declare a weight, missing the heightened stakes.
- Orchestrator cites only one of the two symptom classes (typically the sensitive-data one) and forgets the new-external-dependency class.
- Orchestrator paraphrases the symptom-class strings instead of quoting them verbatim from `auto-escalation.md`.
- Orchestrator drops a subagent from the Critical team ("we don't need doc-writer for this") — Critical Mode hard-floor forbids subtractions.
