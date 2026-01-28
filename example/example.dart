/// VGV CLI - Flutter Project Generator
///
/// A command-line tool for generating Flutter projects with production-ready
/// architecture including Clean Architecture, BLoC, Freezed, and more.
///
/// ## Installation
///
/// ```bash
/// dart pub global activate vgv_cli
/// ```
///
/// ## Quick Start
///
/// ### Interactive Mode (Recommended)
///
/// Simply run the CLI and follow the prompts:
///
/// ```bash
/// vgv
/// ```
///
/// ### Quick Mode
///
/// Create a project with sensible defaults:
///
/// ```bash
/// vgv -q -n my_awesome_app
/// ```
///
/// ### With Custom Organization
///
/// ```bash
/// vgv -n my_app --org com.mycompany
/// ```
///
/// ### Preview Mode (Dry Run)
///
/// See what would be created without creating files:
///
/// ```bash
/// vgv --dry-run -n test_app
/// ```
///
/// ## Available Commands
///
/// | Command | Description |
/// |---------|-------------|
/// | `vgv` | Interactive mode |
/// | `vgv -h` | Show help |
/// | `vgv -v` | Show version |
/// | `vgv -u` | Update CLI |
/// | `vgv -q -n <name>` | Quick create |
/// | `vgv -n <name> --org <org>` | With organization |
/// | `vgv -n <name> -o <dir>` | Custom output directory |
/// | `vgv -n <name> --no-git` | Skip git init |
/// | `vgv --dry-run -n <name>` | Preview mode |
///
/// ## Generated Project Features
///
/// - Clean Architecture (Domain, Data, Presentation layers)
/// - BLoC state management with Freezed
/// - GoRouter for navigation
/// - Internationalization (English & Spanish)
/// - 3 environments (Dev, Staging, Production)
/// - Authentication flow (Login/Register)
/// - Settings with theme and language
/// - VSCode launch configurations
/// - GetIt dependency injection
///
/// ## Running Generated Projects
///
/// ```bash
/// cd my_app
///
/// # Development
/// flutter run -t lib/main_dev.dart
///
/// # Staging
/// flutter run -t lib/main_staging.dart
///
/// # Production
/// flutter run -t lib/main_production.dart
/// ```
library;

// This is a CLI tool, not a library.
// Install and use via command line:
//
//   dart pub global activate vgv_cli
//   vgv
//
// For programmatic usage, you can import the main class:

import 'package:vgv_cli/vgv_cli.dart';

void main(List<String> args) async {
  // Run the CLI
  await VgvCli().run(args);
}
