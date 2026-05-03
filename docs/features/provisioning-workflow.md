# Provisioning projektu (Issue → repozytoria)

## Wymagania

1. **Sekret** `PDLC_REPO_ADMIN_TOKEN` — PAT z prawem tworzenia repozytoriów pod kontem `github.repository_owner`.
2. **Etykieta** `pdlc-provision` musi istnieć w repozytorium (Issues → Labels → New label).
3. Template repozytoria muszą mieć włączone **Template repository** na GitHubie.

## Ścieżka z Issue

1. **New issue** → szablon **New PLDC project (provision)**.
2. Tytuł: `[provision] <nazwa>` (np. `[provision] System do zarządzania szablonami maili`).
3. Uzupełnij pola (slug ASCII, widoczność, krótki opis).
4. Zapisz issue, potem dodaj label **`pdlc-provision`**.

Workflow `Provision PLDC project repos` utworzy brakujące repozytoria (`gh repo create … --template …`) i doda komentarz z linkami.

## Ścieżka ręczna (Actions)

`Actions` → `Provision PLDC project repos` → `Run workflow` z polami `display_name`, `project_slug`, `visibility`.

## Idempotentność

Jeśli repo o docelowej nazwie już istnieje, provisioning je **pomija** (nie nadpisuje).
