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
  }) async {
    _printWelcomeMessage();

    final projectName = _getProjectName();
    final org = _getOrganization(projectName, organization);
    final platforms = _getPlatforms();
    final flavors = _getFlavors();
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
      flavors: flavors,
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

    final selected = _logger.chooseOne(
      '${lightCyan.wrap('?')} Select platforms',
      choices: platformOptions,
      defaultValue: platformOptions.first,
    );
    final selection = platformOptions.indexOf(selected);

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

    // Bundle ID preview: the entered id is production; others derive a suffix.
    final baseId = '${config.organizationName}.${config.projectName}';
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

  void _printCancelledMessage() {
    _logger
      ..info('')
      ..warn('Project creation cancelled.')
      ..info(styleDim.wrap('  Run vgv again when ready.'))
      ..info('');
  }
}
