extension StringExtensions on String {
  String get initials {
    if (isEmpty) return '?';
    final String localPart = split('@').first;
    if (localPart.length >= 2) {
      return localPart.substring(0, 2).toUpperCase();
    }
    return localPart.toUpperCase();
  }

  String get nameInitials {
    if (isEmpty) return '?';
    final List<String> words = trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }
    if (words.first.length >= 2) {
      return words.first.substring(0, 2).toUpperCase();
    }
    return words.first.toUpperCase();
  }

  String get toTitleCase {
    if (isEmpty) return this;
    return split(' ')
        .map((String word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  bool get isValidEmail =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);

  String truncate(int maxLength, {String suffix = '...'}) =>
      length <= maxLength ? this : '${substring(0, maxLength)}$suffix';
}
