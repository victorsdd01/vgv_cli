import 'dart:io';
import 'package:flutterforge/core/templates/template_generator.dart';
import 'package:path/path.dart' as path;
import '../../domain/entities/project_config.dart';

/// Data source for file system operations
abstract class FileSystemDataSource {
  Future<void> addDependencies(String projectName, StateManagementType stateManagement, bool includeGoRouter, bool includeCleanArchitecture, bool includeFreezed);
  Future<void> createDirectoryStructure(String projectName, StateManagementType stateManagement, bool includeGoRouter);
  Future<void> createStateManagementTemplates(String projectName, StateManagementType stateManagement, bool includeFreezed);
  Future<void> createGoRouterTemplates(String projectName);
  Future<void> createDefaultNavigationTemplates(String projectName);
  Future<void> createCleanArchitectureStructure(String projectName, StateManagementType stateManagement, ArchitectureType architecture, {bool includeGoRouter = false, bool includeFreezed = false});
  Future<void> updateMainFile(String projectName, StateManagementType stateManagement, bool includeGoRouter, bool includeCleanArchitecture, bool includeFreezed);
  Future<void> createLinterRules(String projectName);
  Future<void> createBarrelFiles(String projectName, StateManagementType stateManagement, bool includeCleanArchitecture, bool includeFreezed);
  Future<void> createBuildYaml(String projectName);
  Future<void> createInternationalization(String projectName);
  Future<void> ensureCleanArchitectureFiles(String projectName);
}

/// Implementation of FileSystemDataSource
class FileSystemDataSourceImpl implements FileSystemDataSource {

  final TemplateGenerator templateGenerator = TemplateGenerator.instance;
  @override
  Future<void> addDependencies(String projectName, StateManagementType stateManagement, bool includeGoRouter, bool includeCleanArchitecture, bool includeFreezed) async {
    final pubspecPath = path.join(projectName, 'pubspec.yaml');
    final pubspecFile = File(pubspecPath);
    
    if (!pubspecFile.existsSync()) {
      throw FileSystemException('pubspec.yaml not found');
    }

    String pubspecContent = pubspecFile.readAsStringSync();
    
    // Build dependencies list
    final dependencies = <String>[];
    
    // Add state management dependencies
    switch (stateManagement) {
      case StateManagementType.bloc:
        dependencies.addAll([
          'flutter_bloc: ^9.1.1',
          'hydrated_bloc: ^10.1.1',
          'replay_bloc: ^0.3.0',
          'bloc_concurrency: ^0.3.0',
          'dartz: ^0.10.1',
          'path_provider: ^2.1.5',
          'path: ^1.9.0',
          'equatable: ^2.0.7',
          'get_it: ^8.0.3',
          'dio: ^5.7.0',
          'flutter_secure_storage: ^9.2.2',
          'nested: ^1.0.0',
          'pretty_dio_logger: ^1.4.0',
          'talker_dio_logger: ^4.4.1',
          'talker_flutter: ^4.4.1',
          'flutter_form_builder: ^9.4.1',
          'form_builder_validators: ^10.0.1',
          'drift: ^2.18.0',
          'sqlite3_flutter_libs: ^0.5.0',
        ]);
        
        if (includeFreezed) {
          dependencies.addAll([
            'json_annotation: ^4.9.0',
            'freezed_annotation: ^2.4.4',
          ]);
        }
        break;
      case StateManagementType.provider:
        dependencies.addAll([
          'provider: ^6.1.5',
          'get_it: ^8.0.3',
        ]);
        
        // Always add Freezed for non-BLoC state management
        dependencies.addAll([
          'json_annotation: ^4.9.0',
          'freezed_annotation: ^2.4.4',
          'freezed: ^2.5.7',
        ]);
        break;
      case StateManagementType.none:
        // Always add Freezed for non-BLoC state management
        dependencies.addAll([
          'json_annotation: ^4.9.0',
          'freezed_annotation: ^2.4.4',
          'freezed: ^2.5.7',
        ]);
        break;
    }

    // Add Go Router dependency if requested
    if (includeGoRouter && !dependencies.any((d) => d.startsWith('go_router:'))) {
      dependencies.add('go_router: ^16.0.0');
    }

    // Always add get_it for dependency injection
    if (!dependencies.any((d) => d.startsWith('get_it:'))) {
      dependencies.add('get_it: ^8.0.3');
    }

    // Add Clean Architecture dependencies if requested
    if (includeCleanArchitecture) {
      if (!dependencies.any((d) => d.startsWith('equatable:'))) {
        dependencies.add('equatable: ^2.0.7');
      }
    }

    // Add internationalization dependencies
    dependencies.addAll([
      'flutter_localizations:',
      '  sdk: flutter',
      'intl: any',
    ]);

    // Build dev dependencies list
    final devDependencies = <String>[];
    
    // Always add Freezed dev dependencies for Provider/None or when Freezed is selected
    if (includeFreezed || stateManagement == StateManagementType.provider || stateManagement == StateManagementType.none) {
      devDependencies.addAll([
        'freezed: ^2.5.7',
        'json_serializable: ^6.9.0',
        'build_runner: ^2.4.13',
      ]);
    }

    // Add Drift dev dependencies for BLoC
    if (stateManagement == StateManagementType.bloc) {
      devDependencies.addAll([
        'drift_dev: ^2.18.0',
      ]);
    }

    // Add internationalization dev dependencies
    devDependencies.addAll([
      'intl_utils: ^2.8.7',
    ]);

    final lines = pubspecContent.split('\n');
    final newLines = <String>[];
    bool skipUntilNextSection = false;
    bool dependenciesAdded = false;
    bool devDependenciesAdded = false;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      
      if (trimmedLine == 'dependencies:') {
        skipUntilNextSection = true;
        if (!dependenciesAdded) {
          newLines.add('dependencies:');
          for (final dep in dependencies) {
            newLines.add('  $dep');
          }
          newLines.add('');
          dependenciesAdded = true;
        }
        continue;
      }
      
      if (trimmedLine == 'dev_dependencies:') {
        skipUntilNextSection = true;
        if (!devDependenciesAdded) {
          newLines.add('dev_dependencies:');
          for (final dep in devDependencies) {
            newLines.add('  $dep');
          }
          newLines.add('');
          devDependenciesAdded = true;
        }
        continue;
      }
      
      if (skipUntilNextSection) {
        if (trimmedLine.isEmpty || trimmedLine.startsWith('  ') || trimmedLine.startsWith('    ') || trimmedLine.startsWith('#')) {
          continue;
        } else {
          skipUntilNextSection = false;
        }
      }
      
      if (trimmedLine == 'flutter:' && !dependenciesAdded) {
        newLines.add('dependencies:');
        for (final dep in dependencies) {
          newLines.add('  $dep');
        }
        newLines.add('');
        dependenciesAdded = true;
      }
      
      if (trimmedLine == 'flutter:' && dependenciesAdded && !devDependenciesAdded) {
        newLines.add('dev_dependencies:');
        for (final dep in devDependencies) {
          newLines.add('  $dep');
        }
        newLines.add('');
        devDependenciesAdded = true;
      }
      
      newLines.add(line);
    }
    
    if (!dependenciesAdded) {
      final flutterIndex = newLines.indexWhere((line) => line.trim() == 'flutter:');
      if (flutterIndex != -1) {
        newLines.insert(flutterIndex, '');
        for (int i = dependencies.length - 1; i >= 0; i--) {
          newLines.insert(flutterIndex, '  ${dependencies[i]}');
        }
        newLines.insert(flutterIndex, 'dependencies:');
        dependenciesAdded = true;
      }
    }
    
