import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:yaml/yaml.dart';

import 'api_generator.dart';
import 'feature_generator.dart';
import 'model_generator.dart';
import 'recase.dart';

/// Routes `vgv gen <subcommand>` — scaffolds code into an existing project.
class GenRunner {
  GenRunner({Logger? logger, bool? interactive})
      : _logger = logger ?? Logger(),
        _interactive = interactive ?? stdin.hasTerminal;

  final Logger _logger;
  final bool _interactive;

  Future<int> run(List<String> args) async {
    if (args.isEmpty || args.first == '-h' || args.first == '--help') {
      _usage();
      return args.isEmpty ? 1 : 0;
    }
    final rest = args.sublist(1);
    switch (args.first) {
      case 'feature':
        return _feature(rest);
      case 'model':
        return _model(rest);
      case 'bloc':
        return _unit(rest, 'bloc');
      case 'page':
        return _unit(rest, 'page');
      case 'usecase':
        return _unit(rest, 'usecase');
      case 'api':
        return _api(rest);
      default:
        _logger.err('Unknown subcommand: gen ${args.first}');
        _usage();
        return 1;
    }
  }

  Future<int> _feature(List<String> args) async {
    final parser = ArgParser()
      ..addFlag('bloc', defaultsTo: true, help: 'Include a Bloc (freezed).')
      ..addOption('bloc-name', help: 'Custom Bloc class name (e.g. HomeBloc).')
      ..addFlag('page', defaultsTo: true, help: 'Include a page.')
      ..addOption('page-name', help: 'Custom page class name (e.g. HomePage).')
      ..addFlag('stateful',
          defaultsTo: false, help: 'Make the page a StatefulWidget.')
      ..addFlag('bloc-in-page',
          defaultsTo: true, help: 'Wire the Bloc into the page.')
      ..addFlag('wire',
          defaultsTo: true,
          help: 'Auto-register DI + route (needs the vgv injector/routes).')
      ..addFlag('force',
          abbr: 'f', defaultsTo: false, help: 'Overwrite existing files.')
      ..addFlag('yes',
          abbr: 'y', defaultsTo: false, help: 'Accept defaults (no prompts).');

    final ArgResults res;
    try {
      res = parser.parse(args);
    } on FormatException catch (e) {
      _logger.err(e.message);
      return 1;
    }

    if (!File('pubspec.yaml').existsSync()) {
      _logger
        ..err('No pubspec.yaml here — run this from a Flutter project root.')
        ..info(styleDim.wrap(
            '  The feature is generated under lib/features/<name>/.'));
      return 1;
    }

    var featureName = res.rest.isNotEmpty ? res.rest.first : null;
    final ask = _interactive && !(res['yes'] as bool);

    featureName ??= ask
        ? _logger.prompt('Feature name (e.g. home, user_profile):')
        : null;
    if (featureName == null || featureName.trim().isEmpty) {
      _logger.err('A feature name is required: vgv gen feature <name>');
      return 1;
    }

    final feature = ReCase(featureName);

    // Resolve options: flags first, then prompt to refine when interactive.
    var includeBloc = res['bloc'] as bool;
    var addPage = res['page'] as bool;
    var stateless = !(res['stateful'] as bool);
    var blocInPage = res['bloc-in-page'] as bool;
    var blocName = res['bloc-name'] as String? ?? '${feature.pascalCase}Bloc';
    var pageName = res['page-name'] as String? ?? '${feature.pascalCase}Page';

    if (ask) {
      includeBloc = _logger.confirm('Include a Bloc?', defaultValue: includeBloc);
      if (includeBloc) {
        blocName = _logger.prompt('Bloc class name:', defaultValue: blocName);
      }
      addPage = _logger.confirm('Include a page?', defaultValue: addPage);
      if (addPage) {
        pageName = _logger.prompt('Page class name:', defaultValue: pageName);
        stateless =
            _logger.confirm('Stateless page?', defaultValue: stateless);
        if (includeBloc) {
          blocInPage =
              _logger.confirm('Wire the Bloc into the page?', defaultValue: blocInPage);
        }
      }
    }

    final options = FeatureOptions(
      featureName: featureName,
      includeBloc: includeBloc,
      blocName: blocName,
      addPage: addPage,
      pageName: pageName,
      statelessPage: stateless,
      addBlocToPage: blocInPage,
    );

    final files = FeatureGenerator().build(options);

    // Guard against clobbering unless --force.
    final existing =
        files.keys.where((path) => File(path).existsSync()).toList();
    if (existing.isNotEmpty && !(res['force'] as bool)) {
      _logger.err('These files already exist (use --force to overwrite):');
      for (final e in existing) {
        _logger.err('  $e');
      }
      return 1;
    }

    for (final entry in files.entries) {
      final file = File(entry.key)..parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
    }

    final wired = (res['wire'] as bool) ? _wireFeature(options) : <String>[];
    _report(options, files.keys.toList()..sort(), wired);
    return 0;
  }

