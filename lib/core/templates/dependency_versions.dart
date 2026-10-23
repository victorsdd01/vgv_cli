/// Single source of truth for the package versions the CLI writes into a
/// generated project's `pubspec.yaml`.
///
/// Keeping them here (instead of inline literals) means `vgv deps` can check
/// them against pub.dev and tell you exactly what has fallen behind.
///
/// These are **not** always the newest releases. A pin is chosen as the newest
/// version that still resolves *and compiles* against the Flutter SDK the
/// project is created with, which is a stricter bound than "latest on pub.dev":
///   * a release may require a newer Dart SDK (freezed 4 needs Dart >= 3.13),
///   * the Flutter SDK pins packages like `meta`, which caps how new
///     `analyzer` — and therefore `build_runner`/`drift_dev` — can be, and
///   * some releases resolve and analyze fine but fail at compile time.
///
/// The main tables target the current stable SDK (Flutter 3.47 / Dart 3.13).
/// Older SDKs get [kLegacyDartVersionOverrides] on top — see [pinsForDart].
/// `vgv deps` lists what is behind; verify a bump with a real project build
/// (`flutter pub get` + `build_runner` + `flutter build apk`) before changing
/// anything here.
library;

/// Runtime dependencies: package name -> caret constraint.
const Map<String, String> kDependencyVersions = <String, String>{
  // State management (BLoC stack)
  'flutter_bloc': '^9.1.1',
  'hydrated_bloc': '^11.0.0',
  'replay_bloc': '^0.3.0',
  'bloc_concurrency': '^0.3.0',
  'nested': '^1.0.0',
  // Functional / value types
  'dartz': '^0.10.1',
  'equatable': '^3.0.0',
  // DI, routing
  'get_it': '^9.3.0',
  'go_router': '^18.1.1',
  // Networking + logging
  'dio': '^5.11.1',
  'pretty_dio_logger': '^1.4.0',
  'talker_dio_logger': '^5.1.20',
  'talker_flutter': '^5.1.20',
  // Storage
  // `sqlite3` 3.x bundles the native library through Dart native assets, which
  // is why the old `sqlite3_flutter_libs` plugin is end-of-life.
  'drift': '^2.35.2',
  'sqlite3': '^3.7.1',
  'path_provider': '^2.1.6',
  'path': '^1.9.1',
  'flutter_secure_storage': '^11.2.0',
  // Forms
  // flutter_form_builder is held at 10.x on purpose: 11.x builds its fields on
  // the decoupled `material_ui` package, whose `InputDecoration` is a
  // different type from Flutter's — every `decoration:` stops compiling.
  'flutter_form_builder': '^10.3.0',
  'form_builder_validators': '^11.3.0',
  // Misc
  'package_info_plus': '^10.2.2',
  // Codegen annotations
  'json_annotation': '^4.12.0',
  'freezed_annotation': '^3.1.0',
  // Provider (non-BLoC path)
  'provider': '^6.1.5',
};

/// Dev dependencies: package name -> caret constraint.
const Map<String, String> kDevDependencyVersions = <String, String>{
  'freezed': '^4.0.3',
  'json_serializable': '^6.15.2',
  'build_runner': '^2.16.2',
  'drift_dev': '^2.35.1',
  'intl_utils': '^2.8.17',
};

/// Every pinned package, for `vgv deps`.
Map<String, String> get kAllPinnedVersions => <String, String>{
      ...kDependencyVersions,
      ...kDevDependencyVersions,
    };

/// Pins for SDKs older than Dart 3.13 (Flutter <= 3.44), applied on top of the
/// main tables: exactly the set that was verified on Flutter 3.44.8. There
/// freezed 4 does not resolve, Flutter's `meta` pin caps `analyzer` (so
/// `build_runner` <= 2.15.1, `drift_dev` <= 2.34, and `intl_utils` < 2.8.17,
/// which needs analyzer >= 13), and go_router 18 resolves but fails to compile
/// (`material_ui` needs a newer `meta`).
///
/// The reverse does not work either: freezed 3 emits `final` on constructor
/// parameters, which Dart 3.13 rejects — so a new SDK *needs* the main tables.
const Map<String, String> kLegacyDartVersionOverrides = <String, String>{
  'go_router': '^17.5.0',
  'drift': '^2.34.4',
  'sqlite3': '^3.5.2',
  'freezed': '^3.2.5',
  'build_runner': '^2.15.1',
  'drift_dev': '^2.34.0',
  'intl_utils': '^2.8.14',
  'json_serializable': '^6.14.1',
  'package_info_plus': '^10.2.1',
};

/// The pins to write for a project whose Dart SDK lower bound is
/// [major].[minor] (as `flutter create` writes it in `environment: sdk:`).
Map<String, String> pinsForDart(int major, int minor) {
  final legacy = major < 3 || (major == 3 && minor < 13);
  return <String, String>{
    ...kAllPinnedVersions,
    if (legacy) ...kLegacyDartVersionOverrides,
  };
}

/// Reads the Dart SDK lower bound from a pubspec's `environment: sdk:` line
/// (`^3.13.4`, `>=3.12.0 <4.0.0`, …) and returns the matching pins. Falls back
/// to the main tables when the constraint cannot be read.
Map<String, String> pinsForPubspec(String pubspec) {
  final match = RegExp(r'^\s+sdk:\s*["\x27]?(?:\^|>=)?\s*(\d+)\.(\d+)',
          multiLine: true)
      .firstMatch(pubspec);
  if (match == null) return kAllPinnedVersions;
  return pinsForDart(int.parse(match.group(1)!), int.parse(match.group(2)!));
}