    if (!devDependenciesAdded && dependenciesAdded) {
      final flutterIndex = newLines.indexWhere((line) => line.trim() == 'flutter:');
      if (flutterIndex != -1) {
        newLines.insert(flutterIndex, '');
        for (int i = devDependencies.length - 1; i >= 0; i--) {
          newLines.insert(flutterIndex, '  ${devDependencies[i]}');
        }
        newLines.insert(flutterIndex, 'dev_dependencies:');
        devDependenciesAdded = true;
      }
    }
    
    pubspecContent = newLines.join('\n');

    pubspecFile.writeAsStringSync(pubspecContent);

    // Add flutter configuration for internationalization
    await _addFlutterConfiguration(projectName);
  }

  Future<void> _addFlutterConfiguration(String projectName) async {
    final pubspecPath = path.join(projectName, 'pubspec.yaml');
    final pubspecFile = File(pubspecPath);
    
    String pubspecContent = pubspecFile.readAsStringSync();
    
    // Add flutter configuration if not present
    if (!pubspecContent.contains('generate: true')) {
      // Find the flutter section and update it
      if (pubspecContent.contains('flutter:')) {
        pubspecContent = pubspecContent.replaceFirst(
          'uses-material-design: true',
          '''uses-material-design: true
  generate: true'''
        );
      }
    }

    // Add or update flutter_intl configuration at root level
    if (!pubspecContent.contains('flutter_intl:')) {
      final flutterIntlConfig = '''
flutter_intl:
  enabled: true
  arb_dir: lib/application/l10n
  output_dir: lib/application/generated
''';
      
      // Add flutter_intl configuration at the end of the file, before the last line
      final lastLineIndex = pubspecContent.lastIndexOf('\n');
      if (lastLineIndex != -1) {
        final beforeLastLine = pubspecContent.substring(0, lastLineIndex);
        final lastLine = pubspecContent.substring(lastLineIndex);
        pubspecContent = '$beforeLastLine\n$flutterIntlConfig$lastLine';
      } else {
        // Fallback: add at the end
        pubspecContent = '$pubspecContent\n$flutterIntlConfig';
      }
    }
    
    pubspecFile.writeAsStringSync(pubspecContent);
  }

  @override
  Future<void> createDirectoryStructure(String projectName, StateManagementType stateManagement, bool includeGoRouter) async {
    final directories = <String>[];

    // Add Go Router directories if requested
    if (includeGoRouter) {
      directories.addAll([
        'lib/routes',
        'lib/pages',
      ]);
    }

    for (final dir in directories) {
      Directory(path.join(projectName, dir)).createSync(recursive: true);
    }
  }

  @override
  Future<void> createStateManagementTemplates(String projectName, StateManagementType stateManagement, bool includeFreezed) async {
    switch (stateManagement) {
      case StateManagementType.bloc:
        final mainFile = File(path.join(projectName, 'lib/main.dart'));
        if (await mainFile.exists()) {
          await mainFile.delete();
        }
        
        final oldDiFile = File(path.join(projectName, 'lib/core/di/dependency_injection.dart'));
        if (await oldDiFile.exists()) {
          await oldDiFile.delete();
        }
        
        final oldDiDir = Directory(path.join(projectName, 'lib/core/di'));
        if (await oldDiDir.exists()) {
          try {
            final contents = await oldDiDir.list().toList();
            if (contents.isEmpty) {
              await oldDiDir.delete(recursive: true);
            }
          } catch (e) {
            // Ignore errors
          }
        }
        
        await templateGenerator.generateProjectTemplates(
          projectName: projectName,
          projectPath: projectName,
        );
        break;
      case StateManagementType.provider:
        break;
      case StateManagementType.none:
        break;
    }
  }

  @override
  Future<void> createGoRouterTemplates(String projectName) async {
    // Create app_router.dart
    final routerFile = File(path.join(projectName, 'lib/routes/app_router.dart'));
    routerFile.writeAsStringSync(_generateAppRouterContent());

    // Check if Clean Architecture structure exists to determine page location
    final cleanArchPagesDir = Directory(path.join(projectName, 'lib/presentation/pages'));
    
    String pagesPath;
    if (cleanArchPagesDir.existsSync()) {
      // Clean Architecture structure exists, use presentation/pages
      pagesPath = 'lib/presentation/pages';
    } else {
      // Regular structure, use pages
      pagesPath = 'lib/pages';
    }

    // Create sample pages with Go Router navigation
    final homePageFile = File(path.join(projectName, '$pagesPath/home_page.dart'));
    homePageFile.writeAsStringSync(_generateHomePageContent());

    final aboutPageFile = File(path.join(projectName, '$pagesPath/about_page.dart'));
    aboutPageFile.writeAsStringSync(_generateAboutPageContent());

    final settingsPageFile = File(path.join(projectName, '$pagesPath/settings_page.dart'));
    settingsPageFile.writeAsStringSync(_generateSettingsPageContent());
  }

  @override
  Future<void> createDefaultNavigationTemplates(String projectName) async {
    // Check if Clean Architecture structure exists to determine page location
    final cleanArchPagesDir = Directory(path.join(projectName, 'lib/presentation/pages'));
    
    String pagesPath;
    if (cleanArchPagesDir.existsSync()) {
      // Clean Architecture structure exists, use presentation/pages
      pagesPath = 'lib/presentation/pages';
    } else {
      // Regular structure, use pages
      pagesPath = 'lib/pages';
    }

    // Create directory if it doesn't exist
    final pagesDir = Directory(path.join(projectName, pagesPath));
    pagesDir.createSync(recursive: true);

    // Create sample pages with default navigation
    final homePageFile = File(path.join(projectName, '$pagesPath/home_page.dart'));
    homePageFile.writeAsStringSync(_generateDefaultHomePageContent());

    final aboutPageFile = File(path.join(projectName, '$pagesPath/about_page.dart'));
    aboutPageFile.writeAsStringSync(_generateDefaultAboutPageContent());

    final settingsPageFile = File(path.join(projectName, '$pagesPath/settings_page.dart'));
    settingsPageFile.writeAsStringSync(_generateDefaultSettingsPageContent());
  }





  @override
  Future<void> updateMainFile(String projectName, StateManagementType stateManagement, bool includeGoRouter, bool includeCleanArchitecture, bool includeFreezed) async {
    final mainPath = path.join(projectName, 'lib/main.dart');
    final mainFile = File(mainPath);
    
    if (!mainFile.existsSync()) {
      throw FileSystemException('main.dart not found');
    }

    final mainContent = _generateMainContent(stateManagement, includeGoRouter, includeCleanArchitecture, includeFreezed);
    mainFile.writeAsStringSync(mainContent);
  }




  String _generateMainContent(StateManagementType stateManagement, bool includeGoRouter, bool includeCleanArchitecture, bool includeFreezed) {
    // Determine architecture type based on state management
    final isCleanArchitecture = stateManagement == StateManagementType.bloc;
    
    if (isCleanArchitecture) {
      // Generate BLoC with Clean Architecture
      if (includeFreezed && includeGoRouter && includeCleanArchitecture) {
        return _generateFreezedBlocWithGoRouterAndCleanArchitecture();
      } else if (includeFreezed && includeCleanArchitecture) {
        return _generateFreezedBlocWithCleanArchitecture();
      } else if (includeFreezed && includeGoRouter) {
        return _generateFreezedBlocWithGoRouter();
      } else if (includeFreezed) {
        return _generateBlocMainContent(includeFreezed);
      } else if (includeGoRouter) {
        return _generateBlocWithGoRouter(includeFreezed);
      } else {
        String baseContent = _generateBlocMainContent(includeFreezed);
        
        // Add Clean Architecture integration if requested
        if (includeCleanArchitecture) {
          baseContent = _integrateCleanArchitecture(baseContent, stateManagement);
        }

        // Add Go Router integration if requested
        if (includeGoRouter) {
          baseContent = _integrateGoRouter(baseContent);
        }

        return baseContent;
      }
    } else {
      // Generate MVVM architecture for non-BLoC state management
      return _generateMvvmMainContent(stateManagement, includeGoRouter, includeFreezed);
    }
  }

  String _integrateCleanArchitecture(String baseContent, StateManagementType stateManagement) {
    // Remove any old imports of core/di/dependency_injection.dart
    baseContent = baseContent.replaceAll('import \'core/di/dependency_injection.dart\';', '');
    baseContent = baseContent.replaceAll('import "core/di/dependency_injection.dart";', '');
    
    // Update imports to use Clean Architecture structure - use application/injector.dart
    if (!baseContent.contains('import \'application/injector.dart\';')) {
      baseContent = baseContent.replaceFirst(
        'import \'package:flutter/material.dart\';',
        '''import 'package:flutter/material.dart';
import 'application/injector.dart';'''
      );
    }

    // Update main function to initialize Injector (handle both async and sync main)
    if (baseContent.contains('Future<void> main() async {')) {
      if (!baseContent.contains('Injector.init();')) {
        baseContent = baseContent.replaceFirst(
          'Future<void> main() async {',
          '''Future<void> main() async {
  // Initialize dependency injection
  Injector.init();'''
        );
      }
    } else if (baseContent.contains('void main() async {')) {
      baseContent = baseContent.replaceFirst(
        'void main() async {',
        '''Future<void> main() async {
  // Initialize dependency injection
  Injector.init();'''
      );
    } else {
      baseContent = baseContent.replaceFirst(
        'void main()',
        '''Future<void> main() async {
  // Initialize dependency injection
  Injector.init();'''
      );
    }

    // Update MaterialApp to use Clean Architecture structure
    if (!baseContent.contains('debugShowCheckedModeBanner: false')) {
      baseContent = baseContent.replaceFirst(
        'MaterialApp(',
        '''MaterialApp(
        debugShowCheckedModeBanner: false,'''
      );
    }

    // Update home page reference to use Clean Architecture path
    baseContent = baseContent.replaceFirst(
      'home: const MyHomePage(',
      'home: const HomePage('
    );

    // Remove the old MyHomePage class if it exists
    if (baseContent.contains('class MyHomePage extends StatefulWidget')) {
      final startIndex = baseContent.indexOf('class MyHomePage extends StatefulWidget');
      final endIndex = baseContent.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1) {
        baseContent = baseContent.substring(0, startIndex) + baseContent.substring(endIndex + 1);
      }
    }

    return baseContent;
  }

  String _integrateGoRouter(String baseContent) {
    // Add Go Router import
    if (!baseContent.contains('import \'routes/app_router.dart\';')) {
      baseContent = baseContent.replaceFirst(
        'import \'package:flutter/material.dart\';',
        '''import 'package:flutter/material.dart';
import 'routes/app_router.dart';'''
      );
    }

    // Replace MaterialApp with MaterialApp.router
    baseContent = baseContent.replaceFirst(
      'MaterialApp(',
      'MaterialApp.router('
    );

    // Add router configuration and remove home property
    if (!baseContent.contains('routerConfig: AppRouter.router')) {
      baseContent = baseContent.replaceFirst(
        'MaterialApp.router(',
        '''MaterialApp.router(
          routerConfig: AppRouter.router,'''
      );
    }

    // Remove the home property since we're using router
    if (baseContent.contains('home: ')) {
      final homeStart = baseContent.indexOf('home: ');
      final homeEnd = baseContent.indexOf(',', homeStart);
      if (homeEnd != -1) {
        baseContent = baseContent.substring(0, homeStart) + baseContent.substring(homeEnd + 1);
      }
    }

    return baseContent;
  }

  String _generateAppRouterContent() {
    return '''
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/pages/home_page.dart';
import '../presentation/pages/about_page.dart';
import '../presentation/pages/settings_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
}

// Navigation service for easy navigation
class NavigationService {
  static void goToHome(BuildContext context) {
    context.go('/');
  }

  static void goToAbout(BuildContext context) {
    context.go('/about');
  }

  static void goToSettings(BuildContext context) {
    context.go('/settings');
  }

  static void goBack(BuildContext context) {
    context.pop();
  }
}
''';
  }

  String _generateHomePageContent() {
    return '''
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Your Flutter App!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'This is your home page with Go Router navigation.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => context.go('/about'),
                  child: const Text('About'),
                ),
                ElevatedButton(
                  onPressed: () => context.go('/settings'),
                  child: const Text('Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
''';
  }

  String _generateAboutPageContent() {
    return '''
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About This App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'This is a Flutter application created with VMGV CLI.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              'Features:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('• Go Router for navigation'),
            Text('• Clean architecture'),
            Text('• State management'),
            Text('• Best practices'),
          ],
        ),
      ),
    );
  }
}
''';
  }

  String _generateSettingsPageContent() {
    return '''
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Enable dark theme'),
              value: _darkMode,
              onChanged: (value) {
                setState(() {
                  _darkMode = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Notifications'),
              subtitle: const Text('Enable push notifications'),
              value: _notifications,
              onChanged: (value) {
                setState(() {
                  _notifications = value;
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Navigation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Go to Home'),
              onTap: () => context.go('/'),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Go to About'),
              onTap: () => context.go('/about'),
            ),
          ],
        ),
      ),
    );
  }
}
''';
  }

  String _generateDefaultHomePageContent() {
    return '''
import 'package:flutter/material.dart';
import 'about_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Your Flutter App!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'This is your home page with default navigation.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AboutPage()),
                    );
                  },
                  child: const Text('About'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsPage()),
                    );
                  },
                  child: const Text('Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
''';
  }

  String _generateDefaultAboutPageContent() {
    return '''
import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About This App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'This is a Flutter application created with VMGV CLI.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              'Features:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('• Default navigation with Navigator'),
            Text('• Clean architecture'),
            Text('• State management'),
            Text('• Best practices'),
          ],
        ),
      ),
    );
  }
}
''';
  }

  String _generateDefaultSettingsPageContent() {
    return '''
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Enable dark theme'),
              value: _darkMode,
              onChanged: (value) {
                setState(() {
                  _darkMode = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Notifications'),
              subtitle: const Text('Enable push notifications'),
              value: _notifications,
              onChanged: (value) {
                setState(() {
                  _notifications = value;
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Navigation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Go to Home'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Go to About'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/about');
              },
            ),
          ],
        ),
      ),
    );
  }
}
''';
  }

  String _generateFreezedBlocWithGoRouterAndCleanArchitecture() {
    return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'application/injector.dart';
import 'features/home/presentation/blocs/home_bloc/home_bloc.dart';
import 'application/routes/routes.dart';
import 'application/generated/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runMainApp();
}

