import 'recase.dart';

/// Generates a freezed data **model** (with `fromJson`) and a matching domain
/// **entity** (with `fromJson` + `fromModel`) from a sample JSON value,
/// following the vgv project conventions (see `user_model.dart` /
/// `user_entity.dart`). Nested JSON objects become nested freezed classes;
/// arrays of objects become `List<...>` of a generated element class.
class ModelGenerator {
  /// [name] is the root class base (e.g. `User`). [json] is a decoded JSON
  /// value (must be a `Map`). When [feature] is set the files land under
  /// `lib/features/<feature>/{data/models,domain/entities}`; otherwise under
  /// `lib/models/`. Returns `<relative path>` -> content.
  Map<String, String> build({
    required String name,
    required Object? json,
    String? feature,
  }) {
    if (json is! Map) {
      throw const FormatException(
          'Top-level JSON must be an object ({ ... }).');
    }
    final rootBase = ReCase(name).pascalCase;
    final classes = <_Class>[];
    final seen = <String>{};

    _collect(rootBase, Map<String, dynamic>.from(json), classes, seen);

    final modelSnake = ReCase(name).snakeCase;
    final String modelPath;
    final String entityPath;
    final String entityToModelImport;
    if (feature != null && feature.isNotEmpty) {
      final f = ReCase(feature).snakeCase;
      modelPath = 'lib/features/$f/data/models/${modelSnake}_model.dart';
      entityPath = 'lib/features/$f/domain/entities/${modelSnake}_entity.dart';
      entityToModelImport = '../../data/models/${modelSnake}_model.dart';
    } else {
      modelPath = 'lib/models/${modelSnake}_model.dart';
      entityPath = 'lib/models/${modelSnake}_entity.dart';
      entityToModelImport = '${modelSnake}_model.dart';
    }

    return <String, String>{
      modelPath: _renderModelFile(modelSnake, classes),
      entityPath: _renderEntityFile(modelSnake, classes, entityToModelImport),
    };
  }

  // ---- inference ----------------------------------------------------------

  void _collect(
    String base,
    Map<String, dynamic> map,
    List<_Class> out,
    Set<String> seen,
  ) {
    var unique = base;
    var i = 2;
    while (seen.contains(unique)) {
      unique = '$base$i';
      i++;
    }
    seen.add(unique);

    final fields = <_Field>[];
    map.forEach((key, value) {
      fields.add(_infer(key.toString(), value, out, seen));
    });
    out.add(_Class(unique, fields));
  }

  _Field _infer(
    String key,
    Object? value,
    List<_Class> out,
    Set<String> seen,
  ) {
    final name = ReCase(key).camelCase;
    if (value == null) {
      return _Field(name: name, type: 'dynamic', nullable: true);
    }
    if (value is bool) return _Field(name: name, type: 'bool');
    if (value is int) return _Field(name: name, type: 'int');
    if (value is double) return _Field(name: name, type: 'double');
    if (value is num) return _Field(name: name, type: 'double');
    if (value is String) return _Field(name: name, type: 'String');

    if (value is Map) {
      final base = ReCase(key).pascalCase;
      final classBase = _findOrCollect(base, value, out, seen);
      return _Field(name: name, type: classBase, nested: true);
    }

    if (value is List) {
      if (value.isEmpty) {
        return _Field(name: name, type: 'List<dynamic>', isList: true);
      }
      final first = value.first;
      if (first is Map) {
        final elemBase = _elementClassName(key);
        final classBase = _findOrCollect(elemBase, first, out, seen);
        return _Field(
            name: name, type: classBase, isList: true, nested: true);
      }
      final elemType = _primitive(first);
      return _Field(name: name, type: 'List<$elemType>', isList: true);
    }

    return _Field(name: name, type: 'dynamic', nullable: true);
  }

  /// Registers a nested class (dedup by resolved unique base) and returns the
  /// unique base name to reference.
  String _findOrCollect(
    String base,
    Map value,
    List<_Class> out,
    Set<String> seen,
  ) {
    final before = seen.toSet();
    _collect(base, Map<String, dynamic>.from(value), out, seen);
    // The base actually used is the last one added.
    final added = seen.difference(before);
    return added.isNotEmpty ? out.last.base : base;
  }

