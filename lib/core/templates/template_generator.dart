import 'dart:io';
import 'package:path/path.dart' as path;
import 'template_contents.dart';

class TemplateGenerator {
  static final TemplateGenerator _instance = TemplateGenerator._();
  TemplateGenerator._();
  static TemplateGenerator get instance => _instance;

  Future<void> generateProjectTemplates({
    required String projectName,
    required String projectPath,
  }) async {
    final templates = TemplateContents.getProcessedTemplates(projectName);
    final libPath = '$projectPath/lib';
    
    for (final entry in templates.entries) {
      final relativePath = entry.key;
      final content = entry.value;
      final filePath = path.join(libPath, relativePath);
      final file = File(filePath);
      
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    }

    final testTemplates = TemplateContents.getProcessedTestTemplates(projectName);
    for (final entry in testTemplates.entries) {
      final file = File(path.join(projectPath, 'test', entry.key));
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
    }

    // `flutter create`'s counter smoke test pumps the counter app the
    // templates replace, so it fails in every generated project (and blocks
    // the lefthook pre-push hook). Remove it only if it is still that test.
    final defaultTest = File(path.join(projectPath, 'test', 'widget_test.dart'));
    if (defaultTest.existsSync() &&
        defaultTest.readAsStringSync().contains('Counter increments smoke test')) {
      await defaultTest.delete();
    }
  }
}