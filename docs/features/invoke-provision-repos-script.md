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
- Po utworzeniu (lub gdy repo już istnieją — same `SKIP`) próbuje **zaktualizować** `config/solutions/sample.json` w `owner/<slug>-hub` przez [GitHub Contents API](https://docs.github.com/en/rest/repos/contents#create-or-update-file-contents), żeby wskazywał na właściwe repo projektu zamiast na nazwy template’ów.
- Aktualizuje **rejestr systemów** w repozytorium Project Manager (`config/provisioned-systems.json`, `docs/systems.md`) — ten sam PAT musi mieć prawo zapisu w `GITHUB_REPOSITORY`.
