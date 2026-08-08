// ignore_for_file: unnecessary_brace_in_string_interps

import 'dart:io';
import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'core/di/dependency_injection.dart';
import 'core/utils/ansi_colors.dart';
import 'core/utils/doctor_runner.dart';
import 'core/utils/gen_runner.dart';
import 'core/utils/screenshot_runner.dart';
import 'core/utils/version_checker.dart';
import 'core/utils/vgv_config.dart';
import 'domain/entities/project_config.dart';
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
      ..addOption(
        'flavors',
        help: 'Comma-separated flavors to generate: dev,staging,prod (default: all)',
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

  Future<void> run(List<String> arguments) async {
    // Subcommands (positional) are handled before flag parsing.
    if (arguments.isNotEmpty && arguments.first == 'screenshots') {
      final code = await ScreenshotRunner().run(arguments.sublist(1));
      exit(code);
    }
    if (arguments.isNotEmpty && arguments.first == 'gen') {
      final code = await GenRunner().run(arguments.sublist(1));
      exit(code);
    }
    if (arguments.isNotEmpty && arguments.first == 'config') {
      exit(_runConfig(arguments.sublist(1)));
    }
    if ((arguments.isNotEmpty && arguments.first == 'doctor') ||
        arguments.contains('--doctor')) {
      exit(await DoctorRunner().run());
    }

    try {
      _argResults = _argParser.parse(arguments);

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

      // Presets (vgv.yaml / ~/.vgvrc) fill in anything not passed as a flag.
      final config = VgvConfig.load();

      // Handle quick mode or flags
      final projectName = _argResults['name'] as String?;
      final organization = (_argResults['org'] as String?) ?? config.organization;
      final outputDir = (_argResults['output'] as String?) ?? config.output;
      var noGit = _argResults['no-git'] as bool;
      if (!_argResults.wasParsed('no-git') && config.git == false) {
        noGit = true;
      }
      final dryRun = _argResults['dry-run'] as bool;
      final quickMode = _argResults['quick'] as bool;
      final flavors =
          _parseFlavors(_argResults['flavors'] as String?) ?? config.flavors;

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
          flavors: flavors,
        );
        return;
      }

      // Run in interactive mode, honoring any flags the user did pass
      // (org / output / no-git / flavors) instead of silently ignoring them.
      await _runInteractiveMode(
        organization: organization,
        outputDir: outputDir,
        noGit: noGit,
        flavors: flavors,
      );
    } catch (e) {
      print('Error: $e');
      _printUsage();
      exit(1);
    }
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

  /// Parses `--flavors dev,staging,prod` into a canonical, de-duplicated list.
  /// Returns null when the flag is absent (callers then use the default set).
  /// Exits with code 1 on an unknown token.
  List<Flavor>? _parseFlavors(String? arg) {
    if (arg == null || arg.trim().isEmpty) return null;
    final selected = <Flavor>{};
    for (final token in arg.split(',')) {
      if (token.trim().isEmpty) continue;
      final flavor = Flavor.tryParse(token);
      if (flavor == null) {
        print('${AnsiColors.brightRed}${AnsiColors.bold}Error:${AnsiColors.reset} '
            'unknown flavor "${token.trim()}". Valid values: dev, staging, prod.');
        exit(1);
      }
      selected.add(flavor);
    }
    if (selected.isEmpty) return null;
    // Preserve canonical order (dev, staging, production).
    return Flavor.values.where(selected.contains).toList();
  }

  Future<void> _runInteractiveMode({
    String? organization,
    String? outputDir,
    bool noGit = false,
    List<Flavor>? flavors,
  }) async {
    await _cliController.runInteractiveMode(
      organization: organization,
      outputDir: outputDir,
      noGit: noGit,
      flavors: flavors,
    );
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
    List<Flavor>? flavors,
  }) async {
    await _cliController.runWithFlags(
      projectName: projectName,
      organization: organization,
      outputDir: outputDir,
      noGit: noGit,
      quickMode: quickMode,
      flavors: flavors,
    );
  }

  Future<void> _updateCLI() async {
    final logger = Logger();

    logger
      ..info('')
      ..info(styleBold.wrap(lightCyan.wrap('  ⬆  VGV UPDATE')))
      ..info('');

    final currentVersion = _version;
    final latestVersion = await VersionChecker.getLatestCLIVersionAny();

    logger.info('  ${styleDim.wrap('Current')}   ${lightYellow.wrap(currentVersion)}');
    if (latestVersion != null) {
      logger.info('  ${styleDim.wrap('Latest ')}   ${lightYellow.wrap(latestVersion)}');
      if (latestVersion == currentVersion) {
        logger
          ..info('')
          ..info(green.wrap('  ✓ You already have the latest version'))
          ..info('');
        return;
      }
    } else {
      logger.warn('Could not check the latest version; updating from main…');
    }
    logger.info('');

    // Real, honest progress: an animated spinner that runs while the async
    // install is in flight and resolves to ✓/✗ based on the actual result.
    final target = latestVersion != null ? 'v$latestVersion' : 'the latest version';
    final progress = logger.progress('Downloading and installing $target');

    try {
      final result = await Process.run(
        'dart',
        <String>[
          'pub',
          'global',
          'activate',
          '--source',
          'git',
          'https://github.com/victorsdd01/vgv_cli.git',
        ],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        progress.complete('Updated to $target');
        logger
          ..info('')
          ..info(styleBold.wrap(lightGreen.wrap('  🎉 VGV CLI updated successfully')))
          ..info(styleDim.wrap('  Verify with `vgv -v`, then run `vgv` to create a project.'))
          ..info('');
      } else {
        progress.fail('Update failed');
        logger
          ..err('  ${result.stderr}')
          ..info(styleDim.wrap('  Retry with: vgv -u'))
          ..info('');
      }
    } catch (e) {
      progress.fail('Update failed');
      logger
        ..err('  $e')
        ..info(styleDim.wrap('  Retry with: vgv -u'))
        ..info('');
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

  /// Handles `vgv config <init|show>`.
  int _runConfig(List<String> args) {
    final sub = args.isNotEmpty ? args.first : 'show';
    switch (sub) {
      case 'init':
        final global = args.contains('--global') || args.contains('-g');
        final force = args.contains('--force') || args.contains('-f');
        final target = global ? VgvConfig.globalPath : VgvConfig.projectPath;
        if (File(target).existsSync() && !force) {
          print('${AnsiColors.brightYellow}Config already exists:${AnsiColors.reset} $target');
          print('${AnsiColors.dim}   Use --force to overwrite.${AnsiColors.reset}');
          return 0;
        }
        VgvConfig.writeTemplate(global: global, force: force);
        print('${AnsiColors.brightGreen}✓ Wrote presets:${AnsiColors.reset} $target');
        print('${AnsiColors.dim}   Edit it, then just run: vgv${AnsiColors.reset}');
        return 0;
      case 'show':
        final c = VgvConfig.load();
        print('');
        print('${AnsiColors.brightGreen}${AnsiColors.bold}Effective presets${AnsiColors.reset} ${AnsiColors.dim}(vgv.yaml over ~/.vgvrc):${AnsiColors.reset}');
        print('  org:     ${c.organization ?? '${AnsiColors.dim}(unset)${AnsiColors.reset}'}');
        print('  output:  ${c.output ?? '${AnsiColors.dim}(unset)${AnsiColors.reset}'}');
        print('  flavors: ${c.flavors?.map((f) => f.flavorName).join(', ') ?? '${AnsiColors.dim}(default: all)${AnsiColors.reset}'}');
        print('  git:     ${c.git ?? '${AnsiColors.dim}(default: true)${AnsiColors.reset}'}');
        print('');
        return 0;
      default:
        print('${AnsiColors.brightRed}Unknown:${AnsiColors.reset} config $sub');
        print('${AnsiColors.dim}   Usage: vgv config init [--global] [--force] | vgv config show${AnsiColors.reset}');
        return 1;
    }
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
    print('${AnsiColors.brightGreen}${AnsiColors.bold}Commands:${AnsiColors.reset}');
    print('  ${AnsiColors.brightYellow}$_appName${AnsiColors.reset} ${AnsiColors.brightCyan}gen feature${AnsiColors.reset} <name>  ${AnsiColors.dim}Scaffold a Clean Architecture feature${AnsiColors.reset}');
    print('  ${AnsiColors.brightYellow}$_appName${AnsiColors.reset} ${AnsiColors.brightCyan}screenshots --init${AnsiColors.reset}   ${AnsiColors.dim}Scaffold a store-screenshots manifest${AnsiColors.reset}');
    print('  ${AnsiColors.brightYellow}$_appName${AnsiColors.reset} ${AnsiColors.brightCyan}screenshots${AnsiColors.reset} <manifest> ${AnsiColors.dim}Render framed store screenshots${AnsiColors.reset}');
    print('  ${AnsiColors.brightYellow}$_appName${AnsiColors.reset} ${AnsiColors.brightCyan}config init${AnsiColors.reset}          ${AnsiColors.dim}Write a presets file (vgv.yaml / ~/.vgvrc)${AnsiColors.reset}');
    print('  ${AnsiColors.brightYellow}$_appName${AnsiColors.reset} ${AnsiColors.brightCyan}doctor${AnsiColors.reset}               ${AnsiColors.dim}Check your environment (Flutter, Python, …)${AnsiColors.reset}');
    print('');
    print('${AnsiColors.brightGreen}${AnsiColors.bold}Flags:${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}-h, --help${AnsiColors.reset}                   ${AnsiColors.dim}Show this help message${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}-v, --version${AnsiColors.reset}                ${AnsiColors.dim}Show version information${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}-u, --update${AnsiColors.reset}                 ${AnsiColors.dim}Update to latest version${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}-q, --quick${AnsiColors.reset}                  ${AnsiColors.dim}Quick mode with defaults${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}-n, --name${AnsiColors.reset} <name>            ${AnsiColors.dim}Project name${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}    --org${AnsiColors.reset} <org>              ${AnsiColors.dim}Organization (com.example)${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}-o, --output${AnsiColors.reset} <dir>           ${AnsiColors.dim}Output directory${AnsiColors.reset}');
    print('  ${AnsiColors.brightCyan}    --flavors${AnsiColors.reset} <list>          ${AnsiColors.dim}Flavors: dev,staging,prod (default all)${AnsiColors.reset}');
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
