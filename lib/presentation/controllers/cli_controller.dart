import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import '../../domain/entities/project_config.dart';
import '../../domain/repositories/project_repository.dart';

class CliController {
  final ProjectRepository _projectRepository;
  final Logger _logger;

  CliController(this._projectRepository, {Logger? logger})
      : _logger = logger ?? Logger();

  Future<void> runInteractiveMode({
    String? organization,
    String? outputDir,
    bool noGit = false,
    List<Flavor>? flavors,
  }) async {
    _printWelcomeMessage();

    final projectName = _getProjectName();
    final org = _getOrganization(projectName, organization);
    final platforms = _getPlatforms();
    // If flavors were passed via --flavors, honor them and skip the prompt.
    final selectedFlavors = flavors ?? _getFlavors();
    final includeFastlane = _getFastlaneChoice(platforms);
    final includeLefthook = _getLefthookChoice();
    final seedColorHex = _getSeedColor();
    final iconMasterPath = _getIconMaster();
    final includeSplash = _getSplashChoice();
    final desktopWindow = _getDesktopWindowChoice(platforms);
    final aiAgents = _getAiAgents();
    final includeLinterRules = _getLinterRulesChoice();

    final config = ProjectConfig(
      projectName: projectName,
      organizationName: org,
      platforms: platforms,
      stateManagement: StateManagementType.bloc,
      architecture: ArchitectureType.cleanArchitecture,
      includeGoRouter: true,
      includeLinterRules: includeLinterRules,
      includeFreezed: true,
      mobilePlatform: _selectedMobilePlatform,
      desktopPlatform: _selectedDesktopPlatforms != null
          ? DesktopPlatform.custom
          : DesktopPlatform.all,
      customDesktopPlatforms: _selectedDesktopPlatforms,
      outputDirectory: outputDir,
      skipGitInit: noGit,
      flavors: selectedFlavors,
      includeFastlane: includeFastlane,
      includeLefthook: includeLefthook,
      seedColorHex: seedColorHex,
      iconMasterPath: iconMasterPath,
      includeSplash: includeSplash,
      desktopWindow: desktopWindow,
      aiAgents: aiAgents,
    );

    _printConfigurationSummary(config);

    if (_confirmConfiguration()) {
      await _createProject(config);
    } else {
      _printCancelledMessage();
    }
  }

  Future<void> runWithFlags({
    String? projectName,
    String? organization,
    String? outputDir,
    bool noGit = false,
    bool quickMode = false,
    List<Flavor>? flavors,
  }) async {
    _printWelcomeMessage();

    // Get or validate project name
    String finalProjectName;
    if (projectName != null && projectName.isNotEmpty) {
      if (!ProjectConfig.isValidProjectName(projectName)) {
        _logger.err('Invalid project name: $projectName');
        _logger.detail('Must be lowercase with underscores only.');
        return;
      }
      finalProjectName = projectName;
    } else if (quickMode) {
      // In quick mode without name, ask for it
      finalProjectName = _getProjectName();
    } else {
      _logger.err('Project name is required.');
      _logger.detail('Use: vgv -n <name>');
      return;
    }

    // Get or use default organization based on project name
    String finalOrganization;
    if (organization != null && organization.isNotEmpty) {
      if (!ProjectConfig.isValidOrganizationName(organization)) {
        _logger.err('Invalid organization: $organization');
        _logger.detail('Must be lowercase with dots (e.g., com.example)');
        return;
      }
      finalOrganization = organization;
    } else {
      finalOrganization = 'com.$finalProjectName';
    }

    // Default platforms for quick/flag mode
    final platforms = [PlatformType.mobile, PlatformType.web];
    _selectedMobilePlatform = MobilePlatform.both;
    _selectedDesktopPlatforms = null;

    final config = ProjectConfig(
      projectName: finalProjectName,
      organizationName: finalOrganization,
      platforms: platforms,
      stateManagement: StateManagementType.bloc,
      architecture: ArchitectureType.cleanArchitecture,
      includeGoRouter: true,
      includeLinterRules: false,
      includeFreezed: true,
      mobilePlatform: _selectedMobilePlatform,
      desktopPlatform: DesktopPlatform.all,
      customDesktopPlatforms: null,
      outputDirectory: outputDir,
      skipGitInit: noGit,
      flavors: flavors ?? const [Flavor.dev, Flavor.staging, Flavor.production],
    );

    _printConfigurationSummary(config);

    if (quickMode) {
      // In quick mode, proceed without confirmation
      await _createProject(config);
    } else if (_confirmConfiguration()) {
      await _createProject(config);
    } else {
      _printCancelledMessage();
    }
  }