  /// Best-effort auto-wiring into a vgv-generated project: registers the
  /// datasource/repository/usecases/bloc in `application/injector.dart` and
  /// adds a route in `application/routes/routes.dart`. Returns what it wired
  /// (empty when the anchors aren't found — e.g. a non-vgv project).
  List<String> _wireFeature(FeatureOptions o) {
    final wired = <String>[];
    final F = o.feature.pascalCase;
    final c = o.feature.camelCase;
    final snake = o.feature.snakeCase;
    final B = o.bloc.pascalCase;
    final bSnake = o.bloc.snakeCase;

    final inj = File('lib/application/injector.dart');
    if (inj.existsSync()) {
      var s = inj.readAsStringSync();
      final canWire = s.contains('class Injector {') &&
          s.contains('_registerDataSources() {') &&
          !s.contains('${F}RemoteDataSource>');
      if (canWire) {
        final imports = StringBuffer()
          ..writeln("import '../features/$snake/data/datasources/remote/${snake}_remote_datasource.dart';")
          ..writeln("import '../features/$snake/data/repositories/${snake}_repository_impl.dart';")
          ..writeln("import '../features/$snake/domain/repositories/${snake}_repository.dart';")
          ..write("import '../features/$snake/domain/use_cases/${snake}_use_cases.dart';\n");
        if (o.includeBloc) {
          imports.write("import '../features/$snake/presentation/blocs/${bSnake}_bloc/${bSnake}_bloc.dart';\n");
        }
        s = s.replaceFirst('\nclass Injector {', '$imports\nclass Injector {');
        s = s.replaceFirst(
          'static void _registerDataSources() {\n',
          'static void _registerDataSources() {\n'
              '    registerLazySingleton<${F}RemoteDataSource>(\n'
              '      () => ${F}RemoteDataSourceImpl(),\n'
              '    );\n',
        );
        s = s.replaceFirst(
          'static void _registerRepositories() {\n',
          'static void _registerRepositories() {\n'
              '    registerLazySingleton<${F}Repository>(\n'
              '      () => ${F}RepositoryImpl(${c}RemoteDataSource: get<${F}RemoteDataSource>()),\n'
              '    );\n',
        );
        s = s.replaceFirst(
          'static void _registerUseCases() {\n',
          'static void _registerUseCases() {\n'
              '    registerLazySingleton<${F}UseCases>(\n'
              '      () => ${F}UseCases(repository: get<${F}Repository>()),\n'
              '    );\n',
        );
        if (o.includeBloc) {
          s = s.replaceFirst(
            'static void _registerBlocs() {\n',
            'static void _registerBlocs() {\n'
                '    registerLazySingleton<${B}Bloc>(\n'
                '      () => ${B}Bloc(${c}UseCases: get<${F}UseCases>()),\n'
                '    );\n',
          );
        }
        inj.writeAsStringSync(s);
        wired.add('application/injector.dart');
      }
    }

    if (o.addPage) {
      final rt = File('lib/application/routes/routes.dart');
      if (rt.existsSync()) {
        var s = rt.readAsStringSync();
        final P = o.page.pascalCase;
        final pSnake = o.page.snakeCase;
        final canWire = s.contains('class Routes {') &&
            s.contains('routes: <RouteBase>[') &&
            !s.contains('${P}Page()');
        if (canWire) {
          s = s.replaceFirst('\nclass Routes {',
              "import '../../features/$snake/presentation/pages/${pSnake}_page.dart';\n\nclass Routes {");
          s = s.replaceFirst('const Routes._();\n',
              "const Routes._();\n  static const String $c = '/$snake';\n");
          s = s.replaceFirst(
            'routes: <RouteBase>[\n',
            'routes: <RouteBase>[\n'
                '      GoRoute(\n'
                '        path: Routes.$c,\n'
                '        builder: (BuildContext context, GoRouterState state) => const ${P}Page(),\n'
                '      ),\n',
          );
          rt.writeAsStringSync(s);
          wired.add('application/routes/routes.dart → /$snake');
        }
      }
    }
    return wired;
  }

