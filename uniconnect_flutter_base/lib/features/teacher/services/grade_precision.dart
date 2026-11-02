bool hasGradePrecision(String representation) {
  final match = RegExp(r'^[+-]?(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$')
      .firstMatch(representation);
  if (match == null) return false;
  final fraction = match.group(2) ?? '';
  final digits = '${match.group(1)}$fraction';
  if (digits.isEmpty) return false;
  final significant = digits.replaceFirst(RegExp(r'0+$'), '');
  if (significant.isEmpty) return true;
  final exponent = int.tryParse(match.group(3) ?? '0');
  return exponent != null &&
      fraction.length - exponent - (digits.length - significant.length) <= 2;
}
