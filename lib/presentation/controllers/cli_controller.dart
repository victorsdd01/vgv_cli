import 'package:interact/interact.dart';
import '../../domain/entities/project_config.dart';
import '../../domain/repositories/project_repository.dart';

class CliController {
  final ProjectRepository _projectRepository;

  CliController(this._projectRepository);

  // ANSI Color Codes
  static const String _reset = '\x1B[0m';
  static const String _bold = '\x1B[1m';
  static const String _dim = '\x1B[2m';
  
  // Colors
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _cyan = '\x1B[36m';
  static const String _red = '\x1B[31m';
  static const String _brightGreen = '\x1B[92m';
  static const String _brightMagenta = '\x1B[95m';

  Future<void> runInteractiveMode() async {
    _printWelcomeMessage();
    
    final projectName = _getProjectName();
    final organization = _getOrganization(projectName);
    final platforms = _getPlatforms();
    final includeLinterRules = _getLinterRulesChoice();

    final config = ProjectConfig(
      projectName: projectName,
      organizationName: organization,
      platforms: platforms,
      stateManagement: StateManagementType.bloc,
      architecture: ArchitectureType.cleanArchitecture,
      includeGoRouter: true,
      includeLinterRules: includeLinterRules,
      includeFreezed: true,
      mobilePlatform: _selectedMobilePlatform,
      desktopPlatform: _selectedDesktopPlatforms != null ? DesktopPlatform.custom : DesktopPlatform.all,
      customDesktopPlatforms: _selectedDesktopPlatforms,
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
      if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(projectName)) {
        print('$_red  Invalid project name: $projectName$_reset');
        print('$_dim  Must be lowercase with underscores only.$_reset');
        return;
      }
      finalProjectName = projectName;
    } else if (quickMode) {
      // In quick mode without name, ask for it
      finalProjectName = _getProjectName();
    } else {
      print('$_red  Project name is required.$_reset');
      print('$_dim  Use: flutterforge -n <name>$_reset');
      return;
    }
    
    // Get or use default organization based on project name
    String finalOrganization;
    if (organization != null && organization.isNotEmpty) {
      if (!RegExp(r'^[a-z][a-z0-9._]*[a-z0-9]$').hasMatch(organization)) {
        print('$_red  Invalid organization: $organization$_reset');
        print('$_dim  Must be lowercase with dots (e.g., com.example)$_reset');
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
    print('');
    print('$_brightMagenta$_bold  ███████╗██╗     ██╗   ██╗████████╗████████╗███████╗██████╗ $_reset');
    print('$_brightMagenta$_bold  ██╔════╝██║     ██║   ██║╚══██╔══╝╚══██╔══╝██╔════╝██╔══██╗$_reset');
    print('$_brightMagenta$_bold  █████╗  ██║     ██║   ██║   ██║      ██║   █████╗  ██████╔╝$_reset');
    print('$_brightMagenta$_bold  ██╔══╝  ██║     ██║   ██║   ██║      ██║   ██╔══╝  ██╔══██╗$_reset');
    print('$_brightMagenta$_bold  ██║     ███████╗╚██████╔╝   ██║      ██║   ███████╗██║  ██║$_reset');
    print('$_brightMagenta$_bold  ╚═╝     ╚══════╝ ╚═════╝    ╚═╝      ╚═╝   ╚══════╝╚═╝  ╚═╝$_reset');
    print('$_brightMagenta$_bold  ███████╗ ██████╗ ██████╗  ███████╗███████╗$_reset');
    print('$_brightMagenta$_bold  ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝$_reset');
    print('$_brightMagenta$_bold  █████╗  ██║   ██║██████╔╝██║  ███╗█████╗  $_reset');
    print('$_brightMagenta$_bold  ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝  $_reset');
    print('$_brightMagenta$_bold  ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗$_reset');
    print('$_brightMagenta$_bold  ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝$_reset');
    print('');
    print('$_dim  The Ultimate Flutter Project Generator$_reset');
    print('');
  }

  String _getProjectName() {
    while (true) {
      final name = Input(
        prompt: 'Project name',
        defaultValue: '',
      ).interact();
      
      if (name.isEmpty) {
        print('$_red  Project name cannot be empty.$_reset');
        continue;
      }
      
      if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
        print('$_red  Project name must be lowercase with underscores only.$_reset');
        print('$_dim  Example: my_awesome_app, flutter_app, todo_list$_reset');
        continue;
      }
      
      return name;
    }
  }

  String _getOrganization(String projectName) {
    final defaultOrg = 'com.$projectName';
    
    while (true) {
      final org = Input(
        prompt: 'Organization',
        defaultValue: defaultOrg,
      ).interact();
      
      if (org.isEmpty) {
        return defaultOrg;
      }
      
      if (!RegExp(r'^[a-z][a-z0-9._]*[a-z0-9]$').hasMatch(org)) {
        print('$_red  Organization must be lowercase with dots, min 2 chars.$_reset');
        print('$_dim  Example: com.example, dev.mycompany$_reset');
        continue;
      }
      
      return org;
    }
  }