  void _printWelcomeMessage() {
    String banner(String line) => styleBold.wrap(lightMagenta.wrap(line)!)!;
    _logger
      ..info('')
      ..info(banner('  ██╗   ██╗ ██████╗ ██╗   ██╗'))
      ..info(banner('  ██║   ██║██╔════╝ ██║   ██║'))
      ..info(banner('  ██║   ██║██║  ███╗██║   ██║'))
      ..info(banner('  ╚██╗ ██╔╝██║   ██║╚██╗ ██╔╝'))
      ..info(banner('   ╚████╔╝ ╚██████╔╝ ╚████╔╝ '))
      ..info(banner('    ╚═══╝   ╚═════╝   ╚═══╝  '))
      ..info('')
      ..info(styleDim.wrap('  The Ultimate Flutter Project Generator'))
      ..info('');
  }

  String _getProjectName() {
    while (true) {
      final name = _logger.prompt('${lightCyan.wrap('?')} Project name');

      if (name.isEmpty) {
        _logger.err('Project name cannot be empty.');
        continue;
      }

      if (!ProjectConfig.isValidProjectName(name)) {
        _logger.err('Project name must be lowercase with underscores only.');
        _logger.detail('Example: my_awesome_app, flutter_app, todo_list');
        continue;
      }

      return name;
    }
  }

  String _getOrganization(String projectName, [String? provided]) {
    // If --org was passed and is valid, use it as the default (the user can
    // still confirm or change it); otherwise fall back to com.<projectName>.
    final defaultOrg =
        (provided != null && ProjectConfig.isValidOrganizationName(provided))
            ? provided
            : 'com.$projectName';

    while (true) {
      final org = _logger.prompt(
        '${lightCyan.wrap('?')} Organization',
        defaultValue: defaultOrg,
      );

      if (org.isEmpty) {
        return defaultOrg;
      }

      if (!ProjectConfig.isValidOrganizationName(org)) {
        _logger.err('Organization must be lowercase with dots, min 2 chars.');
        _logger.detail('Example: com.example, dev.mycompany');
        continue;
      }

      return org;
    }
  }

  // Store custom selections for use in config
  MobilePlatform _selectedMobilePlatform = MobilePlatform.both;
  CustomDesktopPlatforms? _selectedDesktopPlatforms;

  /// Single-choice selector with arrow keys, drawn with **relative** cursor
  /// movement (works in macOS Terminal.app, unlike mason_logger's chooseOne
  /// which relies on save/restore cursor and stacks). Falls back to a numbered
  /// prompt when there's no TTY. Returns the chosen index.
  int _selectOne(String message, List<String> options, {int initialIndex = 0}) {
    if (!stdin.hasTerminal) {
      _logger.info(message);
      for (var i = 0; i < options.length; i++) {
        _logger.info('  ${i + 1}) ${options[i]}');
      }
      final answer =
          _logger.prompt('  #:', defaultValue: '${initialIndex + 1}').trim();
      final n = int.tryParse(answer);
      return (n != null && n >= 1 && n <= options.length)
          ? n - 1
          : initialIndex;
    }

    var index = initialIndex;
    final count = options.length;

    void draw(bool first) {
      if (!first) stdout.write('\x1B[${count + 1}A'); // up to the message line
      stdout.write('\x1B[0J'); // clear from here to end of screen
      stdout.writeln(message);
      for (var i = 0; i < count; i++) {
        final selected = i == index;
        final pointer = selected ? green.wrap('❯')! : ' ';
        final box = selected ? lightCyan.wrap('◉')! : '◯';
        final label =
            selected ? lightCyan.wrap(options[i])! : options[i];
        stdout.writeln('$pointer $box  $label');
      }
    }

    stdout.write('\x1B[?25l'); // hide cursor
    stdin
      ..echoMode = false
      ..lineMode = false;
    draw(true);
    try {
      var done = false;
      while (!done) {
        final b = stdin.readByteSync();
        if (b == -1) break;
        if (b == 0x1b) {
          // Escape sequence: ESC [ A|B for arrow up/down.
          if (stdin.readByteSync() == 0x5b) {
            final c = stdin.readByteSync();
            if (c == 0x41) {
              index = (index - 1 + count) % count;
            } else if (c == 0x42) {
              index = (index + 1) % count;
            }
          }
          draw(false);
        } else if (b == 0x0a || b == 0x0d) {
          // Enter → collapse the list to a single summary line.
          stdout
            ..write('\x1B[${count + 1}A')
            ..write('\x1B[0J')
            ..writeln('$message ${styleDim.wrap(lightCyan.wrap(options[index])!)!}');
          done = true;
        } else if (b == 0x6b) {
          index = (index - 1 + count) % count;
          draw(false);
        } else if (b == 0x6a) {
          index = (index + 1) % count;
          draw(false);
        }
      }
    } finally {
      stdin
        ..lineMode = true
        ..echoMode = true;
      stdout.write('\x1B[?25h'); // show cursor
    }
    return index;
  }

