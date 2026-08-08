/// Minimal case converter (snake/pascal/camel) so `vgv gen` can accept a
/// feature/bloc/page name in any casing and emit idiomatic Dart identifiers.
class ReCase {
  ReCase(String input) : _words = _split(input);

  final List<String> _words;

  static List<String> _split(String input) {
    // Break on camelCase boundaries first, then on any non-alphanumeric run.
    final withBreaks = input
        .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(RegExp(r'([A-Z]+)([A-Z][a-z])'), (m) => '${m[1]} ${m[2]}');
    return withBreaks
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.toLowerCase())
        .toList();
  }

  String get snakeCase => _words.join('_');

  String get pascalCase => _words.map(_cap).join();

  String get camelCase {
    if (_words.isEmpty) return '';
    final p = pascalCase;
    return p[0].toLowerCase() + p.substring(1);
  }

  static String _cap(String w) =>
      w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}';
}