  /// Handles `vgv gen api <Name> --from <openapi.json|yaml>`.
  Future<int> _api(List<String> args) async {
    final parser = ArgParser()
      ..addOption('from', help: 'Path to an OpenAPI/Swagger spec (.json/.yaml).')
      ..addOption('feature',
          help: 'Place under lib/features/<f>/data (else lib/api/).')
      ..addFlag('force', abbr: 'f', defaultsTo: false)
      ..addFlag('yes', abbr: 'y', defaultsTo: false);

    final ArgResults res;
    try {
      res = parser.parse(args);
    } on FormatException catch (e) {
      _logger.err(e.message);
      return 1;
    }

    if (!File('pubspec.yaml').existsSync()) {
      _logger.err('No pubspec.yaml here — run this from a Flutter project root.');
      return 1;
    }

    final ask = _interactive && !(res['yes'] as bool);
    var name = res.rest.isNotEmpty ? res.rest.first : null;
    name ??= ask ? _logger.prompt('API name (e.g. Store, Petshop):') : null;
    if (name == null || name.trim().isEmpty) {
      _logger.err('A name is required: vgv gen api <Name> --from <spec>');
      return 1;
    }

    var fromPath = res['from'] as String?;
    fromPath ??= ask ? _logger.prompt('Path to the OpenAPI/Swagger spec:') : null;
    if (fromPath == null || !File(fromPath).existsSync()) {
      _logger.err('Spec not found: ${fromPath ?? '(none)'} — pass --from <spec>');
      return 1;
    }

    final Object? decoded;
    try {
      final raw = File(fromPath).readAsStringSync();
      decoded = fromPath.endsWith('.json') ? jsonDecode(raw) : loadYaml(raw);
    } on FormatException catch (e) {
      _logger.err('Could not parse $fromPath: ${e.message}');
      return 1;
    }
    if (decoded is! Map) {
      _logger.err('The spec must be a map (OpenAPI/Swagger document).');
      return 1;
    }

    final files = ApiGenerator()
        .build(name: name, spec: decoded, feature: res['feature'] as String?);

    final existing = files.keys.where((p) => File(p).existsSync()).toList();
    if (existing.isNotEmpty && !(res['force'] as bool)) {
      _logger.err('These files already exist (use --force to overwrite):');
      for (final e in existing) {
        _logger.err('  $e');
      }
      return 1;
    }
    for (final entry in files.entries) {
      (File(entry.key)..parent.createSync(recursive: true))
          .writeAsStringSync(entry.value);
    }

    _logger
      ..info('')
      ..info(green.wrap('  ✓ API "$name" generated:')!);
    for (final p in files.keys.toList()..sort()) {
      _logger.info('    ${styleDim.wrap(p)}');
    }
    _logger
      ..info('')
      ..info('  ${styleDim.wrap('Models use freezed — run build_runner:')}')
      ..info('       ${lightCyan.wrap('dart run build_runner build --delete-conflicting-outputs')}')
      ..info('  ${styleDim.wrap('Then implement the stubbed methods in the generated *_api.dart.')}')
      ..info('');
    return 0;
  }

