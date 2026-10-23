import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../data/datasources/file_system_datasource.dart';
import '../../domain/entities/project_config.dart';
import 'agent_rules_generator.dart';
import 'fastlane_generator.dart';
import 'flutter_toolchain.dart';
import 'fvm_generator.dart';
import 'lefthook_generator.dart';
import 'polish_generators.dart';
import 'theme_seed_generator.dart';

/// `vgv add <thing>` — applies one piece of vgv's project configuration to a
/// Flutter project that already exists.
///
/// The generators the CLI runs while creating a project are otherwise
/// unreachable: if you already have an app and just need flavors, there was
/// nothing to run. This adds that configuration in place and touches nothing
/// else.
class AddRunner {
  AddRunner({
    Logger? logger,
    FileSystemDataSource? fileSystem,
    bool? interactive,
    Future<int> Function(String executable, List<String> args)? runProcess,
  })  : _logger = logger ?? Logger(),
        _fileSystem = fileSystem ?? FileSystemDataSourceImpl(),
        _interactive = interactive ?? stdin.hasTerminal,
        _runProcess = runProcess ?? _defaultRunProcess;

  final Logger _logger;
  final FileSystemDataSource _fileSystem;
  final bool _interactive;

  /// Runs a tool (flutter, dart, fvm) in the current directory and returns its
  /// exit code. Injectable so tests don't spawn real toolchains.
  final Future<int> Function(String executable, List<String> args) _runProcess;

  static Future<int> _defaultRunProcess(
      String executable, List<String> args) async {
    try {
      final result = await Process.run(executable, args, runInShell: true);
      return result.exitCode;
    } catch (_) {
      return 1;
    }
  }

  Future<int> run(List<String> args) async {
    if (args.isEmpty || args.first == '-h' || args.first == '--help') {
      usage(_logger);
      return args.isEmpty ? 1 : 0;
    }
    final rest = args.sublist(1);
    switch (args.first) {
      case 'flavors':
        return _flavors(rest);
      case 'fastlane':
        return _fastlane(rest);
      case 'lefthook':
        return _lefthook(rest);
      case 'fvm':
        return _fvm(rest);
      case 'icons':
        return _icons(rest);
      case 'splash':
        return _splash(rest);
      case 'seed':
      case 'theme':
        return _seed(rest);
      case 'agents':
        return _agents(rest);
      case 'window':
        return _window(rest);
      default:
        _logger.err('Unknown subcommand: vgv add ${args.first}');
        usage(_logger);
        return 1;
    }
  }

  // ---- flavors --------------------------------------------------------

  Future<int> _flavors(List<String> args) async {
    String? flavorsArg;
    String? bundleId;
    String? appNameArg;
    var force = false;
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      String? next() => i + 1 < args.length ? args[++i] : null;
      if (a == '--flavors') {
        flavorsArg = next();
      } else if (a.startsWith('--flavors=')) {
        flavorsArg = a.substring('--flavors='.length);
      } else if (a == '--app-name') {
        appNameArg = next();
      } else if (a.startsWith('--app-name=')) {
        appNameArg = a.substring('--app-name='.length);
      } else if (a == '--bundle-id') {
        bundleId = next();
      } else if (a.startsWith('--bundle-id=')) {
        bundleId = a.substring('--bundle-id='.length);
      } else if (a == '-f' || a == '--force') {
        force = true;
      }
    }

    final project = _resolveProject();
    if (project == null) return 1;

    if (!Directory('android').existsSync() && !Directory('ios').existsSync()) {
      _logger
        ..err('This project has no android/ or ios/ folder.')
        ..info(styleDim.wrap('  Native flavors only apply to mobile targets. '
            'Add a platform first: flutter create --platforms android,ios .'));
      return 1;
    }

    // Refuse to touch a project that already defines flavors: the gradle and
    // pbxproj edits are not something to apply twice.
    final existing = _existingAndroidFlavors();
    if (existing.isNotEmpty && !force) {
      _logger
        ..err('This project already declares Android product flavors: '
            '${existing.join(', ')}.')
        ..info(styleDim.wrap('  vgv will not rewrite them. Remove them first, '
            'or re-run with --force if you know what you are doing.'));
      return 1;
    }

    final flavors = _parseFlavors(flavorsArg);
    if (flavors == null) return 1;

    final baseId = bundleId ?? _detectApplicationId();
    if (baseId == null) {
      _logger
        ..err('Could not detect the current application id.')
        ..info(styleDim.wrap('  Pass it explicitly: '
            'vgv add flavors --bundle-id com.example.my_app'));
      return 1;
    }

