# FlutterForge CLI

A command-line tool for generating Flutter projects with a production-ready architecture out of the box.

FlutterForge creates projects following Clean Architecture principles, with BLoC for state management, proper dependency injection, internationalization, and environment configuration — all the boilerplate you'd normally spend hours setting up.

## What's Included (Phase 1)

This initial release focuses on generating a solid foundation:

- **Clean Architecture** — Domain, Data, and Presentation layers properly structured
- **BLoC Pattern** — State management with Freezed for immutable states
- **Environment Configuration** — Dev, Staging, and Production environments ready to use
- **Internationalization** — English and Spanish translations pre-configured
- **Authentication Flow** — Login and Registration screens with local persistence
- **Settings** — Theme and language preferences with HydratedBloc persistence
- **VSCode Integration** — Launch configurations for all environments
- **Dependency Injection** — GetIt setup with all services registered

## Installation

```bash
# Clone the repository
git clone https://github.com/victorsdd01/flutter_forge.git
cd flutter_forge

# Compile the CLI
dart compile exe bin/flutterforge.dart -o build/flutterforge

# Run from anywhere
./build/flutterforge
```

Or install globally:

```bash
dart pub global activate --source path .
```

## Usage

Simply run the CLI and follow the interactive prompts:

```bash
flutterforge
```

You'll be asked for:
- Project name
- Organization (e.g., com.yourcompany)
- Target platforms
- Whether to include custom linter rules

The CLI handles everything else.

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
│   ├── main.dart             # Entry point (accepts environment)
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

## Environments

Three environments are pre-configured: **Development**, **Staging**, and **Production**.

Each has its own entry point (`main_dev.dart`, `main_staging.dart`, `main_production.dart`) and VSCode launch configuration ready to use.

## Dependencies

The generated project includes:

| Category | Packages |
|----------|----------|
| State Management | flutter_bloc, hydrated_bloc, freezed |
| Navigation | go_router |
| DI | get_it |
| Network | dio |
| Storage | drift, flutter_secure_storage |
| Forms | flutter_form_builder, form_builder_validators |
| Utilities | dartz, equatable, path_provider |

## After Generation

The CLI runs these commands automatically:
1. `flutter pub get`
2. `dart run intl_utils:generate` (translations)
3. `dart run build_runner build -d` (Freezed classes)
4. `pod install` (iOS/macOS if applicable)

Your project is ready to run immediately.

## Requirements

- Dart SDK >= 3.0.0
- Flutter >= 3.10.0

## Contributing

Contributions are welcome. Please open an issue first to discuss what you'd like to change.

## License

MIT

---

Built for developers who want to ship faster without compromising on architecture.
