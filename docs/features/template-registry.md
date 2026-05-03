# Rejestr template’ów (`config/templates.json`)

## Cel

Jedno miejsce z referencjami do **wszystkich** oficjalnych template repozytoriów PLDC używanych przy zakładaniu projektu.

## Domyślne wpisy

| `repo_suffix` | Template GitHub | Docelowy typ repo |
|---------------|-----------------|-------------------|
| `fe` | `LordIllidan/PdlcTemplateAngularFrontend` | Frontend Angular |
| `api` | `LordIllidan/PdlcTemplateDotNetApi` | API .NET |
| `db` | `LordIllidan/PdlcTemplateLiquibaseDb` | Migracje Liquibase |
| `gitops` | `LordIllidan/PdlcTemplateFluxGitOps` | GitOps Flux |
| `hub` | `LordIllidan/PdlcTemplatePLDCHub` | Hub konfiguracji rozwiązania |
| `docs` | `LordIllidan/PdlcTemplatePLDCProjectDocs` | Dokumentacja projektu |

## Nazewnictwo

Dla slug projektu `mail-templates-system` powstaną m.in.:

- `LordIllidan/mail-templates-system-fe`
- `LordIllidan/mail-templates-system-hub`
- itd.

## Zmiana rejestru

Edytuj `config/templates.json` w PR i dopisz wpis w `docs/changes/`.
