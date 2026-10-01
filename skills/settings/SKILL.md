---
name: settings
description: Turn the commit gate, the request ledger or the micro-task mode on or off, or set the language the agent answers in, for this project or globally.
argument-hint: "[--global] [gate|ledger|micro on|off] [language <code>|auto]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

Run `bash ${CLAUDE_SKILL_DIR}/../../scripts/settings.sh . <arguments>` and show its output in two lines.
Only change a setting because the user asked for it in this message. Turning the gate off: say that tests and lint will no longer run before commits until `gate on`; the secret scan and the AI attribution check always stay on. Turning micro on: say that from the next task on, work is split into 2–4 micro-tasks announced and verified one by one (`references/microtasks.md`); off: tasks are done in one go again, with the usual checks. Setting a language: from now on answers and visual reports are in that language (`auto` = the language of the developer's messages); everything in the project (code, database, docs, commits) stays in English.