Future<void> runMainApp() async {
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorageDirectory.web
        : HydratedStorageDirectory((await getTemporaryDirectory()).path),
  );
  Injector.init();

  runApp(
    MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<HomeBloc>(
          create: (BuildContext _) => Injector.get<HomeBloc>(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    theme: AppTheme.light,
    themeMode: ThemeMode.light,
    routerConfig: AppRoutes.router,
    localizationsDelegates: AppLocalizationsSetup.localizationsDelegates,
    supportedLocales: AppLocalizationsSetup.supportedLocales,
    debugShowCheckedModeBanner: kDebugMode,
    themeAnimationCurve: Curves.easeInOut,
    themeAnimationDuration: const Duration(milliseconds: 300),
    themeAnimationStyle: AnimationStyle(
      curve: Curves.easeInOut,
      duration: const Duration(milliseconds: 300),
      reverseCurve: Curves.easeInOut,
      reverseDuration: const Duration(milliseconds: 300),
    ),
  );
}
''';
  }

  String _generateFreezedBlocWithGoRouter() {
    return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'application/injector.dart';
import 'features/home/presentation/blocs/home_bloc/home_bloc.dart';
import 'application/routes/routes.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (kReleaseMode) {
      debugPrintRebuildDirtyWidgets = false;
      debugPrint = (String? message, {int? wrapWidth}) {};
    }
  } finally {
    await runMainApp();
  }
}

Future<void> runMainApp() async {
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: !kIsWeb
        ? HydratedStorageDirectory((await getTemporaryDirectory()).path)
        : HydratedStorageDirectory.web,
  );

  Injector.init();

  runApp(
    MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<HomeBloc>(
          create: (BuildContext _) => Injector.get<HomeBloc>(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    theme: AppTheme.light,
    themeMode: ThemeMode.light,
    routerConfig: AppRoutes.router,
    locale: AppLocalizationsSetup.supportedLocales.last,
    localizationsDelegates: AppLocalizationsSetup.localizationsDelegates,
    supportedLocales: AppLocalizationsSetup.supportedLocales,
    debugShowCheckedModeBanner: kDebugMode,
  );
}
''';
  }

  String _generateFreezedBlocWithCleanArchitecture() {
    return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:nested/nested.dart';
import 'application/injector.dart';
import 'features/home/presentation/blocs/home_bloc/home_bloc.dart';
import 'core/services/talker_service.dart';
import 'application/application.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (kReleaseMode) {
      debugPrintRebuildDirtyWidgets = false;
      debugPrint = (String? message, {int? wrapWidth}) {};
    }
  } finally {
    await runMainApp();
  }
}

