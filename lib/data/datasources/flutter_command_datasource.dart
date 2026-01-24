import 'dart:io';
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
      final result = await Process.run('flutter', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> generateLocalizationFiles(String projectName) async {
    try {
      // Always run intl_utils:generate directly since it's more reliable
      final result = await Process.run(
        'dart',
        ['run', 'intl_utils:generate'],
        workingDirectory: projectName,
      );

      if (result.exitCode != 0) {
        print('Warning: Failed to generate localization files. You may need to run "dart run intl_utils:generate" manually.');
      }

      // Always fix the import in app_localizations.dart after generation
      await _fixAppLocalizationsImport(projectName);
    } catch (e) {
      print('Warning: Failed to generate localization files: $e');
    }
  }

  Future<void> _fixAppLocalizationsImport(String projectName) async {
    try {
      final appLocalizationsFile = File('$projectName/lib/application/generated/l10n/app_localizations.dart');
      if (appLocalizationsFile.existsSync()) {
        String content = appLocalizationsFile.readAsStringSync();
        
        // Replace the wrong import with the correct one
        content = content.replaceFirst(
          "import 'package:flutter_gen/gen_l10n/app_localizations.dart';",
          "import '../l10n.dart';"
        );
        
        appLocalizationsFile.writeAsStringSync(content);
      }
    } catch (e) {
      // Silently handle the error - this is not critical for the user experience
    }
  }

  @override
  Future<void> cleanBuildCache(String projectName) async {
    try {
      // Run flutter clean to clear build cache
      final result = await Process.run(
        'flutter',
        ['clean'],
        workingDirectory: projectName,
      );

      if (result.exitCode == 0) {
        // Run flutter pub get to restore dependencies
        await Process.run(
          'flutter',
          ['pub', 'get'],
          workingDirectory: projectName,
        );
      }
    } catch (e) {
      print('Warning: Failed to clean build cache: $e');
    }
  }

  @override
  Future<void> runBuildRunner(String projectName) async {
    try {
      final result = await Process.run(
        'dart',
        ['run', 'build_runner', 'build', '-d'],
        workingDirectory: projectName,
      );

      if (result.exitCode != 0) {
        // Warning will be shown silently - user can run manually if needed
      }
    } catch (e) {
      // Silently handle - user can run manually if needed
    }
  }

  @override
  Future<void> setupCocoaPods(String projectName, List<PlatformType> platforms) async {
    final bool hasIOS = platforms.contains(PlatformType.mobile) && 
                        Directory('$projectName/ios').existsSync();
    final bool hasMacOS = platforms.contains(PlatformType.desktop) && 
                          Directory('$projectName/macos').existsSync();
    
    if (!hasIOS && !hasMacOS) {
      return;
    }
    
    try {
      final podCheck = await Process.run('which', ['pod']);
      if (podCheck.exitCode != 0) {
        return; // CocoaPods not installed, skip silently
      }

      // Setup iOS CocoaPods
      if (hasIOS) {
        final iosDir = Directory('$projectName/ios');
        if (iosDir.existsSync()) {
          final podsDir = Directory('$projectName/ios/Pods');
          final podfileLock = File('$projectName/ios/Podfile.lock');
          
          if (podsDir.existsSync()) {
            await podsDir.delete(recursive: true);
          }
          if (podfileLock.existsSync()) {
            await podfileLock.delete();
          }

          await Process.run('pod', ['repo', 'update'], workingDirectory: '$projectName/ios');
          await Process.run('pod', ['install', '--repo-update'], workingDirectory: '$projectName/ios');
        }
      }

      // Setup macOS CocoaPods
      if (hasMacOS) {
        final macosDir = Directory('$projectName/macos');
        if (macosDir.existsSync()) {
          final podsDir = Directory('$projectName/macos/Pods');
          final podfileLock = File('$projectName/macos/Podfile.lock');
          
          if (podsDir.existsSync()) {
            await podsDir.delete(recursive: true);
          }
          if (podfileLock.existsSync()) {
            await podfileLock.delete();
          }

          await Process.run('pod', ['repo', 'update'], workingDirectory: '$projectName/macos');
          await Process.run('pod', ['install', '--repo-update'], workingDirectory: '$projectName/macos');
        }
      }
    } catch (e) {
      // Silently handle - user can run pod install manually if needed
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