/// Single source of truth for the package versions the CLI writes into a
/// generated project's `pubspec.yaml`.
///
/// Keeping them here (instead of inline literals) means `vgv deps` can check
/// them against pub.dev and tell you exactly what has fallen behind.
///
/// These are **not** always the newest releases. A pin is chosen as the newest
/// version that still resolves against the Flutter SDK the CLI targets, which
/// is a stricter bound than "latest on pub.dev" for two reasons:
///   * the release may require a newer Dart SDK than that Flutter ships
///     (freezed 4 needs Dart >= 3.13, Flutter 3.44 ships 3.12), and
///   * the Flutter SDK pins packages like `meta`, which caps how new
///     `analyzer` — and therefore `build_runner`/`drift_dev` — can be.
/// `vgv deps` lists what is behind; verify a bump with a real project build
/// (`flutter pub get` + `build_runner`) before changing anything here.
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
  'go_router': '^18.0.1',
  // Networking + logging
  'dio': '^5.11.1',
  'pretty_dio_logger': '^1.4.0',
  'talker_dio_logger': '^5.1.20',
  'talker_flutter': '^5.1.20',
  // Storage
  // `sqlite3` 3.x bundles the native library through Dart native assets, which
  // is why the old `sqlite3_flutter_libs` plugin is end-of-life.
  'drift': '^2.34.4',
  'sqlite3': '^3.5.2',
  'path_provider': '^2.1.6',
  'path': '^1.9.1',
  'flutter_secure_storage': '^11.2.0',
  // Forms
  'flutter_form_builder': '^10.3.0',
  'form_builder_validators': '^11.3.0',
  // Misc
  'package_info_plus': '^10.2.1',
  // Codegen annotations
  'json_annotation': '^4.12.0',
  'freezed_annotation': '^3.1.0',
  // Provider (non-BLoC path)
  'provider': '^6.1.5',
};

/// Dev dependencies: package name -> caret constraint.
const Map<String, String> kDevDependencyVersions = <String, String>{
  'freezed': '^3.2.5',
  'json_serializable': '^6.14.1',
  'build_runner': '^2.15.1',
  'drift_dev': '^2.34.0',
  'intl_utils': '^2.8.14',
};

/// Every pinned package, for `vgv deps`.
Map<String, String> get kAllPinnedVersions => <String, String>{
      ...kDependencyVersions,
      ...kDevDependencyVersions,
    };
