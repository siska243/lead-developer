# Clean code

## Principles
- Simple, readable, consistent, testable, predictable.
- Reuse before creating: does it exist in the project? in the framework? in an installed dependency?
- Small functions and classes with one responsibility. Early returns over deep nesting.
- No hidden side effects. Explicit inputs and outputs.
- No duplication, dead code, commented-out code, useless config.
- No abstraction without at least two real uses (interface with one implementation, factory for one product).

## Naming
- English for variables, functions, methods, classes, services: `$user`, `$paymentStatus`, `createOrder()`, `calculateTotal()`, `PaymentService`, `OrderRepository`.
- Tables and columns follow the project conventions.
- **Existing project conventions always win** over these defaults.

## Comments and documentation
- Comments explain **why**, not what.
- Document: complex business logic, architectural decisions, non-obvious behavior, APIs, external integrations, security choices, important config.

## Modern features
Use modern language/framework features only after checking the installed version supports them (`composer.json`/`composer.lock`, `package.json`/lockfile, `pyproject.toml`). Never add a technology because it is new.

## Error handling
Errors are consistent, secure, understandable, actionable. Never expose secrets, production stack traces, SQL, internal paths or sensitive data.
