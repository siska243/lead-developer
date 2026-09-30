# CI templates

The same checks as the local commit gate, in the pipeline, where nobody can skip them.

| File | Pipeline |
|------|----------|
| `github-actions.yml` | GitHub Actions: copy to `.github/workflows/siska-checks.yml` |
| `gitlab-ci.yml` | GitLab CI: add its jobs to `.gitlab-ci.yml` |

Two jobs:
- **secrets**: `secret-scan.sh --range` on the pull/merge request commits, then `--history` on every commit. Needs the full history (`fetch-depth: 0` / `GIT_DEPTH: 0`) and no project setup.
- **checks**: `check-project.sh --run-tests --run-lint` (or the commands of `.siska/checks`). Put it **after the project's own setup steps** (runtime, dependencies, services), copied from its existing pipeline; do not create a second setup.

Pinning: `SISKA_REF` is a release tag or a commit SHA of siska-lead-developer, never a branch; third-party actions are pinned by commit SHA (the comment keeps the version readable).
A history finding fails the job until the value is rotated and its location listed in `.siska/secrets-allow` with the reason.