  /// Handles `vgv gen bloc|page|usecase <name> --feature <f>`.
  Future<int> _unit(List<String> args, String kind) async {
    final parser = ArgParser()
      ..addOption('feature', help: 'Target feature (under lib/features/).')
      ..addFlag('stateful', defaultsTo: false, help: 'page: StatefulWidget.')
      ..addOption('bloc', help: 'page: wire this Bloc into the page.')
      ..addFlag('force', abbr: 'f', defaultsTo: false)
      ..addFlag('yes', abbr: 'y', defaultsTo: false);

    final ArgResults res;
    try {
      res = parser.parse(args);
    } on FormatException catch (e) {
      _logger.err(e.message);
      return 1;
    }

    if (!File('pubspec.yaml').existsSync()) {
      _logger.err('No pubspec.yaml here — run this from a Flutter project root.');
      return 1;
    }

    final ask = _interactive && !(res['yes'] as bool);
    var name = res.rest.isNotEmpty ? res.rest.first : null;
    name ??= ask ? _logger.prompt('Name for the $kind:') : null;
    if (name == null || name.trim().isEmpty) {
      _logger.err('A name is required: vgv gen $kind <name> --feature <feature>');
      return 1;
    }

    var feature = res['feature'] as String?;
    // usecase is feature-scoped by nature: the name IS the feature if omitted.
    feature ??= kind == 'usecase' ? name : (ask ? _logger.prompt('Feature it belongs to:') : null);
    if (feature == null || feature.trim().isEmpty) {
      _logger.err('A feature is required: --feature <feature>');
      return 1;
    }

    final gen = FeatureGenerator();
    final Map<String, String> files;
    switch (kind) {
      case 'bloc':
        files = gen.buildBloc(FeatureOptions(
          featureName: feature,
          blocName: name,
          includeBloc: true,
          addPage: false,
        ));
      case 'page':
        final blocName = res['bloc'] as String?;
        files = gen.buildPage(FeatureOptions(
          featureName: feature,
          pageName: name,
          blocName: blocName ?? name,
          includeBloc: blocName != null,
          addBlocToPage: blocName != null,
          statelessPage: !(res['stateful'] as bool),
        ));
      case 'usecase':
      default:
        files = gen.buildUseCases(FeatureOptions(featureName: feature));
    }

    final existing = files.keys.where((p) => File(p).existsSync()).toList();
    if (existing.isNotEmpty && !(res['force'] as bool)) {
      _logger.err('These files already exist (use --force to overwrite):');
      for (final e in existing) {
        _logger.err('  $e');
      }
      return 1;
    }
    for (final entry in files.entries) {
      (File(entry.key)..parent.createSync(recursive: true))
          .writeAsStringSync(entry.value);
    }

    _logger
      ..info('')
      ..info(green.wrap('  ✓ Generated $kind "$name":')!);
    for (final p in files.keys.toList()..sort()) {
      _logger.info('    ${styleDim.wrap(p)}');
    }
    _logger
      ..info('')
      ..info('  ${styleDim.wrap('Then run build_runner if it uses freezed:')}')
      ..info('       ${lightCyan.wrap('dart run build_runner build --delete-conflicting-outputs')}')
      ..info('');
    return 0;
  }