  List<PlatformType> _getPlatforms() {
    const platformOptions = [
      'Mobile Only (Android & iOS)',
      'Web Only',
      'Desktop Only (Windows, macOS, Linux)',
      'Mobile + Web',
      'Mobile + Desktop',
      'Web + Desktop',
      'All Platforms',
      'Custom Selection',
    ];

    final selection = _selectOne(
      '${lightCyan.wrap('?')} Select platforms',
      platformOptions,
    );

    // Reset custom selections
    _selectedMobilePlatform = MobilePlatform.both;
    _selectedDesktopPlatforms = null;

    switch (selection) {
      case 0:
        return [PlatformType.mobile];
      case 1:
        return [PlatformType.web];
      case 2:
        return [PlatformType.desktop];
      case 3:
        return [PlatformType.mobile, PlatformType.web];
      case 4:
        return [PlatformType.mobile, PlatformType.desktop];
      case 5:
        return [PlatformType.web, PlatformType.desktop];
      case 6:
        return [PlatformType.mobile, PlatformType.web, PlatformType.desktop];
      case 7:
        return _getCustomPlatformSelection();
      default:
        return [PlatformType.mobile];
    }
  }

  List<PlatformType> _getCustomPlatformSelection() {
    const android = 'Android';
    const ios = 'iOS';
    const web = 'Web';
    const windows = 'Windows';
    const macos = 'macOS';
    const linux = 'Linux';
    const platformOptions = [android, ios, web, windows, macos, linux];

    final selections = _logger.chooseAny(
      '${lightCyan.wrap('?')} Select platforms '
      '${styleDim.wrap('(space to toggle, enter to confirm)')}',
      choices: platformOptions,
      defaultValues: const [android, ios],
    );

    final platforms = <PlatformType>[];

    // Track specific mobile platforms
    final hasAndroid = selections.contains(android);
    final hasIOS = selections.contains(ios);

    if (hasAndroid || hasIOS) {
      platforms.add(PlatformType.mobile);
      if (hasAndroid && hasIOS) {
        _selectedMobilePlatform = MobilePlatform.both;
      } else if (hasAndroid) {
        _selectedMobilePlatform = MobilePlatform.android;
      } else {
        _selectedMobilePlatform = MobilePlatform.ios;
      }
    }

    // Track web
    if (selections.contains(web)) {
      platforms.add(PlatformType.web);
    }

    // Track specific desktop platforms
    final hasWindows = selections.contains(windows);
    final hasMacOS = selections.contains(macos);
    final hasLinux = selections.contains(linux);

    if (hasWindows || hasMacOS || hasLinux) {
      platforms.add(PlatformType.desktop);
      _selectedDesktopPlatforms = CustomDesktopPlatforms(
        windows: hasWindows,
        macos: hasMacOS,
        linux: hasLinux,
      );
    }

    if (platforms.isEmpty) {
      _logger.warn('No platforms selected. Defaulting to Mobile.');
      platforms.add(PlatformType.mobile);
      _selectedMobilePlatform = MobilePlatform.both;
    }

    return platforms;
  }