Future<void> runMainApp() async {
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: !kIsWeb
        ? HydratedStorageDirectory((await getTemporaryDirectory()).path)
        : HydratedStorageDirectory.web,
  );

  TalkerService.init();

  Injector.init();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    return true;
  };

  runApp(
    MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<HomeBloc>(
          create: (BuildContext _) => Injector.get<HomeBloc>(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    theme: AppTheme.light,
    themeMode: ThemeMode.light,
    routerConfig: AppRoutes.router,
    locale: AppLocalizationsSetup.supportedLocales.last,
    localizationsDelegates: AppLocalizationsSetup.localizationsDelegates,
    supportedLocales: AppLocalizationsSetup.supportedLocales,
    debugShowCheckedModeBanner: kDebugMode,
  );
}
''';
  }


  String _generateBlocWithGoRouter(bool includeFreezed) {
    return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:nested/nested.dart';
import 'application/injector.dart';
import 'features/home/presentation/blocs/home_bloc/home_bloc.dart';
import 'application/routes/routes.dart';
import 'core/services/talker_service.dart';
import 'application/application.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runMainApp();
}

Future<void> runMainApp() async {
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: !kIsWeb
        ? HydratedStorageDirectory((await getTemporaryDirectory()).path)
        : HydratedStorageDirectory.web,
  );

  TalkerService.init();

  Injector.init();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    return true;
  };

  runApp(
    MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<HomeBloc>(
          create: (BuildContext _) => Injector.get<HomeBloc>(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    theme: AppTheme.light,
    themeMode: ThemeMode.light,
    routerConfig: AppRoutes.router,
    locale: AppLocalizationsSetup.supportedLocales.last,
    localizationsDelegates: AppLocalizationsSetup.localizationsDelegates,
    supportedLocales: AppLocalizationsSetup.supportedLocales,
    debugShowCheckedModeBanner: kDebugMode,
  );
}
''';
  }

  String _generateBlocMainContent(bool includeFreezed) {
    if (includeFreezed) {
      return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:nested/nested.dart';
import 'application/injector.dart';
import 'features/home/presentation/blocs/home_bloc/home_bloc.dart';
import 'core/services/talker_service.dart';
import 'application/application.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (kReleaseMode) {
      debugPrintRebuildDirtyWidgets = false;
      debugPrint = (String? message, {int? wrapWidth}) {};
    }
  } finally {
    await runMainApp();
  }
}

