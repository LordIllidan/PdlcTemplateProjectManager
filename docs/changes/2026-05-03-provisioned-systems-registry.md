# Change: Rejestr zainicjowanych systemów w Project Manager

## Summary

Po provisioning CI zapisuje listę systemów w `config/provisioned-systems.json` oraz generuje `docs/systems.md`, żeby projekty były widoczne bez przeszukiwania Issues.

## Verification

- `pwsh ./scripts/ci/Test-ContextDocs.ps1`
- `pwsh ./scripts/ci/Test-ChangeDocs.ps1`

## Context Updates

- `context.md`
- `docs/context.md`
- `README.md`
- `docs/features/provisioning-workflow.md`
