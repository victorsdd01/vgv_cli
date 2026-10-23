import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:vgv_cli/core/templates/template_contents.dart';
import 'package:vgv_cli/core/templates/template_generator.dart';

void main() {
  test('writes the project test files with the package name', () async {
    final tmp = Directory.systemTemp.createTempSync('vgv_templates_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final project = p.join(tmp.path, 'shop_app');

    await TemplateGenerator.instance
        .generateProjectTemplates(projectName: 'shop_app', projectPath: project);

    final test = File(p.join(project, 'test', 'features', 'auth', 'data',
        'repositories', 'auth_repository_impl_test.dart'));
    expect(test.existsSync(), isTrue);
    final content = test.readAsStringSync();
    expect(content, contains("import 'package:shop_app/features/auth/"));
    expect(content, isNot(contains('{{project_name}}')));
  });

  test('login/register fail when the session cannot be persisted', () {
    final repository = TemplateContents.templates[
        'features/auth/data/repositories/auth_repository_impl.dart']!;
    // The success branch must go through _persistSession, which returns the
    // local save failure instead of ignoring it.
    expect(repository, contains('_persistSession,'));
    expect(repository, contains('return Left<Failure, UserEntity>(saveFailure);'));
    // No bare `await …saveUser(…);` statement that discards the result.
    expect(
      RegExp(r'^\s*await authLocalDataSource\.saveUser', multiLine: true)
          .hasMatch(repository),
      isFalse,
    );
  });

  test('removes flutter create\'s counter test, keeps a user\'s own', () async {
    final tmp = Directory.systemTemp.createTempSync('vgv_templates_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    Future<File> generateWith(String name, String widgetTest) async {
      final project = p.join(tmp.path, name);
      final file = File(p.join(project, 'test', 'widget_test.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync(widgetTest);
      await TemplateGenerator.instance
          .generateProjectTemplates(projectName: name, projectPath: project);
      return file;
    }

    final counter = await generateWith(
        'a', "testWidgets('Counter increments smoke test', (t) async {});");
    expect(counter.existsSync(), isFalse);

    final own = await generateWith('b', "testWidgets('my test', (t) async {});");
    expect(own.existsSync(), isTrue);
  });
}
