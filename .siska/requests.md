# Requests











## T36 · Micro-task mode (on/off)
- Status: ✅ done · Priority: P1 · Created: 2026-10-01 · Updated: 2026-10-01
- Instructions: 2026-10-01 add a micro-task mode that can be turned on/off: the agent does not do a whole task for 10–15 minutes; to avoid errors and gaps it splits a task into 2, 3 or 4 micro-tasks, explains what it does, may give them to sub-agents but must validate before integrating.
- Result: settings micro on|off (default off, project or --global), references/microtasks.md (2–4 verified micro-tasks, announce/do/verify/report, sub-agent contract + review before integration, T<n>.1 tracking), SKILL.md rule, prompt hook reminder (also with ledger off), help/README/CHANGELOG/compat; 7 tests
