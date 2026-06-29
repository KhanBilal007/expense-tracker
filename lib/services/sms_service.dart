import 'package:another_telephony/telephony.dart';
import '../db/database_helper.dart';
import 'sms_parser.dart';

/// Item 2: Automatic PhonePe/UPI SMS reading using telephony package
class SmsService {
  static final SmsService _instance = SmsService._();
  factory SmsService() => _instance;
  SmsService._();

  final _telephony = Telephony.instance;
  final _db = DatabaseHelper();

  Future<bool> requestPermission() async {
    return await _telephony.requestPhoneAndSmsPermissions ?? false;
  }

  /// Start listening to incoming SMS in background
  void startListening(void Function(String msg) onProcessed) {
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        final body = message.body ?? '';
        await _processMessage(body, onProcessed);
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );
  }

  Future<void> _processMessage(String body, void Function(String) onProcessed) async {
    final parsed = SmsParser.parse(body);
    if (parsed == null) return;
    final defAccId = await _db.getDefaultAccountId();
    final accounts = await _db.getAccounts();
    if (accounts.isEmpty) return;
    final accountId = (defAccId != null && accounts.any((a) => a['id'] == defAccId))
        ? defAccId
        : accounts.first['id'] as int;
    final acc = accounts.firstWhere((a) => a['id'] == accountId);
    final amount = (parsed['amount'] as num).toDouble();
    final type   = parsed['type'] as String;
    final bal    = (acc['balance'] as num).toDouble();
    final newBal = type == 'expense' ? bal - amount : bal + amount;
    await _db.updateAccountBalance(accountId, newBal);
    // Auto-match category via rules
    final catId = await _db.matchRule(parsed['merchant'] as String);
    await _db.insertTransaction({
      'account_id':  accountId,
      'category_id': catId,
      'type':        type,
      'amount':      amount,
      'description': parsed['merchant'],
      'date':        DateTime.now().toIso8601String(),
      'balance_after': newBal,
    });
    onProcessed('${parsed['merchant']} ₹${parsed['amount']}');
  }

  /// Also read recent SMS on demand (last 50 PhonePe messages)
  Future<List<Map<String, dynamic>>> readRecentUpiSms() async {
    final granted = await requestPermission();
    if (!granted) return [];
    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      filter: SmsFilter.where(SmsColumn.ADDRESS).like('%PhonePe%')
          .or(SmsColumn.ADDRESS).like('%HDFCBK%')
          .or(SmsColumn.ADDRESS).like('%SBIINB%')
          .or(SmsColumn.ADDRESS).like('%ICICI%')
          .or(SmsColumn.ADDRESS).like('%UPI%'),
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
    final results = <Map<String, dynamic>>[];
    for (final m in messages.take(50)) {
      final parsed = SmsParser.parse(m.body ?? '');
      if (parsed != null) {
        results.add({...parsed, 'raw': m.body, 'date': m.dateSent});
      }
    }
    return results;
  }
}

// Top-level function required by telephony for background handling
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  final body = message.body ?? '';
  final parsed = SmsParser.parse(body);
  if (parsed == null) return;
  final db = DatabaseHelper();
  final defAccId = await db.getDefaultAccountId();
  final accounts = await db.getAccounts();
  if (accounts.isEmpty) return;
  final accountId = (defAccId != null && accounts.any((a) => a['id'] == defAccId))
      ? defAccId
      : accounts.first['id'] as int;
  final acc = accounts.firstWhere((a) => a['id'] == accountId);
  final amount = (parsed['amount'] as num).toDouble();
  final type   = parsed['type'] as String;
  final bal    = (acc['balance'] as num).toDouble();
  final newBal = type == 'expense' ? bal - amount : bal + amount;
  await db.updateAccountBalance(accountId, newBal);
  final catId = await db.matchRule(parsed['merchant'] as String);
  await db.insertTransaction({
    'account_id': accountId, 'category_id': catId, 'type': type,
    'amount': amount, 'description': parsed['merchant'],
    'date': DateTime.now().toIso8601String(), 'balance_after': newBal,
  });
}
