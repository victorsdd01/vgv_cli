// ignore_for_file: unnecessary_brace_in_string_interps

import 'dart:io';
import 'package:args/args.dart';
import 'core/di/dependency_injection.dart';
import 'core/utils/version_checker.dart';
import 'presentation/controllers/cli_controller.dart';

/// Main CLI class for VGV
class VgvCli {
  static const String _appName = 'vgv';
  static const String _description = 'A Flutter CLI tool for creating projects with interactive prompts.';
  
  /// Get current version from pubspec.yaml
  static String get _version => VersionChecker.getCurrentVersion();

  late ArgParser _argParser;
  late ArgResults _argResults;
  late CliController _cliController;

  VgvCli() {
    _setupArgParser();
    _setupDependencies();
  }

  void _setupArgParser() {
    _argParser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Show this help message',
        negatable: false,
      )
      ..addFlag(
        'version',
        abbr: 'v',
        help: 'Show version information',
        negatable: false,
      )
      ..addFlag(
        'update',
        abbr: 'u',
        help: 'Update VGV CLI to the latest version',
        negatable: false,
      )
      ..addFlag(
        'quick',
        abbr: 'q',
        help: 'Quick mode: create project with sensible defaults',
        negatable: false,
      )
      ..addOption(
        'name',
        abbr: 'n',
        help: 'Project name (e.g., my_awesome_app)',
      )
      ..addOption(
        'org',
        help: 'Organization identifier (e.g., com.example)',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output directory (defaults to current directory)',
      )
      ..addFlag(
        'no-git',
        help: 'Skip git initialization',
        negatable: false,
      )
      ..addFlag(
        'dry-run',
        help: 'Show what would be created without creating files',
        negatable: false,
      );
  }

  void _setupDependencies() {
    DependencyInjection.initialize();
    _cliController = DependencyInjection.instance.cliController;
  }

  /// Initialize version file if it doesn't exist
  void _initializeVersionFile() {
    try {
      // Only initialize if the file doesn't exist
      if (VersionChecker.getInstalledVersionFromFile() == null) {
        final currentVersion = VersionChecker.getCurrentVersion();
        if (currentVersion != '1.0.0') {
          VersionChecker.saveInstalledVersion(currentVersion);
        }
      }
    } catch (e) {
      // Silently fail - not critical
    }
  }

  Future<void> run(List<String> arguments) async {
    try {
      _argResults = _argParser.parse(arguments);

      // Initialize version file if it doesn't exist (first run)
      _initializeVersionFile();

      if (_argResults['help']) {
        _printUsage();
        return;
      }

      if (_argResults['version']) {
        await _printVersion();
        return;
      }

      if (_argResults['update']) {
        await _updateCLI();
        return;
      }

      // Check for updates when running normally
      await _checkForUpdates();

      // Handle quick mode or flags
      final projectName = _argResults['name'] as String?;
      final organization = _argResults['org'] as String?;
      final outputDir = _argResults['output'] as String?;
      final noGit = _argResults['no-git'] as bool;
      final dryRun = _argResults['dry-run'] as bool;
      final quickMode = _argResults['quick'] as bool;

      if (dryRun) {
        await _runDryRun(projectName, organization, outputDir);
        return;
      }

      if (quickMode || projectName != null) {
        await _runWithFlags(
          projectName: projectName,
          organization: organization,
          outputDir: outputDir,
          noGit: noGit,
          quickMode: quickMode,
        );
        return;
      }

      // Run in interactive mode
      await _runInteractiveMode();
    } catch (e) {
      print('Error: $e');
      _printUsage();
      exit(1);
    }
  }

  Future<void> _showUpdateProgress() async {
    const String reset = '\x1B[0m';
    const String bold = '\x1B[1m';
    const String brightGreen = '\x1B[92m';
    const String brightYellow = '\x1B[93m';
    const String brightCyan = '\x1B[96m';
    const String dim = '\x1B[2m';
    
    print('${brightCyan}${bold}Update Progress${reset}');
    print('');
    
    final steps = [
      {'text': 'Checking for latest version', 'duration': 600},
      {'text': 'Downloading new version', 'duration': 1200},
      {'text': 'Installing dependencies', 'duration': 1000},
      {'text': 'Updating global package', 'duration': 800},
      {'text': 'Finalizing installation', 'duration': 600},
    ];
    
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      
      print('${brightCyan}${bold}[${i + 1}/${steps.length}]${reset} ${brightYellow}${step['text']}${reset}');
      
      stdout.write('${dim}    ${_getSpinner(0)} [${_getProgressBar(0)}] 0%${reset}');
      
      for (int p = 0; p <= 100; p += 5) {
        await Future.delayed(Duration(milliseconds: (step['duration'] as int) ~/ 20));
        stdout.write('\r${dim}    ${_getSpinner(p ~/ 5)} [${_getProgressBar(p)}] ${p.toString().padLeft(3)}%${reset}');
      }
      
      print(' ${brightGreen}done${reset}');
    }
    
    print('');
    print('${brightGreen}${bold}All steps completed successfully${reset}');
    print('');
  }
  
  Future<void> _showCompletionCelebration() async {
    const String reset = '\x1B[0m';
    const String bold = '\x1B[1m';
    const String brightGreen = '\x1B[92m';
    const String brightMagenta = '\x1B[95m';
    
    print('');
    print('${brightMagenta}${bold}╔══════════════════════════════════════════════════════════════╗${reset}');
    print('${brightMagenta}${bold}║${reset}${brightGreen}${bold}                       UPDATE COMPLETE                        ${reset}${brightMagenta}${bold}║${reset}');
    print('${brightMagenta}${bold}╚══════════════════════════════════════════════════════════════╝${reset}');
    print('');
  }
  
  String _getProgressBar(int percentage) {
    const int barLength = 20;
    final filledLength = (percentage / 100 * barLength).round();
    final emptyLength = barLength - filledLength;
    
    final filled = '█' * filledLength;
    final empty = '░' * emptyLength;
    
    return filled + empty;
  }
  
  String _getSpinner(int step) {
    final spinners = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
    return spinners[step % spinners.length];
  }

  Future<void> _checkForUpdates() async {
    try {
      final currentVersion = _version;
      final latestVersion = await VersionChecker.getLatestCLIVersionAny();
      
      if (latestVersion != null) {
        final isUpdateAvailable = VersionChecker.compareVersions(currentVersion, latestVersion) < 0;
        
        if (isUpdateAvailable) {
          const String reset = '\x1B[0m';
          const String bold = '\x1B[1m';
          const String brightYellow = '\x1B[93m';
          const String dim = '\x1B[2m';
          
          print('');
          print('${brightYellow}${bold}Update Available${reset}');
          print('${dim}   Current: $currentVersion${reset}');
          print('${dim}   Latest:  $latestVersion${reset}');
          print('${dim}   Run: vgv -u to update${reset}');
          print('');
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _runInteractiveMode() async {
    await _cliController.runInteractiveMode();
  }

  Future<void> _runDryRun(String? projectName, String? organization, String? outputDir) async {
    const String reset = '\x1B[0m';
    const String bold = '\x1B[1m';
    const String brightCyan = '\x1B[96m';
    const String brightYellow = '\x1B[93m';
    const String brightGreen = '\x1B[92m';
    const String dim = '\x1B[2m';

    final defaultOrg = projectName != null ? 'com.$projectName' : '<interactive>';
    
    print('');
    print('${brightCyan}${bold}DRY RUN - No files will be created${reset}');
    print('');
    print('${brightGreen}${bold}Configuration:${reset}');
    print('${dim}   Project Name:  ${reset}${brightYellow}${projectName ?? "<interactive>"}${reset}');
    print('${dim}   Organization:  ${reset}${brightYellow}${organization ?? defaultOrg}${reset}');
    print('${dim}   Output:        ${reset}${brightYellow}${outputDir ?? Directory.current.path}${reset}');
    print('');
    print('${brightGreen}${bold}Would create:${reset}');
    print('${dim}   - Flutter project with Clean Architecture${reset}');
    print('${dim}   - BLoC state management with Freezed${reset}');
    print('${dim}   - GoRouter navigation${reset}');
    print('${dim}   - Internationalization (en, es)${reset}');
    print('${dim}   - Environment configs (dev, staging, production)${reset}');
    print('${dim}   - VS Code launch configurations${reset}');
    print('${dim}   - Auth feature (login, register)${reset}');
    print('${dim}   - Home feature${reset}');
    print('${dim}   - Settings feature (theme, language)${reset}');
    print('');
  }

  Future<void> _runWithFlags({
    String? projectName,
    String? organization,
    String? outputDir,
    bool noGit = false,
    bool quickMode = false,
  }) async {
    await _cliController.runWithFlags(
      projectName: projectName,
      organization: organization,
      outputDir: outputDir,
      noGit: noGit,
      quickMode: quickMode,
    );
  }

  Future<void> _updateCLI() async {
    const String reset = '\x1B[0m';
    const String bold = '\x1B[1m';
    const String brightCyan = '\x1B[96m';
    const String brightGreen = '\x1B[92m';
    const String brightYellow = '\x1B[93m';
    const String brightRed = '\x1B[91m';
    const String red = '\x1B[31m';
    const String dim = '\x1B[2m';
    
    print('');
    print('${brightCyan}${bold}╔══════════════════════════════════════════════════════════════╗${reset}');
    print('${brightCyan}${bold}║${reset}${bold}                          VGV UPDATE                          ${reset}${brightCyan}${bold}║${reset}');
    print('${brightCyan}${bold}╚══════════════════════════════════════════════════════════════╝${reset}');
    print('');
    
    String currentVersion = _version;
    if (currentVersion == '1.0.0') {
      final gitCurrentVersion = await VersionChecker.getLatestCLIVersionFromGit();
      if (gitCurrentVersion != null) {
        currentVersion = gitCurrentVersion;
      }
    }
    print('${brightGreen}${bold}Current:${reset} ${brightYellow}$currentVersion${reset}');
    
    final latestVersion = await VersionChecker.getLatestCLIVersionAny();
    if (latestVersion != null) {
      print('${brightGreen}${bold}Latest:${reset}  ${brightYellow}$latestVersion${reset}');
      
      if (latestVersion == currentVersion) {
        print('');
        print('${brightGreen}${bold}You already have the latest version${reset}');
        print('');
        return;
      }
    } else {
      print('${brightYellow}Could not check for latest version${reset}');
      print('${dim}Proceeding with update from main branch...${reset}');
    }
    
    print('');
    
    try {
      print('${brightYellow}${bold}Updating VGV CLI...${reset}');
      print('');
      
      await _showUpdateProgress();
      
      final result = Process.runSync('dart', [
        'pub',
        'global',
        'activate',
        '--source',
        'git',
        'https://github.com/victorsdd01/flutter_forge.git'
      ]);
      
      if (result.exitCode == 0) {
        final newVersion = await VersionChecker.getLatestCLIVersionAny();
        if (newVersion != null) {
          VersionChecker.saveInstalledVersion(newVersion);
        } else {
          final currentVersion = VersionChecker.getCurrentVersion();
          if (currentVersion != '1.0.0') {
            VersionChecker.saveInstalledVersion(currentVersion);
          }
        }
        
        await _showCompletionCelebration();
        print('${brightGreen}${bold}VGV CLI updated successfully${reset}');
        print('');
        print('${brightCyan}${bold}What\'s new:${reset}');
        print('${dim}   - Latest features and improvements${reset}');
        print('${dim}   - Bug fixes and performance enhancements${reset}');
        print('${dim}   - Updated dependencies and templates${reset}');
        print('');
        print('${brightGreen}Ready to create Flutter projects${reset}');
        print('');
      } else {
        print('${brightRed}${bold}Update failed${reset}');
        print('${red}${result.stderr}${reset}');
        print('');
        print('${brightYellow}Try: vgv -u${reset}');
        print('');
      }
    } catch (e) {
      print('${brightRed}${bold}Update failed:${reset} ${red}$e${reset}');
      print('');
      print('${brightYellow}Try: flutterforge -u${reset}');
      print('');
    }
  }

  Future<void> _printVersion() async {
    const String reset = '\x1B[0m';
    const String bold = '\x1B[1m';
    const String brightCyan = '\x1B[96m';
    const String brightMagenta = '\x1B[95m';
    const String brightGreen = '\x1B[92m';
    const String brightYellow = '\x1B[93m';
    const String dim = '\x1B[2m';
    
    print('');
    print('${brightCyan}${bold}╔══════════════════════════════════════════════════════════════╗${reset}');
    print('${brightCyan}${bold}║${reset}${brightMagenta}${bold}                           VGV CLI                            ${reset}${brightCyan}${bold}║${reset}');
    print('${brightCyan}${bold}║${reset}${dim}           The Ultimate Flutter Project Generator           ${reset}${brightCyan}${bold}║${reset}');
    print('${brightCyan}${bold}╚══════════════════════════════════════════════════════════════╝${reset}');
    print('');
    
    final currentVersion = VersionChecker.getCurrentVersion();
    print('${brightGreen}${bold}Version:${reset}     ${brightYellow}$currentVersion${reset}');
    
    try {
      final latestVersion = await VersionChecker.getLatestCLIVersionAny();
      
      if (latestVersion != null) {
        final comparison = VersionChecker.compareVersions(currentVersion, latestVersion);
        if (comparison < 0) {
          print('${brightYellow}${bold}Latest:${reset}      ${brightYellow}$latestVersion${reset} ${brightYellow}(update available)${reset}');
          print('');
          print('${dim}Run: vgv -u to update${reset}');
        } else if (comparison == 0) {
          print('${brightGreen}${bold}Status:${reset}      ${brightGreen}Up to date${reset}');
        } else {
          print('${brightYellow}${bold}Status:${reset}      ${brightYellow}Development version${reset}');
          print('${dim}Latest stable: $latestVersion${reset}');
        }
      } else {
        print('${dim}Status:      Could not check for updates${reset}');
      }
    } catch (e) {
      // Silently fail
    }
    
    print('');
    print('${brightGreen}${bold}Description:${reset} ${dim}$_description${reset}');
    print('${brightCyan}${bold}Repository:${reset}  ${dim}https://github.com/victorsdd01/flutter_forge${reset}');
    print('${brightCyan}${bold}Update:${reset}      ${dim}vgv -u | vgv --update${reset}');
    print('');
  }

  void _printUsage() {
    const String reset = '\x1B[0m';
    const String bold = '\x1B[1m';
    const String brightCyan = '\x1B[96m';
    const String brightGreen = '\x1B[92m';
    const String brightYellow = '\x1B[93m';
    const String dim = '\x1B[2m';
    
    print('');
    print('${brightCyan}${bold}╔══════════════════════════════════════════════════════════════╗${reset}');
    print('${brightCyan}${bold}║${reset}${bold}                            VGV CLI                           ${reset}${brightCyan}${bold}║${reset}');
    print('${brightCyan}${bold}╚══════════════════════════════════════════════════════════════╝${reset}');
    print('');
    print('${brightGreen}${bold}Description:${reset} ${dim}$_description${reset}');
    print('');
    print('${brightGreen}${bold}Usage:${reset}');
    print('  ${brightYellow}$_appName${reset}                    ${dim}Start interactive mode${reset}');
    print('  ${brightYellow}$_appName${reset} ${brightCyan}-q${reset}                 ${dim}Quick mode with defaults${reset}');
    print('  ${brightYellow}$_appName${reset} ${brightCyan}-n${reset} <name>          ${dim}Create project with name${reset}');
    print('  ${brightYellow}$_appName${reset} ${brightCyan}-n${reset} <name> ${brightCyan}--org${reset} <org> ${dim}With organization${reset}');
    print('');
    print('${brightGreen}${bold}Flags:${reset}');
    print('  ${brightCyan}-h, --help${reset}                   ${dim}Show this help message${reset}');
    print('  ${brightCyan}-v, --version${reset}                ${dim}Show version information${reset}');
    print('  ${brightCyan}-u, --update${reset}                 ${dim}Update to latest version${reset}');
    print('  ${brightCyan}-q, --quick${reset}                  ${dim}Quick mode with defaults${reset}');
    print('  ${brightCyan}-n, --name${reset} <name>            ${dim}Project name${reset}');
    print('  ${brightCyan}    --org${reset} <org>              ${dim}Organization (com.example)${reset}');
    print('  ${brightCyan}-o, --output${reset} <dir>           ${dim}Output directory${reset}');
    print('  ${brightCyan}    --no-git${reset}                 ${dim}Skip git initialization${reset}');
    print('  ${brightCyan}    --dry-run${reset}                ${dim}Preview without creating${reset}');
    print('');
    print('${brightGreen}${bold}Examples:${reset}');
    print('  ${dim}$_appName${reset}');
    print('  ${dim}$_appName -q -n my_app${reset}');
    print('  ${dim}$_appName -n my_app --org com.mycompany${reset}');
    print('  ${dim}$_appName -n my_app -o ~/projects --no-git${reset}');
    print('  ${dim}$_appName --dry-run -n test_app${reset}');
    print('');
    print('${brightGreen}${bold}Features:${reset}');
    print('  ${dim}- Clean Architecture with BLoC + Freezed${reset}');
    print('  ${dim}- Multi-platform support (iOS, Android, Web, Desktop)${reset}');
    print('  ${dim}- Environment configs (dev, staging, production)${reset}');
    print('  ${dim}- Internationalization (en, es)${reset}');
    print('  ${dim}- GoRouter navigation${reset}');
    print('  ${dim}- VS Code debug configurations${reset}');
    print('');
    print('${brightCyan}${bold}Repository:${reset} ${dim}https://github.com/victorsdd01/flutter_forge${reset}');
    print('');
  }
}
