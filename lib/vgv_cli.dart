// ignore_for_file: unnecessary_brace_in_string_interps

import 'dart:io';
import 'package:args/args.dart';
import 'core/di/dependency_injection.dart';
import 'core/utils/ansi_colors.dart';
import 'core/utils/version_checker.dart';
import 'presentation/controllers/cli_controller.dart';

// Short alias for AnsiColors to keep print statements readable
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
      stderr.writeln('Warning: Could not initialize version file: $e');
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
    print('${AnsiColors.brightCyan}${AnsiColors.bold}Update Progress${AnsiColors.reset}');
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

      print('${AnsiColors.brightCyan}${AnsiColors.bold}[${i + 1}/${steps.length}]${AnsiColors.reset} ${AnsiColors.brightYellow}${step['text']}${AnsiColors.reset}');

      stdout.write('${AnsiColors.dim}    ${_getSpinner(0)} [${_getProgressBar(0)}] 0%${AnsiColors.reset}');

      for (int p = 0; p <= 100; p += 5) {
        await Future.delayed(Duration(milliseconds: (step['duration'] as int) ~/ 20));
        stdout.write('\r${AnsiColors.dim}    ${_getSpinner(p ~/ 5)} [${_getProgressBar(p)}] ${p.toString().padLeft(3)}%${AnsiColors.reset}');
      }

      print(' ${AnsiColors.brightGreen}done${AnsiColors.reset}');
    }

    print('');
    print('${AnsiColors.brightGreen}${AnsiColors.bold}All steps completed successfully${AnsiColors.reset}');
    print('');
  }

  Future<void> _showCompletionCelebration() async {
    print('');
    print('${AnsiColors.brightMagenta}${AnsiColors.bold}╔══════════════════════════════════════════════════════════════╗${AnsiColors.reset}');
    print('${AnsiColors.brightMagenta}${AnsiColors.bold}║${AnsiColors.reset}${AnsiColors.brightGreen}${AnsiColors.bold}                       UPDATE COMPLETE                        ${AnsiColors.reset}${AnsiColors.brightMagenta}${AnsiColors.bold}║${AnsiColors.reset}');
    print('${AnsiColors.brightMagenta}${AnsiColors.bold}╚══════════════════════════════════════════════════════════════╝${AnsiColors.reset}');
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
          print('');
          print('${AnsiColors.brightYellow}${AnsiColors.bold}Update Available${AnsiColors.reset}');
          print('${AnsiColors.dim}   Current: $currentVersion${AnsiColors.reset}');
          print('${AnsiColors.dim}   Latest:  $latestVersion${AnsiColors.reset}');
          print('${AnsiColors.dim}   Run: vgv -u to update${AnsiColors.reset}');
          print('');
        }
      }
    } catch (e) {
      // Update check failure is not critical
    }
  }

  Future<void> _runInteractiveMode() async {
    await _cliController.runInteractiveMode();
  }

  Future<void> _runDryRun(String? projectName, String? organization, String? outputDir) async {
    final defaultOrg = projectName != null ? 'com.$projectName' : '<interactive>';

    print('');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}DRY RUN - No files will be created${AnsiColors.reset}');
    print('');
    print('${AnsiColors.brightGreen}${AnsiColors.bold}Configuration:${AnsiColors.reset}');
    print('${AnsiColors.dim}   Project Name:  ${AnsiColors.reset}${AnsiColors.brightYellow}${projectName ?? "<interactive>"}${AnsiColors.reset}');
    print('${AnsiColors.dim}   Organization:  ${AnsiColors.reset}${AnsiColors.brightYellow}${organization ?? defaultOrg}${AnsiColors.reset}');
    print('${AnsiColors.dim}   Output:        ${AnsiColors.reset}${AnsiColors.brightYellow}${outputDir ?? Directory.current.path}${AnsiColors.reset}');
    print('');
    print('${AnsiColors.brightGreen}${AnsiColors.bold}Would create:${AnsiColors.reset}');
    print('${AnsiColors.dim}   - Flutter project with Clean Architecture${AnsiColors.reset}');
    print('${AnsiColors.dim}   - BLoC state management with Freezed${AnsiColors.reset}');
    print('${AnsiColors.dim}   - GoRouter navigation${AnsiColors.reset}');
    print('${AnsiColors.dim}   - Internationalization (en, es)${AnsiColors.reset}');
    print('${AnsiColors.dim}   - Environment configs (dev, staging, production)${AnsiColors.reset}');
    print('${AnsiColors.dim}   - VS Code launch configurations${AnsiColors.reset}');
    print('${AnsiColors.dim}   - Auth feature (login, register)${AnsiColors.reset}');
    print('${AnsiColors.dim}   - Home feature${AnsiColors.reset}');
    print('${AnsiColors.dim}   - Settings feature (theme, language)${AnsiColors.reset}');
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
    print('');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}╔══════════════════════════════════════════════════════════════╗${AnsiColors.reset}');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}║${AnsiColors.reset}${AnsiColors.bold}                          VGV UPDATE                          ${AnsiColors.reset}${AnsiColors.brightCyan}${AnsiColors.bold}║${AnsiColors.reset}');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}╚══════════════════════════════════════════════════════════════╝${AnsiColors.reset}');
    print('');

    String currentVersion = _version;
    if (currentVersion == '1.0.0') {
      final gitCurrentVersion = await VersionChecker.getLatestCLIVersionFromGit();
      if (gitCurrentVersion != null) {
        currentVersion = gitCurrentVersion;
      }
    }
    print('${AnsiColors.brightGreen}${AnsiColors.bold}Current:${AnsiColors.reset} ${AnsiColors.brightYellow}$currentVersion${AnsiColors.reset}');

    final latestVersion = await VersionChecker.getLatestCLIVersionAny();
    if (latestVersion != null) {
      print('${AnsiColors.brightGreen}${AnsiColors.bold}Latest:${AnsiColors.reset}  ${AnsiColors.brightYellow}$latestVersion${AnsiColors.reset}');

      if (latestVersion == currentVersion) {
        print('');
        print('${AnsiColors.brightGreen}${AnsiColors.bold}You already have the latest version${AnsiColors.reset}');
        print('');
        return;
      }
    } else {
      print('${AnsiColors.brightYellow}Could not check for latest version${AnsiColors.reset}');
      print('${AnsiColors.dim}Proceeding with update from main branch...${AnsiColors.reset}');
    }

    print('');

    try {
      print('${AnsiColors.brightYellow}${AnsiColors.bold}Updating VGV CLI...${AnsiColors.reset}');
      print('');

      await _showUpdateProgress();

      final result = Process.runSync('dart', [
        'pub',
        'global',
        'activate',
        '--source',
        'git',
        'https://github.com/victorsdd01/vgv_cli.git'
      ], runInShell: true);

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
        print('${AnsiColors.brightGreen}${AnsiColors.bold}VGV CLI updated successfully${AnsiColors.reset}');
        print('');
        print('${AnsiColors.brightCyan}${AnsiColors.bold}What\'s new:${AnsiColors.reset}');
        print('${AnsiColors.dim}   - Latest features and improvements${AnsiColors.reset}');
        print('${AnsiColors.dim}   - Bug fixes and performance enhancements${AnsiColors.reset}');
        print('${AnsiColors.dim}   - Updated dependencies and templates${AnsiColors.reset}');
        print('');
        print('${AnsiColors.brightGreen}Ready to create Flutter projects${AnsiColors.reset}');
        print('');
      } else {
        print('${AnsiColors.brightRed}${AnsiColors.bold}Update failed${AnsiColors.reset}');
        print('${AnsiColors.red}${result.stderr}${AnsiColors.reset}');
        print('');
        print('${AnsiColors.brightYellow}Try: vgv -u${AnsiColors.reset}');
        print('');
      }
    } catch (e) {
      print('${AnsiColors.brightRed}${AnsiColors.bold}Update failed:${AnsiColors.reset} ${AnsiColors.red}$e${AnsiColors.reset}');
      print('');
      print('${AnsiColors.brightYellow}Try: vgv -u${AnsiColors.reset}');
      print('');
    }
  }

  Future<void> _printVersion() async {
    print('');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}╔══════════════════════════════════════════════════════════════╗${AnsiColors.reset}');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}║${AnsiColors.reset}${AnsiColors.brightMagenta}${AnsiColors.bold}                           VGV CLI                            ${AnsiColors.reset}${AnsiColors.brightCyan}${AnsiColors.bold}║${AnsiColors.reset}');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}║${AnsiColors.reset}${AnsiColors.dim}           The Ultimate Flutter Project Generator           ${AnsiColors.reset}${AnsiColors.brightCyan}${AnsiColors.bold}║${AnsiColors.reset}');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}╚══════════════════════════════════════════════════════════════╝${AnsiColors.reset}');
    print('');

    final currentVersion = VersionChecker.getCurrentVersion();
    print('${AnsiColors.brightGreen}${AnsiColors.bold}Version:${AnsiColors.reset}     ${AnsiColors.brightYellow}$currentVersion${AnsiColors.reset}');

    try {
      final latestVersion = await VersionChecker.getLatestCLIVersionAny();

      if (latestVersion != null) {
        final comparison = VersionChecker.compareVersions(currentVersion, latestVersion);
        if (comparison < 0) {
          print('${AnsiColors.brightYellow}${AnsiColors.bold}Latest:${AnsiColors.reset}      ${AnsiColors.brightYellow}$latestVersion${AnsiColors.reset} ${AnsiColors.brightYellow}(update available)${AnsiColors.reset}');
          print('');
          print('${AnsiColors.dim}Run: vgv -u to update${AnsiColors.reset}');
        } else if (comparison == 0) {
          print('${AnsiColors.brightGreen}${AnsiColors.bold}Status:${AnsiColors.reset}      ${AnsiColors.brightGreen}Up to date${AnsiColors.reset}');
        } else {
          print('${AnsiColors.brightYellow}${AnsiColors.bold}Status:${AnsiColors.reset}      ${AnsiColors.brightYellow}Development version${AnsiColors.reset}');
          print('${AnsiColors.dim}Latest stable: $latestVersion${AnsiColors.reset}');
        }
      } else {
        print('${AnsiColors.dim}Status:      Could not check for updates${AnsiColors.reset}');
      }
    } catch (e) {
      // Version check failure is not critical
    }

    print('');
    print('${AnsiColors.brightGreen}${AnsiColors.bold}Description:${AnsiColors.reset} ${AnsiColors.dim}$_description${AnsiColors.reset}');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}Repository:${AnsiColors.reset}  ${AnsiColors.dim}https://github.com/victorsdd01/vgv_cli${AnsiColors.reset}');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}Update:${AnsiColors.reset}      ${AnsiColors.dim}vgv -u | vgv --update${AnsiColors.reset}');
    print('');
  }

  void _printUsage() {
    print('');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}╔══════════════════════════════════════════════════════════════╗${AnsiColors.reset}');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}║${AnsiColors.reset}${AnsiColors.bold}                            VGV CLI                           ${AnsiColors.reset}${AnsiColors.brightCyan}${AnsiColors.bold}║${AnsiColors.reset}');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}╚══════════════════════════════════════════════════════════════╝${AnsiColors.reset}');
    print('');
    print('${AnsiColors.brightGreen}${AnsiColors.bold}Description:${AnsiColors.reset} ${AnsiColors.dim}$_description${AnsiColors.reset}');
    print('');
    print('${AnsiColors.brightGreen}${AnsiColors.bold}Usage:${AnsiColors.reset}');
    print('  ${AnsiColors.brightYellow}$_appName${AnsiColors.reset}                    ${AnsiColors.dim}Start interactive mode${AnsiColors.reset}');
    print('  ${AnsiColors.brightYellow}$_appName${AnsiColors.reset} ${AnsiColors.brightCyan}-q${AnsiColors.reset}                 ${AnsiColors.dim}Quick mode with defaults${AnsiColors.reset}');
    print('  ${AnsiColors.brightYellow}$_appName${AnsiColors.reset} ${AnsiColors.brightCyan}-n${AnsiColors.reset} <name>          ${AnsiColors.dim}Create project with name${AnsiColors.reset}');
    print('  ${AnsiColors.brightYellow}$_appName${AnsiColors.reset} ${AnsiColors.brightCyan}-n${AnsiColors.reset} <name> ${AnsiColors.brightCyan}--org${AnsiColors.reset} <org> ${AnsiColors.dim}With organization${AnsiColors.reset}');
    print('');
    print('${AnsiColors.brightGreen}${AnsiColors.bold}Flags:${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}-h, --help${AnsiColors.reset}                   ${AnsiColors.dim}Show this help message${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}-v, --version${AnsiColors.reset}                ${AnsiColors.dim}Show version information${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}-u, --update${AnsiColors.reset}                 ${AnsiColors.dim}Update to latest version${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}-q, --quick${AnsiColors.reset}                  ${AnsiColors.dim}Quick mode with defaults${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}-n, --name${AnsiColors.reset} <name>            ${AnsiColors.dim}Project name${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}    --org${AnsiColors.reset} <org>              ${AnsiColors.dim}Organization (com.example)${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}-o, --output${AnsiColors.reset} <dir>           ${AnsiColors.dim}Output directory${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}    --no-git${AnsiColors.reset}                 ${AnsiColors.dim}Skip git initialization${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}    --dry-run${AnsiColors.reset}                ${AnsiColors.dim}Preview without creating${AnsiColors.reset}');
    print('');
    print('${AnsiColors.brightGreen}${AnsiColors.bold}Examples:${AnsiColors.reset}');
    print('  ${AnsiColors.dim}$_appName${AnsiColors.reset}');
    print('  ${AnsiColors.dim}$_appName -q -n my_app${AnsiColors.reset}');
    print('  ${AnsiColors.dim}$_appName -n my_app --org com.mycompany${AnsiColors.reset}');
    print('  ${AnsiColors.dim}$_appName -n my_app -o ~/projects --no-git${AnsiColors.reset}');
    print('  ${AnsiColors.dim}$_appName --dry-run -n test_app${AnsiColors.reset}');
    print('');
    print('${AnsiColors.brightGreen}${AnsiColors.bold}Features:${AnsiColors.reset}');
    print('  ${AnsiColors.dim}- Clean Architecture with BLoC + Freezed${AnsiColors.reset}');
    print('  ${AnsiColors.dim}- Multi-platform support (iOS, Android, Web, Desktop)${AnsiColors.reset}');
    print('  ${AnsiColors.dim}- Environment configs (dev, staging, production)${AnsiColors.reset}');
    print('  ${AnsiColors.dim}- Internationalization (en, es)${AnsiColors.reset}');
    print('  ${AnsiColors.dim}- GoRouter navigation${AnsiColors.reset}');
    print('  ${AnsiColors.dim}- VS Code debug configurations${AnsiColors.reset}');
    print('');
    print('${AnsiColors.brightCyan}${AnsiColors.bold}Repository:${AnsiColors.reset} ${AnsiColors.dim}https://github.com/victorsdd01/vgv_cli${AnsiColors.reset}');
    print('');
  }
}
