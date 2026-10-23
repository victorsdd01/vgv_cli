# VGV CLI

A command-line tool for generating Flutter projects with a production-ready architecture out of the box.

VGV CLI creates projects following Clean Architecture principles, with BLoC for state management, proper dependency injection, internationalization, and environment configuration — all the boilerplate you'd normally spend hours setting up.

## 🎬 Demo

![VGV CLI Demo](demo.gif)

> **30 seconds** from zero to a production-ready Flutter project

---

## Quick Start

```bash
# Install
dart pub global activate vgv_cli

# Create a project (interactive mode)
vgv

# Or quick mode
vgv -q -n my_app
```

---

## 📖 Commands Reference

### Basic Usage

| Command | Description |
|---------|-------------|
| `vgv` | Start interactive mode with guided prompts |
| `vgv -h` | Show help and all available options |
| `vgv -v` | Show current version and check for updates |
| `vgv -u` | Update VGV CLI to the latest version |

### Create Projects

| Command | Description |
|---------|-------------|
| `vgv -q -n my_app` | Quick mode: create project with defaults |
| `vgv -n my_app` | Create project with specific name |
| `vgv -n my_app --org com.company` | Create with custom organization |
| `vgv -n my_app -o ~/projects` | Create in specific directory |
| `vgv -n my_app --no-git` | Create without git initialization |
| `vgv --dry-run -n my_app` | Preview what would be created |

### All Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--help` | `-h` | Show help message |
| `--version` | `-v` | Show version information |
| `--update` | `-u` | Update to latest version |
| `--quick` | `-q` | Quick mode with sensible defaults |
| `--name <name>` | `-n` | Project name (lowercase, underscores) |
| `--org <org>` | | Organization identifier (e.g., com.example) |
| `--output <dir>` | `-o` | Output directory |
| `--flavors <list>` | | Native flavors to set up (e.g. `dev,staging,prod`) |
| `--fvm` / `--no-fvm` | | Run through FVM (auto-detected on FVM-pinned projects) |
| `--no-git` | | Skip git initialization |
| `--dry-run` | | Preview without creating files |

### Scaffolding into an Existing Project

| Command | Description |
|---------|-------------|
| `vgv gen feature <name>` | Full Clean Architecture feature (domain/data/presentation) |
| `vgv gen model <Name> --from <file.json>` | Freezed model + domain entity from a JSON sample |
| `vgv gen api <Name> --from <openapi.yaml>` | Typed API client + models from an OpenAPI spec |
| `vgv gen bloc <Name> --feature <f>` | Just a BLoC (also: `gen page`, `gen usecase`) |
| `vgv gen brick [name]` | Render one of **your own** Mason bricks from a git repo |

Generators auto-wire DI + routes and run `build_runner` for you
(`--no-wire` / `--no-build-runner` to skip).

### Store Screenshots

| Command | Description |
|---------|-------------|
| `vgv screenshots web` | Visual editor in your browser (Canvas, no Python) |
| `vgv screenshots frames --cloud` | Download the device-frame library to `~/.vgv/frames` |
| `vgv screenshots frames <dir>` | Build the frame library from your own bezels (`.dmg`/`.png`) |
| `vgv screenshots --init` | Scaffold a manifest for the batch renderer |
| `vgv screenshots <manifest>` | Render framed store screenshots (needs Python + Pillow) |
| `vgv screenshots capture --init` | Scaffold a golden harness to auto-capture raw screens |

### Adding Configuration to an Existing Project

| Command | Description |
|---------|-------------|
| `vgv add flavors` | Add native dev/staging/prod flavors to a project you already have |

Run it inside the project. It reads your current application id, refuses to
touch a project that already declares product flavors, and writes the Android
product flavors, iOS build configs and schemes, per-flavor launcher icons and
a `lib/main_<flavor>.dart` per flavor that calls your existing `main()`.
It also reads the display name your app already uses and asks whether to keep
it (the flavors just append their suffix) or change it — so adding flavors
never renames your app behind your back.

Flags: `--flavors dev,prod`, `--app-name <name>`, `--bundle-id <id>`, `--force`.

### Utilities

| Command | Description |
|---------|-------------|
| `vgv doctor` | Check the toolchain (Flutter, Dart, git + optional tools) |
| `vgv deps` | Audit the dependency versions the CLI pins against pub.dev |
| `vgv config init` | Create a `vgv.yaml` with your default flags |
| `vgv config show` | Show the effective presets |

Presets precedence: **flags > `vgv.yaml` > `~/.vgvrc`**.

### FVM

