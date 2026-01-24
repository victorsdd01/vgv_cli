# 🚀 FlutterForge CLI - Quick Usage Guide

## 📦 Installation

### **Cross-Platform Support** 🌍
FlutterForge CLI works on **Windows**, **macOS**, and **Linux**!

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
flutterforge

# Or with the full command
dart pub global run flutterforge
```

### Follow the Interactive Prompts

The CLI will guide you through:

1. **Project Details**
   - Project name (e.g., `my_awesome_app`)
   - Organization name (e.g., `com.example`)

2. **Platform Selection**
   - Mobile (Android/iOS)
   - Web
   - Desktop (Windows/macOS/Linux)
   - Custom selection

3. **State Management**
   - BLoC (Business Logic Component)
   - Cubit (Simplified BLoC)
   - Provider
   - None

4. **Freezed Configuration** (if BLoC selected)
   - Enable Freezed for immutable data classes

5. **Navigation**
   - Go Router integration

6. **Architecture**
   - Clean Architecture structure

7. **Code Quality**
   - Custom linter rules

8. **Internationalization**
   - Multi-language support

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
flutterforge

# 3. Follow prompts:
#    Project name: my_app
#    Organization: com.example
#    Platforms: Mobile (Android & iOS)
#    State Management: BLoC
#    Freezed: Yes
#    Go Router: Yes
#    Clean Architecture: Yes
#    Linter Rules: Yes

# 4. Navigate to project
cd my_app

# 5. Get dependencies
flutter pub get

# 6. Generate Freezed files (if enabled)
dart run build_runner build -d

# 7. Run the app
flutter run
```

## 🎨 Generated Project Structure

```
my_app/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   ├── errors/
│   │   ├── utils/
│   │   └── di/
│   ├── domain/
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── usecases/
│   ├── data/
│   │   ├── datasources/
│   │   ├── repositories/
│   │   └── models/
│   ├── presentation/
│   │   ├── pages/
│   │   ├── widgets/
│   │   └── controllers/
│   ├── application/
│   │   ├── l10n/
│   │   └── generated/
│   └── main.dart
├── pubspec.yaml
├── analysis_options.yaml
├── build.yaml (if Freezed enabled)
└── README.md
```

## 🚀 Happy Coding!

Your Flutter project is now ready with:
- ✅ Clean Architecture structure
- ✅ State management setup
- ✅ Navigation configuration
- ✅ Internationalization
- ✅ Code quality rules
- ✅ Latest dependencies

Start building amazing Flutter apps! 🎉 