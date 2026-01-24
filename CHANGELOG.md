# Changelog

All notable changes to FlutterForge CLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.10.30] - 2026-01-24

### Changes
- chore: add .pubignore file to exclude unnecessary files from publication

## [1.10.29] - 2026-01-24

### Changes
- chore: update .gitignore to include Swift Package Manager files

## [1.10.28] - 2026-01-24

### Changes
- feat: update banner display logic in MyApp

## [1.10.27] - 2026-01-24

### Changes
- feat: enhance CLI project creation with new flags and quick mode

## [1.10.26] - 2026-01-24

### Changes
- feat: add .gitignore file generation during project setup

## [1.10.25] - 2026-01-24

### Changes
- feat: add VSCode launch configuration generation for projects

## [1.10.24] - 2026-01-24

### Changes
- feat: introduce environment-specific main entry points and configuration management

## [1.10.23] - 2026-01-24

### Changes
- feat: enhance CLI project creation with improved user interaction and platform selection

## [1.10.22] - 2026-01-24

### Changes
- feat: enhance localization support with additional strings for user interface

## [1.10.21] - 2026-01-24

### Changes
- feat: implement Settings feature with theme and language management

## [1.10.20] - 2026-01-24

### Changes
- refactor: convert LoginPage to StatefulWidget for improved state management

## [1.10.19] - 2026-01-24

### Changes
- refactor: remove const from LoginPage instantiation for consistency

## [1.10.18] - 2026-01-24

### Changes
- feat: update ARB content generation to include project name in app title

## [1.10.17] - 2026-01-24

### Changes
- feat: enhance LoginPage with improved form handling and localization

## [1.10.16] - 2026-01-24

### Changes
- refactor: convert HomePage and LoginPage to TStateless, enhancing state management

## [1.10.15] - 2026-01-24

### Changes
- feat: enhance state management and localization in auth and home features

## [1.10.14] - 2026-01-24

### Changes
- chore: update dependencies and improve .gitignore

## [1.10.13] - 2026-01-23

### Changes
- merge: bring debug commit from develop to main

## [1.10.12] - 2025-12-13

### Changes
- feat: add push to main trigger for version bump workflow (temporary)

## [1.10.11] - 2025-12-12

### Changes
- fix: don't overwrite existing version file

## [1.10.10] - 2025-12-12

### Changes
- feat: save installed version to file for accurate version tracking

## [1.10.9] - 2025-12-12

### Changes
- fix: get current version dynamically in --version command

## [1.10.8] - 2025-12-12

### Changes
- fix: use dart pub global list to get installed version

## [1.10.7] - 2025-12-12

### Changes
- fix: prioritize pub-cache version over local repo version

## [1.10.6] - 2025-12-12

### Changes
- feat: show update availability in --version command

## [1.10.5] - 2025-12-12

### Changes
- refactor: update BLoC states to use individual status flags per opera…

## [1.10.4] - 2025-12-12

### Changes
- feat: implement CocoaPods setup for iOS/macOS in FlutterCommandDataSo…

## [1.10.4] - 2025-12-12

### Changes
- feat: implement CocoaPods setup for iOS/macOS in FlutterCommandDataSo…

## [1.10.4] - 2025-12-12

### Changes
- feat: implement CocoaPods setup for iOS/macOS in FlutterCommandDataSo…

## [1.10.3] - 2025-12-07

### Changes
- chore: enhance auto version bump workflow with detailed version compa…

## [1.10.2] - 2025-12-07

### Changes
- feat: enhance version retrieval logic to fallback on Git for current version detection

## [1.10.1] - 2025-12-07

### Changes
- feat: enhance auto version bump workflow with improved triggering and…

### Added
- Version management system with automatic bumping
- GitHub Actions workflow for automated releases
- CHANGELOG.md for tracking version history

## [1.10.0] - 2025-07-28

### Added
- 🎯 **Improved Platform Selection Flow** - No more tedious individual platform questions!
- ⚡ **Quick Selection Options** - Choose from preset configurations or use quick commands
- 🚀 **Better User Experience** - Streamlined platform selection with 8 preset options
- 🎨 **Enhanced CLI Interface** - More intuitive and user-friendly platform selection
- 🏗️ **MVVM Architecture Support** - Automatic MVVM pattern for non-BLoC state management
- ❄️ **Automatic Freezed Integration** - Freezed automatically added for non-BLoC (required for intl_utils:generate)
- 📁 **Complete MVVM Structure** - Full folder structure with Models, Views, ViewModels, and Services
- 🔧 **MVVM Dependency Injection** - GetIt-based DI specifically designed for MVVM pattern
- 💉 **Universal Dependency Injection** - Injector class always included regardless of state management or architecture
- 🛣️ **Smart Navigation System** - Default Navigator when Go Router is not selected, Go Router when selected
- ✅ **Input Validation** - Proper validation for quick platform selection with error messages and retry loops
- 🔧 **Custom Selection Flow** - Quick commands now pre-fill individual platform selections and skip irrelevant questions
- 📱 **Mobile Platform Selection** - Proper Android and iOS individual selection when mobile is chosen
- 💻 **Desktop Platform Selection** - Proper Windows, macOS, and Linux individual selection when desktop is chosen
- 🐛 **Bug Fix** - Fixed directory creation issue in state management template generation
- 🐛 **Bug Fix** - Fixed directory creation issue in default navigation template generation
- 🏗️ **Architecture Fix** - Provider state management now correctly uses MVVM architecture instead of Clean Architecture
- 🏗️ **Explicit Architecture Selection** - Users can now choose between Clean Architecture and MVVM regardless of state management
- 🔧 **Main File Structure Fixed** - MultiBlocProvider/MultiProvider now correctly placed in runMainApp() function
- 🛣️ **Go Router Configuration Fixed** - Proper MaterialApp.router configuration with all required parameters
- 🏗️ **Architecture Mapping Fixed** - Provider no longer created in Clean Architecture, only in MVVM
- 📁 **Directory Structure Fixed** - BLoCs folder properly created in presentation layer for Clean Architecture
- 🔧 **Dependency Injection Fixed** - Correct import paths and proper state management registration
- 📦 **Dependencies Maintained** - dartz package kept for Clean Architecture functional programming
- 🚀 **Simplified CLI Flow** - Go Router and Freezed are now always included by default

