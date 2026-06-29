import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  static Database? _db;

  Future<Database> get database async { _db ??= await _initDB(); return _db!; }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'expense_v4.db');
    return openDatabase(path, version: 5, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int v) async {
    await db.execute('''CREATE TABLE accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, balance REAL DEFAULT 0)''');
    await db.execute('''CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE recurring(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, amount REAL NOT NULL, frequency TEXT NOT NULL, next_date TEXT NOT NULL, account_id INTEGER, category_id INTEGER, type TEXT NOT NULL DEFAULT 'expense')''');
    await db.execute('''CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER, category_id INTEGER, type TEXT NOT NULL, amount REAL NOT NULL, description TEXT, date TEXT NOT NULL, balance_after REAL, is_recurring INTEGER DEFAULT 0)''');
    await db.execute('''CREATE TABLE transfers(id INTEGER PRIMARY KEY AUTOINCREMENT, from_account INTEGER, to_account INTEGER, amount REAL NOT NULL, date TEXT NOT NULL, note TEXT)''');
    await db.execute('''CREATE TABLE budgets(id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER NOT NULL, limit_amount REAL NOT NULL, month TEXT NOT NULL, UNIQUE(category_id, month))''');
    await db.execute('''CREATE TABLE rules(id INTEGER PRIMARY KEY AUTOINCREMENT, keyword TEXT NOT NULL, category_id INTEGER NOT NULL)''');
    for (var cat in ['Food','Transport','Shopping','Bills','Health','Entertainment','Petrol','Milk','Tea','Other']) {
      await db.insert('categories', {'name': cat});
    }
    await db.insert('accounts', {'name': 'Cash',  'balance': 0.0});
    await db.insert('accounts', {'name': 'Bank',  'balance': 0.0});
    await db.insert('accounts', {'name': 'PhonePe Wallet', 'balance': 0.0});
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 5) {
      await db.rawUpdate(
        "UPDATE transactions SET amount = ABS(amount) WHERE type = 'transfer_out' AND amount < 0",
      );
    }
  }

  Future<int?> getDefaultAccountId() async => (await SharedPreferences.getInstance()).getInt('default_account_id');
  Future<void> setDefaultAccountId(int id) async => (await SharedPreferences.getInstance()).setInt('default_account_id', id);

  Future<List<Map<String, dynamic>>> getAccounts() async => (await database).query('accounts', orderBy: 'name ASC');
  Future<Map<String, dynamic>?> getAccountById(int id) async { final r = await (await database).query('accounts', where: 'id=?', whereArgs: [id]); return r.isNotEmpty ? r.first : null; }
  Future<int> insertAccount(String name, double balance) async => (await database).insert('accounts', {'name': name, 'balance': balance});
  Future<void> updateAccount(int id, String name) async => (await database).update('accounts', {'name': name}, where: 'id=?', whereArgs: [id]);
  Future<void> updateAccountBalance(int id, double balance) async => (await database).update('accounts', {'balance': balance}, where: 'id=?', whereArgs: [id]);
  Future<bool> deleteAccount(int id) async {
    final db = await database;
    final c = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM transactions WHERE account_id=?', [id]));
    if ((c ?? 0) > 0) return false;
    await db.delete('accounts', where: 'id=?', whereArgs: [id]);
    return true;
  }

  Future<List<Map<String, dynamic>>> getCategories() async => (await database).query('categories', orderBy: 'name ASC');
  Future<int> insertCategory(String name) async => (await database).insert('categories', {'name': name});
  Future<void> updateCategory(int id, String name) async => (await database).update('categories', {'name': name}, where: 'id=?', whereArgs: [id]);
  Future<void> deleteCategory(int id) async => (await database).delete('categories', where: 'id=?', whereArgs: [id]);

  Future<List<Map<String, dynamic>>> getTransactions({int? limit, String? type, int? accountId, int? categoryId, DateTime? from, DateTime? to}) async {
    final db = await database;
    final wheres = <String>[]; final args = <dynamic>[];
    if (type != null)       { wheres.add("t.type=?");            args.add(type); }
    if (accountId != null)  { wheres.add("t.account_id=?");      args.add(accountId); }
    if (categoryId != null) { wheres.add("t.category_id=?");     args.add(categoryId); }
    if (from != null)       { wheres.add("t.date >= ?");         args.add(from.toIso8601String()); }
    if (to != null)         { wheres.add("t.date <= ?");         args.add(to.add(const Duration(days:1)).toIso8601String()); }
    final where = wheres.isNotEmpty ? 'WHERE ${wheres.join(' AND ')}' : '';
    final lim   = limit != null ? 'LIMIT $limit' : '';
    return db.rawQuery('''SELECT t.*, a.name as account_name, c.name as category_name FROM transactions t LEFT JOIN accounts a ON t.account_id=a.id LEFT JOIN categories c ON t.category_id=c.id $where ORDER BY t.date DESC $lim''', args);
  }

  Future<List<Map<String, dynamic>>> getTransactionsByMonth(String month, {int? accountId}) async {
    final db = await database;
    final args = <dynamic>['$month%'];
    final accWhere = accountId != null ? 'AND t.account_id=$accountId' : '';
    return db.rawQuery('''SELECT t.*, a.name as account_name, c.name as category_name FROM transactions t LEFT JOIN accounts a ON t.account_id=a.id LEFT JOIN categories c ON t.category_id=c.id WHERE t.date LIKE ? $accWhere ORDER BY t.date DESC''', args);
  }

  Future<int> insertTransaction(Map<String, dynamic> data) async => (await database).insert('transactions', data);

  Future<void> doTransfer({
    required int fromId,
    required int toId,
    required double amount,
    String? note,
  }) async {
    final db = await database;
    final transferAmount = amount.abs();

    if (transferAmount <= 0) {
      throw Exception('Invalid transfer amount');
    }

    if (fromId == toId) {
      throw Exception('Cannot transfer to same account');
    }

    await db.transaction((txn) async {
      final fromRows = await txn.query(
        'accounts',
        where: 'id=?',
        whereArgs: [fromId],
      );

      final toRows = await txn.query(
        'accounts',
        where: 'id=?',
        whereArgs: [toId],
      );

      if (fromRows.isEmpty || toRows.isEmpty) {
        throw Exception('Account not found');
      }

      final fromAcc = fromRows.first;
      final toAcc = toRows.first;

      final oldFromBal = (fromAcc['balance'] as num).toDouble();
      final oldToBal = (toAcc['balance'] as num).toDouble();

      if (transferAmount > oldFromBal) {
        throw Exception('Insufficient balance');
      }

      final newFromBal = oldFromBal - transferAmount;
      final newToBal = oldToBal + transferAmount;

      await txn.update(
        'accounts',
        {'balance': newFromBal},
        where: 'id=?',
        whereArgs: [fromId],
      );

      await txn.update(
        'accounts',
        {'balance': newToBal},
        where: 'id=?',
        whereArgs: [toId],
      );

      final now = DateTime.now().toIso8601String();
      final desc = (note != null && note.trim().isNotEmpty)
          ? ' (${note.trim()})'
          : '';

      await txn.insert('transactions', {
        'account_id': fromId,
        'category_id': null,
        'type': 'transfer_out',
        'amount': transferAmount,
        'description': 'Transfer to ${toAcc['name']}$desc',
        'date': now,
        'balance_after': newFromBal,
      });

      await txn.insert('transactions', {
        'account_id': toId,
        'category_id': null,
        'type': 'transfer_in',
        'amount': transferAmount,
        'description': 'Transfer from ${fromAcc['name']}$desc',
        'date': now,
        'balance_after': newToBal,
      });
    });
  }
  Future<List<Map<String, dynamic>>> getBudgets(String month) async => (await database).rawQuery('''SELECT b.*, c.name as category_name FROM budgets b LEFT JOIN categories c ON b.category_id=c.id WHERE b.month=?''', [month]);
  Future<void> upsertBudget(int categoryId, double limit, String month) async => (await database).rawInsert('INSERT INTO budgets(category_id,limit_amount,month) VALUES(?,?,?) ON CONFLICT(category_id,month) DO UPDATE SET limit_amount=excluded.limit_amount', [categoryId, limit, month]);
  Future<void> deleteBudget(int id) async => (await database).delete('budgets', where: 'id=?', whereArgs: [id]);
  Future<Map<String, dynamic>?> getBudgetForCategory(int categoryId, String month) async { final r = await (await database).query('budgets', where: 'category_id=? AND month=?', whereArgs: [categoryId, month]); return r.isNotEmpty ? r.first : null; }

  Future<List<Map<String, dynamic>>> getRecurring() async => (await database).rawQuery('''SELECT r.*, a.name as account_name, c.name as category_name FROM recurring r LEFT JOIN accounts a ON r.account_id=a.id LEFT JOIN categories c ON r.category_id=c.id ORDER BY r.next_date ASC''');
  Future<int> insertRecurring(Map<String, dynamic> data) async => (await database).insert('recurring', data);
  Future<void> updateRecurringNextDate(int id, String nextDate) async => (await database).update('recurring', {'next_date': nextDate}, where: 'id=?', whereArgs: [id]);
  Future<void> deleteRecurring(int id) async => (await database).delete('recurring', where: 'id=?', whereArgs: [id]);

  Future<List<String>> processDueRecurring() async {
    final all = await getRecurring(); final now = DateTime.now(); final processed = <String>[];
    for (final r in all) {
      final nextDate = DateTime.tryParse(r['next_date'] ?? '');
      if (nextDate == null || nextDate.isAfter(now)) continue;
      final accountId = r['account_id'] as int?; if (accountId == null) continue;
      final acc = await getAccountById(accountId); if (acc == null) continue;
      final amount = (r['amount'] as num).toDouble(); final type = r['type'] as String? ?? 'expense';
      final bal = (acc['balance'] as num).toDouble(); final newBal = type == 'expense' ? bal - amount : bal + amount;
      await updateAccountBalance(accountId, newBal);
      await insertTransaction({'account_id': accountId, 'category_id': r['category_id'], 'type': type, 'amount': amount, 'description': r['name'], 'date': now.toIso8601String(), 'balance_after': newBal, 'is_recurring': 1});
      final freq = r['frequency'] as String? ?? 'Monthly';
      DateTime adv;
      switch (freq) {
        case 'Daily':  adv = nextDate.add(const Duration(days: 1)); break;
        case 'Weekly': adv = nextDate.add(const Duration(days: 7)); break;
        case 'Yearly': adv = DateTime(nextDate.year+1, nextDate.month, nextDate.day); break;
        default:       adv = DateTime(nextDate.year, nextDate.month+1, nextDate.day);
      }
      await updateRecurringNextDate(r['id'] as int, adv.toIso8601String());
      processed.add(r['name'] as String);
    }
    return processed;
  }

  Future<List<Map<String, dynamic>>> getRules() async => (await database).rawQuery('''SELECT r.*, c.name as category_name FROM rules r LEFT JOIN categories c ON r.category_id=c.id ORDER BY r.keyword ASC''');
  Future<int> insertRule(String keyword, int categoryId) async => (await database).insert('rules', {'keyword': keyword.toLowerCase().trim(), 'category_id': categoryId});
  Future<void> deleteRule(int id) async => (await database).delete('rules', where: 'id=?', whereArgs: [id]);
  Future<int?> matchRule(String description) async {
    final rules = await (await database).query('rules');
    final lower = description.toLowerCase();
    for (final rule in rules) { if (lower.contains(rule['keyword'] as String)) return rule['category_id'] as int; }
    return null;
  }

  Future<double> getTotalBalance() async { final r = await (await database).rawQuery('SELECT SUM(balance) as total FROM accounts'); return (r.first['total'] as num?)?.toDouble() ?? 0.0; }
  Future<double> getTodayExpense() async { final today = DateTime.now().toIso8601String().substring(0,10); final r = await (await database).rawQuery("SELECT SUM(amount) as total FROM transactions WHERE type='expense' AND date LIKE ?", ['$today%']); return (r.first['total'] as num?)?.toDouble() ?? 0.0; }
  Future<double> getMonthlyExpense(String month, {int? accountId}) async { final where = accountId != null ? "AND account_id=$accountId" : ''; final r = await (await database).rawQuery("SELECT SUM(amount) as total FROM transactions WHERE type='expense' AND date LIKE ? $where", ['$month%']); return (r.first['total'] as num?)?.toDouble() ?? 0.0; }
  Future<double> getMonthlyIncome(String month, {int? accountId}) async { final where = accountId != null ? "AND account_id=$accountId" : ''; final r = await (await database).rawQuery("SELECT SUM(amount) as total FROM transactions WHERE type='income' AND date LIKE ? $where", ['$month%']); return (r.first['total'] as num?)?.toDouble() ?? 0.0; }
  Future<Map<int, double>> getCategoryExpensesById(String month) async { final r = await (await database).rawQuery("SELECT category_id, SUM(amount) as total FROM transactions WHERE type='expense' AND date LIKE ? AND category_id IS NOT NULL GROUP BY category_id", ['$month%']); final map = <int,double>{}; for (final row in r) { map[row['category_id'] as int] = (row['total'] as num).toDouble(); } return map; }
  Future<Map<String, double>> getCategoryExpenses(String month, {int? accountId}) async { final where = accountId != null ? "AND t.account_id=$accountId" : ''; final r = await (await database).rawQuery("SELECT c.name as cat_name, SUM(t.amount) as total FROM transactions t LEFT JOIN categories c ON t.category_id=c.id WHERE t.type='expense' AND t.date LIKE ? $where GROUP BY t.category_id", ['$month%']); final map = <String,double>{}; for (final row in r) { map[row['cat_name'] as String? ?? 'Unknown'] = (row['total'] as num).toDouble(); } return map; }
  Future<double> getCategorySpentThisMonth(int categoryId, String month) async { final r = await (await database).rawQuery("SELECT SUM(amount) as total FROM transactions WHERE type='expense' AND category_id=? AND date LIKE ?", [categoryId, '$month%']); return (r.first['total'] as num?)?.toDouble() ?? 0.0; }

  Future<double> getRangeExpense(String from, String to, {int? accountId}) async { final where = accountId != null ? "AND account_id=$accountId" : ''; final r = await (await database).rawQuery("SELECT SUM(amount) as total FROM transactions WHERE type='expense' AND date >= ? AND date <= ? $where", [from, to]); return (r.first['total'] as num?)?.toDouble() ?? 0.0; }
  Future<Map<String, double>> getRangeCategoryExpenses(String from, String to, {int? accountId}) async { final where = accountId != null ? "AND t.account_id=$accountId" : ''; final r = await (await database).rawQuery("SELECT c.name as cat_name, SUM(t.amount) as total FROM transactions t LEFT JOIN categories c ON t.category_id=c.id WHERE t.type='expense' AND t.date >= ? AND t.date <= ? $where GROUP BY t.category_id", [from, to]); final map = <String,double>{}; for (final row in r) { map[row['cat_name'] as String? ?? 'Unknown'] = (row['total'] as num).toDouble(); } return map; }
  Future<List<Map<String, dynamic>>> getTransactionsByRange(String from, String to, {int? accountId}) async { final db = await database; final accWhere = accountId != null ? 'AND t.account_id=$accountId' : ''; return db.rawQuery('SELECT t.*, a.name as account_name, c.name as category_name FROM transactions t LEFT JOIN accounts a ON t.account_id=a.id LEFT JOIN categories c ON t.category_id=c.id WHERE t.date >= ? AND t.date <= ? $accWhere ORDER BY t.date DESC', [from, to]); }
  Future<void> resetAccount(int accountId) async { final prefs = await SharedPreferences.getInstance(); final acc = await getAccountById(accountId); if (acc == null) return; await prefs.setString('reset_date_$accountId', DateTime.now().toIso8601String()); await prefs.setDouble('reset_balance_$accountId', (acc['balance'] as num).toDouble()); }
  Future<String?> getResetDate(int accountId) async { return (await SharedPreferences.getInstance()).getString('reset_date_$accountId'); }
  Future<double> getResetBalance(int accountId) async { return (await SharedPreferences.getInstance()).getDouble('reset_balance_$accountId') ?? 0.0; }

  Future<void> resetAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('transfers');
    await db.rawUpdate('UPDATE accounts SET balance=0');
  }

  Future<String> exportCsv() async {
    final txs = await getTransactions();
    final buf = StringBuffer('date,type,amount,account,category,description\n');
    for (final t in txs) {
      buf.write('${t['date']},${t['type']},${t['amount']},${t['account_name'] ?? ''},${t['category_name'] ?? ''},${(t['description'] ?? '').toString().replaceAll(',', ';')}\n');
    }
    return buf.toString();
  }
}

