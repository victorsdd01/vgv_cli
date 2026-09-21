# 🚀 VGV CLI - Quick Usage Guide

## 📦 Installation

### **Cross-Platform Support** 🌍
VGV CLI works on **Windows**, **macOS**, and **Linux**!

### Option 1: Install from Git (Recommended)
```bash
# All platforms
dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git
```

### Option 2: Install from Local Source
```bash
# Clone the repository
git clone https://github.com/victorsdd01/vgv_cli.git
cd vgv_cli

# Install globally
dart pub global activate --source path .
```

### Option 3: Use Installation Scripts

#### **Windows**
```cmd
# Using batch script
git clone https://github.com/victorsdd01/vgv_cli.git
cd vgv_cli
install.bat

# Using PowerShell script
git clone https://github.com/victorsdd01/vgv_cli.git
cd vgv_cli
powershell -ExecutionPolicy Bypass -File install.ps1
```

#### **macOS/Linux**
```bash
# Using shell script
git clone https://github.com/victorsdd01/vgv_cli.git
cd vgv_cli
./install.sh
```

## 🎯 Basic Usage

### Create a New Project
```bash
# Start the interactive CLI
vgv

# Or with the full command
dart pub global run vgv
```

### The stack is fixed (opinionated)

Every project is generated with the author's production setup — **you don't pick these**:

- **BLoC + Freezed** for state management (immutable states)
- **Clean Architecture** (domain / data / presentation layers)
- **GoRouter** for navigation
- **intl_utils** for internationalization

### Follow the Interactive Prompts

The CLI asks you for:

1. **Project details** — name (e.g. `my_awesome_app`) + organization (e.g. `com.example`)
2. **Platforms** — Mobile (Android/iOS), Web, Desktop (Windows/macOS/Linux), or a custom selection
3. **Native flavors** *(mobile)* — `dev` / `staging` / `prod` with native build configs + a bundle-id suffix per flavor; pick 1, 2 or 3
4. **Fastlane** *(mobile, optional)* — CI/CD lanes for Play Store / TestFlight
5. **lefthook** *(optional)* — pre-commit / pre-push git hooks
6. **Seed color** *(optional)* — a hex color for `ColorScheme.fromSeed` (light + dark)
7. **App icon** *(optional)* — a 1024px master → launcher icons (with a per-flavor banner on dev/staging)
8. **Splash screen** *(optional)* — native splash from the seed color + icon
9. **Desktop window** *(desktop, optional)* — min size + title via `window_manager`
10. **AI agent rules** *(optional)* — a rules file per agent (Claude / Cursor / Copilot / Gemini / Windsurf / Codex)
11. **Linter rules** — custom analysis options

At the end you get a **review-and-edit summary**: create, tweak any field, or cancel.

## 🔧 Post-Generation Steps

### For All Projects
```bash
cd my_app
flutter pub get
flutter analyze
flutter run
```

### For Freezed Projects
```bash
cd my_app
dart run build_runner build -d
flutter pub get
flutter run
```

## 📋 Example Workflow

```bash
# 1. Install the CLI
dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git

# 2. Create a project
vgv

# 3. Follow prompts:
#    Project name: my_app
#    Organization: com.example
#    Platforms: Mobile (Android & iOS)
#    Flavors: dev, staging, prod
#    (BLoC + Freezed + Clean Architecture + GoRouter come baked in)

# 4. Navigate to project
cd my_app

# 5. Get dependencies
flutter pub get

# 6. Generate Freezed files
dart run build_runner build -d

# 7. Run the app (with a flavor if you enabled them)
flutter run --flavor dev -t lib/main_dev.dart
```

## ⚡ Non-interactive & other commands

```bash
# Quick create with flags (skips the prompts)
vgv -q -n my_app --org com.example --flavors dev,prod
vgv --dry-run -n my_app            # preview without writing files

# Scaffold into an existing project
vgv gen feature profile            # full Clean-Architecture feature
vgv gen model User --from user.json # freezed model + entity from JSON
vgv gen api Store --from openapi.yaml
vgv gen bloc Cart --feature cart   # also: page, usecase
vgv gen brick                      # render your own Mason bricks (lists them)

# Store screenshots
vgv screenshots web                # visual editor in the browser
vgv screenshots frames --cloud     # download the device-frame library
vgv screenshots --init             # scaffold a manifest for the CLI renderer

# Utilities
vgv doctor                         # check the toolchain (Flutter/Dart/git + optional)
vgv deps                           # audit the pinned dependency versions
vgv config init                    # create a vgv.yaml with default flags
vgv -u                             # update the CLI
vgv -h                             # full help
```

Useful create flags: `--name/-n`, `--org`, `--output/-o`, `--flavors`, `--quick/-q`,
`--no-git`, `--dry-run`, `--fvm`/`--no-fvm`. Precedence for presets:
**flags > `vgv.yaml` > `~/.vgvrc`**.

**FVM:** if `fvm` is installed and the project is pinned (`.fvmrc`/`.fvm/`), vgv
runs Flutter/Dart through it automatically. Creating with `--fvm` pins the new
project too (`.fvmrc` + editor SDK path).

## 🎨 Generated Project Structure

```
my_app/
├── lib/
│   ├── application/                # app wiring
│   │   ├── injector.dart           # DI (get_it)
│   │   ├── routes/                 # GoRouter config
│   │   ├── app_shell.dart          # adaptive navigation shell
│   │   └── l10n/ + generated/      # intl_utils
│   ├── core/
│   │   ├── config/                 # AppConfiguration / environments
│   │   ├── states/                 # TStateless / TStatefull
│   │   └── utils/
│   ├── features/                   # one folder per feature
│   │   └── <feature>/
│   │       ├── domain/             # entities, repositories, use_cases
│   │       ├── data/               # datasources, models, repositories
│   │       └── presentation/       # blocs (freezed), pages
│   ├── shared/widgets/             # e.g. ResponsiveCenter
│   ├── main_dev.dart               # entry point per flavor
│   ├── main_staging.dart
│   └── main_production.dart
├── android/ + ios/                 # native flavors (build configs, schemes)
├── pubspec.yaml
├── analysis_options.yaml
├── build.yaml                      # freezed / json_serializable
└── README.md
```

## 🚀 Happy Coding!

Your Flutter project is ready with:
- ✅ BLoC + Freezed
- ✅ Clean Architecture
- ✅ GoRouter navigation
- ✅ Internationalization (intl_utils)
- ✅ Native flavors (dev / staging / prod)
- ✅ Linter rules & latest dependencies

Start building amazing Flutter apps! 🎉 