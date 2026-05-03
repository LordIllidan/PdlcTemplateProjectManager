# Context: PLDC Project Manager

## Purpose

Orkiestracja tworzenia zestawu repozytoriów projektu PLDC z szablonów GitHub oraz zbieranie metadanych wejściowych z Issues.

## Boundaries

- Owns registry szablonów (`config/templates.json`), automatyzację provisioning oraz dokumentację procesu.
- Does not own kod aplikacji; repozytoria kodu powstają jako osobne repo utworzone z template’ów.

## Important Files

- `config/templates.json`: lista template → docelowe sufiksy nazw repozytoriów.
- `.github/workflows/provision-project-repos.yml`: provisioning z Issue lub `workflow_dispatch`.
- `scripts/ci/Invoke-ProvisionRepos.ps1`: logika `gh repo create --template`.

## Local Commands

- `pwsh ./scripts/ci/Test-ContextDocs.ps1`
- `pwsh ./scripts/ci/Test-ChangeDocs.ps1`

## Decisions

- Provisioning jest **idempotentny**: istniejące repo o docelowej nazwie jest pomijane.
- Tworzenie repo poza `GITHUB_TOKEN` odbywa się przez **PAT** (`PDLC_REPO_ADMIN_TOKEN`), bo domyślny token Actions nie tworzy nowych repozytoriów na koncie użytkownika.

## Child Contexts

- `docs/context.md`
