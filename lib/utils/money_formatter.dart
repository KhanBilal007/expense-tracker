import 'package:intl/intl.dart';

String formatMoneyWhole(num amount) {
  return NumberFormat('#,##0').format(amount.round());
}