### Changed
- 🔄 **Platform Selection Redesign** - Replaced individual platform questions with smart preset options
- 📱 **Mobile Platform Handling** - Android and iOS are now grouped as "Mobile" platform
- 💻 **Desktop Platform Handling** - Windows, macOS, and Linux are now grouped as "Desktop" platform
- 🌐 **Web Platform** - Standalone web platform option
- ⚡ **Quick Commands** - Added "mobile", "desktop", "all", "none" quick selection commands
- 🏛️ **Architecture Selection** - BLoC and Cubit use Clean Architecture, Provider and None use MVVM pattern
- 📦 **Dependency Management** - Freezed automatically included for Provider and None state management
- 🎯 **State Management Integration** - Proper MVVM integration for Provider and None

### Features
- **8 Preset Options**: Mobile Only, Web Only, Desktop Only, Mobile + Web, Mobile + Desktop, Web + Desktop, All Platforms, Custom Selection
- **Quick Commands**: Type "mobile", "desktop", "all", or "none" for instant selection
- **Fallback to Individual**: Still available for users who want granular control
- **Smart Defaults**: Defaults to Mobile (Android & iOS) if no selection is made
- **MVVM Structure**: Complete folder organization with Models, Views, ViewModels, Services
- **Automatic Freezed**: Required dependencies automatically added for internationalization support
- **State Management Templates**: Proper MVVM templates for Provider and Controller patterns
- **Dependency Injection**: Universal DI setup with GetIt for all architectures

## [1.1.0] - 2025-07-28

### Added
- ✨ Beautiful animated progress bar for CLI updates
- 🎊 Completion celebration animation
- 🔄 Enhanced update system with version checking
- 🎨 Improved CLI styling with colors and emojis
- 📊 Step-by-step progress visualization
- 🎯 Spinning animations during updates

### Changed
- 🎨 Enhanced CLI appearance with professional styling
- 📋 Improved help and version display
- 🚀 Better user experience with visual feedback

### Fixed
- 🔧 Resolved dependency injection issues
- 🐛 Fixed CLI controller method signatures
- 🔧 Corrected import paths and class references

## [1.0.0] - 2024-12-27

### Added
- 🚀 Initial FlutterForge CLI release
- 📝 Interactive project configuration
- 🌍 Multi-platform support (Mobile, Web, Desktop)
- 🎯 State management options (BLoC, Cubit, Provider)
- 🏛️ Clean Architecture integration
- 🛣️ Smart navigation system (Go Router or Default Navigator)
- ❄️ Freezed code generation
- 🔍 Custom linter rules
- 🌐 Internationalization support
- 📦 Dependency injection with GetIt
- 🔄 Update and uninstall functionality
- 📚 Comprehensive documentation
- 🎨 Beautiful CLI interface with colors and styling

### Features
- Interactive prompts for project setup
- Platform selection (Android, iOS, Web, Windows, macOS, Linux)
- State management configuration
- Clean Architecture structure generation
- Smart navigation setup (Go Router or Default Navigator) with sample pages
- Freezed integration for immutable data classes
- Custom linter rules for code quality
- Internationalization with ARB files
- Cross-platform installation scripts
- Version checking and update system
- Professional CLI styling and animations

---

## Version Bumping Guidelines

### Patch (1.0.0 → 1.0.1)
- Bug fixes
- Minor improvements
- Documentation updates
- Performance optimizations

### Minor (1.0.0 → 1.1.0)
- New features
- Enhanced functionality
- UI/UX improvements
- New configuration options

### Major (1.0.0 → 2.0.0)
- Breaking changes
- Major architectural changes
- Significant feature additions
- Incompatible API changes

## Automatic Version Bumping

This project uses GitHub Actions to automatically bump versions when PRs are merged to main:

- **Default**: Patch bump (1.0.0 → 1.0.1)
- **[MINOR] in PR title**: Minor bump (1.0.0 → 1.1.0)
- **[MAJOR] in PR title**: Major bump (1.0.0 → 2.0.0)
- **Labels**: Use `minor` or `major` labels for automatic detection

## Manual Version Management

Use the version manager script:

```bash
# Show current version
dart run scripts/version_manager.dart show

# Bump versions
dart run scripts/version_manager.dart patch   # 1.0.0 → 1.0.1
dart run scripts/version_manager.dart minor   # 1.0.0 → 1.1.0
dart run scripts/version_manager.dart major   # 1.0.0 → 2.0.0
```
