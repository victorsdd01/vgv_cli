import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:vgv_cli/core/utils/fastlane_generator.dart';
import 'package:vgv_cli/domain/entities/project_config.dart';

/// Generates Fastlane for [projectName] inside a throwaway folder that has the
/// native `android/` and `ios/` dirs, and returns that project's root.
Future<String> generate(String projectName, String org) async {
  final tmp = Directory.systemTemp.createTempSync('vgv_fastlane_');
  addTearDown(() => tmp.deleteSync(recursive: true));
  final root = p.join(tmp.path, projectName);
  Directory(p.join(root, 'android')).createSync(recursive: true);
  Directory(p.join(root, 'ios')).createSync(recursive: true);

  final original = Directory.current;
  Directory.current = tmp;
  try {
    await const FastlaneGenerator().generate(ProjectConfig(
      projectName: projectName,
      organizationName: org,
      stateManagement: StateManagementType.bloc,
      architecture: ArchitectureType.cleanArchitecture,
      includeFastlane: true,
    ));
  } finally {
    Directory.current = original;
  }
  return root;
}

String read(String root, String relative) =>
    File(p.join(root, relative)).readAsStringSync();

void main() {
  test('iOS Appfile uses the camelCased id flutter gives the iOS app', () async {
    final root = await generate('ios_app', 'com.acme');
    expect(read(root, 'ios/fastlane/Appfile'),
        contains('app_identifier("com.acme.iosApp")'));
    expect(read(root, 'android/fastlane/Appfile'),
        contains('package_name("com.acme.ios_app")'));
    expect(read(root, 'fastlane-config.md'),
        contains('`com.acme.ios_app.dev` (iOS: `com.acme.iosApp.dev`)'));
  });

  test('ids match across platforms when the name has no underscore', () async {
    final root = await generate('shop', 'com.acme');
    expect(read(root, 'ios/fastlane/Appfile'),
        contains('app_identifier("com.acme.shop")'));
    expect(read(root, 'fastlane-config.md'), isNot(contains('(iOS:')));
  });
}
