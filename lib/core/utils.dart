import 'package:intl/intl.dart' show NumberFormat, DateFormat;

final _moneyFmt = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('yyyy-MM-dd  HH:mm');

String formatMoney(num v) => '${_moneyFmt.format(v)} \$';

String formatDate(DateTime d) => _dateFmt.format(d);

String formatQty(double q) =>
    q % 1 == 0 ? q.toInt().toString() : q.toString();

/// Превращает текст в число. Понимает арабские цифры и запятую.
double? parseNumber(String s) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  var t = s.trim().replaceAll('٫', '.').replaceAll(',', '.');
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(arabic[i], '$i');
  }
  return double.tryParse(t);
}