    // configureFlavors derives the per-flavor ids from `<org>.<projectName>`,
    // so the id has to end with the folder name for the base id to come out
    // unchanged.
    if (!baseId.endsWith('.${project.dirName}')) {
      _logger
        ..err('The application id "$baseId" does not end with the project '
            'folder name "${project.dirName}".')
        ..info(styleDim.wrap('  vgv derives per-flavor ids from the base id, '
            'and cannot do that safely here.'))
        ..info(styleDim.wrap('  Rename the folder to match the id, or pass '
            '--bundle-id <id ending in .${project.dirName}>.'));
      return 1;
    }

    _logger
      ..info('')
      ..info(styleBold.wrap(lightCyan.wrap('  🍨 Adding native flavors'))!)
      ..info('  ${styleDim.wrap(project.dirName)}')
      ..info('');

    // Ask before touching the name: an existing app already has one, and the
    // flavors only append a suffix to it.
    final appName = _resolveAppName(appNameArg, project.dirName);

    final config = ProjectConfig(
      projectName: project.dirName,
      organizationName: baseId,
      appName: appName,
      platforms: const <PlatformType>[PlatformType.mobile],
      mobilePlatform: MobilePlatform.both,
      flavors: flavors,
      // Required by the entity but irrelevant here: this command only runs
      // the native flavor configuration, it does not generate app code.
      stateManagement: StateManagementType.bloc,
      architecture: ArchitectureType.cleanArchitecture,
    );

    _logger.info('');
    for (final f in flavors) {
      final id = '$baseId${f.bundleIdSuffix}';
      final label = '${config.effectiveAppName}${f.appNameSuffix}';
      _logger.info('    ${f.displayName.padRight(12)} '
          '${label.padRight(22)} ${styleDim.wrap(id)}');
    }
    _logger.info('');

    if (_interactive && !force) {
      final answer = _confirm('Apply this to the project?');
      if (answer == false) {
        _logger.info(styleDim.wrap('  Cancelled.'));
        return 0;
      }
    }

    final progress = _logger.progress('Configuring flavors');
    try {
      // configureFlavors builds its paths as <projectName>/android|ios, so it
      // has to run from the parent directory.
      final original = Directory.current;
      Directory.current = project.parent;
      try {
        await _fileSystem.configureFlavors(config);
      } finally {
        Directory.current = original;
      }
      _writeEntryPoints(flavors, project.packageName);
      progress.complete('Flavors configured');
    } catch (e) {
      progress.fail('Could not configure flavors');
      _logger.err('  $e');
      return 1;
    }

