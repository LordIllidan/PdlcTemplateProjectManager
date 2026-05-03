# Przykład: „System do zarządzania szablonami maili”

## Issue

- **Tytuł:** `[provision] System do zarządzania szablonami maili`
- **Project slug (ASCII):** `mail-templates-system` (przykład — możesz wybrać inny, byle spełniał reguły z formularza)
- **Visibility:** `public` lub `private` wg polityki organizacji
- **Short description:** np. `Centralne zarządzanie szablonami wiadomości e-mail, wersjonowanie i publikacja.`

## Oczekiwane repozytoria (owner = właściciel template PM)

Przy slug `mail-templates-system`:

- `…/mail-templates-system-fe`
- `…/mail-templates-system-api`
- `…/mail-templates-system-db`
- `…/mail-templates-system-gitops`
- `…/mail-templates-system-hub`
- `…/mail-templates-system-docs`

## Po utworzeniu

1. W repo `*-hub` ustaw profile w `config/solutions/*.json` na faktyczne URL-e powyższych repozytoriów.
2. W repo `*-docs` zbieraj dokumentację analityczną i ADR-y projektu.