  Future<int> _model(List<String> args) async {
    final parser = ArgParser()
      ..addOption('from', help: 'Path to a sample .json file.')
      ..addOption('feature',
          help: 'Place under lib/features/<feature>/ (else lib/models/).')
      ..addFlag('force',
          abbr: 'f', defaultsTo: false, help: 'Overwrite existing files.')
      ..addFlag('yes', abbr: 'y', defaultsTo: false, help: 'No prompts.');

    final ArgResults res;
    try {
      res = parser.parse(args);
    } on FormatException catch (e) {
      _logger.err(e.message);
      return 1;
    }

    if (!File('pubspec.yaml').existsSync()) {
      _logger.err('No pubspec.yaml here — run this from a Flutter project root.');
      return 1;
    }

    final ask = _interactive && !(res['yes'] as bool);

    var name = res.rest.isNotEmpty ? res.rest.first : null;
    name ??= ask ? _logger.prompt('Model name (e.g. User, Product):') : null;
    if (name == null || name.trim().isEmpty) {
      _logger.err('A model name is required: vgv gen model <Name> --from <file.json>');
      return 1;
    }

    var fromPath = res['from'] as String?;
    fromPath ??= ask ? _logger.prompt('Path to a sample .json file:') : null;
    if (fromPath == null || fromPath.trim().isEmpty) {
      _logger.err('A JSON source is required: --from <file.json>');
      return 1;
    }
    final jsonFile = File(fromPath);
    if (!jsonFile.existsSync()) {
      _logger.err('JSON file not found: $fromPath');
      return 1;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(jsonFile.readAsStringSync());
    } on FormatException catch (e) {
      _logger.err('Invalid JSON in $fromPath: ${e.message}');
      return 1;
    }

    final Map<String, String> files;
    try {
      files = ModelGenerator().build(
        name: name,
        json: decoded,
        feature: res['feature'] as String?,
      );
    } on FormatException catch (e) {
      _logger.err(e.message);
      return 1;
    }

    final existing = files.keys.where((p) => File(p).existsSync()).toList();
    if (existing.isNotEmpty && !(res['force'] as bool)) {
      _logger.err('These files already exist (use --force to overwrite):');
      for (final e in existing) {
        _logger.err('  $e');
      }
      return 1;
    }

    for (final entry in files.entries) {
      (File(entry.key)..parent.createSync(recursive: true))
          .writeAsStringSync(entry.value);
    }

    _logger
      ..info('')
      ..info(green.wrap('  ✓ Model "$name" generated:'));
    for (final path in files.keys.toList()..sort()) {
      _logger.info('    ${styleDim.wrap(path)}');
    }
    _logger
      ..info('')
      ..info('  ${styleDim.wrap('Then run build_runner:')}')
      ..info('       ${lightCyan.wrap('dart run build_runner build --delete-conflicting-outputs')}')
      ..info('');
    return 0;
  }