If you pin Flutter with [FVM](https://fvm.app), vgv uses it automatically: when
`fvm` is installed and the project has `.fvmrc`/`.fvm/`, every `flutter`/`dart`
call runs through it. Force it either way with `--fvm` / `--no-fvm`.

Creating a project with `--fvm` also pins the new project — it writes `.fvmrc`,
points the editor at `.fvm/flutter_sdk`, and ignores the SDK symlink — so the
whole team builds with the same SDK.

---

## Examples

### Interactive Mode (Recommended for first-time users)

```bash
vgv
```

You'll be guided through:
1. Project name
2. Organization
3. Platform selection (Mobile, Web, Desktop, or combinations)
4. Linter rules preference

### Quick Project Creation

```bash
# Minimal - just the name
vgv -q -n todo_app

# With organization
vgv -q -n todo_app --org com.mycompany

# In a specific folder
vgv -q -n todo_app -o ~/flutter_projects

# Without git
vgv -q -n todo_app --no-git
```

### Preview Mode

```bash
# See what would be created without actually creating files
vgv --dry-run -n test_app
```

Output:
```
DRY RUN - No files will be created

Configuration:
   Project Name:  test_app
   Organization:  com.test_app
   Output:        /current/directory

Would create:
   - Flutter project with Clean Architecture
   - BLoC state management with Freezed
   - GoRouter navigation
   - Internationalization (en, es)
   - Environment configs (dev, staging, production)
   - VS Code launch configurations
   - Auth feature (login, register)
   - Home feature
   - Settings feature (theme, language)
```

---

## What's Included

| Feature | Details |
|---------|---------|
| **Clean Architecture** | Domain, Data, and Presentation layers properly structured |
| **BLoC Pattern** | State management with Freezed for immutable states |
| **Native Flavors** | Real dev/staging/prod flavors — Android `productFlavors` + iOS build configs & schemes, with a bundle-id suffix and app name per flavor |
| **Per-flavor App Icons** | dev/staging get a diagonal banner on the icon so you can tell builds apart |
| **Environment Configuration** | Dev, Staging, and Production environments ready to use |
| **Internationalization** | English and Spanish translations pre-configured (intl_utils) |
| **Authentication Flow** | Login and Registration screens with local persistence |
| **Settings** | Theme and language preferences with HydratedBloc persistence |
| **Adaptive Navigation** | `NavigationRail` on wide screens, `NavigationBar` on mobile |
| **Responsive UI** | Forms and content constrained/centered on desktop & web |
| **Brand Seed Color** | Material 3 light + dark schemes from `ColorScheme.fromSeed` |
| **Launcher Icon & Splash** | Optional icon set + native splash wired from a 1024px master |
| **Fastlane** | Optional CI/CD lanes for Play Store (per flavor) and TestFlight |
| **lefthook Git Hooks** | Optional pre-commit (format + analyze) and pre-push (test) |
| **AI Agent Rules** | Optional rules file per agent (Claude, Cursor, Copilot, Gemini, Windsurf, Codex) |
| **FVM-ready** | With `--fvm`, the project is pinned to an FVM-managed SDK (`.fvmrc` + editor config) |
| **VSCode Integration** | Flavor-aware launch configurations for all environments |
| **Dependency Injection** | GetIt setup with all services registered |

---

## Generated Project Structure

```
your_project/
├── lib/
│   ├── application/
│   │   ├── config/           # Environment configuration
│   │   ├── l10n/             # Translation files (.arb)
│   │   ├── routes/           # GoRouter setup
│   │   └── theme/            # App theming
│   ├── core/
│   │   ├── database/         # Drift database setup
│   │   ├── errors/           # Failure classes
│   │   ├── extensions/       # String extensions
│   │   ├── network/          # HTTP client
│   │   ├── services/         # Talker logging
│   │   ├── states/           # Base widget classes
│   │   └── utils/            # Helpers and utilities
│   ├── features/
│   │   ├── auth/             # Authentication feature
│   │   ├── home/             # Home feature
│   │   └── settings/         # Settings feature
│   ├── shared/
│   │   └── widgets/          # Reusable widgets and dialogs
│   ├── main.dart             # Entry point
│   ├── main_dev.dart         # Development entry
│   ├── main_staging.dart     # Staging entry
│   └── main_production.dart  # Production entry
├── .vscode/
│   ├── launch.json           # Run configurations
│   └── settings.json         # Editor settings
├── pubspec.yaml
├── build.yaml
└── analysis_options.yaml
```

---

## Running Your Generated Project

```bash
cd your_project

# Development
flutter run -t lib/main_dev.dart

# Staging
flutter run -t lib/main_staging.dart

# Production
flutter run -t lib/main_production.dart
```

Or use the VSCode launch configurations (F5).

---

## Dependencies in Generated Projects

| Category | Packages |
|----------|----------|
| State Management | flutter_bloc, hydrated_bloc, freezed |
| Navigation | go_router |
| DI | get_it |
| Network | dio |
| Storage | drift, flutter_secure_storage |
| Forms | flutter_form_builder, form_builder_validators |
| Utilities | dartz, equatable, path_provider |

---

## Installation

### From pub.dev (recommended)

```bash
dart pub global activate vgv_cli
```

### From source

```bash
git clone https://github.com/victorsdd01/vgv_cli.git
cd vgv_cli
dart pub global activate --source path .
```

### Update

```bash
vgv -u
```

---

## Requirements

- Dart SDK >= 3.0.0
- Flutter >= 3.10.0

---

## Troubleshooting

### Command not found: vgv

Make sure Dart's global bin is in your PATH:

```bash
# Add to ~/.zshrc or ~/.bashrc
export PATH="$PATH:$HOME/.pub-cache/bin"
```

### Flutter doctor issues

Run `flutter doctor` and resolve any issues before using VGV CLI.

---

## Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

---

## Support

If this tool saves you time, consider:
- ⭐ Starring the repo on [GitHub](https://github.com/victorsdd01/vgv_cli)
- 👍 Liking the package on [pub.dev](https://pub.dev/packages/vgv_cli)

---

## License

MIT

---

Built for developers who want to ship faster without compromising on architecture.
