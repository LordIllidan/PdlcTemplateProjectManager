# Rejestr zainicjowanych systemów (w repo Project Manager)

## Cel

Żeby po provisioning widać było **listę projektów** utworzonych z tego szablonu — bez szukania po Issues.

## Gdzie to jest

| Plik | Rola |
|------|------|
| [`config/provisioned-systems.json`](../config/provisioned-systems.json) | Kanoniczny JSON (slug, nazwa, linki hub/docs, widoczność, źródło triggera, timestamp UTC). |
| [`docs/systems.md`](../systems.md) | Tabela do czytania w interfejsie GitHub (generowana z tych samych danych). |

## Kiedy się aktualizuje

Po każdym **udanym** przebiegu workflow `Provision PLDC project repos` (Issue + `pdlc-provision` albo `workflow_dispatch`). Przy ponownym uruchomieniu dla tego samego **slug** wpis jest **nadpisywany** (nowy timestamp i źródło).

## Uwaga wsteczna

Systemy utworzone **przed** wdrożeniem tej funkcji nie pojawią się automatycznie — uruchom ponownie provisioning dla danego slug (workflow zwykle tylko zaktualizuje hub + rejestr).
