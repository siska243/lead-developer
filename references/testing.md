# Testing

## Find the existing system first – never replace it without need
| Signal | Framework | Run |
|--------|-----------|-----|
| `phpunit.xml`, `vendor/bin/phpunit` | PHPUnit | `vendor/bin/phpunit` or `php artisan test` |
| `vendor/bin/pest`, `tests/Pest.php` | Pest | `vendor/bin/pest` |
| `jest.config.*`, `"jest"` in package.json | Jest | `npx jest` / project script |
| `vitest.config.*`, `vitest` dep | Vitest | `npx vitest run` |
| `playwright.config.*` | Playwright | `npx playwright test` |
| `cypress.config.*` | Cypress | `npx cypress run` |
| `pytest.ini`, `conftest.py`, `[tool.pytest]` | Pytest | `pytest` |

Prefer the project's scripts (`composer test`, `npm test`, `make test`) when they exist. `bash scripts/check-project.sh <project>` lists what it finds.

## What to test
- New behavior: happy path + errors + edge cases (empty, null, limits, duplicates, concurrency where relevant).
- Bug fix: a regression test that fails before the fix.
- Permissions: each role allowed/denied.
- API: status codes, response shape (contract), validation errors.
- UI: states (loading, error, empty, disabled) when the project has component/E2E tests.

## Rules
- Run the existing suite before and after the change; report real results.
- Never delete, skip or weaken a test to make it pass. If a test is wrong, explain why before changing it.
- Tests use test databases/fakes – never production services.
- A task is not done while tests fail. If a failure pre-exists, prove it (run on the base branch) and report it.
