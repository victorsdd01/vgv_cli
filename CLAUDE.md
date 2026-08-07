# CLAUDE.md

Contexto del proyecto para Claude Code. Este archivo se **actualiza y commitea** a medida que agregamos features/fixes, para no perder contexto entre sesiones (aprendimos por las malas: se perdió ~1 mes de trabajo local no pusheado cuando se dañó la placa de la laptop).

---

## Qué es este proyecto

`vgv_cli` es una **CLI en Dart** para generar proyectos Flutter production-ready y **evitar el boilerplate** de configurar todo a mano cada vez. La idea es generar un proyecto ya armado con la forma en la que el autor suele trabajar:

- **BLoC + Freezed** para state management (estados inmutables)
- **intl_utils** para traducciones (estilo claves como `jornaDay`) — de hecho **JornaDay se creó con este CLI**
- **Clean Architecture** por capas (domain / data / presentation)
- **GoRouter** para navegación
- **bundleID configurado de una** para Android e iOS (y la plataforma que sea) al momento de crear la app
- Entornos **dev / staging / production** listos
- Config de VS Code (launch configs)

Publicado en pub.dev como `vgv_cli`. Comando: `vgv`.

- Repo: https://github.com/victorsdd01/vgv_cli
- Autor: Victor Gonzalez (victorsdd01)

---

## Convenciones de trabajo (IMPORTANTE)

- **Rama de trabajo: `develop`.** Trabajamos y commiteamos aquí.
- **Commitear seguido** para no perder cambios (regla nacida de perder trabajo local).
- **Mantener este `CLAUDE.md` actualizado**: cada vez que agregamos algo o arreglamos un bug, actualizamos la sección correspondiente y commiteamos.
- Idioma de trabajo con el autor: **español**.

---

## Arquitectura del CLI (Clean Architecture)

El CLI mismo está estructurado en capas dentro de `lib/`:

| Capa | Ubicación | Responsabilidad |
|------|-----------|-----------------|
| **Entry** | `bin/vgv.dart` → `lib/vgv_cli.dart` | Parseo de args (`args`), help/version/update, dry-run, orquestación |
| **Presentation** | `lib/presentation/controllers/cli_controller.dart` | UI interactiva (paquete `interact`), modo por flags, resumen de config |
| **Domain** | `lib/domain/` | `entities/project_config.dart` (entidad + enums), `usecases/` (crear + validar), `repositories/project_repository.dart` (interfaz) |
| **Data** | `lib/data/` | `repositories/project_repository_impl.dart`, `datasources/file_system_datasource.dart`, `datasources/flutter_command_datasource.dart` |
| **Core** | `lib/core/` | DI manual (`di/dependency_injection.dart`), `utils/version_checker.dart`, `utils/ansi_colors.dart`, y el sistema de **templates** |

### Sistema de templates (el corazón de la generación)

- `lib/core/templates/template_contents.dart` — **~3600 líneas**: el contenido (como strings) de todos los archivos que se generan en el proyecto Flutter destino.
- `lib/core/templates/template_generator.dart` — orquesta la escritura de esos contenidos.
- `lib/core/templates/blocs/` — **proyecto Flutter completo de referencia** que sirve de base de las plantillas (features `auth`, `home`, `settings`, con capas domain/data/presentation, l10n, theme, routes, config de entornos, etc.).

> Nota: hay artefactos de build commiteados en `lib/core/templates/blocs/build/` que probablemente no deberían estar versionados (candidato a limpieza).

---

## Entidad de configuración

`ProjectConfig` (`lib/domain/entities/project_config.dart`) con enums:
- `StateManagementType`: `bloc`, `provider`, `none`
- `ArchitectureType`: `cleanArchitecture`, `mvvm`
- `PlatformType`: `mobile`, `web`, `desktop`
- `MobilePlatform`: `android`, `ios`, `both`
- `DesktopPlatform`: `windows`, `macos`, `linux`, `all`, `custom` (+ `CustomDesktopPlatforms`)

Validaciones (regex):
- Nombre proyecto: `^[a-z][a-z0-9_]*$`
- Organización: `^[a-z][a-z0-9._]*[a-z0-9]$`

> Hoy el flujo interactivo **fija** `bloc` + `cleanArchitecture` + `goRouter` + `freezed` (no se preguntan todavía), aunque los enums soportan más opciones.

---

## Comandos / modos de uso

```bash
vgv                         # modo interactivo (prompts guiados)
vgv -q -n my_app            # quick mode con defaults
vgv -n my_app --org com.x   # con organización
vgv -n my_app -o ~/proj     # directorio de salida
vgv -n my_app --no-git      # sin git init
vgv --dry-run -n my_app     # preview sin crear archivos
vgv -h                      # help
vgv -v                      # versión + check de updates
vgv -u                      # auto-update (reinstala desde git)
```

Flags: `--help/-h`, `--version/-v`, `--update/-u`, `--quick/-q`, `--name/-n`, `--org`, `--output/-o`, `--no-git`, `--dry-run`.

---

## Stack del CLI

- Dart SDK `>=3.7.0 <4.0.0`
- Deps: `args`, `path`, `http`, `mason_logger` (UI de terminal estilo Mason)
- Dev: `lints`, `test`
- **UI interactiva**: `cli_controller.dart` usa `mason_logger` (`prompt`, `confirm`, `chooseOne`, `chooseAny` multi-select ◉/◯, `progress`). Los prompts requieren un TTY real (no se pueden verificar con stdout redirigido).
- Tests en `test/` (3 archivos: validate config, version checker, project config)
- CI: `.github/workflows/auto-version-bump.yml` (bump automático de versión con `[skip ci]` para evitar loops)

