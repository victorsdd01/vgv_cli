import 'package:test/test.dart';
import 'package:vgv_cli/core/utils/web_database_assets.dart';

void main() {
  test('sqlite3.wasm URL follows the resolved sqlite3 version', () {
    const lock = '''
packages:
  sqlite3:
    dependency: "direct main"
    description:
      name: sqlite3
      url: "https://pub.dev"
    source: hosted
    version: "3.8.0"
sdks:
  dart: ">=3.13.0 <4.0.0"
''';
    expect(
      WebDatabaseAssets.sqlite3WasmUrl(lock),
      'https://github.com/simolus3/sqlite3.dart/releases/download/'
      'sqlite3-3.8.0/sqlite3.wasm',
    );
  });

  test('null when sqlite3 is missing or the lock is unreadable', () {
    expect(
      WebDatabaseAssets.sqlite3WasmUrl(
          'packages:\n  drift:\n    version: "2.35.2"\n'),
      isNull,
    );
    expect(WebDatabaseAssets.sqlite3WasmUrl('not: [valid'), isNull);
  });

  test('the worker source is the drift entry point', () {
    expect(WebDatabaseAssets.workerSource,
        contains('WasmDatabase.workerMainForOpen()'));
  });
}
