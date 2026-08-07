import 'dart:io';

/// Bakes the version from `pubspec.yaml` into `lib/src/version.dart`.
///
/// This is the single source of truth for the CLI's own version at runtime:
/// reading `pubspec.yaml` at runtime is unreliable for a globally activated
/// package. Run locally with `dart run tool/generate_version.dart`; the
/// auto-version-bump workflow runs it whenever it bumps the version.
void main() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('pubspec.yaml not found (run from the package root).');
    exit(1);
  }

  final match = RegExp(r'^version:\s*(\S+)', multiLine: true)
      .firstMatch(pubspec.readAsStringSync());
  if (match == null) {
    stderr.writeln('Could not find a version in pubspec.yaml.');
    exit(1);
  }

  final version = match.group(1)!;
  final out = File('lib/src/version.dart')..parent.createSync(recursive: true);
  out.writeAsStringSync('''// GENERATED CODE - DO NOT MODIFY BY HAND.
// Regenerate with: dart run tool/generate_version.dart
// Kept in sync with pubspec.yaml by the auto-version-bump workflow.

/// The current VGV CLI version, baked at build time from pubspec.yaml.
const String packageVersion = '$version';
''');
  stdout.writeln('Wrote lib/src/version.dart ($version)');
}
