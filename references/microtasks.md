# Micro-task mode

On with `settings micro on` (project, or `--global`); off by default. The goal is to avoid gaps and silent errors: no long uninterrupted stretch of work, every step checked before the next one starts.

## Split
- Any non-trivial task becomes **2 to 4 micro-tasks**, in order of dependency. More than 4 → the task is too big: propose separate tickets.
- One micro-task = **one verifiable result** (a function and its test, an endpoint and its request test, a component and its states, a migration and its rollback), a small diff in one area of the code, a few minutes of work.
- A trivial change (typo, one-line fix) stays one step: no artificial split.
- Record them in the ticket: `- Micro-tasks: T12.1 <result> ⬜ · T12.2 <result> ⬜ …`, status updated as they finish.

## Each micro-task
1. **Announce** (2–3 plain lines): what will change, why it is needed for the ticket, how it will be checked.
2. **Do** only that micro-task.
3. **Verify** before moving on: the tests and linters it touches (`check-project.sh --run-tests --run-lint --scope …`), the "what could break" items of that step, a read of its own diff.
4. **Report** in 1–2 lines: done / not done, the evidence (test output, measure), anything found on the way. A failure is fixed in the same micro-task, or the plan is adjusted and said so; the next micro-task never starts on a broken one.

## Sub-agents
- A micro-task can go to a sub-agent when it is independent of the others (`references/agents.md`), with a contract: the goal, the files it may touch, the conventions to follow, the acceptance criteria, what it must not change. Parallel sub-agents work in isolated worktrees.
- **Nothing a sub-agent returns is integrated unread.** The lead reads the whole diff, checks it against the contract and the project's conventions, runs the tests and linters, and only then integrates it. Rejected → the reason, then a fix by the lead or a precise new contract.
- The lead stays responsible for the whole ticket: the final review of the full diff (`references/workflow.md`) still happens once all micro-tasks are integrated.

## Delivery
The usual delivery, plus the list of micro-tasks with their result and evidence.
