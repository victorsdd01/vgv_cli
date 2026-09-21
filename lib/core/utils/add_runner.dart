import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../data/datasources/file_system_datasource.dart';
import '../../domain/entities/project_config.dart';

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
  })  : _logger = logger ?? Logger(),
        _fileSystem = fileSystem ?? FileSystemDataSourceImpl(),
        _interactive = interactive ?? stdin.hasTerminal;

  final Logger _logger;
  final FileSystemDataSource _fileSystem;
  final bool _interactive;

  Future<int> run(List<String> args) async {
    if (args.isEmpty || args.first == '-h' || args.first == '--help') {
      usage(_logger);
      return args.isEmpty ? 1 : 0;
    }
    final rest = args.sublist(1);
    switch (args.first) {
      case 'flavors':
        return _flavors(rest);
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
    logger
      ..info('')
      ..info(styleBold.wrap('  vgv add — add vgv configuration to an existing project'))
      ..info('')
      ..info('  ${lightCyan.wrap('vgv add flavors [--flavors dev,staging,prod]')}')
      ..info('')
      ..info('  ${styleDim.wrap('--flavors <list>')}   which flavors (default: all three)')
      ..info('  ${styleDim.wrap('--app-name <name>')}  display name under the icon (detected/asked by default)')
      ..info('  ${styleDim.wrap('--bundle-id <id>')}   base application id (detected by default)')
      ..info('  ${styleDim.wrap('--force, -f')}        skip the confirmation and the "already has flavors" guard')
      ..info('')
      ..info(styleDim.wrap('  Run it inside the project. Adds Android product flavors, iOS build'))
      ..info(styleDim.wrap('  configs + schemes, per-flavor launcher icons and lib/main_<flavor>.dart,'))
      ..info(styleDim.wrap('  deriving the per-flavor ids from the app id you already have.'))
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
