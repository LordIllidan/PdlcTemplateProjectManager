# PdlcTemplateProjectManager

Szablon repozytorium **Project Manager** dla PLDC: z poziomu **Issue** uruchamiasz provisioning — CI tworzy **komplet repozytoriów** projektu z istniejących **template repozytoriów** (Angular FE, .NET API, Liquibase, Flux GitOps, PLDC Hub, Project Docs).

## Wymagania (GitHub)

1. **Sekret** `PDLC_REPO_ADMIN_TOKEN` — PAT z prawem **tworzenia repozytoriów** oraz **zapisu plików** w repozytoriach (aktualizacja `sample.json` w `*-hub` odbywa się przez [Contents API](https://docs.github.com/en/rest/repos/contents#create-or-update-file-contents); typowo scope **`repo`** dla tokenów classic).
2. **Etykieta** `pdlc-provision` — utwórz ją raz w repozytorium (Issues → Labels), workflow reaguje na dodanie tej etykiety do issue.
3. Wszystkie repozytoria w `config/templates.json` muszą być oznaczone jako **Template** na GitHubie (`is_template=true`).

## Jak utworzyć projekt (Issue)

1. Utwórz issue z szablonu **New PLDC project (provision)**.
2. Ustaw tytuł w formacie: `[provision] <czytelna nazwa projektu>`.
3. Uzupełnij pola formularza (slug ASCII, widoczność, opis).
4. Zapisz issue, a następnie **dodaj label `pdlc-provision`** — dopiero to uruchamia workflow tworzący repozytoria.

Alternatywa: **Actions → Provision PLDC project repos → Run workflow** (ręczne uruchomienie z parametrami).

## Lista zainicjowanych systemów

Po każdym udanym provisioning CI aktualizuje:

- [`docs/systems.md`](docs/systems.md) — tabela do przeglądania w GitHubie  
- [`config/provisioned-systems.json`](config/provisioned-systems.json) — kanoniczny zapis (JSON)

## Po provisioning

- Po każdym udanym provisioning CI aktualizuje **rejestr systemów** w tym samym repo: [`config/provisioned-systems.json`](config/provisioned-systems.json) oraz [`docs/systems.md`](docs/systems.md).
- CI **nadpisuje** w `*-hub` plik `config/solutions/sample.json` (URL-e do `*-fe`, `*-api`, `*-db`, `*-gitops` oraz `project.name` / `project.code` z danych provisioning).
- W repozytorium **`*-docs`** zbieraj dokumentację projektu; w kodzie trzymaj tylko odesłania do `docs/`.

## Testowy przykład biznesowy

Projekt: **System do zarządzania szablonami maili** — przykładowy slug i pełna ścieżka opisana w `docs/features/provisioning-example-mail-template-system.md`.
