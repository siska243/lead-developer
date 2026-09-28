# Maintenance (TMA) on an existing application

```text
Understand existing → Locate precisely → Change the minimum → Test → Check neighbours → Review
```

## Rules
- No redesign, no refactor, no dependency upgrade unless the ticket requires it.
- Bug = root cause, not symptom. Reproduce first (failing test or documented steps). If a debugging skill/tool is available, use it.
- Before editing a shared function, list every caller. A fix in the shared function beats a patch in one caller, but it must be safe for all callers.
- Keep behavior identical for everything the ticket does not cover (API responses, messages, UI, timing, permissions).
- Production data: never run destructive commands, migrations or scripts against production. Propose them, with a rollback.

## Steps
1. Reproduce and capture current behavior (logs, test, screenshot).
2. Locate: trace the flow from entry point (route/screen/job) to the failing line.
3. Identify neighbours: features sharing the same code, data or component.
4. Fix minimally, add a regression test that fails before the fix.
5. Run the suite, then manually check neighbours.
6. Review the diff: only lines needed for the fix.
7. Report root cause, fix, verification, and any other defect found (separate ticket).
