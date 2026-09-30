---
name: settings
description: Turn the commit gate or the request ledger on or off, for this project or globally.
argument-hint: "[--global] [gate|ledger on|off]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

Run `bash ${CLAUDE_SKILL_DIR}/../../scripts/settings.sh . <arguments>` and show its output in two lines.
Only change a setting because the user asked for it in this message. Turning the gate off: say that tests and lint will no longer run before commits until `gate on`; the secret scan and the AI attribution check always stay on.