  List<Flavor> _getFlavors() {
    final selected = _logger.chooseAny<Flavor>(
      '${lightCyan.wrap('?')} Which flavors do you want to generate? '
      '${styleDim.wrap('(space to toggle, enter to confirm)')}',
      choices: Flavor.values,
      defaultValues: Flavor.values,
      display: (flavor) => flavor.displayName,
    );

    if (selected.isEmpty) {
      _logger.warn(
        'No flavors selected. Defaulting to all (dev, staging, production).',
      );
      return const [Flavor.dev, Flavor.staging, Flavor.production];
    }

    // Preserve canonical order (dev, staging, production).
    return Flavor.values.where(selected.contains).toList();
  }

  bool _getLinterRulesChoice() {
    return _logger.confirm(
      '${lightCyan.wrap('?')} Include custom linter rules?',
      defaultValue: false,
    );
  }

  /// Only offered for mobile projects (Fastlane targets Play Store / App Store).
  bool _getFastlaneChoice(List<PlatformType> platforms) {
    if (!platforms.contains(PlatformType.mobile)) return false;
    return _logger.confirm(
      '${lightCyan.wrap('?')} Configure Fastlane (Play Store / App Store deploy)?',
      defaultValue: false,
    );
  }

  /// Asks for an optional brand (seed) color for the Material 3 theme.
  /// Returns a 6-digit hex (no #) or null to keep the default.
  String? _getSeedColor() {
    final useCustom = _logger.confirm(
      '${lightCyan.wrap('?')} Set a brand (seed) color for the theme?',
      defaultValue: false,
    );
    if (!useCustom) return null;
    final re = RegExp(r'^[0-9A-Fa-f]{6}$');
    while (true) {
      final input = _logger
          .prompt('${lightCyan.wrap('?')} Brand color hex (e.g. 4B60AA):',
              defaultValue: '2196F3')
          .replaceAll('#', '')
          .trim();
      if (re.hasMatch(input)) return input.toUpperCase();
      _logger.err('  Enter a 6-digit hex like 4B60AA.');
    }
  }

  /// Asks for an optional 1024×1024 master app icon. Returns an absolute path
  /// (resolved now, before the CWD changes) or null.
  String? _getIconMaster() {
    final useIcon = _logger.confirm(
      '${lightCyan.wrap('?')} Generate app icons from a 1024×1024 master image?',
      defaultValue: false,
    );
    if (!useIcon) return null;
    while (true) {
      final input = _logger
          .prompt('${lightCyan.wrap('?')} Path to the master icon (.png):')
          .trim();
      if (input.isEmpty) return null;
      final file = File(input);
      if (file.existsSync()) return file.absolute.path;
      _logger.err('  File not found: $input');
    }
  }

  /// Asks whether to configure a native splash screen.
  bool _getSplashChoice() {
    return _logger.confirm(
      '${lightCyan.wrap('?')} Configure a native splash screen (flutter_native_splash)?',
      defaultValue: false,
    );
  }

  /// Asks whether to set a desktop window min-size + title (desktop only).
  bool _getDesktopWindowChoice(List<PlatformType> platforms) {
    if (!platforms.contains(PlatformType.desktop)) return false;
    return _logger.confirm(
      '${lightCyan.wrap('?')} Set a desktop window min-size + title (window_manager)?',
      defaultValue: true,
    );
  }

  /// Asks whether to scaffold lefthook git hooks (format/analyze on commit,
  /// tests on push). Platform-agnostic.
  bool _getLefthookChoice() {
    return _logger.confirm(
      '${lightCyan.wrap('?')} Add lefthook git hooks (format/analyze on commit, tests on push)?',
      defaultValue: false,
    );
  }

  /// Asks whether the user works with an AI agent and, if so, which ones to
  /// generate a project-conventions rules file for.
  List<AiAgent> _getAiAgents() {
    final usesAgent = _logger.confirm(
      '${lightCyan.wrap('?')} Do you use an AI coding agent (Claude, Cursor, Gemini…)?',
      defaultValue: false,
    );
    if (!usesAgent) return const [];

    final selected = _logger.chooseAny<AiAgent>(
      '${lightCyan.wrap('?')} Generate a project-rules file for which agents? '
      '${styleDim.wrap('(space to toggle, enter to confirm)')}',
      choices: AiAgent.values,
      defaultValues: const [AiAgent.claude],
      display: (agent) => agent.displayName,
    );
    return AiAgent.values.where(selected.contains).toList();
  }

