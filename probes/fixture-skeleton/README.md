# Fixture Skeleton

A minimal mock project that gives the action-on-existing-code probes something concrete to act on. Without this skeleton, probes like `01-conversation-cosmetic.md` ("Change the homepage CTA button colour") correctly refuse with "no homepage in this directory" — which short-circuits the classification + dispatch behaviour those probes are meant to measure.

This is not a real product. The files are realistic-looking placeholders sized just large enough to be a credible target for the orchestrator's dispatch decision.

## How to use

Before running a probe that has a `## Fixture` block, copy the skeleton into your runtime fixture folder:

```
cp -r probes/fixture-skeleton/ /tmp/code4me-probe-fixture/
cd /tmp/code4me-probe-fixture/
# then open Claude Code here and paste the probe's Input prompt
```

Do not commit `.wolf/` or `.code4me/` into the skeleton — those should remain absent so probes also exercise cold-start behaviour.

## Which probes need which files

| Probe | Required file |
|---|---|
| `classification/01-conversation-cosmetic.md` | `src/ui/Homepage.tsx` |
| `classification/03-tech-debt-refactor.md` | `src/ScoreFormatter.cs` |
| `team-composition/05-bug-fix-reproduce-first.md` | `src/Leaderboard.cs` |
| `auto-escalation/07-conversation-touches-auth.md` | `src/auth/PasswordReset.cs` |
| `auto-escalation/08-conversation-touches-migration.md` | `schema/users.sql` (optional context) |
