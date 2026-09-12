/// ISO 3166-1 alpha-2 code → regional-indicator emoji flag.
/// Works for every code: the emoji set covers A–Z, so no lookup table needed.
String countryFlag(String code) {
  if (code.length != 2) return '🌍';
  final upper = code.toUpperCase();
  return upper
      .split('')
      .map((c) => String.fromCharCode(c.codeUnitAt(0) + 0x1F1A5 - 0x41))
      .join();
}