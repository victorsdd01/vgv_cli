import 'dart:io';
import 'package:path/path.dart' as path;

void main() async {
  final templatesDir = Directory('lib/core/templates/blocs');
  if (!await templatesDir.exists()) {
    print('Templates directory not found!');
    exit(1);
  }

  final outputFile = File('lib/core/templates/template_contents.dart');
  final variablesBuffer = StringBuffer();
  final mapBuffer = StringBuffer();
  final templateFiles = <String, String>{};

  await _collectTemplates(templatesDir, templatesDir.path, templateFiles);

  for (final entry in templateFiles.entries) {
    final relativePath = entry.key;
    final content = entry.value;
    final varName = _toVarName(relativePath);
    
    variablesBuffer.writeln('  static const String _$varName = r\'\'\'$content\'\'\';');
    mapBuffer.writeln('    \'$relativePath\': _$varName,');
  }

  final buffer = StringBuffer();
  buffer.writeln('class TemplateContents {');
  buffer.writeln('  TemplateContents._();');
  buffer.writeln('');
  buffer.write(variablesBuffer.toString());
  buffer.writeln('');
  buffer.writeln('  static Map<String, String> get templates => {');
  buffer.write(mapBuffer.toString());
  buffer.writeln('  };');
  buffer.writeln('');
  buffer.writeln('  static String _processTemplate(String content, String projectName) {');
  buffer.writeln('    final String titleCaseName = projectName.split(\'_\').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : \'\').join(\' \');');
  buffer.writeln('    return content');
  buffer.writeln('        .replaceAll(\'{{project_name}}\', projectName)');
  buffer.writeln('        .replaceAll(\'{{PROJECT_NAME}}\', titleCaseName)');
  buffer.writeln('        .replaceAll(\'template_project\', projectName);');
  buffer.writeln('  }');
  buffer.writeln('');
  buffer.writeln('  static Map<String, String> getProcessedTemplates(String projectName) {');
  buffer.writeln('    return templates.map((key, value) => MapEntry(key, _processTemplate(value, projectName)));');
  buffer.writeln('  }');
  buffer.writeln('}');

  await outputFile.writeAsString(buffer.toString());
  print('✅ Generated template_contents.dart with ${templateFiles.length} templates!');
}

Future<void> _collectTemplates(Directory dir, String basePath, Map<String, String> templates) async {
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File) {
      final fileName = path.basename(entity.path);
      final relativePath = path.relative(entity.path, from: basePath);
      
      if (fileName == 'pubspec.yaml' || 
          fileName == 'pubspec.lock' || 
          fileName == 'README.md' ||
          fileName.contains('.stamp') ||
          fileName.contains('outputs.json') ||
          fileName.contains('.g.dart') ||
          relativePath.startsWith('.dart_tool') ||
          relativePath.startsWith('.flutter-plugins') ||
          relativePath.startsWith('build/')) {
        continue;
      }

      final content = await entity.readAsString();
      templates[relativePath] = content;
    }
  }
}

String _toVarName(String path) {
  return path
      .replaceAll('/', '_')
      .replaceAll('.', '_')
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
}