    _logger
      ..info('')
      ..info(green.wrap('  ✓ Added ${flavors.length} flavor(s)')!)
      ..info('  ${styleDim.wrap('Android product flavors, iOS build configs + schemes,')}')
      ..info('  ${styleDim.wrap('per-flavor launcher icons, and lib/main_<flavor>.dart.')}')
      ..info('')
      ..info(styleBold.wrap('  Next')!);
    for (final f in flavors) {
      _logger.info('    ${lightCyan.wrap('flutter run --flavor ${f.flavorName} '
          '-t lib/main_${f.entryPoint}.dart')}');
    }
    _logger
      ..info('  ${styleDim.wrap('Each main_<flavor>.dart just calls your existing main() — ')}')
      ..info('  ${styleDim.wrap('wire your per-flavor config in there.')}')
      ..info('');
    return 0;
  }

  /// Minimal entry points that defer to the app's existing `main()`, so the
  /// flavor targets resolve without assuming anything about the project.
  void _writeEntryPoints(List<Flavor> flavors, String packageName) {
    for (final f in flavors) {
      final file = File(p.join('lib', 'main_${f.entryPoint}.dart'));
      if (file.existsSync()) continue;
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('''// Entry point for the ${f.displayName} flavor.
//
// Run with:
//   flutter run --flavor ${f.flavorName} -t lib/main_${f.entryPoint}.dart
//
// Put anything specific to this flavor (API base URL, logging, analytics)
// here before handing off to the app.
import 'package:$packageName/main.dart' as app;

void main() => app.main();
''');
    }
  }

  // ---- fastlane -------------------------------------------------------

  Future<int> _fastlane(List<String> args) async {
    final o = _Opts(args);
    final project = _resolveProject();
    if (project == null) return 1;

    final platforms = _detectPlatforms();
    if (!platforms.mobile) {
      _logger.err('Fastlane deploys to the Play Store / App Store, but this '
          'project has no android/ or ios/ folder.');
      return 1;
    }
    // The lanes, AAB paths and per-store ids are all per flavor.
    final flavors = _detectFlavors();
    if (flavors.isEmpty) {
      _logger
        ..err('This project has no dev/staging/prod flavors, and the Fastlane '
            'lanes are per flavor.')
        ..info(styleDim.wrap('  Add them first: vgv add flavors'));
      return 1;
    }
    if (!o.force &&
        (File('Gemfile').existsSync() ||
            Directory(p.join('android', 'fastlane')).existsSync() ||
            Directory(p.join('ios', 'fastlane')).existsSync())) {
      _logger
        ..err('This project already has Fastlane files (Gemfile or */fastlane/).')
        ..info(styleDim.wrap('  Re-run with --force to overwrite them.'));
      return 1;
    }

    final androidId = _detectApplicationId();
    final iosId = _detectIosBaseBundleId();
    if (androidId == null && iosId == null) {
      _logger.err('Could not detect the application id / bundle id.');
      return 1;
    }

    final config = _config(
      project,
      platforms,
      flavors: flavors,
      includeFastlane: true,
    );
    await _inParent(
      project,
      () => const FastlaneGenerator().generate(
        config,
        androidBaseId: androidId ?? iosId,
        iosBaseId: iosId ?? androidId,
      ),
    );

    _done('Fastlane configured', <String>[
      'Gemfile, android/fastlane and ios/fastlane (lanes per flavor:'
          ' ${flavors.map((f) => f.flavorName).join(', ')}).',
      'Setup steps (store keys, signing): fastlane-config.md',
    ], next: <String>[
      'bundle install',
      'cd android && bundle exec fastlane deploy_${flavors.first.flavorName}',
    ]);
    return 0;
  }

  // ---- lefthook -------------------------------------------------------

  Future<int> _lefthook(List<String> args) async {
    final o = _Opts(args);
    final project = _resolveProject();
    if (project == null) return 1;
    if (File('lefthook.yml').existsSync() && !o.force) {
      _logger
        ..err('This project already has a lefthook.yml.')
        ..info(styleDim.wrap('  Re-run with --force to replace it.'));
      return 1;
    }
    final config = _config(project, _detectPlatforms(), includeLefthook: true);
    await _inParent(project, () => const LefthookGenerator().generate(config));

    _done('lefthook configured', <String>[
      'lefthook.yml: format + analyze on commit, tests on push.',
    ], next: <String>[
      'brew install lefthook   # or: dart pub global activate lefthook',
      'lefthook install',
    ]);
    return 0;
  }

  // ---- fvm ------------------------------------------------------------

  Future<int> _fvm(List<String> args) async {
    final o = _Opts(args, values: <String>{'version'});
    final project = _resolveProject();
    if (project == null) return 1;
    if (!await FlutterToolchain.isFvmAvailable()) {
      _logger
        ..err('fvm is not installed.')
        ..info(styleDim.wrap('  Install it: dart pub global activate fvm'));
      return 1;
    }
    final current = FlutterToolchain.pinnedVersion('.');
    if (current != null && !o.force) {
      _logger
        ..err('This project is already pinned to Flutter $current (.fvmrc).')
        ..info(styleDim.wrap('  Re-run with --force (and --version <v>) to change it.'));
      return 1;
    }

    String? pinned;
    await _inParent(project, () async {
      pinned = await const FvmGenerator()
          .pinSdk(project.dirName, version: o['version']);
      if (pinned != null) const FvmGenerator().configureEditor(project.dirName);
    });
    if (pinned == null) {
      _logger
        ..err('FVM has no Flutter SDK to pin.')
        ..info(styleDim.wrap('  Install one first: fvm install stable'));
      return 1;
    }

    // Downloads the SDK if needed and links .fvm/flutter_sdk for the editor.
    final linked = await _runProcess(
            'fvm', <String>['use', pinned!, '--force', '--skip-pub-get']) ==
        0;
    _done('Pinned to Flutter $pinned', <String>[
      '.fvmrc, .vscode/settings.json (dart.flutterSdkPath) and .fvm/ ignored.',
      if (!linked) 'Could not link the SDK yet — run: fvm use $pinned',
    ], next: <String>[
      'fvm flutter run',
    ]);
    return 0;
  }

  // ---- icons ----------------------------------------------------------

  Future<int> _icons(List<String> args) async {
    final o = _Opts(args, values: <String>{'from'});
    final from = o['from'] ?? (o.positional.isNotEmpty ? o.positional.first : null);
    if (from == null) {
      _logger
        ..err('Pass the master icon: vgv add icons --from icon.png')
        ..info(styleDim.wrap('  A square PNG, ideally 1024×1024.'));
      return 1;
    }
    final master = File(from).absolute;
    final size = _pngSize(master);
    if (size == null) {
      _logger.err('Not a PNG file: $from');
      return 1;
    }
    final project = _resolveProject();
    if (project == null) return 1;
    if (File('flutter_launcher_icons.yaml').existsSync() && !o.force) {
      _logger
        ..err('This project already has a flutter_launcher_icons.yaml.')
        ..info(styleDim.wrap('  Re-run with --force to replace it.'));
      return 1;
    }
    if (size.$1 != size.$2 || size.$1 < 1024) {
      _logger.warn('The icon is ${size.$1}×${size.$2}; stores expect a square '
          '1024×1024 master. Continuing anyway.');
    }

    final config = _config(project, _detectPlatforms(),
        iconMasterPath: master.path);
    await _inParent(project, () => const IconSetGenerator().generate(config));

    final generated = await _pubGetThen(
        <String>['run', 'flutter_launcher_icons'], 'Generating launcher icons');
    _done(generated ? 'Launcher icons generated' : 'Icon config added',
        <String>[
      'assets/icon/app_icon.png + flutter_launcher_icons.yaml for: '
          '${config.flutterPlatforms.join(', ')}.',
      if (!generated) 'Generate them: dart run flutter_launcher_icons',
    ]);
    return 0;
  }

  // ---- splash ---------------------------------------------------------

  Future<int> _splash(List<String> args) async {
    final o = _Opts(args, values: <String>{'color', 'image'});
    final project = _resolveProject();
    if (project == null) return 1;
    if (File('flutter_native_splash.yaml').existsSync() && !o.force) {
      _logger
        ..err('This project already has a flutter_native_splash.yaml.')
        ..info(styleDim.wrap('  Re-run with --force to replace it.'));
      return 1;
    }
    final color = _hexColor(o['color']);
    if (o['color'] != null && color == null) {
      _logger.err('Invalid --color "${o['color']}": use a 6-digit hex like 4B60AA.');
      return 1;
    }

    String? image;
    if (o['image'] != null) {
      final source = File(o['image']!);
      if (_pngSize(source) == null) {
        _logger.err('Not a PNG file: ${o['image']}');
        return 1;
      }
      image = 'assets/splash/splash.png';
      File(image)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(source.readAsBytesSync());
    } else if (File(p.join('assets', 'icon', 'app_icon.png')).existsSync()) {
      image = 'assets/icon/app_icon.png';
    }

    final config = _config(project, _detectPlatforms(),
        includeSplash: true, seedColorHex: color);
    await _inParent(
        project, () => const SplashGenerator().generate(config, image: image));

    final generated = await _pubGetThen(
        <String>['run', 'flutter_native_splash:create'], 'Generating the splash');
    _done(generated ? 'Native splash generated' : 'Splash config added',
        <String>[
      'flutter_native_splash.yaml (color ${color != null ? '#$color' : '#FFFFFF'}'
          '${image != null ? ', image $image' : ''}).',
      if (!generated) 'Generate it: dart run flutter_native_splash:create',
    ]);
    return 0;
  }

  // ---- seed (theme brand color) ----------------------------------------

  Future<int> _seed(List<String> args) async {
    final o = _Opts(args, values: <String>{'color'});
    final raw = o['color'] ?? (o.positional.isNotEmpty ? o.positional.first : null);
    final color = _hexColor(raw);
    if (color == null) {
      _logger.err(raw == null
          ? 'Pass the brand color: vgv add seed --color 4B60AA'
          : 'Invalid color "$raw": use a 6-digit hex like 4B60AA.');
      return 1;
    }
    final project = _resolveProject();
    if (project == null) return 1;
    if (!File(ThemeSeedGenerator.themePath).existsSync()) {
      _logger
        ..err('${ThemeSeedGenerator.themePath} not found.')
        ..info(styleDim.wrap('  The brand color is applied to the theme vgv '
            'generates, so this only works on projects created with vgv.'));
      return 1;
    }
    final config = _config(project, _detectPlatforms(), seedColorHex: color);
    var applied = false;
    await _inParent(project, () async {
      applied = await const ThemeSeedGenerator().generate(config);
    });
    if (!applied) {
      _logger.err('No `seedColor:` found in ${ThemeSeedGenerator.themePath}.');
      return 1;
    }
    _done('Brand color set to #$color', <String>[
      'ColorScheme.fromSeed in ${ThemeSeedGenerator.themePath} (light + dark).',
    ]);
    return 0;
  }

  // ---- agents ---------------------------------------------------------

  Future<int> _agents(List<String> args) async {
    final o = _Opts(args, values: <String>{'agents'});
    final agents = _parseAgents(o['agents']);
    if (agents == null) return 1;
    final project = _resolveProject();
    if (project == null) return 1;

    // Never overwrite rules someone already wrote by hand.
    final existing = agents
        .map((a) => a.rulesFilePath)
        .where((f) => File(f).existsSync())
        .toList();
    if (existing.isNotEmpty && !o.force) {
      _logger
        ..err('Already exists: ${existing.join(', ')}.')
        ..info(styleDim.wrap('  Re-run with --force to overwrite, or pick other '
            'agents with --agents.'));
      return 1;
    }
    final flavors = _detectFlavors();
    final config = _config(project, _detectPlatforms(),
        aiAgents: agents,
        flavors: flavors.isEmpty ? null : flavors);
    await _inParent(project, () => const AgentRulesGenerator().generate(config));

    _done('AI agent rules written', <String>[
      for (final a in agents) a.rulesFilePath,
      if (!Directory(p.join('lib', 'application')).existsSync())
        'They describe vgv\'s conventions (Clean Architecture, BLoC + freezed); '
            'edit them to match this project.',
    ]);
    return 0;
  }

  // ---- window ---------------------------------------------------------

  Future<int> _window(List<String> args) async {
    final project = _resolveProject();
    if (project == null) return 1;
    final platforms = _detectPlatforms();
    if (!platforms.desktop) {
      _logger.err('This project has no macos/, windows/ or linux/ folder.');
      return 1;
    }
    final main = File(p.join('lib', 'main.dart'));
    if (main.existsSync() && main.readAsStringSync().contains('window_manager')) {
      _logger.info(styleDim.wrap('  lib/main.dart already uses window_manager — nothing to do.'));
      return 0;
    }
    final config = _config(project, platforms,
        desktopWindow: true, appName: _detectAppName());
    var wired = false;
    await _inParent(project, () async {
      wired = await const DesktopWindowGenerator().generate(config);
    });
    if (!wired) {
      _logger
        ..err('Could not find main() in lib/main.dart.')
        ..info(styleDim.wrap('  Add window_manager by hand: '
            'https://pub.dev/packages/window_manager'));
      return 1;
    }
    final resolved = await _runFlutter(<String>['pub', 'get'], 'Resolving window_manager');
    _done('Desktop window configured', <String>[
      'lib/main.dart: minimum size 400×600 and the window title.',
      if (!resolved) 'Then run: flutter pub get',
    ]);
    return 0;
  }

  // ---- shared helpers -------------------------------------------------

  /// A config describing the existing project, for the generators. The
  /// state-management/architecture fields are required by the entity but
  /// unused by these generators.
  ProjectConfig _config(
    _Project project,
    _Platforms platforms, {
    List<Flavor>? flavors,
    bool includeFastlane = false,
    bool includeLefthook = false,
    bool includeSplash = false,
    bool desktopWindow = false,
    String? iconMasterPath,
    String? seedColorHex,
    String? appName,
    List<AiAgent> aiAgents = const <AiAgent>[],
  }) {
    return ProjectConfig(
      projectName: project.dirName,
      organizationName: _detectApplicationId() ?? 'com.example.${project.dirName}',
      appName: appName,
      stateManagement: StateManagementType.bloc,
      architecture: ArchitectureType.cleanArchitecture,
      platforms: platforms.types,
      mobilePlatform: platforms.mobilePlatform,
      desktopPlatform: DesktopPlatform.custom,
      customDesktopPlatforms: platforms.desktopPlatforms,
      flavors: flavors ??
          const <Flavor>[Flavor.dev, Flavor.staging, Flavor.production],
      includeFastlane: includeFastlane,
      includeLefthook: includeLefthook,
      includeSplash: includeSplash,
      desktopWindow: desktopWindow,
      iconMasterPath: iconMasterPath,
      seedColorHex: seedColorHex,
      aiAgents: aiAgents,
    );
  }

  /// The generators build their paths as `<projectName>/…`, so they run from
  /// the parent directory with the folder name as the project name.
  Future<void> _inParent(_Project project, Future<void> Function() body) async {
    final original = Directory.current;
    Directory.current = project.parent;
    try {
      await body();
    } finally {
      Directory.current = original;
    }
  }

  _Platforms _detectPlatforms() {
    bool has(String dir) => Directory(dir).existsSync();
    return _Platforms(
      android: has('android'),
      ios: has('ios'),
      web: has('web'),
      windows: has('windows'),
      macos: has('macos'),
      linux: has('linux'),
    );
  }

  /// dev/staging/prod flavors the project defines (Android product flavors,
  /// falling back to the iOS schemes), in canonical order.
  List<Flavor> _detectFlavors() {
    final names = <String>{..._existingAndroidFlavors()};
    final schemes = Directory(
        p.join('ios', 'Runner.xcodeproj', 'xcshareddata', 'xcschemes'));
    if (names.isEmpty && schemes.existsSync()) {
      for (final f in schemes.listSync()) {
        final name = p.basenameWithoutExtension(f.path);
        if (name != 'Runner') names.add(name);
      }
    }
    final found = names.map(Flavor.tryParse).whereType<Flavor>().toSet();
    return Flavor.values.where(found.contains).toList();
  }

  /// The production iOS bundle id: with flavors every build configuration has
  /// its own id, and the base one is the shortest (the others add a suffix).
  String? _detectIosBaseBundleId() {
    final pbx = File(p.join('ios', 'Runner.xcodeproj', 'project.pbxproj'));
    if (!pbx.existsSync()) return null;
    final ids = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = "?([^";]+)"?;')
        .allMatches(pbx.readAsStringSync())
        .map((m) => m.group(1)!.trim())
        .where((id) => !id.contains('RunnerTests') && !id.contains(r'$'))
        .toList()
      ..sort((a, b) => a.length.compareTo(b.length));
    return ids.isEmpty ? null : ids.first;
  }

  /// Width and height from a PNG header, or null when it is not a PNG.
  (int, int)? _pngSize(File file) {
    if (!file.existsSync()) return null;
    final bytes = file.openSync()..setPositionSync(0);
    try {
      final head = bytes.readSync(24);
      const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
      if (head.length < 24) return null;
      for (var i = 0; i < signature.length; i++) {
        if (head[i] != signature[i]) return null;
      }
      int be(int at) =>
          (head[at] << 24) | (head[at + 1] << 16) | (head[at + 2] << 8) | head[at + 3];
      return (be(16), be(20));
    } finally {
      bytes.closeSync();
    }
  }

  String? _hexColor(String? raw) {
    if (raw == null) return null;
    final hex = raw.replaceAll('#', '').trim();
    return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex) ? hex.toUpperCase() : null;
  }

  List<AiAgent>? _parseAgents(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const <AiAgent>[AiAgent.claude];
    final out = <AiAgent>[];
    for (final token in raw.split(',')) {
      final t = token.trim().toLowerCase();
      if (t.isEmpty) continue;
      final agent = switch (t) {
        'claude' => AiAgent.claude,
        'cursor' => AiAgent.cursor,
        'copilot' => AiAgent.copilot,
        'gemini' => AiAgent.gemini,
        'windsurf' => AiAgent.windsurf,
        'agents' || 'agents.md' || 'generic' => AiAgent.agentsMd,
        _ => null,
      };
      if (agent == null) {
        _logger
          ..err('Unknown agent "$token".')
          ..info(styleDim.wrap('  Valid: claude, cursor, copilot, gemini, windsurf, agents'));
        return null;
      }
      out.add(agent);
    }
    return out.toSet().toList();
  }

  /// Runs `flutter pub get` (the generators add dev dependencies), then
  /// `dart` with [dartArgs]. Returns whether both succeeded.
  Future<bool> _pubGetThen(List<String> dartArgs, String label) async {
    if (!await _runFlutter(<String>['pub', 'get'], 'Resolving dependencies')) {
      return false;
    }
    final toolchain = await FlutterToolchain.resolve();
    final progress = _logger.progress(label);
    final ok = await _runProcess(
            toolchain.dartExecutable, toolchain.dart(dartArgs)) ==
        0;
    ok ? progress.complete(label) : progress.fail('$label failed');
    return ok;
  }

  Future<bool> _runFlutter(List<String> args, String label) async {
    final toolchain = await FlutterToolchain.resolve();
    final progress = _logger.progress(label);
    final ok = await _runProcess(toolchain.executable, toolchain.flutter(args)) == 0;
    ok ? progress.complete(label) : progress.fail('$label failed');
    return ok;
  }

  void _done(String title, List<String> details, {List<String> next = const <String>[]}) {
    _logger
      ..info('')
      ..info(green.wrap('  ✓ $title')!);
    for (final d in details) {
      _logger.info('  ${styleDim.wrap(d)}');
    }
    if (next.isNotEmpty) {
      _logger
        ..info('')
        ..info(styleBold.wrap('  Next')!);
      for (final n in next) {
        _logger.info('    ${lightCyan.wrap(n)}');
      }
    }
    _logger.info('');
  }

  // ---- detection ------------------------------------------------------

  _Project? _resolveProject() {
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      _logger
        ..err('No pubspec.yaml here — run this inside a Flutter project.')
        ..info(styleDim.wrap('  To create a new project instead: vgv'));
      return null;
    }
    final content = pubspec.readAsStringSync();
    if (!content.contains('flutter:')) {
      _logger.err('This looks like a Dart package, not a Flutter app.');
      return null;
    }
    final name = RegExp(r'^name:\s*(\S+)', multiLine: true)
        .firstMatch(content)
        ?.group(1);
    if (name == null) {
      _logger.err('Could not read the package name from pubspec.yaml.');
      return null;
    }
    final dir = Directory.current;
    return _Project(
      packageName: name,
      dirName: p.basename(dir.path),
      parent: dir.parent,
    );
  }

  /// The applicationId gradle currently builds with, falling back to the iOS
  /// bundle identifier.
  String? _detectApplicationId() {
    for (final name in <String>['build.gradle.kts', 'build.gradle']) {
      final file = File(p.join('android', 'app', name));
      if (!file.existsSync()) continue;
      final m = RegExp(r'''applicationId\s*=?\s*["']([^"']+)["']''')
          .firstMatch(file.readAsStringSync());
      if (m != null) return m.group(1);
    }
    final pbx = File(p.join('ios', 'Runner.xcodeproj', 'project.pbxproj'));
    if (pbx.existsSync()) {
      final m = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
          .firstMatch(pbx.readAsStringSync());
      final id = m?.group(1)?.trim();
      if (id != null && !id.contains(r'$')) return id;
    }
    return null;
  }

  /// Flavor names already declared in the gradle `productFlavors { }` block.
  List<String> _existingAndroidFlavors() {
    for (final name in <String>['build.gradle.kts', 'build.gradle']) {
      final file = File(p.join('android', 'app', name));
      if (!file.existsSync()) continue;
      final block = _braceBlock(file.readAsStringSync(), 'productFlavors');
      if (block == null) continue;
      // `create("dev") {` (Kotlin DSL) or `dev {` (Groovy).
      final re = RegExp(
        r'create\(\s*["' "'" r']([A-Za-z]\w*)["' "'" r']\s*\)\s*\{'
        r'|^\s*([A-Za-z]\w*)\s*\{',
        multiLine: true,
      );
      return re
          .allMatches(block)
          .map((m) => m.group(1) ?? m.group(2)!)
          .toSet()
          .toList();
    }
    return const <String>[];
  }

  /// The body of `<keyword> { ... }`, matched by balancing braces so the scan
  /// stops at the end of that block instead of running into the next one
  /// (otherwise `buildTypes { release { … } }` looks like a flavor).
  String? _braceBlock(String source, String keyword) {
    final start = source.indexOf(keyword);
    if (start < 0) return null;
    final open = source.indexOf('{', start);
    if (open < 0) return null;
    var depth = 0;
    for (var i = open; i < source.length; i++) {
      final c = source[i];
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) return source.substring(open + 1, i);
      }
    }
    return null;
  }

  /// The display name the app currently uses, read from the Android manifest
  /// (following `@string/...` into strings.xml) or the iOS Info.plist.
  /// Returns null when it is only a build variable or nothing is set.
  String? _detectAppName() {
    final manifest = File(
        p.join('android', 'app', 'src', 'main', 'AndroidManifest.xml'));
    if (manifest.existsSync()) {
      final label = RegExp(r'android:label\s*=\s*"([^"]*)"')
          .firstMatch(manifest.readAsStringSync())
          ?.group(1);
      if (label != null && label.isNotEmpty) {
        if (!label.startsWith('@')) return label;
        final resource = label.split('/').last;
        final strings = File(p.join(
            'android', 'app', 'src', 'main', 'res', 'values', 'strings.xml'));
        if (strings.existsSync()) {
          final value = RegExp('<string name="$resource">([^<]*)</string>')
              .firstMatch(strings.readAsStringSync())
              ?.group(1);
          if (value != null && value.trim().isNotEmpty) return value.trim();
        }
      }
    }

    final plist = File(p.join('ios', 'Runner', 'Info.plist'));
    if (plist.existsSync()) {
      final content = plist.readAsStringSync();
      for (final key in <String>['CFBundleDisplayName', 'CFBundleName']) {
        final value = RegExp('<key>$key</key>\\s*<string>([^<]*)</string>')
            .firstMatch(content)
            ?.group(1)
            ?.trim();
        // `$(PRODUCT_NAME)` and friends are placeholders, not a real name.
        if (value != null && value.isNotEmpty && !value.contains(r'$(')) {
          return value;
        }
      }
    }
    return null;
  }

  /// Settles on the display name the flavors will be built from: the flag if
  /// given, otherwise what the project already uses — confirmed with you, so
  /// `add flavors` never renames an app behind your back.
  String? _resolveAppName(String? fromFlag, String fallback) {
    if (fromFlag != null && fromFlag.trim().isNotEmpty) return fromFlag.trim();
    final detected = _detectAppName() ?? fallback;
    if (!_interactive) return detected;

    _logger.info('  ${styleDim.wrap('Current app name:')} '
        '${styleBold.wrap(detected)}');
    final keep = _confirm('Keep "$detected" and just add the flavor suffixes?');
    if (keep != false) return detected;

    final entered = _ask('App name:', defaultValue: detected);
    return (entered == null || entered.trim().isEmpty)
        ? detected
        : entered.trim();
  }

  List<Flavor>? _parseFlavors(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <Flavor>[Flavor.dev, Flavor.staging, Flavor.production];
    }
    final out = <Flavor>[];
    for (final token in raw.split(',')) {
      final t = token.trim().toLowerCase();
      if (t.isEmpty) continue;
      switch (t) {
        case 'dev':
        case 'development':
          out.add(Flavor.dev);
        case 'stg':
        case 'stage':
        case 'staging':
          out.add(Flavor.staging);
        case 'prod':
        case 'production':
          out.add(Flavor.production);
        default:
          _logger
            ..err('Unknown flavor "$token".')
            ..info(styleDim.wrap('  Valid: dev, staging, prod'));
          return null;
      }
    }
    if (out.isEmpty) {
      _logger.err('No valid flavors given.');
      return null;
    }
    return out.toSet().toList();
  }

  /// `stdin.hasTerminal` can be true where prompting still fails: mason_logger
  /// throws StdinException (no echo mode) or StateError (stdout not attached).
  /// Treat both as "not interactive" instead of crashing.
  String? _ask(String message, {String? defaultValue}) {
    if (!_interactive) return null;
    try {
      return _logger.prompt(message, defaultValue: defaultValue);
    } on StdinException {
      return null;
    } on StateError {
      return null;
    }
  }

  bool? _confirm(String message) {
    try {
      return _logger.confirm(message, defaultValue: true);
    } on StdinException {
      return null;
    } on StateError {
      return null;
    }
  }

  static void usage(Logger logger) {
    String cmd(String c) => lightCyan.wrap(c)!;
    String dim(String t) => styleDim.wrap(t)!;
    logger
      ..info('')
      ..info(styleBold.wrap('  vgv add — add vgv configuration to an existing project'))
      ..info('')
      ..info('  ${cmd('vgv add flavors')}   ${dim('[--flavors dev,staging,prod] [--app-name N] [--bundle-id ID]')}')
      ..info('  ${cmd('vgv add fastlane')}  ${dim('Play Store / App Store lanes per flavor (needs flavors)')}')
      ..info('  ${cmd('vgv add lefthook')}  ${dim('format + analyze on commit, tests on push')}')
      ..info('  ${cmd('vgv add fvm')}       ${dim('[--version 3.47.5]  pin the Flutter SDK + editor setup')}')
      ..info('  ${cmd('vgv add icons')}     ${dim('--from icon.png  launcher icons for every platform')}')
      ..info('  ${cmd('vgv add splash')}    ${dim('[--color 4B60AA] [--image splash.png]  native splash')}')
      ..info('  ${cmd('vgv add seed')}      ${dim('--color 4B60AA  brand color of a vgv theme')}')
      ..info('  ${cmd('vgv add agents')}    ${dim('[--agents claude,cursor,copilot,gemini,windsurf,agents]')}')
      ..info('  ${cmd('vgv add window')}    ${dim('desktop window min size + title (window_manager)')}')
      ..info('')
      ..info('  ${dim('--force, -f')}  overwrite existing files / skip confirmations')
      ..info('')
      ..info(dim('  Run it inside the project. Each command only adds that piece and'))
      ..info(dim('  refuses to overwrite what is already there unless you pass --force.'))
      ..info('');
  }

}

