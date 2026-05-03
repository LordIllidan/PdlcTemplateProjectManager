# PdlcTemplateProjectManager

Szablon repozytorium **Project Manager** dla PLDC: z poziomu **Issue** uruchamiasz provisioning — CI tworzy **komplet repozytoriów** projektu z istniejących **template repozytoriów** (Angular FE, .NET API, Liquibase, Flux GitOps, PLDC Hub, Project Docs).

## Wymagania (GitHub)

1. **Sekret** `PDLC_REPO_ADMIN_TOKEN` — PAT użytkownika lub bot-account z prawem tworzenia repozytoriów pod docelowym kontem/organizacją (np. scope `repo` dla konta użytkownika).
2. **Etykieta** `pdlc-provision` — utwórz ją raz w repozytorium (Issues → Labels), workflow reaguje na dodanie tej etykiety do issue.
3. Wszystkie repozytoria w `config/templates.json` muszą być oznaczone jako **Template** na GitHubie (`is_template=true`).

## Jak utworzyć projekt (Issue)

1. Utwórz issue z szablonu **New PLDC project (provision)**.
2. Ustaw tytuł w formacie: `[provision] <czytelna nazwa projektu>`.
3. Uzupełnij pola formularza (slug ASCII, widoczność, opis).
4. Zapisz issue, a następnie **dodaj label `pdlc-provision`** — dopiero to uruchamia workflow tworzący repozytoria.

Alternatywa: **Actions → Provision PLDC project repos → Run workflow** (ręczne uruchomienie z parametrami).

## Po provisioning

- W repozytorium **`*-hub`** uzupełnij `config/solutions/*.json` linkami do utworzonych repo FE/API/GitOps/DB/Docs (szablon hubu zawiera przykład).
- W repozytorium **`*-docs`** zbieraj dokumentację projektu; w kodzie trzymaj tylko odesłania do `docs/`.

## Testowy przykład biznesowy

Projekt: **System do zarządzania szablonami maili** — przykładowy slug i pełna ścieżka opisana w `docs/features/provisioning-example-mail-template-system.md`.