  // Store custom selections for use in config
  MobilePlatform _selectedMobilePlatform = MobilePlatform.both;
  CustomDesktopPlatforms? _selectedDesktopPlatforms;

  List<PlatformType> _getPlatforms() {
    print('');
    
    final platformOptions = [
      'Mobile Only (Android & iOS)',
      'Web Only',
      'Desktop Only (Windows, macOS, Linux)',
      'Mobile + Web',
      'Mobile + Desktop',
      'Web + Desktop',
      'All Platforms',
      'Custom Selection',
    ];

    final selection = Select(
      prompt: 'Select platforms',
      options: platformOptions,
      initialIndex: 0,
    ).interact();

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
    print('');
    
    final platformOptions = [
      'Android',
      'iOS',
      'Web',
      'Windows',
      'macOS',
      'Linux',
    ];

    final selections = MultiSelect(
      prompt: 'Select platforms (space to toggle, enter to confirm)',
      options: platformOptions,
      defaults: [true, true, false, false, false, false],
    ).interact();

    final platforms = <PlatformType>[];
    
    // Track specific mobile platforms
    final hasAndroid = selections.contains(0);
    final hasIOS = selections.contains(1);
    
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
    if (selections.contains(2)) {
      platforms.add(PlatformType.web);
    }
    
    // Track specific desktop platforms
    final hasWindows = selections.contains(3);
    final hasMacOS = selections.contains(4);
    final hasLinux = selections.contains(5);
    
    if (hasWindows || hasMacOS || hasLinux) {
      platforms.add(PlatformType.desktop);
      _selectedDesktopPlatforms = CustomDesktopPlatforms(
        windows: hasWindows,
        macos: hasMacOS,
        linux: hasLinux,
      );
    }
    
    if (platforms.isEmpty) {
      print('$_yellow  No platforms selected. Defaulting to Mobile.$_reset');
      platforms.add(PlatformType.mobile);
      _selectedMobilePlatform = MobilePlatform.both;
    }
    
    return platforms;
  }

  bool _getLinterRulesChoice() {
    print('');
    return Confirm(
      prompt: 'Include custom linter rules?',
      defaultValue: false,
    ).interact();
  }

  void _printConfigurationSummary(ProjectConfig config) {
    print('');
    print('$_cyan$_bold  Configuration Summary$_reset');
    print('$_dim  ─────────────────────────────────────────$_reset');
    print('');
    print('  $_dim Project:$_reset       $_brightGreen${config.projectName}$_reset');
    print('  $_dim Organization:$_reset  $_brightGreen${config.organizationName}$_reset');
    print('  $_dim Platforms:$_reset     $_brightGreen${_formatPlatforms(config.platforms)}$_reset');
    print('  $_dim State:$_reset         ${_brightGreen}BLoC$_reset');
    print('  $_dim Navigation:$_reset    ${_brightGreen}Go Router$_reset');
    print('  $_dim Architecture:$_reset  ${_brightGreen}Clean Architecture$_reset');
    print('  $_dim Code Gen:$_reset      ${_brightGreen}Freezed$_reset');
    print('  $_dim Environments:$_reset  ${_brightGreen}Dev, Staging, Production$_reset');
    if (config.includeLinterRules) {
      print('  $_dim Linter:$_reset        ${_brightGreen}Custom Rules$_reset');
    }
    print('');
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
    return Confirm(
      prompt: 'Create project with this configuration?',
      defaultValue: true,
    ).interact();
  }

  Future<void> _createProject(ProjectConfig config) async {
    print('');
    
    final spinner = Spinner(
      icon: '$_brightGreen[+]$_reset',
      leftPrompt: (done) => '',
      rightPrompt: (done) => done 
          ? '$_brightGreen Project created successfully$_reset'
          : '$_cyan Creating Flutter project...$_reset',
    ).interact();
    
    try {
      await _projectRepository.createProject(config);
      spinner.done();
      
      print('');
      print('$_green$_bold  Done!$_reset');
      print('');
      print('$_dim  Next steps:$_reset');
      print('    cd ${config.projectName}');
      print('    flutter run -t lib/main_dev.dart');
      print('');
      print('$_dim  Run environments:$_reset');
      print('    flutter run -t lib/main_dev.dart        $_dim# Development$_reset');
      print('    flutter run -t lib/main_staging.dart    $_dim# Staging$_reset');
      print('    flutter run -t lib/main_production.dart $_dim# Production$_reset');
      print('');
      
    } catch (e) {
      spinner.done();
      print('');
      print('$_red$_bold  Error creating project:$_reset');
      print('$_red  $e$_reset');
      print('');
      print('$_dim  Troubleshooting:$_reset');
      print('    - Check your Flutter installation');
      print('    - Ensure you have write permissions');
      print('    - Try running: flutter doctor');
      print('');
    }
  }

  void _printCancelledMessage() {
    print('');
    print('$_yellow  Project creation cancelled.$_reset');
    print('$_dim  Run flutterforge again when ready.$_reset');
    print('');
  }
}