  void _report(FeatureOptions o, List<String> paths, List<String> wired) {
    _logger
      ..info('')
      ..info(green.wrap(
          '  ✓ Feature "${o.feature.snakeCase}" generated (${paths.length} files):'));
    for (final path in paths) {
      _logger.info('    ${styleDim.wrap(path)}');
    }

    final F = o.feature.pascalCase;
    final c = o.feature.camelCase;

    if (wired.isNotEmpty) {
      // Auto-wired: just tell the user what changed.
      _logger.info('');
      _logger.info(green.wrap('  ✓ Auto-wired:')!);
      for (final w in wired) {
        _logger.info('    ${styleDim.wrap(w)}');
      }
      _logger
        ..info('')
        ..info('  ${styleDim.wrap('Run build_runner:')}')
        ..info('       ${lightCyan.wrap('dart run build_runner build --delete-conflicting-outputs')}')
        ..info('');
      return;
    }

    // Not wired (non-vgv project or --no-wire): print manual steps.
    _logger
      ..info('')
      ..info(styleBold.wrap('  Next steps — wire it up:'))
      ..info('  ${styleDim.wrap('1. Register dependencies in application/injector.dart:')}')
      ..info(lightCyan.wrap('       registerLazySingleton<${F}RemoteDataSource>(')!)
      ..info(lightCyan.wrap('         () => ${F}RemoteDataSourceImpl(),')!)
      ..info(lightCyan.wrap('       );')!)
      ..info(lightCyan.wrap('       registerLazySingleton<${F}Repository>(')!)
      ..info(lightCyan.wrap('         () => ${F}RepositoryImpl(${c}RemoteDataSource: get()),')!)
      ..info(lightCyan.wrap('       );')!)
      ..info(lightCyan.wrap('       registerLazySingleton<${F}UseCases>(')!)
      ..info(lightCyan.wrap('         () => ${F}UseCases(repository: get()),')!)
      ..info(lightCyan.wrap('       );')!);
    if (o.includeBloc) {
      final B = o.bloc.pascalCase;
      _logger
        ..info(lightCyan.wrap('       registerLazySingleton<${B}Bloc>(')!)
        ..info(lightCyan.wrap('         () => ${B}Bloc(${c}UseCases: get()),')!)
        ..info(lightCyan.wrap('       );')!);
    }
    if (o.addPage) {
      _logger.info(
          '  ${styleDim.wrap('2. Add a route in application/routes/routes.dart pointing to ${o.page.pascalCase}Page.')}');
    }
    _logger
      ..info('  ${styleDim.wrap('3. Run build_runner:')}')
      ..info('       ${lightCyan.wrap('dart run build_runner build --delete-conflicting-outputs')}')
      ..info('');
  }

  void _usage() {
    _logger
      ..info('')
      ..info(styleBold.wrap('  vgv gen — scaffold code into your project'))
      ..info('')
      ..info('  ${lightCyan.wrap('vgv gen feature <name>')}          ${styleDim.wrap('Clean Architecture feature (data/domain/presentation)')}')
      ..info('  ${lightCyan.wrap('vgv gen model <Name> --from x.json')} ${styleDim.wrap('freezed model + entity from a sample JSON')}')
      ..info('  ${lightCyan.wrap('vgv gen bloc <Name> --feature <f>')}  ${styleDim.wrap('a HydratedBloc + freezed (bloc/event/state)')}')
      ..info('  ${lightCyan.wrap('vgv gen page <Name> --feature <f>')}  ${styleDim.wrap('a TStateless/TStateful page (--stateful, --bloc)')}')
      ..info('  ${lightCyan.wrap('vgv gen usecase <feature>')}          ${styleDim.wrap('domain repository interface + use cases')}')
      ..info('  ${lightCyan.wrap('vgv gen api <Name> --from api.yaml')} ${styleDim.wrap('freezed models + API client from an OpenAPI spec')}')
      ..info('')
      ..info(styleDim.wrap('  Options for feature:'))
      ..info('    ${lightCyan.wrap('--no-bloc')}              ${styleDim.wrap('skip the Bloc')}')
      ..info('    ${lightCyan.wrap('--bloc-name <Name>')}     ${styleDim.wrap('custom Bloc class name')}')
      ..info('    ${lightCyan.wrap('--no-page')}              ${styleDim.wrap('skip the page')}')
      ..info('    ${lightCyan.wrap('--page-name <Name>')}     ${styleDim.wrap('custom page class name')}')
      ..info('    ${lightCyan.wrap('--stateful')}             ${styleDim.wrap('StatefulWidget page (default: stateless)')}')
      ..info('    ${lightCyan.wrap('--no-bloc-in-page')}      ${styleDim.wrap('do not wire the Bloc into the page')}')
      ..info('    ${lightCyan.wrap('-y, --yes')}              ${styleDim.wrap('accept defaults (no prompts)')}')
      ..info('    ${lightCyan.wrap('-f, --force')}            ${styleDim.wrap('overwrite existing files')}')
      ..info('');
  }
}