class _Project {
  const _Project({
    required this.packageName,
    required this.dirName,
    required this.parent,
  });

  /// `name:` from pubspec.yaml — what `package:` imports use.
  final String packageName;

  /// Folder name; the flavor generators build their paths from it.
  final String dirName;
  final Directory parent;
}

/// Minimal option parser for the `vgv add` subcommands: `--key value`,
/// `--key=value`, `-f/--force`, and positional arguments.
class _Opts {
  _Opts(List<String> args, {Set<String> values = const <String>{}}) {
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      if (a == '-f' || a == '--force') {
        force = true;
      } else if (a.startsWith('--') && a.contains('=')) {
        final eq = a.indexOf('=');
        _values[a.substring(2, eq)] = a.substring(eq + 1);
      } else if (a.startsWith('--') && values.contains(a.substring(2))) {
        if (i + 1 < args.length) _values[a.substring(2)] = args[++i];
      } else if (!a.startsWith('-')) {
        positional.add(a);
      }
    }
  }

  final Map<String, String> _values = <String, String>{};
  final List<String> positional = <String>[];
  bool force = false;

  String? operator [](String key) => _values[key];
}

/// Which platform folders the project has.
class _Platforms {
  const _Platforms({
    required this.android,
    required this.ios,
    required this.web,
    required this.windows,
    required this.macos,
    required this.linux,
  });

  final bool android;
  final bool ios;
  final bool web;
  final bool windows;
  final bool macos;
  final bool linux;

  bool get mobile => android || ios;
  bool get desktop => windows || macos || linux;

  List<PlatformType> get types => <PlatformType>[
        if (mobile) PlatformType.mobile,
        if (web) PlatformType.web,
        if (desktop) PlatformType.desktop,
      ];

  MobilePlatform get mobilePlatform => android && ios
      ? MobilePlatform.both
      : (ios ? MobilePlatform.ios : MobilePlatform.android);

  CustomDesktopPlatforms get desktopPlatforms =>
      CustomDesktopPlatforms(windows: windows, macos: macos, linux: linux);
}
