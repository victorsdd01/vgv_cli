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
- Implementado: entidad `Flavor` (`project_config.dart`), prompt (`cli_controller.dart`), preview de bundle IDs en el resumen, inyección Android + **iOS** (`configureFlavors` en `file_system_datasource.dart`, llamado desde `project_repository_impl.dart` tras `flutter create`).
  - iOS: genera xcconfig `<BuildType>-<flavor>.xcconfig` (con `FLUTTER_TARGET`, `PRODUCT_BUNDLE_IDENTIFIER`, `BUNDLE_DISPLAY_NAME`), duplica las build configs Debug/Release/Profile → `-<flavor>` en las 3 config lists del `pbxproj` (bundle id por flavor solo en el target Runner), y crea schemes `<flavor>.xcscheme`. Ids de pbxproj generados con prefijo `FF` (sin colisión con flutter). **Validado con `xcodebuild -list`** (reconoce configs y schemes).
  - Parte 4 (✅): `launch.json` flavor-aware (una config por flavor×modo con `"args":["--flavor",...]`), poda de entry points `main_<f>.dart` no seleccionados, y "Next steps" del CLI con `flutter run --flavor`.
  - Parte 5 (✅) **verificación end-to-end con builds reales**: se generó `flavor_test` con el CLI (147s) y se compilaron ambas plataformas:
    - Android: `✓ app-dev-debug.apk` (flavor dev). **Requirió fix**: AGP 8+ necesita `buildFeatures { resValues = true }` para `resValue app_name` (sin eso el build falla). Ya inyectado.
    - iOS: `✓ Runner.app`, bundle `com.flavortest.flavorTest.dev` (flavor dev aplicado).
    - Chequeos confirmados en el proyecto generado: auth state con **freezed** (igual que JornaDay), build_runner generó `*.freezed.dart`/`*.g.dart`, capas de datos completas (data/domain/presentation en auth+home), states custom `core/states/tstateless.dart` + `tstatefull.dart`.

### 1.c Bug hunt del CLI (feature #9) — hallazgos y estado
Análisis exhaustivo del CLI (2026-08-07). Arreglados:
- **P1** `-o/--output` se ignoraba (proyecto siempre en CWD) → `createProject` ahora hace `Directory.current = outputDir`.
- **P1** `--no-git` no hacía nada y además `flutter create` no inicializa git → nuevo `initializeGit` (git init + add) que corre salvo `--no-git`.
- **P2** flavors en proyectos web/desktop-only rompían (`--flavor` no soportado) → `launch.json` y hints omiten `--flavor` si no hay mobile (`ProjectConfig.usesNativeFlavors`).
- **P2** `addDependencies` corrompía el pubspec (metía el SDK de flutter y `cupertino_icons` bajo `dev_dependencies`) → reescrito para insertar tras cada header de sección preservando lo existente.
- **P2** Android `resValues` (ver Parte 5).
- **P3** regex de org aceptaba puntos consecutivos (`com..x`) → corregida; `compareVersions` podía lanzar `FormatException` → parseo defensivo; `getLatestCLIVersion` sin timeout → timeout 10s.

Pendientes (menor prioridad, ver #9): reporte de éxito engañoso cuando build_runner/l10n/pods fallan en silencio (P2); use cases de dominio (`CreateProjectUseCase`/`ValidateProjectConfigUseCase`) nunca se invocan → sin pre-check limpio de "flutter no instalado" (P2); barra de progreso de update falsa (cosmético); exit code 0 en fallos de validación; flags ignoradas fuera de flag-mode.

### 2. Bugs al actualizar
Al hacer `vgv -u` había bugs. Revisar el flujo de update en `lib/vgv_cli.dart` (`_updateCLI`, `_checkForUpdates`, `_showUpdateProgress`) y `version_checker.dart`.

**Causa raíz (con evidencia, 2026-08-07):** no hay una fuente única de verdad de versión y discrepan entre sí:
- `main` pubspec → **1.10.49** (bump `d8dfebb`, 2026-03-08, **sin tag ni release**)
- último git tag / GitHub Release → **v1.10.48** (2026-03-07)
- pub.dev → **1.10.41** (muy atrasado)

El `[skip ci]` del fix `977bd56` (para cortar el loop infinito del bump) también evitó que se tagueara/publicara el bump final → por eso 1.10.49 quedó sin tag/release. `getLatestCLIVersion()` lee releases (1.10.48) y `getLatestCLIVersionFromGit()` lee main pubspec (1.10.49) → inconsistencia. Además `getCurrentVersion()` lee primero `~/.vgv_version` (caché que queda viejo y tapa la versión real) y su fallback "dev mode" lee el pubspec del **CWD** (no el del CLI). Al actualizar, guarda la versión *esperada del remoto*, no la *realmente instalada*.

**Fix aplicado (✅):**
- **Versión horneada como fuente única**: `lib/src/version.dart` con `const packageVersion` (generado por `tool/generate_version.dart` desde pubspec). `VersionChecker.getCurrentVersion()` ahora devuelve esa constante. Eliminado el frágil `~/.vgv_version` (que quedaba viejo y tapaba la versión real) y el fallback al pubspec del CWD.
- **Canal canónico único**: `getLatestCLIVersionAny()` lee el `pubspec` de `main` (lo que instala `vgv -u`); GitHub Releases queda solo como fallback. Se acabó la discrepancia releases vs main.
- **CI**: el workflow `auto-version-bump.yml` ahora sincroniza `lib/src/version.dart` (via sed) al hacer bump y lo incluye en el commit del bump.
- Limpieza en `vgv_cli.dart`: quitado `_initializeVersionFile`, los `saveInstalledVersion` y el fallback muerto `1.0.0`.
- Verificado: `vgv -v` → current 1.10.39 (horneada) / latest 1.10.49 (git main). 31 tests pasan.

**Nota (lag de tag/release, no crítico):** el job de release taguea la versión actual del pubspec en el siguiente push que NO sea de bump; por eso el último tag/release (v1.10.48) va una versión detrás del pubspec de main (1.10.49). Ya no afecta al CLI porque "latest" se lee de main, no de releases. `develop` (1.10.39) está detrás de `main` (1.10.49) — otro efecto del auto-bump en main sin merge-back a develop.

### Ideas / features futuras
- Preguntar en interactivo por state management / arquitectura (ya soportado en enums).
- Limpiar artefactos de build versionados en `templates/blocs/build/`.
- Alinear docs (`USAGE.md` menciona Cubit/Provider/MVVM que el flujo actual no expone).

---

## Historial de sesiones

- **2026-08-07**: Máquina restaurada (placa reemplazada). Repo re-clonado limpio; se confirmó pérdida de ~1 mes de cambios locales no pusheados. Último commit real del proyecto: 2026-03-08 (v1.10.49). Se creó este `CLAUDE.md`. Se decidió trabajar en `develop`. Próximo paso: mejorar UI de terminal estilo Mason/Inquirer + arreglar bugs de update.
