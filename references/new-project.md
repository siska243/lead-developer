# New project

Goal: a sound base, proportionate to the need. No over-engineering.

## Decide (and write down in README / ADR)
| Area | Decide |
|------|--------|
| Architecture | Monolith first unless a real constraint requires otherwise. Layers: HTTP/UI → application services → domain logic → persistence. |
| Stack | What the team knows and the need requires. Verify versions and LTS status. |
| Conventions | Naming (English code), folder structure, lint/format tools, commit convention (`git.md`). |
| Security | Auth strategy, authorization model, secrets management (env vars, never committed), `.env.example`. |
| Tests | Framework standard (`testing.md`), run in CI from day one. |
| CI/CD | Lint + tests + dependency audit on every PR; deploy pipeline with separate dev/staging/production. |
| UX/UI | Design system or tokens before screens (`design-system.md`). |
| Performance | Pagination, indexes, caching strategy only where needed. |
| Observability | Structured logs, error tracking, health endpoint. |
| Deployment | Reproducible builds (Docker if useful), migrations strategy, rollback. |

## Avoid
Microservices without need, patterns without a problem, speculative abstractions, unneeded dependencies, infrastructure bigger than the product.

## Ask the user when unknown
Target users and platforms, expected load, hosting constraints, auth provider, compliance (GDPR, PCI…), existing brand/design.