---

## Roadmap / trabajo en curso

### 1. Mejorar la UI de terminal (✅ HECHO)
Migrado de `interact` a **`mason_logger`** (el logger de Mason CLI, hecho por Very Good Ventures — mismo ecosistema que VGV). `cli_controller.dart` ahora usa `chooseOne`/`chooseAny` (multi-select estilo inquirer), `prompt`, `confirm` y `progress`. `interact` removido.

### 1.b Flavors nativos + entry points (EN CURSO — feature grande)
Configurar **flavors nativos reales** (Android `productFlavors` en `build.gradle.kts` + iOS build configs/schemes en `pbxproj`) con **bundleID distinto por flavor**, app name por flavor, y entry points cableados con `--flavor`. El prompt (`chooseAny`) permite elegir 3, 2 o 1 flavor. Referencia de la convención: **el proyecto JornaDay** (`/Users/victorsdd/Desktop/JornaDay`), creado con la versión buena del CLI que se perdió.

**Convención de flavors confirmada** (el bundleID que escribe el usuario ES production/base; los demás derivan sufijo). Base `com.test.app`:

| Flavor | flavorName (`--flavor`, gradle, iOS scheme) | entry point | bundleId | app name |
|--------|------|------|------|------|
| production | `prod` | `main_production.dart` | `com.test.app` (limpio) | Test App |
| dev | `dev` | `main_dev.dart` | `com.test.app.dev` | Test App Dev |
| staging | `staging` | `main_staging.dart` | `com.test.app.stage` | Test App Stage |

- Base id real = `${organizationName}.${projectName}` (así lo arma `flutter create --org`).
- Android: `flavorDimensions += "environment"`, `applicationIdSuffix` por flavor (prod sin sufijo), `resValue("string","app_name",...)`, y `AndroidManifest` con `android:label="@string/app_name"`.
- iOS: xcconfig `Debug/Release/Profile-<flavorName>.xcconfig` con `FLUTTER_TARGET`, `PRODUCT_BUNDLE_IDENTIFIER`, `BUNDLE_DISPLAY_NAME`; build configs en `pbxproj`; schemes `<flavorName>.xcscheme`.
- ⚠️ JornaDay tiene el Android editado a mano para **compartir** id (Firebase único) — eso NO es la base; la base usa sufijo por flavor.
- Hoy (antes de esto) solo había "entornos por código" (entry points + `AppEnvironment`), sin flavors nativos. Flutter local: 3.44.8, Android Kotlin DSL.
- Implementado: entidad `Flavor` (`project_config.dart`), prompt (`cli_controller.dart`), preview de bundle IDs en el resumen, inyección Android (`configureFlavors` en `file_system_datasource.dart`, llamado desde `project_repository_impl.dart` tras `flutter create`). **Pendiente: iOS + entry points/launch.json + verificación.**

### 2. Bugs al actualizar
Al hacer `vgv -u` había bugs. Revisar el flujo de update en `lib/vgv_cli.dart` (`_updateCLI`, `_checkForUpdates`, `_showUpdateProgress`) y `version_checker.dart`.

**Causa raíz (con evidencia, 2026-08-07):** no hay una fuente única de verdad de versión y discrepan entre sí:
- `main` pubspec → **1.10.49** (bump `d8dfebb`, 2026-03-08, **sin tag ni release**)
- último git tag / GitHub Release → **v1.10.48** (2026-03-07)
- pub.dev → **1.10.41** (muy atrasado)

El `[skip ci]` del fix `977bd56` (para cortar el loop infinito del bump) también evitó que se tagueara/publicara el bump final → por eso 1.10.49 quedó sin tag/release. `getLatestCLIVersion()` lee releases (1.10.48) y `getLatestCLIVersionFromGit()` lee main pubspec (1.10.49) → inconsistencia. Además `getCurrentVersion()` lee primero `~/.vgv_version` (caché que queda viejo y tapa la versión real) y su fallback "dev mode" lee el pubspec del **CWD** (no el del CLI). Al actualizar, guarda la versión *esperada del remoto*, no la *realmente instalada*.

**Fix pendiente (2 frentes):** (a) código — elegir canal canónico único + versión horneada (constante Dart generada, estilo Mason) y eliminar el `~/.vgv_version` frágil; (b) CI — que el bump final sí genere su tag/release sin reactivar el loop.

### Ideas / features futuras
- Preguntar en interactivo por state management / arquitectura (ya soportado en enums).
- Limpiar artefactos de build versionados en `templates/blocs/build/`.
- Alinear docs (`USAGE.md` menciona Cubit/Provider/MVVM que el flujo actual no expone).

---

## Historial de sesiones

- **2026-08-07**: Máquina restaurada (placa reemplazada). Repo re-clonado limpio; se confirmó pérdida de ~1 mes de cambios locales no pusheados. Último commit real del proyecto: 2026-03-08 (v1.10.49). Se creó este `CLAUDE.md`. Se decidió trabajar en `develop`. Próximo paso: mejorar UI de terminal estilo Mason/Inquirer + arreglar bugs de update.
