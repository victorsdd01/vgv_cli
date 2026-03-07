import 'dart:io';
import 'package:path/path.dart' as p;
import '../../domain/entities/project_config.dart';

/// Data source for Flutter command operations
abstract class FlutterCommandDataSource {
  Future<void> createFlutterProject({
    required String projectName,
    required String organizationName,
    required List<PlatformType> platforms,
    required MobilePlatform mobilePlatform,
    required DesktopPlatform desktopPlatform,
    CustomDesktopPlatforms? customDesktopPlatforms,
  });

  Future<bool> isFlutterInstalled();

  Future<void> generateLocalizationFiles(String projectName);

  Future<void> cleanBuildCache(String projectName);

  Future<void> runBuildRunner(String projectName);

  Future<void> setupCocoaPods(String projectName, List<PlatformType> platforms);
}

/// Implementation of FlutterCommandDataSource
class FlutterCommandDataSourceImpl implements FlutterCommandDataSource {
  @override
  Future<void> createFlutterProject({
    required String projectName,
    required String organizationName,
    required List<PlatformType> platforms,
    required MobilePlatform mobilePlatform,
    required DesktopPlatform desktopPlatform,
    CustomDesktopPlatforms? customDesktopPlatforms,
  }) async {
    // Validate project name is a valid Dart package name
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(projectName)) {
      throw FlutterCommandException(
        'Invalid project name "$projectName". Must be lowercase with underscores only.',
      );
    }

    // Check if directory already exists
    final projectDir = Directory(p.join(Directory.current.path, projectName));
    if (projectDir.existsSync()) {
      throw FlutterCommandException(
        'Directory "$projectName" already exists. Choose a different name or delete the existing directory.',
      );
    }

    final args = ['create', '--org', organizationName];

    // Collect all platforms in a single list
    final allPlatforms = <String>[];

    // Add mobile platforms
    if (platforms.contains(PlatformType.mobile)) {
      if (mobilePlatform == MobilePlatform.android || mobilePlatform == MobilePlatform.both) {
        allPlatforms.add('android');
      }
      if (mobilePlatform == MobilePlatform.ios || mobilePlatform == MobilePlatform.both) {
        allPlatforms.add('ios');
      }
    }

    // Add web platform
    if (platforms.contains(PlatformType.web)) {
      allPlatforms.add('web');
    }

    // Add desktop platforms
    if (platforms.contains(PlatformType.desktop)) {
      if (desktopPlatform == DesktopPlatform.custom && customDesktopPlatforms != null) {
        if (customDesktopPlatforms.windows) allPlatforms.add('windows');
        if (customDesktopPlatforms.macos) allPlatforms.add('macos');
        if (customDesktopPlatforms.linux) allPlatforms.add('linux');
      } else {
        if (desktopPlatform == DesktopPlatform.windows || desktopPlatform == DesktopPlatform.all) {
          allPlatforms.add('windows');
        }
        if (desktopPlatform == DesktopPlatform.macos || desktopPlatform == DesktopPlatform.all) {
          allPlatforms.add('macos');
        }
        if (desktopPlatform == DesktopPlatform.linux || desktopPlatform == DesktopPlatform.all) {
          allPlatforms.add('linux');
        }
      }
    }

    // Add single --platforms flag with all platforms combined
    if (allPlatforms.isNotEmpty) {
      args.add('--platforms=${allPlatforms.join(',')}');
    }

    args.add(projectName);

