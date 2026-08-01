import 'package:intl/intl.dart';

final _rupee = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _rupee0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

String money(num v) => _rupee.format(v);
String money0(num v) => _rupee0.format(v);
