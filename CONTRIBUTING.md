# Contributing to VGV CLI

First off, thanks for taking the time to contribute! 🎉

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report, please check if the issue already exists. When creating a bug report, include as many details as possible:

- **Dart/Flutter version** (`dart --version`, `flutter --version`)
- **OS and version**
- **Steps to reproduce**
- **Expected vs actual behavior**
- **Screenshots or terminal output** if applicable

### Suggesting Features

Feature requests are welcome! Please describe:

- **The problem** you're trying to solve
- **The solution** you'd like
- **Alternatives** you've considered

### Pull Requests

1. **Fork** the repo
2. **Clone** your fork:
   ```bash
   git clone git@github.com:YOUR_USERNAME/vgv_cli.git
   ```
3. **Create a branch**:
   ```bash
   git checkout -b feature/my-feature
   # or
   git checkout -b fix/bug-description
   ```
4. **Make your changes**
5. **Test** your changes:
   ```bash
   dart pub get
   dart run bin/vgv.dart
   ```
6. **Commit** with a clear message:
   ```bash
   git commit -m "feat: add new feature"
   # or
   git commit -m "fix: resolve issue with X"
   ```
7. **Push** to your fork:
   ```bash
   git push origin feature/my-feature
   ```
8. **Open a Pull Request**

## Development Setup

### Prerequisites

- Dart SDK >= 3.7.0
- Flutter >= 3.10.0

### Running Locally

```bash
# Clone the repo
git clone git@github.com:victorsdd01/vgv_cli.git
cd vgv_cli

# Install dependencies
dart pub get

# Run the CLI
dart run bin/vgv.dart

# Or activate locally
dart pub global activate --source path .
vgv
```

### Project Structure

```
vgv_cli/
├── bin/
│   └── vgv.dart              # Entry point
├── lib/
│   ├── core/
│   │   ├── di/               # Dependency injection
│   │   ├── templates/        # Generated project templates
│   │   └── utils/            # Utilities (version checker)
│   ├── data/
│   │   ├── datasources/      # File system & Flutter commands
│   │   └── repositories/     # Repository implementations
│   ├── domain/
│   │   ├── entities/         # Project config entity
│   │   ├── repositories/     # Repository interfaces
│   │   └── usecases/         # Business logic
│   ├── presentation/
│   │   └── controllers/      # CLI controller
│   └── vgv_cli.dart          # Main CLI class
├── example/                   # pub.dev example
└── scripts/                   # Build scripts
```

### Modifying Templates

Templates are in `lib/core/templates/`. After modifying:

```bash
dart run scripts/generate_template_contents.dart
```

## Code Style

- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Run `dart analyze` before committing
- Keep commits atomic and focused

## Commit Messages

Use conventional commits:

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only
- `refactor:` Code change that neither fixes a bug nor adds a feature
- `test:` Adding tests
- `chore:` Maintenance tasks

## Questions?

Feel free to open an issue with the `question` label.

---

Thanks for contributing! 🚀
