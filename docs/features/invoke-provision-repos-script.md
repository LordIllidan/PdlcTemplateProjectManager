# Skrypt `Invoke-ProvisionRepos.ps1`

## Cel

Wykonać provisioning repozytoriów na podstawie zdarzenia GitHub Actions (`workflow_dispatch` lub `issues` + label `pdlc-provision`).

## Wejście

- `GITHUB_EVENT_PATH` — pełny payload zdarzenia (wymagane).
- `GITHUB_EVENT_NAME` — `workflow_dispatch` albo `issues`.
- `GITHUB_REPOSITORY` — repo Project Manager (do komentarza na issue).
- `GH_TOKEN` — PAT z sekretu `PDLC_REPO_ADMIN_TOKEN`.

## Wyjście

- Tworzy repozytoria `owner/<slug>-<suffix>` lub pomija, jeśli istnieją.
- Dla zdarzenia `issues` dodaje komentarz z wynikiem i linkami.
