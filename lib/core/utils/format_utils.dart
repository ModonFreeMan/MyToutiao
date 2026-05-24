class FormatUtils {
  const FormatUtils._();

  static String compactCount(int count) {
    if (count >= 10000) {
      final value = count / 10000;
      final text = value >= 10
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
      return '${text.replaceFirst(RegExp(r'\.0$'), '')}万';
    }

    return count.toString();
  }
}
