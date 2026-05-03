# Change: Add PLDC Orchestrator template to provisioning

## Summary

Project Manager provisionuje dodatkowe repo `*-control` z szablonu `PdlcTemplatePLDCOrchestrator`; hub dostaje `repos.orchestrator` w profilu generowanym przez CI.

## Verification

- `pwsh ./scripts/ci/Test-ContextDocs.ps1`
- `pwsh ./scripts/ci/Test-ChangeDocs.ps1`

## Context Updates

- `README.md`
- `config/templates.json`
- `docs/features/template-registry.md`
