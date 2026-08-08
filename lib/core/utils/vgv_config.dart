import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../domain/entities/project_config.dart';

/// User presets loaded from a global `~/.vgvrc` and/or a project-local
/// `vgv.yaml`. Precedence (highest first): CLI flags > `vgv.yaml` > `~/.vgvrc`.
/// Only the flag-threaded settings are supported (org, output, flavors, git);
/// anything else in the file is ignored.
class VgvConfig {
  const VgvConfig({this.organization, this.output, this.flavors, this.git});

  final String? organization;
  final String? output;
  final List<Flavor>? flavors;
  final bool? git;

  static String get _home =>
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '';

  /// Global config path (`~/.vgvrc`).
  static String get globalPath => p.join(_home, '.vgvrc');

  /// Project config path (`./vgv.yaml`).
  static const String projectPath = 'vgv.yaml';

  /// Loads and merges the global then project config. Missing/invalid files
  /// are treated as empty (never throws).
  static VgvConfig load() {
    final g = _fromFile(globalPath);
    final proj = _fromFile(projectPath);
    return VgvConfig(
      organization: proj.organization ?? g.organization,
      output: proj.output ?? g.output,
      flavors: proj.flavors ?? g.flavors,
      git: proj.git ?? g.git,
    );
  }

  static VgvConfig _fromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return const VgvConfig();
    return fromYamlString(file.readAsStringSync());
  }

  /// Parses a YAML string into a [VgvConfig]. Never throws — malformed or
  /// non-map documents yield an empty config.
  static VgvConfig fromYamlString(String content) {
    try {
      final doc = loadYaml(content);
      if (doc is! Map) return const VgvConfig();
      final gitValue = doc['git'];
      return VgvConfig(
        organization: (doc['org'] ?? doc['organization'])?.toString(),
        output: doc['output']?.toString(),
        flavors: _parseFlavors(doc['flavors']),
        git: gitValue is bool ? gitValue : null,
      );
    } catch (_) {
      return const VgvConfig();
    }
  }

  static List<Flavor>? _parseFlavors(Object? value) {
    final tokens = <String>[];
    if (value is String) {
      tokens.addAll(value.split(','));
    } else if (value is Iterable) {
      tokens.addAll(value.map((e) => e.toString()));
    } else {
      return null;
    }
    final selected = <Flavor>{};
    for (final token in tokens) {
      final flavor = Flavor.tryParse(token);
      if (flavor != null) selected.add(flavor);
    }
    if (selected.isEmpty) return null;
    return Flavor.values.where(selected.contains).toList();
  }

  /// A commented starter config.
  static const String template = '''# vgv CLI presets.
# CLI flags always override these values.
# Precedence: flags > ./vgv.yaml > ~/.vgvrc

# Default organization / bundle-id base for new projects.
org: com.mycompany

# Default output directory (where projects are created).
# output: ~/projects

# Default flavors to generate (any of: dev, staging, prod).
flavors: [dev, staging, prod]

# Initialize a git repo after creating the project (true/false).
git: true
''';

  /// Writes the starter template to the global or project path (does not
  /// overwrite an existing file unless [force]). Returns the target file.
  static File writeTemplate({required bool global, bool force = false}) {
    final path = global ? globalPath : projectPath;
    final file = File(path);
    if (file.existsSync() && !force) return file;
    file.writeAsStringSync(template);
    return file;
  }
}
