import 'package:intl/intl.dart';

/// Montos en Bs con punto de miles y coma decimal: «Bs 60», «Bs 1.080,50» (Idiomas y nomenclatura).
String bs(num? monto, {bool decimales = false}) {
  final m = (monto ?? 0).toDouble();
  final signo = m < 0 ? '− ' : '';
  final abs = m.abs();
  final entero = abs == abs.truncateToDouble() && !decimales;
  final f = NumberFormat(entero ? '#,##0' : '#,##0.00', 'en_US').format(abs);
  final txt = f.replaceAll(',', '#').replaceAll('.', ',').replaceAll('#', '.');
  return '${signo}Bs $txt';
}

num aNum(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// «Miércoles 27 de mayo · 10:00», en la zona horaria del teléfono (Q-CU-GEN-04).
String fechaHora(DateTime d) => _cap(DateFormat("EEEE d 'de' MMMM · HH:mm", 'es').format(d.toLocal()));

/// «Miércoles 27 de mayo»
String fechaLarga(DateTime d) => _cap(DateFormat("EEEE d 'de' MMMM", 'es').format(d.toLocal()));

/// «21 may»
String fechaCorta(DateTime d) => DateFormat('d MMM', 'es').format(d.toLocal()).replaceAll('.', '');

String hora(DateTime d) => DateFormat('HH:mm', 'es').format(d.toLocal());

/// Separa «Apellidos Nombres» (un alumno por línea, Q-CU-CUR-05). Con 2 palabras: 1 apellido y 1 nombre;
/// con 3 o más: los 2 primeros son apellidos (propuesta del equipo: se corrige luego con «Editar»).
({String apellidos, String nombres})? separarNombre(String linea) {
  final p = linea.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (p.length < 2) return null;
  final nAp = p.length == 2 ? 1 : 2;
  return (apellidos: p.take(nAp).join(' '), nombres: p.skip(nAp).join(' '));
}
