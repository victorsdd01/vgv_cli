/// Shared ANSI color constants for consistent CLI output styling.
class AnsiColors {
  // Modifiers
  static const String reset = '\x1B[0m';
  static const String bold = '\x1B[1m';
  static const String dim = '\x1B[2m';

  // Standard colors
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String cyan = '\x1B[36m';

  // Bright colors
  static const String brightRed = '\x1B[91m';
  static const String brightGreen = '\x1B[92m';
  static const String brightYellow = '\x1B[93m';
  static const String brightMagenta = '\x1B[95m';
  static const String brightCyan = '\x1B[96m';
}
