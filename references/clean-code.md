# Clean code

## Principles
- Simple, readable, consistent, testable, predictable.
- Reuse before creating: does it exist in the project? in the framework? in an installed dependency?
- Small functions and classes with one responsibility. Early returns over deep nesting.
- No hidden side effects. Explicit inputs and outputs.
- No duplication, dead code, commented-out code, useless config.
- No abstraction without at least two real uses (interface with one implementation, factory for one product).

## Uniformity – one way to do one thing
- Same problem → same solution everywhere: validation, error handling, API responses, date/money formatting, HTTP calls, logging, auth checks, state management.
- Before writing a helper, service, hook or component, search for one that already does it. Found → use it. Two already exist → use the one the project uses most, and report the duplicate as a separate ticket.
- Never add a second library for something an installed one already does (two HTTP clients, two date libraries, two state managers, two UI kits).
- Follow the project's linters and formatters (Pint, PHP-CS-Fixer, PHPStan/Larastan, ESLint, Prettier, TypeScript strict, Ruff, Black, mypy…) and run them on changed files. Do not change their config to make code pass.

## Naming – English, always
- **Everything written in code is English**, whatever the developer's or the product's language: variables, functions, methods, classes, services, files, routes, tables, columns, indexes, migrations, enums, config keys, events, queues, translation keys, comments, doc comments, commit messages. `$user`, `$paymentStatus`, `createOrder()`, `calculateTotal()`, `PaymentService`, `OrderRepository`, `orders.delivery_date`, `order_statuses`. Never `$commande`, `calculerTotal()`, `date_livraison`.
- Senior conventions of the stack on top: casing (`camelCase`, `snake_case` tables and columns, `PascalCase` classes), plural table names where the framework expects them, clear full words, no abbreviations nobody shares.
- **Text shown to the product's users** (labels, messages, emails) is written in the product's language through its i18n system (`lang/fr/*.php`, `i18n/fr.json`, `__('orders.created')`), with English keys. Never hardcode it in a non-English identifier.
- **Existing non-English names** (a French column, a French method) are never renamed silently: renaming a column, a route or a public method breaks queries, API clients and mobile apps. New code around them is in English; the rename is proposed as a separate ticket with a compatible migration (new column, backfill, both read during the transition, old one dropped last) and the list of callers. Report them as found.
- The project's casing and structure conventions win; the language rule does not change.

## Comments and documentation
- Comments explain **why**, not what.
- Everything written for humans (comments, docs, README, commit messages, PR descriptions, UI copy, error messages) reads as written by a careful human: plain, specific, short. No filler, no inflated or promotional wording, no generic "robust/seamless/comprehensive", no emoji decoration, no rule-of-three padding, no vague claims. If a humanizer skill or tool is available, apply it to docs and PR text.
- Document: complex business logic, architectural decisions, non-obvious behavior, APIs, external integrations, security choices, important config.

## Modern features
Use modern language/framework features only after checking the installed version supports them (`composer.json`/`composer.lock`, `package.json`/lockfile, `pyproject.toml`). Never add a technology because it is new.

## Error handling
Errors are consistent, secure, understandable, actionable. Never expose secrets, production stack traces, SQL, internal paths or sensitive data.
