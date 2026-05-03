# Context: Documentation

## Purpose

Dokumentacja procesu Project Manager: rejestr template’ów, provisioning z Issue oraz przykłady nazewnictwa projektów.

## Boundaries

- Owns treści w `docs/` oraz reguły dla Issues.
- Does not implementuje logiki aplikacji docelowej.

## Important Files

- `features/template-registry.md`: mapowanie template → repo docelowe.
- `features/systems-registry.md`: rejestr zainicjowanych systemów w tym repo.
- `features/provisioning-workflow.md`: krok po kroku (Issue + label + sekrety).
- `features/provisioning-example-mail-template-system.md`: przykład testowy „System do zarządzania szablonami maili”.

## Local Commands

- `pwsh ./scripts/ci/Test-ChangeDocs.ps1` (z katalogu głównego repozytorium)

## Decisions

- Przykłady biznesowe trzymamy w `docs/features/`, żeby nie rozpychać README.

## Child Contexts