  void _printConfigurationSummary(ProjectConfig config) {
    String label(String text) => styleDim.wrap(text)!;
    String value(String text) => lightGreen.wrap(text)!;

    _logger
      ..info('')
      ..info(styleBold.wrap(cyan.wrap('  Configuration Summary')))
      ..info(styleDim.wrap('  ─────────────────────────────────────────'))
      ..info('')
      ..info('  ${label('Project:')}       ${value(config.projectName)}')
      ..info('  ${label('Organization:')}  ${value(config.organizationName)}')
      ..info('  ${label('Platforms:')}     ${value(_formatPlatforms(config.platforms))}')
      ..info('  ${label('State:')}         ${value('BLoC')}')
      ..info('  ${label('Navigation:')}    ${value('Go Router')}')
      ..info('  ${label('Architecture:')}  ${value('Clean Architecture')}')
      ..info('  ${label('Code Gen:')}      ${value('Freezed')}')
      ..info('  ${label('Flavors:')}       ${value(config.flavors.map((f) => f.displayName).join(', '))}');
    if (config.includeLinterRules) {
      _logger.info('  ${label('Linter:')}        ${value('Custom Rules')}');
    }
    if (config.includeFastlane) {
      _logger.info('  ${label('Fastlane:')}      ${value('Play Store / App Store')}');
    }
    if (config.includeLefthook) {
      _logger.info('  ${label('Lefthook:')}      ${value('pre-commit / pre-push hooks')}');
    }
    if (config.seedColorHex != null) {
      _logger.info('  ${label('Brand color:')}   ${value('#${config.seedColorHex}')}');
    }
    if (config.iconMasterPath != null) {
      _logger.info('  ${label('App icons:')}     ${value('from master image')}');
    }
    if (config.includeSplash) {
      _logger.info('  ${label('Splash:')}        ${value('native splash screen')}');
    }
    if (config.desktopWindow) {
      _logger.info('  ${label('Desktop:')}       ${value('window min-size + title')}');
    }
    if (config.aiAgents.isNotEmpty) {
      _logger.info('  ${label('AI rules:')}      ${value(config.aiAgents.map((a) => a.name).join(', '))}');
    }

    // Bundle ID preview: the entered id is production; others derive a suffix.
    final baseId = config.baseBundleId;
    _logger
      ..info('')
      ..info('  ${label('Bundle IDs')}');
    for (final flavor in config.flavors) {
      final name = flavor.displayName.padRight(12);
      _logger.info('    ${styleDim.wrap(name)} ${value(flavor.bundleId(baseId))}');
    }
    _logger.info('');
  }

  String _formatPlatforms(List<PlatformType> platforms) {
    final names = <String>[];

    for (final p in platforms) {
      switch (p) {
        case PlatformType.mobile:
          if (_selectedMobilePlatform == MobilePlatform.both) {
            names.add('Android, iOS');
          } else if (_selectedMobilePlatform == MobilePlatform.android) {
            names.add('Android');
          } else {
            names.add('iOS');
          }
        case PlatformType.web:
          names.add('Web');
        case PlatformType.desktop:
          if (_selectedDesktopPlatforms != null) {
            final desktopNames = <String>[];
            if (_selectedDesktopPlatforms!.windows) desktopNames.add('Windows');
            if (_selectedDesktopPlatforms!.macos) desktopNames.add('macOS');
            if (_selectedDesktopPlatforms!.linux) desktopNames.add('Linux');
            names.add(desktopNames.join(', '));
          } else {
            names.add('Windows, macOS, Linux');
          }
      }
    }

    return names.join(', ');
  }

  bool _confirmConfiguration() {
    return _logger.confirm(
      '${lightCyan.wrap('?')} Create project with this configuration?',
      defaultValue: true,
    );
  }

  Future<void> _createProject(ProjectConfig config) async {
    _logger.info('');

    if (!await _projectRepository.isFlutterInstalled()) {
      _logger
        ..err('Flutter is not installed or not on your PATH.')
        ..detail('Install Flutter, verify with `flutter doctor`, then retry.');
      return;
    }

    final progress = _logger.progress('Creating Flutter project...');

    try {
      final warnings = await _projectRepository.createProject(config);
      progress.complete(
        warnings.isEmpty
            ? 'Project created successfully'
            : 'Project created with ${warnings.length} warning(s)',
      );

      final firstFlavor = config.flavors.first;
      final native = config.usesNativeFlavors;
      String runCmd(Flavor f) => native
          ? 'flutter run --flavor ${f.flavorName} -t lib/main_${f.entryPoint}.dart'
          : 'flutter run -t lib/main_${f.entryPoint}.dart';
      _logger
        ..info('')
        ..info(styleBold.wrap(green.wrap('  Done!')))
        ..info('')
        ..info(styleDim.wrap('  Next steps:'))
        ..info('    cd ${config.projectName}')
        ..info('    ${runCmd(firstFlavor)}')
        ..info('')
        ..info(styleDim.wrap('  Run flavors:'));
      for (final flavor in config.flavors) {
        _logger.info(
          '    ${runCmd(flavor)}  ${styleDim.wrap('# ${flavor.displayName}')}',
        );
      }
      _logger.info('');

      if (config.includeFastlane) {
        await _reportFastlaneTooling(config.projectName);
      }

      if (config.includeLefthook) {
        await _reportLefthookTooling();
      }

      if (warnings.isNotEmpty) {
        _logger.warn('Some post-generation steps need your attention:');
        for (final warning in warnings) {
          _logger.info('    - $warning');
        }
        _logger.info(styleDim.wrap('  The project was created; finish these steps manually.'));
        _logger.info('');
      }
    } catch (e) {
      progress.fail('Failed to create project');
      _logger
        ..err('  Error creating project:')
        ..err('  $e')
        ..info('')
        ..info(styleDim.wrap('  Troubleshooting:'))
        ..info('    - Check your Flutter installation')
        ..info('    - Ensure you have write permissions')
        ..info('    - Try running: flutter doctor')
        ..info('');
    }
  }

  /// Detects lefthook and prints how to enable the hooks.
  Future<void> _reportLefthookTooling() async {
    var installed = false;
    try {
      final result = await Process.run('which', ['lefthook'], runInShell: true);
      installed = result.exitCode == 0;
    } catch (_) {
      installed = false;
    }

    _logger.info(styleDim.wrap('  Lefthook (git hooks — see lefthook.yml):'));
    if (installed) {
      _logger
        ..info('    ${green.wrap('✓')} lefthook installed — enable it from the project root:')
        ..info('      ${lightCyan.wrap('lefthook install')}');
    } else {
      _logger
        ..info('    ${yellow.wrap('•')} lefthook not found. Install then enable:')
        ..info('      ${lightCyan.wrap('brew install lefthook')}  ${styleDim.wrap('# or: dart pub global activate lefthook')}')
        ..info('      ${lightCyan.wrap('lefthook install')}');
    }
    _logger.info('');
  }

  /// Detects the Fastlane toolchain and prints a concise status + next steps.
  Future<void> _reportFastlaneTooling(String projectName) async {
    Future<bool> has(String cmd) async {
      try {
        final result = await Process.run('which', [cmd], runInShell: true);
        return result.exitCode == 0;
      } catch (_) {
        return false;
      }
    }

    final ruby = await has('ruby');
    final bundler = await has('bundle');
    final brew = await has('brew');
    String mark(bool ok) => ok ? green.wrap('✓')! : yellow.wrap('•')!;

    _logger
      ..info(styleDim.wrap('  Fastlane (see fastlane-config.md for full setup):'))
      ..info('    ${mark(ruby)} ruby${ruby ? '' : '     ${styleDim.wrap('(macOS ships Ruby; otherwise brew install ruby)')}'}')
      ..info('    ${mark(bundler)} bundler${bundler ? '' : '  ${styleDim.wrap('(gem install bundler)')}'}');

    if (!ruby && !brew) {
      _logger.info(
        '    ${yellow.wrap('!')} No Ruby or Homebrew found — install Homebrew, then `brew install ruby` '
        '${styleDim.wrap('(needs your admin password; the CLI won\'t do it for you)')}',
      );
    }

    _logger
      ..info('')
      ..info('    ${styleDim.wrap('Then:')} cd $projectName && ${lightCyan.wrap('bundle install')}')
      ..info('    ${styleDim.wrap('Deploy:')} cd android && ${lightCyan.wrap('bundle exec fastlane deploy_dev')}')
      ..info('');
  }

  void _printCancelledMessage() {
    _logger
      ..info('')
      ..warn('Project creation cancelled.')
      ..info(styleDim.wrap('  Run vgv again when ready.'))
      ..info('');
  }
}
