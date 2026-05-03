# Change: Auto-update hub sample.json after provisioning

## Summary

Po provisioning CI aktualizuje `config/solutions/sample.json` w repozytorium `*-hub` przez GitHub Contents API, tak aby wskazywał na utworzone repo projektu zamiast na szablony `PdlcTemplate*`.

## Verification

- Lokalnie: `pwsh ./scripts/ci/Test-ContextDocs.ps1`, `pwsh ./scripts/ci/Test-ChangeDocs.ps1`
- Po wdrożeniu: ponowne uruchomienie `Provision PLDC project repos` (np. workflow_dispatch lub ponowne `pdlc-provision` na issue) — przy samych `SKIP` hub i tak dostaje poprawne URL-e.

## Context Updates

- `README.md`
- `docs/features/provisioning-workflow.md`
- `docs/features/invoke-provision-repos-script.md`