Future<void> runMainApp() async {
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: !kIsWeb
        ? HydratedStorageDirectory((await getTemporaryDirectory()).path)
        : HydratedStorageDirectory.web,
  );

  TalkerService.init();

  Injector.init();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    return true;
  };

  runApp(
    MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<HomeBloc>(
          create: (BuildContext _) => Injector.get<HomeBloc>(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    theme: AppTheme.light,
    themeMode: ThemeMode.light,
    routerConfig: AppRoutes.router,
    locale: AppLocalizationsSetup.supportedLocales.last,
    localizationsDelegates: AppLocalizationsSetup.localizationsDelegates,
    supportedLocales: AppLocalizationsSetup.supportedLocales,
    debugShowCheckedModeBanner: kDebugMode,
  );
}
''';
    } else {
      return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:nested/nested.dart';
import 'application/injector.dart';
import 'features/home/presentation/blocs/home_bloc/home_bloc.dart';
import 'core/services/talker_service.dart';
import 'application/application.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runMainApp();
}

Future<void> runMainApp() async {
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: !kIsWeb
        ? HydratedStorageDirectory((await getTemporaryDirectory()).path)
        : HydratedStorageDirectory.web,
  );

  TalkerService.init();

  Injector.init();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    return true;
  };

  runApp(
    MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<HomeBloc>(
          create: (BuildContext _) => Injector.get<HomeBloc>(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    theme: AppTheme.light,
    themeMode: ThemeMode.light,
    routerConfig: AppRoutes.router,
    locale: AppLocalizationsSetup.supportedLocales.last,
    localizationsDelegates: AppLocalizationsSetup.localizationsDelegates,
    supportedLocales: AppLocalizationsSetup.supportedLocales,
    debugShowCheckedModeBanner: kDebugMode,
  );
}
''';
    }
  }

  @override
  Future<void> createCleanArchitectureStructure(String projectName, StateManagementType stateManagement, ArchitectureType architecture, {bool includeGoRouter = false, bool includeFreezed = false}) async {
    if (architecture == ArchitectureType.cleanArchitecture) {
      // Create Clean Architecture directory structure
      await _createCleanArchitectureStructure(projectName, stateManagement, includeGoRouter, includeFreezed);
    } else {
      // Create MVVM directory structure
      await _createMvvmStructure(projectName, stateManagement, includeGoRouter, includeFreezed);
    }
  }

  Future<void> _createCleanArchitectureStructure(String projectName, StateManagementType stateManagement, bool includeGoRouter, bool includeFreezed) async {
    // Create Clean Architecture directory structure - only core, features are created by templates
    // NOTE: Do NOT create lib/core/di/ - templates handle application/injector.dart
    final cleanArchDirectories = [
      'lib/core',
      'lib/core/constants',
      'lib/core/errors',
      'lib/core/utils',
      'lib/core/utils/helpers',
      'lib/core/network',
      'lib/core/services',
      'lib/core/enums',
      'lib/core/states',
    ];

    for (final dir in cleanArchDirectories) {
      Directory(path.join(projectName, dir)).createSync(recursive: true);
    }

    // Create base files for Clean Architecture
    await _createCleanArchitectureBaseFiles(projectName, stateManagement, includeFreezed);
  }

  Future<void> _createMvvmStructure(String projectName, StateManagementType stateManagement, bool includeGoRouter, bool includeFreezed) async {
    // Create MVVM directory structure
    final mvvmDirectories = [
      'lib/core',
      'lib/core/constants',
      'lib/core/errors',
      'lib/core/utils',
      'lib/core/di',
      'lib/models',
      'lib/models/entities',
      'lib/models/dto',
      'lib/services',
      'lib/services/api',
      'lib/services/local',
      'lib/viewmodels',
      'lib/views',
      'lib/views/pages',
      'lib/views/widgets',
      'lib/views/components',
    ];

    // Add state management specific directories
    switch (stateManagement) {
      case StateManagementType.provider:
        mvvmDirectories.add('lib/viewmodels/providers');
        break;
      case StateManagementType.none:
        mvvmDirectories.add('lib/viewmodels/controllers');
        break;
      case StateManagementType.bloc:
        // Should not happen in MVVM, but just in case
        mvvmDirectories.add('lib/viewmodels/blocs');
        break;
    }

    // Add Go Router directories if requested
    if (includeGoRouter) {
      mvvmDirectories.addAll([
        'lib/routes',
      ]);
    }

    for (final dir in mvvmDirectories) {
      Directory(path.join(projectName, dir)).createSync(recursive: true);
    }

    // Create base files for MVVM
    await _createMvvmBaseFiles(projectName, stateManagement, includeFreezed);
  }

  Future<void> _createCleanArchitectureBaseFiles(String projectName, StateManagementType stateManagement, bool includeFreezed) async {
    // Don't create files that templates will generate
    // Templates handle: failures.dart, core files, features, application, etc.
    // Only create app_constants.dart if it doesn't exist (templates don't include it)
    final constantsFile = File(path.join(projectName, 'lib/core/constants/app_constants.dart'));
    if (!await constantsFile.exists()) {
      constantsFile.writeAsStringSync(_generateAppConstantsContent());
    }
    
    // Ensure lib/core/di/dependency_injection.dart does NOT exist in Clean Architecture
    // Templates use application/injector.dart instead
    final oldDiFile = File(path.join(projectName, 'lib/core/di/dependency_injection.dart'));
    if (await oldDiFile.exists()) {
      await oldDiFile.delete();
    }
    
    // Also delete the directory if it's empty
    final oldDiDir = Directory(path.join(projectName, 'lib/core/di'));
    if (await oldDiDir.exists()) {
      try {
        final contents = await oldDiDir.list().toList();
        if (contents.isEmpty) {
          await oldDiDir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore errors when trying to delete directory
      }
    }
  }


  String _generateBaseEntityContent() {
    return '''
import 'package:equatable/equatable.dart';

/// Base entity class for all domain entities
abstract class BaseEntity extends Equatable {
  const BaseEntity();
  
  @override
  List<Object?> get props => [];
}
''';
  }


  String _generateSampleEntityContent(bool includeFreezed) {
    if (includeFreezed) {
      return '''import 'package:freezed_annotation/freezed_annotation.dart';
import '../../data/models/sample_model.dart';

part 'sample_entity.freezed.dart';
part 'sample_entity.g.dart';

/// Sample entity for demonstration
@freezed
abstract class SampleEntity with _\$SampleEntity {
  const factory SampleEntity({
    required String id,
    required String name,
    required String description,
  }) = _SampleEntity;

  factory SampleEntity.fromJson(Map<String, dynamic> json) => _\$SampleEntityFromJson(json);

  factory SampleEntity.fromModel(SampleModel model) => SampleEntity(
    id: model.id,
    name: model.name,
    description: model.description,
  );
}
''';
    } else {
      return '''import 'package:equatable/equatable.dart';
import '../../data/models/sample_model.dart';

/// Sample entity for demonstration
class SampleEntity extends Equatable {
  final String id;
  final String name;
  final String description;

  const SampleEntity({
    required this.id,
    required this.name,
    required this.description,
  });

  factory SampleEntity.fromModel(SampleModel model) => SampleEntity(
    id: model.id,
    name: model.name,
    description: model.description,
  );

  @override
  List<Object?> get props => [id, name, description];
}
''';
    }
  }



  String _generateFailuresContent() {
    return '''
import 'package:equatable/equatable.dart';

/// Base failure class for all errors
abstract class Failure extends Equatable {
  const Failure([this.message = '']);
  
  final String message;
  
  @override
  List<Object?> get props => [message];
}

/// Server failure
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error occurred']);
}

/// Cache failure
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache error occurred']);
}

/// Network failure
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error occurred']);
}
''';
  }

  String _generateAppConstantsContent() {
    return '''
/// Application constants
class AppConstants {
  const AppConstants._();
  
  // API URLs
  static const String baseUrl = 'https://api.example.com';
  
  // App Info
  static const String appName = 'Flutter App';
  static const String appVersion = '1.0.0';
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
''';
  }






  String _generateSampleModelContent(bool includeFreezed) {
    if (includeFreezed) {
      return '''import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/sample_entity.dart';

part 'sample_model.freezed.dart';
part 'sample_model.g.dart';

/// Sample model for demonstration
@freezed
abstract class SampleModel with _\$SampleModel {
  const factory SampleModel({
    required String id,
    required String name,
    required String description,
  }) = _SampleModel;

  factory SampleModel.fromJson(Map<String, dynamic> json) => _\$SampleModelFromJson(json);

  factory SampleModel.fromEntity(SampleEntity entity) => SampleModel(
    id: entity.id,
    name: entity.name,
    description: entity.description,
  );
}
''';
    } else {
      return '''import 'package:equatable/equatable.dart';

/// Sample model for demonstration
class SampleModel extends Equatable {
  final String id;
  final String name;
  final String description;

  const SampleModel({
    required this.id,
    required this.name,
    required this.description,
  });

  factory SampleModel.fromJson(Map<String, dynamic> json) {
    return SampleModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  @override
  List<Object?> get props => [id, name, description];
}
''';
    }
  }

  @override
  Future<void> createLinterRules(String projectName) async {
    final analysisOptionsPath = path.join(projectName, 'analysis_options.yaml');
    final analysisOptionsFile = File(analysisOptionsPath);
    
    final content = '''
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    unnecessary_null_comparison: ignore
    invalid_annotation_target: ignore
    constant_identifier_names: ignore
    depend_on_referenced_packages: ignore
  exclude:
    - bricks/**
    - '**/*.arb'
    - '**/*.g.dart'
    - '**/*.freezed.dart'
    - 'lib/application/generated/**'
    - 'lib/application/l10n/**.dart'
    - 'test/**'

linter:
  rules:
    always_specify_types: true
    prefer_expression_function_bodies: true
    always_declare_return_types: true
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    avoid_print: true
''';
    
    analysisOptionsFile.writeAsStringSync(content);
  }

  @override
  Future<void> createBarrelFiles(String projectName, StateManagementType stateManagement, bool includeCleanArchitecture, bool includeFreezed) async {
    if (!includeCleanArchitecture) return;

    // Create barrel files - only core, features are created by templates
    await _createCoreBarrelFile(projectName);
  }

  Future<void> _createCoreBarrelFile(String projectName) async {
    final barrelFile = File(path.join(projectName, 'lib/core/core.dart'));
    final content = '''
// Core layer exports
export 'errors/failures.dart';
export 'network/http_client.dart';
export 'services/talker_service.dart';
export 'utils/secure_storage_utils.dart';
export 'enums/server_status.dart';
''';
    barrelFile.writeAsStringSync(content);
  }




  @override
  Future<void> createInternationalization(String projectName) async {
    // Create application directory structure
    final applicationDir = Directory(path.join(projectName, 'lib/application'));
    if (!applicationDir.existsSync()) {
      applicationDir.createSync(recursive: true);
    }

    // Create l10n directory
    final l10nDir = Directory(path.join(projectName, 'lib/application/l10n'));
    if (!l10nDir.existsSync()) {
      l10nDir.createSync(recursive: true);
    }

    // Create generated directory
    final generatedDir = Directory(path.join(projectName, 'lib/application/generated'));
    if (!generatedDir.existsSync()) {
      generatedDir.createSync(recursive: true);
    }

    // Create l10n subdirectory in generated (intl_utils expects this)
    final generatedL10nDir = Directory(path.join(projectName, 'lib/application/generated/l10n'));
    if (!generatedL10nDir.existsSync()) {
      generatedL10nDir.createSync(recursive: true);
    }

    // Create app_localizations.dart file with correct import
    final appLocalizationsFile = File(path.join(projectName, 'lib/application/generated/l10n/app_localizations.dart'));
    appLocalizationsFile.writeAsStringSync(_generateAppLocalizationsContent());

    // Create ARB files
    final intlEnFile = File(path.join(projectName, 'lib/application/l10n/intl_en.arb'));
    intlEnFile.writeAsStringSync(_generateIntlEnArbContent());

    final intlEsFile = File(path.join(projectName, 'lib/application/l10n/intl_es.arb'));
    intlEsFile.writeAsStringSync(_generateIntlEsArbContent());
  }

  String _generateAppLocalizationsContent() {
    return '''
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../l10n.dart';

class AppLocalizationsSetup {
  static final List<Locale> supportedLocales = S.delegate.supportedLocales;

  static final Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    S.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
''';
  }

  String _generateIntlEnArbContent() {
    return '''{
  "@@locale": "en",
  "appTitle": "Flutter App",
  "@appTitle": {
    "description": "The title of the application"
  },
  "welcome": "Welcome",
  "@welcome": {
    "description": "Welcome message"
  },
  "hello": "Hello",
  "@hello": {
    "description": "Hello message"
  }
}''';
  }

  String _generateIntlEsArbContent() {
    return '''{
  "@@locale": "es",
  "appTitle": "Aplicación Flutter",
  "@appTitle": {
    "description": "El título de la aplicación"
  },
  "welcome": "Bienvenido",
  "@welcome": {
    "description": "Mensaje de bienvenida"
  },
  "hello": "Hola",
  "@hello": {
    "description": "Mensaje de hola"
  }
}''';
  }

  @override
  Future<void> createBuildYaml(String projectName) async {
    final buildYamlPath = path.join(projectName, 'build.yaml');
    final buildYamlFile = File(buildYamlPath);
    
    final content = '''targets:
  \$default:
    builders:
      json_serializable:
        options:
          explicit_to_json: true
''';
    
    buildYamlFile.writeAsStringSync(content);
  }




  Future<void> _createMvvmBaseFiles(String projectName, StateManagementType stateManagement, bool includeFreezed) async {
    // Create base entity
    final entityFile = File(path.join(projectName, 'lib/models/entities/base_entity.dart'));
    entityFile.writeAsStringSync(_generateBaseEntityContent());

    // Create sample entity
    final sampleEntityFile = File(path.join(projectName, 'lib/models/entities/sample_entity.dart'));
    sampleEntityFile.writeAsStringSync(_generateSampleEntityContent(includeFreezed));

    // Create base service
    final serviceFile = File(path.join(projectName, 'lib/services/base_service.dart'));
    serviceFile.writeAsStringSync(_generateBaseServiceContent());

    // Create sample service
    final sampleServiceFile = File(path.join(projectName, 'lib/services/api/sample_api_service.dart'));
    sampleServiceFile.writeAsStringSync(_generateSampleApiServiceContent());

    // Create base view model
    final viewModelFile = File(path.join(projectName, 'lib/viewmodels/base_viewmodel.dart'));
    viewModelFile.writeAsStringSync(_generateBaseViewModelContent());

    // Create sample view model based on state management
    await _createSampleViewModel(projectName, stateManagement, includeFreezed);

    // Create dependency injection for MVVM
    final diFile = File(path.join(projectName, 'lib/core/di/dependency_injection.dart'));
    diFile.writeAsStringSync(_generateMvvmDependencyInjectionContent(projectName, stateManagement, includeFreezed));

    // Create base error classes
    final errorFile = File(path.join(projectName, 'lib/core/errors/failures.dart'));
    errorFile.writeAsStringSync(_generateFailuresContent());

    // Create base constants
    final constantsFile = File(path.join(projectName, 'lib/core/constants/app_constants.dart'));
    constantsFile.writeAsStringSync(_generateAppConstantsContent());

    // Create MVVM HomePage
    final homePageFile = File(path.join(projectName, 'lib/views/pages/home_page.dart'));
    homePageFile.writeAsStringSync(_generateMvvmHomePageContent(projectName, stateManagement));

    // Create data layer files
    await _createMvvmDataLayerFiles(projectName, includeFreezed);
  }

  Future<void> _createSampleViewModel(String projectName, StateManagementType stateManagement, bool includeFreezed) async {
    switch (stateManagement) {
      case StateManagementType.provider:
        final providerFile = File(path.join(projectName, 'lib/viewmodels/providers/sample_provider.dart'));
        providerFile.writeAsStringSync(_generateMvvmProviderContent(includeFreezed));
        break;
      case StateManagementType.none:
        final controllerFile = File(path.join(projectName, 'lib/viewmodels/controllers/sample_controller.dart'));
        controllerFile.writeAsStringSync(_generateMvvmControllerContent(includeFreezed));
        break;
      case StateManagementType.bloc:
        // Should not happen in MVVM, but just in case
        final blocFile = File(path.join(projectName, 'lib/viewmodels/blocs/sample_bloc.dart'));
        blocFile.writeAsStringSync(_generateMvvmBlocContent(includeFreezed));
        break;
    }
  }

  Future<void> _createMvvmDataLayerFiles(String projectName, bool includeFreezed) async {
    // Create sample model
    final sampleModelFile = File(path.join(projectName, 'lib/models/dto/sample_model.dart'));
    sampleModelFile.writeAsStringSync(_generateSampleModelContent(includeFreezed));

    // Create local service
    final localServiceFile = File(path.join(projectName, 'lib/services/local/sample_local_service.dart'));
    localServiceFile.writeAsStringSync(_generateSampleLocalServiceContent());
  }

  String _generateBaseServiceContent() {
    return '''
/// Base service interface for all services
abstract class BaseService {
  const BaseService();
}
''';
  }

  String _generateSampleApiServiceContent() {
    return '''
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../models/dto/sample_model.dart';
import '../base_service.dart';

/// Sample API service interface
abstract class SampleApiService extends BaseService {
  Future<Either<Failure, List<SampleModel>>> getSamples();
  Future<Either<Failure, SampleModel>> getSampleById(String id);
  Future<Either<Failure, SampleModel>> createSample(SampleModel sample);
  Future<Either<Failure, SampleModel>> updateSample(SampleModel sample);
  Future<Either<Failure, bool>> deleteSample(String id);
}

/// Implementation of SampleApiService
class SampleApiServiceImpl implements SampleApiService {
  @override
  Future<Either<Failure, List<SampleModel>>> getSamples() async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      
      final samples = [
        const SampleModel(id: '1', name: 'Sample 1', description: 'Description 1'),
        const SampleModel(id: '2', name: 'Sample 2', description: 'Description 2'),
      ];
      
      return Right(samples);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch samples: \$e'));
    }
  }

  @override
  Future<Either<Failure, SampleModel>> getSampleById(String id) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      
      final sample = SampleModel(id: id, name: 'Sample \$id', description: 'Description \$id');
      return Right(sample);
    } catch (e) {
      return Left(ServerFailure('Failed to fetch sample: \$e'));
    }
  }

  @override
  Future<Either<Failure, SampleModel>> createSample(SampleModel sample) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      return Right(sample);
    } catch (e) {
      return Left(ServerFailure('Failed to create sample: \$e'));
    }
  }

  @override
  Future<Either<Failure, SampleModel>> updateSample(SampleModel sample) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      return Right(sample);
    } catch (e) {
      return Left(ServerFailure('Failed to update sample: \$e'));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteSample(String id) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure('Failed to delete sample: \$e'));
    }
  }
}
''';
  }

  String _generateBaseViewModelContent() {
    return '''
import 'package:flutter/foundation.dart';

/// Base view model class for all view models
abstract class BaseViewModel extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
''';
  }


  String _generateMvvmProviderContent(bool includeFreezed) {
    return '''
import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../services/api/sample_api_service.dart';
import '../../models/entities/sample_entity.dart';

enum SampleStatus { initial, loading, success, error }

class SampleProvider with ChangeNotifier {
  final SampleApiService _apiService;
  
  SampleStatus _status = SampleStatus.initial;
  List<SampleEntity> _samples = [];
  String? _error;

  SampleProvider({required SampleApiService apiService}) : _apiService = apiService {
    loadSamples();
  }

  SampleStatus get status => _status;
  List<SampleEntity> get samples => _samples;
  String? get error => _error;

  Future<void> loadSamples() async {
    _status = SampleStatus.loading;
    _error = null;
    notifyListeners();
    
    final result = await _apiService.getSamples();
    result.fold(
      (failure) {
        _status = SampleStatus.error;
        _error = failure.message;
        notifyListeners();
      },
      (models) {
        _samples = models.map((model) => SampleEntity.fromModel(model)).toList();
        _status = SampleStatus.success;
        notifyListeners();
      },
    );
  }
}
''';
  }

  String _generateMvvmControllerContent(bool includeFreezed) {
    return '''
import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../services/api/sample_api_service.dart';
import '../../models/entities/sample_entity.dart';
import '../base_viewmodel.dart';

class SampleController extends BaseViewModel {
  final SampleApiService _apiService;
  
  List<SampleEntity> _samples = [];

  SampleController({required SampleApiService apiService}) : _apiService = apiService {
    loadSamples();
  }

  List<SampleEntity> get samples => _samples;

  Future<void> loadSamples() async {
    setLoading(true);
    clearError();
    
    final result = await _apiService.getSamples();
    result.fold(
      (failure) {
        setError(failure.message);
      },
      (models) {
        _samples = models.map((model) => SampleEntity.fromModel(model)).toList();
      },
    );
    
    setLoading(false);
  }
}
''';
  }

  String _generateMvvmBlocContent(bool includeFreezed) {
    return '''
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../services/api/sample_api_service.dart';
import '../../models/entities/sample_entity.dart';

// This should not be used in MVVM, but included for completeness
class SampleBloc extends HydratedBloc<SampleEvent, SampleState> {
  final SampleApiService _apiService;

  SampleBloc({required SampleApiService apiService}) 
    : _apiService = apiService, super(const SampleState()) {
    on<LoadSamples>(_onLoadSamples);
  }

  Future<void> _onLoadSamples(LoadSamples event, Emitter<SampleState> emit) async {
    emit(state.copyWith(status: SampleStatus.loading));
    
    final result = await _apiService.getSamples();
    result.fold(
      (failure) => emit(state.copyWith(
        status: SampleStatus.error,
        error: failure.message,
      )),
      (models) {
        final entities = models.map((model) => SampleEntity.fromModel(model)).toList();
        emit(state.copyWith(
          status: SampleStatus.success,
          samples: entities,
        ));
      },
    );
  }

  @override
  SampleState? fromJson(Map<String, dynamic> json) => SampleState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(SampleState state) => state.toJson();
}

abstract class SampleEvent {}

class LoadSamples extends SampleEvent {}

enum SampleStatus { initial, loading, success, error }

class SampleState {
  final SampleStatus status;
  final List<SampleEntity> samples;
  final String? error;

  const SampleState({
    this.status = SampleStatus.initial,
    this.samples = const [],
    this.error,
  });

  SampleState copyWith({
    SampleStatus? status,
    List<SampleEntity>? samples,
    String? error,
  }) {
    return SampleState(
      status: status ?? this.status,
      samples: samples ?? this.samples,
      error: error ?? this.error,
    );
  }
}
''';
  }

  String _generateSampleLocalServiceContent() {
    return '''
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../dto/sample_model.dart';
import '../base_service.dart';

/// Sample local service for caching
abstract class SampleLocalService extends BaseService {
  Future<Either<Failure, List<SampleModel>>> getSamples();
  Future<Either<Failure, SampleModel>> getSampleById(String id);
  Future<Either<Failure, SampleModel>> saveSample(SampleModel sample);
  Future<Either<Failure, bool>> deleteSample(String id);
}

/// Implementation of SampleLocalService
class SampleLocalServiceImpl implements SampleLocalService {
  @override
  Future<Either<Failure, List<SampleModel>>> getSamples() async {
    try {
      // Simulate local storage
      await Future.delayed(const Duration(milliseconds: 100));
      
      final samples = [
        const SampleModel(id: '1', name: 'Local Sample 1', description: 'Local Description 1'),
        const SampleModel(id: '2', name: 'Local Sample 2', description: 'Local Description 2'),
      ];
      
      return Right(samples);
    } catch (e) {
      return Left(CacheFailure('Failed to fetch samples from cache: \$e'));
    }
  }

  @override
  Future<Either<Failure, SampleModel>> getSampleById(String id) async {
    try {
      // Simulate local storage
      await Future.delayed(const Duration(milliseconds: 100));
      
      final sample = SampleModel(id: id, name: 'Local Sample \$id', description: 'Local Description \$id');
      return Right(sample);
    } catch (e) {
      return Left(CacheFailure('Failed to fetch sample from cache: \$e'));
    }
  }

  @override
  Future<Either<Failure, SampleModel>> saveSample(SampleModel sample) async {
    try {
      // Simulate local storage
      await Future.delayed(const Duration(milliseconds: 100));
      return Right(sample);
    } catch (e) {
      return Left(CacheFailure('Failed to save sample to cache: \$e'));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteSample(String id) async {
    try {
      // Simulate local storage
      await Future.delayed(const Duration(milliseconds: 100));
      return const Right(true);
    } catch (e) {
      return Left(CacheFailure('Failed to delete sample from cache: \$e'));
    }
  }
}
''';
  }

  String _generateMvvmDependencyInjectionContent(String projectName, StateManagementType stateManagement, bool includeFreezed) {
    String viewModelRegistration = '';
    
    switch (stateManagement) {
      case StateManagementType.provider:
        viewModelRegistration = '''
    // Register SampleProvider
    registerLazySingleton<SampleProvider>(() => SampleProvider(apiService: get<SampleApiService>()));''';
        break;
      case StateManagementType.none:
        viewModelRegistration = '''
    // Register SampleController
    registerLazySingleton<SampleController>(() => SampleController(apiService: get<SampleApiService>()));''';
        break;
      case StateManagementType.bloc:
        viewModelRegistration = '''
    // Register SampleBloc (should not be used in MVVM)
    registerLazySingleton<SampleBloc>(() => SampleBloc(apiService: get<SampleApiService>()));''';
        break;
    }
    
    return '''
import 'package:get_it/get_it.dart';
import '../services/api/sample_api_service.dart';
import '../services/local/sample_local_service.dart';

/// MVVM Dependency Injection container using GetIt
class Injector {
  Injector._();

  static final GetIt _locator = GetIt.instance;

  static void init() {
    _registerServices();
    _registerViewModels();
  }

  static T get<T extends Object>() => _locator<T>();

  static void registerSingleton<T extends Object>(T instance) {
    _locator.registerSingleton<T>(instance);
  }

  static void registerLazySingleton<T extends Object>(T Function() factory) {
    _locator.registerLazySingleton<T>(factory);
  }

  static void registerFactory<T extends Object>(T Function() factory) {
    _locator.registerFactory<T>(factory);
  }

  //** ---- Services ---- */
  static void _registerServices() {
    // Register API services
    registerLazySingleton<SampleApiService>(() => SampleApiServiceImpl());
    
    // Register local services
    registerLazySingleton<SampleLocalService>(() => SampleLocalServiceImpl());
  }

  //** ---- View Models ---- */
  static void _registerViewModels() {
    $viewModelRegistration
  }
}
''';
  }

  String _generateMvvmMainContent(StateManagementType stateManagement, bool includeGoRouter, bool includeFreezed) {
    String imports = '';
    String providers = '';
    String providerType = '';
    
    switch (stateManagement) {
      
      case StateManagementType.provider:
        imports = '''
import 'package:provider/provider.dart';
import 'viewmodels/providers/sample_provider.dart';''';
        providers = '''
        ChangeNotifierProvider<SampleProvider>(
          create: (BuildContext _) => Injector.get<SampleProvider>(),
        ),''';
        providerType = 'MultiProvider';
        break;
      case StateManagementType.none:
        imports = '''
import 'package:provider/provider.dart';
import 'viewmodels/controllers/sample_controller.dart';''';
        providers = '''
        ChangeNotifierProvider<SampleController>(
          create: (BuildContext _) => Injector.get<SampleController>(),
        ),''';
        providerType = 'MultiProvider';
        break;
      case StateManagementType.bloc:
        imports = '''
import 'package:flutter_bloc/flutter_bloc.dart';
import 'viewmodels/blocs/sample_bloc.dart';''';
        providers = '''
        BlocProvider<SampleBloc>(
          create: (BuildContext _) => Injector.get<SampleBloc>(),
        ),''';
        providerType = 'MultiBlocProvider';
        break;
    }
    
    String routerConfig = '';
    String routerImports = '';
    String localizationsImports = '';
    String localizationsSetup = '';
    String homePageImport = '';
    
    if (includeGoRouter) {
      routerImports = '''
import 'routes/app_router.dart';''';
      localizationsImports = '''
import 'application/generated/l10n/app_localizations.dart';''';
      localizationsSetup = '''
    localizationsDelegates: AppLocalizationsSetup.localizationsDelegates,
    supportedLocales: AppLocalizationsSetup.supportedLocales,''';
      routerConfig = '''
    routerConfig: AppRouter.router,''';
    } else {
      homePageImport = '''
import 'views/pages/home_page.dart';''';
    }
    
    return '''
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'application/injector.dart';$imports$routerImports$localizationsImports$homePageImport

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runMainApp();
}

Future<void> runMainApp() async {
  Injector.init();

  runApp($providerType(
    providers: [$providers
    ],
    child: const MyApp()
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp${includeGoRouter ? '.router' : ''}(
      title: 'MVVM Flutter App',
      debugShowCheckedModeBanner: kDebugMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),$routerConfig$localizationsSetup
      themeAnimationCurve: Curves.easeInOut,
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationStyle: AnimationStyle(
        curve: Curves.easeInOut,
        duration: const Duration(milliseconds: 300),
        reverseCurve: Curves.easeInOut,
        reverseDuration: const Duration(milliseconds: 300),
      ),
        home: ${includeGoRouter ? 'null' : 'const HomePage()'},
      ),
    );
  }
}
''';
  }

  @override
  Future<void> ensureCleanArchitectureFiles(String projectName) async {
    final oldDiFile = File(path.join(projectName, 'lib/core/di/dependency_injection.dart'));
    if (await oldDiFile.exists()) {
      await oldDiFile.delete();
    }
    
    final oldDiDir = Directory(path.join(projectName, 'lib/core/di'));
    if (await oldDiDir.exists()) {
      try {
        final contents = await oldDiDir.list().toList();
        if (contents.isEmpty) {
          await oldDiDir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore errors
      }
    }
  }

  String _generateMvvmHomePageContent(String projectName, StateManagementType stateManagement) {
    String stateManagementWidget = '';
    String imports = '';
    
    switch (stateManagement) {
      case StateManagementType.provider:
        imports = '''
import 'package:provider/provider.dart';
import '../viewmodels/providers/sample_provider.dart';''';
        stateManagementWidget = '''
            Consumer<SampleProvider>(
              builder: (context, provider, child) {
                switch (provider.status) {
                  case SampleStatus.loading:
                    return const CircularProgressIndicator();
                  case SampleStatus.error:
                    return Text('Error: \${provider.error}');
                  case SampleStatus.success:
                    return Column(
                      children: [
                        Text('Samples: \${provider.samples.length}'),
                        ...provider.samples.map((sample) => ListTile(
                          title: Text(sample.name),
                          subtitle: Text(sample.description),
                        )),
                      ],
                    );
                  case SampleStatus.initial:
                    return const Text('Initial state');
                }
              },
            ),''';
        break;
      case StateManagementType.none:
        imports = '''
import '../viewmodels/controllers/sample_controller.dart';
import '../core/di/dependency_injection.dart';''';
        stateManagementWidget = '''
            Consumer<SampleController>(
              builder: (context, controller, child) {
                if (controller.isLoading) {
                  return const CircularProgressIndicator();
                }
                if (controller.error != null) {
                  return Text('Error: \${controller.error}');
                }
                return Column(
                  children: [
                    Text('Samples: \${controller.samples.length}'),
                    ...controller.samples.map((sample) => ListTile(
                      title: Text(sample.name),
                      subtitle: Text(sample.description),
                    )),
                  ],
                );
              },
            ),''';
        break;
      case StateManagementType.bloc:
        imports = '''
import 'package:flutter_bloc/flutter_bloc.dart';
import '../viewmodels/blocs/sample_bloc.dart';''';
        stateManagementWidget = '''
            BlocBuilder<SampleBloc, SampleState>(
              builder: (context, state) {
                switch (state.status) {
                  case SampleStatus.loading:
                    return const CircularProgressIndicator();
                  case SampleStatus.error:
                    return Text('Error: \${state.error}');
                  case SampleStatus.success:
                    return Column(
                      children: [
                        Text('Samples: \${state.samples.length}'),
                        ...state.samples.map((sample) => ListTile(
                          title: Text(sample.name),
                          subtitle: Text(sample.description),
                        )),
                      ],
                    );
                  case SampleStatus.initial:
                    return const Text('Initial state');
                }
              },
            ),''';
        break;
    }
    
    return '''
import 'package:flutter/material.dart';$imports

/// MVVM HomePage
/// This page follows MVVM pattern and is located in the views layer
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('MVVM Home'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Welcome to MVVM Architecture!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'This page demonstrates MVVM pattern with state management.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            $stateManagementWidget
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Column(
                children: [
                  Text(
                    '🏗️ MVVM Architecture Structure:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text('• lib/models/ - Entities and DTOs'),
                  Text('• lib/services/ - API and Local services'),
                  Text('• lib/viewmodels/ - Business logic and state'),
                  Text('• lib/views/ - UI components'),
                  Text('• lib/core/ - Utilities and DI'),
                  SizedBox(height: 8),
                  Text(
                    '💉 Dependency Injection: GetIt + MVVM Injector',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
''';
  }

}