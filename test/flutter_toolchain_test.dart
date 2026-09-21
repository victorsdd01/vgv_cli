import 'dart:io';

import 'package:test/test.dart';
import 'package:vgv_cli/core/utils/flutter_toolchain.dart';

void main() {
  group('FlutterToolchain command building', () {
    test('global toolchain calls flutter/dart directly', () {
      const t = FlutterToolchain.global();
      expect(t.useFvm, isFalse);
      expect(t.executable, 'flutter');
      expect(t.dartExecutable, 'dart');
      expect(t.flutter(<String>['clean']), <String>['clean']);
      expect(t.dart(<String>['run', 'build_runner']), <String>['run', 'build_runner']);
      expect(t.hintPrefix, '');
    });

    test('fvm toolchain prefixes the subcommand', () {
      const t = FlutterToolchain(useFvm: true);
      expect(t.executable, 'fvm');
      expect(t.dartExecutable, 'fvm');
      expect(t.flutter(<String>['pub', 'get']), <String>['flutter', 'pub', 'get']);
      expect(t.dart(<String>['run', 'intl_utils:generate']),
          <String>['dart', 'run', 'intl_utils:generate']);
      expect(t.hintPrefix, 'fvm ');
    });
  });

  group('FVM project detection', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('vgv_fvm_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('plain directory is not FVM-pinned', () {
      expect(FlutterToolchain.hasFvmMarker(dir.path), isFalse);
      expect(FlutterToolchain.pinnedVersion(dir.path), isNull);
    });

    test('.fvmrc marks the project and exposes the version', () {
      File('${dir.path}/.fvmrc').writeAsStringSync('{"flutter": "3.44.8"}');
      expect(FlutterToolchain.hasFvmMarker(dir.path), isTrue);
      expect(FlutterToolchain.pinnedVersion(dir.path), '3.44.8');
    });

    test('legacy .fvm/fvm_config.json is still recognized', () {
      Directory('${dir.path}/.fvm').createSync();
      File('${dir.path}/.fvm/fvm_config.json')
          .writeAsStringSync('{"flutterSdkVersion": "3.29.0"}');
      expect(FlutterToolchain.hasFvmMarker(dir.path), isTrue);
      expect(FlutterToolchain.pinnedVersion(dir.path), '3.29.0');
    });

    test('malformed config never throws', () {
      File('${dir.path}/.fvmrc').writeAsStringSync('not json at all');
      expect(FlutterToolchain.hasFvmMarker(dir.path), isTrue);
      expect(FlutterToolchain.pinnedVersion(dir.path), isNull);
    });
  });

  group('resolution', () {
    test('--no-fvm always wins, even on an FVM project', () async {
      final dir = Directory.systemTemp.createTempSync('vgv_fvm_off_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/.fvmrc').writeAsStringSync('{"flutter": "3.44.8"}');
      final t = await FlutterToolchain.resolve(
          explicit: false, workingDirectory: dir.path);
      expect(t.useFvm, isFalse);
    });

    test('a project without markers auto-resolves to the global SDK', () async {
      final dir = Directory.systemTemp.createTempSync('vgv_fvm_auto_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final t = await FlutterToolchain.resolve(workingDirectory: dir.path);
      expect(t.useFvm, isFalse);
    });
  });
}
