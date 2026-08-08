import 'recase.dart';

/// Generates freezed data **models** from an OpenAPI/Swagger spec's schemas and
/// an API **client** with one typed method per operation (stubbed bodies).
///
/// Pragmatic subset: `components.schemas` (OpenAPI 3) or `definitions`
/// (Swagger 2) become freezed models; `paths` become client methods whose
/// return types are resolved from the 2xx JSON response schema when possible.
class ApiGenerator {
  Map<String, String> build({
    required String name,
    required Map<dynamic, dynamic> spec,
    String? feature,
  }) {
    final schemas = _schemas(spec);
    final snake = ReCase(name).snakeCase;

    final String base;
    final String modelsImport;
    if (feature != null && feature.isNotEmpty) {
      final f = ReCase(feature).snakeCase;
      base = 'lib/features/$f/data';
      modelsImport = 'models/${snake}_models.dart';
    } else {
      base = 'lib/api/$snake';
      modelsImport = '${snake}_models.dart';
    }

    return <String, String>{
      '$base/models/${snake}_models.dart': _renderModels(snake, schemas),
      '$base/datasources/remote/${snake}_api.dart':
          _renderClient(name, spec, modelsImport),
    };
  }

  Map<dynamic, dynamic> _schemas(Map<dynamic, dynamic> spec) {
    final components = spec['components'];
    if (components is Map && components['schemas'] is Map) {
      return components['schemas'] as Map;
    }
    if (spec['definitions'] is Map) return spec['definitions'] as Map; // Swagger 2
    return const <dynamic, dynamic>{};
  }

  // ---- models -------------------------------------------------------------

  String _renderModels(String snake, Map<dynamic, dynamic> schemas) {
    final buf = StringBuffer()
      ..writeln("import 'package:freezed_annotation/freezed_annotation.dart';")
      ..writeln()
      ..writeln("part '${snake}_models.freezed.dart';")
      ..writeln("part '${snake}_models.g.dart';");
    schemas.forEach((rawName, schema) {
      if (schema is Map) {
        buf
          ..writeln()
          ..write(_renderModelClass(rawName.toString(), schema));
      }
    });
    return buf.toString();
  }

  String _renderModelClass(String rawName, Map<dynamic, dynamic> schema) {
    final cls = '${ReCase(rawName).pascalCase}Model';
    final props = (schema['properties'] is Map)
        ? schema['properties'] as Map
        : const <dynamic, dynamic>{};
    final required = <String>{
      ...((schema['required'] is List) ? (schema['required'] as List).map((e) => e.toString()) : const <String>[]),
    };

    final buf = StringBuffer()
      ..writeln('@freezed')
      ..writeln('abstract class $cls with _\$$cls {')
      ..writeln('  const factory $cls({');
    props.forEach((rawKey, propSchema) {
      final key = rawKey.toString();
      final field = ReCase(key).camelCase;
      final type = _dartType(propSchema is Map ? propSchema : const <dynamic, dynamic>{});
      final isReq = required.contains(key);
      final jsonKey = field == key ? '' : "@JsonKey(name: '$key') ";
      if (isReq) {
        buf.writeln('    ${jsonKey}required $type $field,');
      } else if (type == 'dynamic') {
        buf.writeln('    $jsonKey$type $field,');
      } else {
        buf.writeln('    $jsonKey$type? $field,');
      }
    });
    buf
      ..writeln('  }) = _$cls;')
      ..writeln()
      ..writeln('  factory $cls.fromJson(Map<String, dynamic> json) => _\$${cls}FromJson(json);')
      ..writeln('}');
    return buf.toString();
  }

  /// Maps an OpenAPI property schema to a Dart type (no trailing `?`).
  String _dartType(Map<dynamic, dynamic> schema) {
    final ref = schema[r'$ref'];
    if (ref is String) return '${_refName(ref)}Model';

    final type = schema['type']?.toString();
    switch (type) {
      case 'integer':
        return 'int';
      case 'number':
        return 'double';
      case 'boolean':
        return 'bool';
      case 'string':
        final fmt = schema['format']?.toString();
        return (fmt == 'date' || fmt == 'date-time') ? 'DateTime' : 'String';
      case 'array':
        final items = schema['items'];
        final elem = items is Map ? _dartType(items) : 'dynamic';
        return 'List<$elem>';
      case 'object':
        return 'Map<String, dynamic>';
      default:
        return 'dynamic';
    }
  }

  String _refName(String ref) => ReCase(ref.split('/').last).pascalCase;

  // ---- client -------------------------------------------------------------

  String _renderClient(String name, Map<dynamic, dynamic> spec, String modelsImport) {
    final cls = '${ReCase(name).pascalCase}Api';
    final paths = (spec['paths'] is Map) ? spec['paths'] as Map : const <dynamic, dynamic>{};
    final buf = StringBuffer()
      ..writeln("import '../../$modelsImport';")
      ..writeln()
      ..writeln('/// Generated API client. Method bodies are stubs — wire your')
      ..writeln('/// HTTP layer (Dio/http) where marked.')
      ..writeln('class $cls {')
      ..writeln('  $cls();');

    const methods = <String>['get', 'post', 'put', 'patch', 'delete'];
    paths.forEach((rawPath, ops) {
      if (ops is! Map) return;
      final path = rawPath.toString();
      ops.forEach((rawMethod, op) {
        final method = rawMethod.toString().toLowerCase();
        if (!methods.contains(method) || op is! Map) return;
        buf
          ..writeln()
          ..write(_renderMethod(method, path, op));
      });
    });
    buf.writeln('}');
    return buf.toString();
  }

  String _renderMethod(String method, String path, Map<dynamic, dynamic> op) {
    final opId = op['operationId']?.toString();
    final methodName = opId != null && opId.isNotEmpty
        ? ReCase(opId).camelCase
        : ReCase('$method $path').camelCase;
    final returnType = _responseType(op);
    return '  /// ${method.toUpperCase()} $path\n'
        '  Future<$returnType> $methodName() async {\n'
        "    throw UnimplementedError('TODO: ${method.toUpperCase()} $path');\n"
        '  }\n';
  }

  String _responseType(Map<dynamic, dynamic> op) {
    final responses = op['responses'];
    if (responses is! Map) return 'void';
    for (final code in <String>['200', '201', '2XX', 'default']) {
      final r = responses[code];
      if (r is Map) {
        // OpenAPI 3: responses.<code>.content.application/json.schema
        final content = r['content'];
        if (content is Map && content['application/json'] is Map) {
          final schema = (content['application/json'] as Map)['schema'];
          if (schema is Map) return _dartType(schema);
        }
        // Swagger 2: responses.<code>.schema
        if (r['schema'] is Map) return _dartType(r['schema'] as Map);
      }
    }
    return 'void';
  }
}