  String _elementClassName(String key) {
    final base = ReCase(key).pascalCase;
    if (base.length > 1 && base.endsWith('s')) {
      return base.substring(0, base.length - 1);
    }
    return '${base}Item';
  }

  String _primitive(Object? v) {
    if (v is bool) return 'bool';
    if (v is int) return 'int';
    if (v is double) return 'double';
    if (v is num) return 'double';
    if (v is String) return 'String';
    return 'dynamic';
  }

  // ---- rendering ----------------------------------------------------------

  String _renderModelFile(String snake, List<_Class> classes) {
    final buf = StringBuffer()
      ..writeln("import 'package:freezed_annotation/freezed_annotation.dart';")
      ..writeln()
      ..writeln("part '${snake}_model.freezed.dart';")
      ..writeln("part '${snake}_model.g.dart';");
    for (final c in classes) {
      buf
        ..writeln()
        ..write(_renderClass(c, suffix: 'Model'));
    }
    return buf.toString();
  }

  String _renderEntityFile(String snake, List<_Class> classes, String import) {
    final buf = StringBuffer()
      ..writeln("import 'package:freezed_annotation/freezed_annotation.dart';")
      ..writeln("import '$import';")
      ..writeln()
      ..writeln("part '${snake}_entity.freezed.dart';")
      ..writeln("part '${snake}_entity.g.dart';");
    for (final c in classes) {
      buf
        ..writeln()
        ..write(_renderClass(c, suffix: 'Entity', fromModel: true));
    }
    return buf.toString();
  }

  String _renderClass(_Class c, {required String suffix, bool fromModel = false}) {
    final cls = '${c.base}$suffix';
    final buf = StringBuffer()
      ..writeln('@freezed')
      ..writeln('abstract class $cls with _\$$cls {')
      ..writeln('  const factory $cls({');
    for (final f in c.fields) {
      buf.writeln('    ${_fieldDecl(f, suffix)}');
    }
    buf
      ..writeln('  }) = _$cls;')
      ..writeln()
      ..writeln(
          '  factory $cls.fromJson(Map<String, dynamic> json) => _\$${cls}FromJson(json);');

    if (fromModel) {
      final modelCls = '${c.base}Model';
      buf
        ..writeln()
        ..writeln('  factory $cls.fromModel($modelCls model) => $cls(');
      for (final f in c.fields) {
        buf.writeln('    ${_fromModelAssign(f)}');
      }
      buf.writeln('  );');
    }

    buf.writeln('}');
    return buf.toString();
  }

  String _fieldDecl(_Field f, String suffix) {
    final type = _resolvedType(f, suffix);
    if (f.nullable) return '$type ${f.name},';
    return 'required $type ${f.name},';
  }

  String _resolvedType(_Field f, String suffix) {
    if (f.nested && f.isList) return 'List<${f.type}$suffix>';
    if (f.nested) return '${f.type}$suffix';
    return f.type; // primitives + List<primitive> already complete
  }

  String _fromModelAssign(_Field f) {
    if (f.nested && f.isList) {
      return '${f.name}: model.${f.name}.map(${f.type}Entity.fromModel).toList(),';
    }
    if (f.nested) {
      if (f.nullable) {
        return '${f.name}: model.${f.name} == null ? null : ${f.type}Entity.fromModel(model.${f.name}!),';
      }
      return '${f.name}: ${f.type}Entity.fromModel(model.${f.name}),';
    }
    return '${f.name}: model.${f.name},';
  }
}

class _Class {
  _Class(this.base, this.fields);
  final String base;
  final List<_Field> fields;
}

class _Field {
  _Field({
    required this.name,
    required this.type,
    this.nullable = false,
    this.isList = false,
    this.nested = false,
  });

  final String name;
  final String type; // primitive/full type, OR nested class base (no suffix)
  final bool nullable;
  final bool isList;
  final bool nested;
}
