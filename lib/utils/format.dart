String rupiah(dynamic value) {
  final n = double.tryParse(value?.toString() ?? '0') ?? 0;
  final s = n.toInt().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
    buffer.write(s[i]);
  }
  return 'Rp $buffer';
}
