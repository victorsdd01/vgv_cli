import 'dart:io';

import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';

import 'feature_generator.dart';
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
        _logger.info('${lightCyan.wrap('vgv gen model')} is coming next.');
        return 0;
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

    _report(options, files.keys.toList()..sort());
    return 0;
  }

  void _report(FeatureOptions o, List<String> paths) {
    _logger
      ..info('')
      ..info(green.wrap(
          '  ✓ Feature "${o.feature.snakeCase}" generated (${paths.length} files):'));
    for (final path in paths) {
      _logger.info('    ${styleDim.wrap(path)}');
    }

    _logger
      ..info('')
      ..info(styleBold.wrap('  Next steps — wire it up:'))
      ..info('  ${styleDim.wrap('1. Register dependencies in application/injector.dart:')}');

    final F = o.feature.pascalCase;
    final c = o.feature.camelCase;
    _logger
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
        ..info(lightCyan.wrap('       registerFactory<${B}Bloc>(')!)
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
      ..info('  ${lightCyan.wrap('vgv gen feature <name>')}   ${styleDim.wrap('Clean Architecture feature (data/domain/presentation)')}')
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