    final result = await Process.run(
      'flutter',
      args,
      workingDirectory: Directory.current.path,
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw FlutterCommandException(
        'Failed to create Flutter project: ${result.stderr}',
      );
    }
  }

  @override
  Future<bool> isFlutterInstalled() async {
    try {
      final result = await Process.run('flutter', ['--version'], runInShell: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> generateLocalizationFiles(String projectName) async {
    try {
      final result = await Process.run(
        'dart',
        ['run', 'intl_utils:generate'],
        workingDirectory: projectName,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        // Silent: runs during spinner animation
      }

      await _fixAppLocalizationsImport(projectName);
    } catch (_) {
      // Silent: runs during spinner animation
    }
  }

  Future<void> _fixAppLocalizationsImport(String projectName) async {
    try {
      final appLocalizationsFile = File(p.join(projectName, 'lib', 'application', 'generated', 'l10n', 'app_localizations.dart'));
      if (appLocalizationsFile.existsSync()) {
        String content = appLocalizationsFile.readAsStringSync();

        content = content.replaceFirst(
          "import 'package:flutter_gen/gen_l10n/app_localizations.dart';",
          "import '../l10n.dart';"
        );

        appLocalizationsFile.writeAsStringSync(content);
      }
    } catch (_) {
      // Silent: runs during spinner animation
    }
  }

  @override
  Future<void> cleanBuildCache(String projectName) async {
    try {
      final result = await Process.run(
        'flutter',
        ['clean'],
        workingDirectory: projectName,
        runInShell: true,
      );

      if (result.exitCode == 0) {
        await Process.run(
          'flutter',
          ['pub', 'get'],
          workingDirectory: projectName,
          runInShell: true,
        );
      }
    } catch (_) {
      // Silent: runs during spinner animation
    }
  }

  @override
  Future<void> runBuildRunner(String projectName) async {
    try {
      final result = await Process.run(
        'dart',
        ['run', 'build_runner', 'build', '-d'],
        workingDirectory: projectName,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        // Silent: runs during spinner animation
      }
    } catch (_) {
      // Silent: runs during spinner animation
    }
  }

  @override
  Future<void> setupCocoaPods(String projectName, List<PlatformType> platforms) async {
    final iosPath = p.join(projectName, 'ios');
    final macosPath = p.join(projectName, 'macos');
    final bool hasIOS = platforms.contains(PlatformType.mobile) &&
                        Directory(iosPath).existsSync();
    final bool hasMacOS = platforms.contains(PlatformType.desktop) &&
                          Directory(macosPath).existsSync();

    if (!hasIOS && !hasMacOS) {
      return;
    }

    try {
      // CocoaPods is only available on macOS
      if (!Platform.isMacOS) return;

      final podCheck = await Process.run('which', ['pod'], runInShell: true);
      if (podCheck.exitCode != 0) {
        return; // CocoaPods not installed, skip silently
      }

      // Setup iOS CocoaPods
      if (hasIOS) {
        final iosDir = Directory(iosPath);
        if (iosDir.existsSync()) {
          final podsDir = Directory(p.join(iosPath, 'Pods'));
          final podfileLock = File(p.join(iosPath, 'Podfile.lock'));

          if (podsDir.existsSync()) {
            await podsDir.delete(recursive: true);
          }
          if (podfileLock.existsSync()) {
            await podfileLock.delete();
          }

          await Process.run('pod', ['repo', 'update'], workingDirectory: iosPath, runInShell: true);
          await Process.run('pod', ['install', '--repo-update'], workingDirectory: iosPath, runInShell: true);
        }
      }

      // Setup macOS CocoaPods
      if (hasMacOS) {
        final macosDir = Directory(macosPath);
        if (macosDir.existsSync()) {
          final podsDir = Directory(p.join(macosPath, 'Pods'));
          final podfileLock = File(p.join(macosPath, 'Podfile.lock'));

          if (podsDir.existsSync()) {
            await podsDir.delete(recursive: true);
          }
          if (podfileLock.existsSync()) {
            await podfileLock.delete();
          }

          await Process.run('pod', ['repo', 'update'], workingDirectory: macosPath, runInShell: true);
          await Process.run('pod', ['install', '--repo-update'], workingDirectory: macosPath, runInShell: true);
        }
      }
    } catch (_) {
      // Silent: runs during spinner animation
    }
  }
}

/// Exception thrown when Flutter command fails
class FlutterCommandException implements Exception {
  final String message;
  FlutterCommandException(this.message);

  @override
  String toString() => 'FlutterCommandException: $message';
}
