import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart' show ConflictAlgorithm;
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'expense_v4.db');
    return openDatabase(path,
        version: 6, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int v) async {
    await db.execute(
        '''CREATE TABLE accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, balance REAL DEFAULT 0)''');
    await db.execute(
        '''CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)''');
    await db.execute(
        '''CREATE TABLE recurring(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, amount REAL NOT NULL, frequency TEXT NOT NULL, next_date TEXT NOT NULL, account_id INTEGER, category_id INTEGER, type TEXT NOT NULL DEFAULT 'expense')''');
    await db.execute(
        '''CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER, category_id INTEGER, type TEXT NOT NULL, amount REAL NOT NULL, description TEXT, date TEXT NOT NULL, balance_after REAL, is_recurring INTEGER DEFAULT 0, source TEXT DEFAULT 'manual', transaction_id TEXT, dedupe_key TEXT UNIQUE)''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_dedupe_key ON transactions(dedupe_key)');
    await db.execute(
        '''CREATE TABLE transfers(id INTEGER PRIMARY KEY AUTOINCREMENT, from_account INTEGER, to_account INTEGER, amount REAL NOT NULL, date TEXT NOT NULL, note TEXT)''');
    await db.execute(
        '''CREATE TABLE budgets(id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER NOT NULL, limit_amount REAL NOT NULL, month TEXT NOT NULL, UNIQUE(category_id, month))''');
    await db.execute(
        '''CREATE TABLE rules(id INTEGER PRIMARY KEY AUTOINCREMENT, keyword TEXT NOT NULL, category_id INTEGER NOT NULL)''');
    for (var cat in [
      'Food',
      'Transport',
      'Shopping',
      'Bills',
      'Health',
      'Entertainment',
      'Petrol',
      'Milk',
      'Tea',
      'Other'
    ]) {
      await db.insert('categories', {'name': cat});
    }
    await db.insert('accounts', {'name': 'Cash', 'balance': 0.0});
    await db.insert('accounts', {'name': 'Bank', 'balance': 0.0});
    await db.insert('accounts', {'name': 'PhonePe Wallet', 'balance': 0.0});
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 5) {
      await db.rawUpdate(
        "UPDATE transactions SET amount = ABS(amount) WHERE type = 'transfer_out' AND amount < 0",
      );
    }
    if (oldV < 6) {
      final info = await db.rawQuery("PRAGMA table_info(transactions)");
      final cols = info.map((r) => r['name'] as String).toSet();
      if (!cols.contains('source'))
        await db.execute(
            "ALTER TABLE transactions ADD COLUMN source TEXT DEFAULT 'manual'");
      if (!cols.contains('transaction_id'))
        await db
            .execute("ALTER TABLE transactions ADD COLUMN transaction_id TEXT");
      if (!cols.contains('dedupe_key'))
        await db.execute("ALTER TABLE transactions ADD COLUMN dedupe_key TEXT");
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_dedupe_key ON transactions(dedupe_key)');
    }
  }

  Future<int?> getDefaultAccountId() async =>
      (await SharedPreferences.getInstance()).getInt('default_account_id');
  Future<void> setDefaultAccountId(int id) async =>
      (await SharedPreferences.getInstance()).setInt('default_account_id', id);

  Future<Map<String, dynamic>?> resolveImportAccount({
    int? preferredAccountId,
  }) async {
    final accounts = await getAccounts();
    if (accounts.isEmpty) return null;

    final defaultAccountId = await getDefaultAccountId();
    debugPrint('[PhonePeImport] defaultAccountId=$defaultAccountId');

    Map<String, dynamic>? selected;
    if (preferredAccountId != null) {
      final matches = accounts.where((a) => a['id'] == preferredAccountId);
      if (matches.isNotEmpty) selected = matches.first;
    }

    if (selected == null && defaultAccountId != null) {
      final matches = accounts.where((a) => a['id'] == defaultAccountId);
      if (matches.isNotEmpty) selected = matches.first;
    }

    selected ??= accounts.first;
    final selectedId = selected['id'] as int;
    if (defaultAccountId != selectedId) {
      await setDefaultAccountId(selectedId);
      debugPrint('[PhonePeImport] Updated defaultAccountId=$selectedId');
    }

    debugPrint('[PhonePeImport] selected import accountId=$selectedId');
    debugPrint(
        '[PhonePeImport] selected import account name=${selected['name']}');
    return selected;
  }

  Future<List<Map<String, dynamic>>> getAccounts() async =>
      (await database).query('accounts', orderBy: 'name ASC');
  Future<Map<String, dynamic>?> getAccountById(int id) async {
    final r = await (await database)
        .query('accounts', where: 'id=?', whereArgs: [id]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<int> insertAccount(String name, double balance) async =>
      (await database).insert('accounts', {'name': name, 'balance': balance});
  Future<void> updateAccount(int id, String name) async => (await database)
      .update('accounts', {'name': name}, where: 'id=?', whereArgs: [id]);
  Future<void> updateAccountBalance(int id, double balance) async =>
      (await database).update('accounts', {'balance': balance},
          where: 'id=?', whereArgs: [id]);
  Future<bool> deleteAccount(int id) async {
    final db = await database;
    final c = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM transactions WHERE account_id=?', [id]));
    if ((c ?? 0) > 0) return false;
    await db.delete('accounts', where: 'id=?', whereArgs: [id]);
    return true;
  }

  Future<List<Map<String, dynamic>>> getCategories() async =>
      (await database).query('categories', orderBy: 'name ASC');
  Future<int> insertCategory(String name) async =>
      (await database).insert('categories', {'name': name});
  Future<void> updateCategory(int id, String name) async => (await database)
      .update('categories', {'name': name}, where: 'id=?', whereArgs: [id]);
  Future<void> deleteCategory(int id) async =>
      (await database).delete('categories', where: 'id=?', whereArgs: [id]);

  Future<List<Map<String, dynamic>>> getTransactions(
      {int? limit,
      String? type,
      int? accountId,
      int? categoryId,
      DateTime? from,
      DateTime? to}) async {
    final db = await database;
    final wheres = <String>[];
    final args = <dynamic>[];
    if (type != null) {
      wheres.add("t.type=?");
      args.add(type);
    }
    if (accountId != null) {
      wheres.add("t.account_id=?");
      args.add(accountId);
    }
    if (categoryId != null) {
      wheres.add("t.category_id=?");
      args.add(categoryId);
    }
    if (from != null) {
      wheres.add("t.date >= ?");
      args.add(from.toIso8601String());
    }
    if (to != null) {
      wheres.add("t.date <= ?");
      args.add(to.add(const Duration(days: 1)).toIso8601String());
    }
    final where = wheres.isNotEmpty ? 'WHERE ${wheres.join(' AND ')}' : '';
    final lim = limit != null ? 'LIMIT $limit' : '';
    return db.rawQuery(
        '''SELECT t.*, a.name as account_name, c.name as category_name FROM transactions t LEFT JOIN accounts a ON t.account_id=a.id LEFT JOIN categories c ON t.category_id=c.id $where ORDER BY t.date DESC $lim''',
        args);
  }

  Future<List<Map<String, dynamic>>> getTransactionsByMonth(String month,
      {int? accountId}) async {
    final db = await database;
    final args = <dynamic>['$month%'];
    final accWhere = accountId != null ? 'AND t.account_id=$accountId' : '';
    return db.rawQuery(
        '''SELECT t.*, a.name as account_name, c.name as category_name FROM transactions t LEFT JOIN accounts a ON t.account_id=a.id LEFT JOIN categories c ON t.category_id=c.id WHERE t.date LIKE ? $accWhere ORDER BY t.date DESC''',
        args);
  }

  Future<int> insertTransaction(Map<String, dynamic> data) async =>
      (await database).insert('transactions', data);

  double _balanceEffectForTransaction(String type, double amount) {
    final value = amount.abs();
    switch (type) {
      case 'income':
      case 'transfer_in':
        return value;
      case 'expense':
      case 'transfer_out':
        return -value;
      default:
        return -value;
    }
  }

  Future<void> updateTransactionAccount(
      int transactionId, int newAccountId) async {
    final db = await database;

    await db.transaction((txn) async {
      final txnRows = await txn.query(
        'transactions',
        where: 'id=?',
        whereArgs: [transactionId],
        limit: 1,
      );

      if (txnRows.isEmpty) {
        throw Exception('Transaction not found');
      }

      final transaction = txnRows.first;
      final oldAccountId = transaction['account_id'] as int?;
      if (oldAccountId == newAccountId) return;

      final newAccountRows = await txn.query(
        'accounts',
        where: 'id=?',
        whereArgs: [newAccountId],
        limit: 1,
      );

      if (newAccountRows.isEmpty) {
        throw Exception('New account not found');
      }

      final type = transaction['type'] as String? ?? 'expense';
      final amount = (transaction['amount'] as num).toDouble().abs();
      final balanceEffect = _balanceEffectForTransaction(type, amount);

      if (oldAccountId != null) {
        final oldAccountRows = await txn.query(
          'accounts',
          where: 'id=?',
          whereArgs: [oldAccountId],
          limit: 1,
        );

        if (oldAccountRows.isNotEmpty) {
          final oldBalance =
              (oldAccountRows.first['balance'] as num).toDouble();
          await txn.update(
            'accounts',
            {'balance': oldBalance - balanceEffect},
            where: 'id=?',
            whereArgs: [oldAccountId],
          );
        }
      }

      final newBalanceBefore =
          (newAccountRows.first['balance'] as num).toDouble();
      final newBalanceAfter = newBalanceBefore + balanceEffect;

      await txn.update(
        'accounts',
        {'balance': newBalanceAfter},
        where: 'id=?',
        whereArgs: [newAccountId],
      );

      await txn.update(
        'transactions',
        {
          'account_id': newAccountId,
          'balance_after': newBalanceAfter,
        },
        where: 'id=?',
        whereArgs: [transactionId],
      );
    });
  }

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
      final desc =
          (note != null && note.trim().isNotEmpty) ? ' (${note.trim()})' : '';

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

  Future<List<Map<String, dynamic>>> getBudgets(String month) async =>
      (await database).rawQuery(
          '''SELECT b.*, c.name as category_name FROM budgets b LEFT JOIN categories c ON b.category_id=c.id WHERE b.month=?''',
          [month]);
  Future<void> upsertBudget(int categoryId, double limit, String month) async =>
      (await database).rawInsert(
          'INSERT INTO budgets(category_id,limit_amount,month) VALUES(?,?,?) ON CONFLICT(category_id,month) DO UPDATE SET limit_amount=excluded.limit_amount',
          [categoryId, limit, month]);
  Future<void> deleteBudget(int id) async =>
      (await database).delete('budgets', where: 'id=?', whereArgs: [id]);
  Future<Map<String, dynamic>?> getBudgetForCategory(
      int categoryId, String month) async {
    final r = await (await database).query('budgets',
        where: 'category_id=? AND month=?', whereArgs: [categoryId, month]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<
      List<
          Map<String,
              dynamic>>> getRecurring() async => (await database).rawQuery(
      '''SELECT r.*, a.name as account_name, c.name as category_name FROM recurring r LEFT JOIN accounts a ON r.account_id=a.id LEFT JOIN categories c ON r.category_id=c.id ORDER BY r.next_date ASC''');
  Future<int> insertRecurring(Map<String, dynamic> data) async =>
      (await database).insert('recurring', data);
  Future<void> updateRecurringNextDate(int id, String nextDate) async =>
      (await database).update('recurring', {'next_date': nextDate},
          where: 'id=?', whereArgs: [id]);
  Future<void> deleteRecurring(int id) async =>
      (await database).delete('recurring', where: 'id=?', whereArgs: [id]);

  Future<List<String>> processDueRecurring() async {
    final all = await getRecurring();
    final now = DateTime.now();
    final processed = <String>[];
    for (final r in all) {
      final nextDate = DateTime.tryParse(r['next_date'] ?? '');
      if (nextDate == null || nextDate.isAfter(now)) continue;
      final accountId = r['account_id'] as int?;
      if (accountId == null) continue;
      final acc = await getAccountById(accountId);
      if (acc == null) continue;
      final amount = (r['amount'] as num).toDouble();
      final type = r['type'] as String? ?? 'expense';
      final bal = (acc['balance'] as num).toDouble();
      final newBal = type == 'expense' ? bal - amount : bal + amount;
      await updateAccountBalance(accountId, newBal);
      await insertTransaction({
        'account_id': accountId,
        'category_id': r['category_id'],
        'type': type,
        'amount': amount,
        'description': r['name'],
        'date': now.toIso8601String(),
        'balance_after': newBal,
        'is_recurring': 1
      });
      final freq = r['frequency'] as String? ?? 'Monthly';
      DateTime adv;
      switch (freq) {
        case 'Daily':
          adv = nextDate.add(const Duration(days: 1));
          break;
        case 'Weekly':
          adv = nextDate.add(const Duration(days: 7));
          break;
        case 'Yearly':
          adv = DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
          break;
        default:
          adv = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
      }
      await updateRecurringNextDate(r['id'] as int, adv.toIso8601String());
      processed.add(r['name'] as String);
    }
    return processed;
  }

  Future<
      List<
          Map<String, dynamic>>> getRules() async => (await database).rawQuery(
      '''SELECT r.*, c.name as category_name FROM rules r LEFT JOIN categories c ON r.category_id=c.id ORDER BY r.keyword ASC''');
  Future<int> insertRule(String keyword, int categoryId) async =>
      (await database).insert('rules',
          {'keyword': keyword.toLowerCase().trim(), 'category_id': categoryId});
  Future<void> deleteRule(int id) async =>
      (await database).delete('rules', where: 'id=?', whereArgs: [id]);
  Future<int?> matchRule(String description) async {
    final rules = await (await database).query('rules');
    final lower = description.toLowerCase();
    for (final rule in rules) {
      if (lower.contains(rule['keyword'] as String))
        return rule['category_id'] as int;
    }
    return null;
  }

  Future<double> getTotalBalance() async {
    final r = await (await database)
        .rawQuery('SELECT SUM(balance) as total FROM accounts');
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTodayExpense() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final r = await (await database).rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE type='expense' AND date LIKE ?",
        ['$today%']);
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getMonthlyExpense(String month, {int? accountId}) async {
    final where = accountId != null ? "AND account_id=$accountId" : '';
    final r = await (await database).rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE type='expense' AND date LIKE ? $where",
        ['$month%']);
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getMonthlyIncome(String month, {int? accountId}) async {
    final where = accountId != null ? "AND account_id=$accountId" : '';
    final r = await (await database).rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE type='income' AND date LIKE ? $where",
        ['$month%']);
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<int, double>> getCategoryExpensesById(String month) async {
    final r = await (await database).rawQuery(
        "SELECT category_id, SUM(amount) as total FROM transactions WHERE type='expense' AND date LIKE ? AND category_id IS NOT NULL GROUP BY category_id",
        ['$month%']);
    final map = <int, double>{};
    for (final row in r) {
      map[row['category_id'] as int] = (row['total'] as num).toDouble();
    }
    return map;
  }

  Future<Map<String, double>> getCategoryExpenses(String month,
      {int? accountId}) async {
    final where = accountId != null ? "AND t.account_id=$accountId" : '';
    final r = await (await database).rawQuery(
        "SELECT c.name as cat_name, SUM(t.amount) as total FROM transactions t LEFT JOIN categories c ON t.category_id=c.id WHERE t.type='expense' AND t.date LIKE ? $where GROUP BY t.category_id",
        ['$month%']);
    final map = <String, double>{};
    for (final row in r) {
      map[row['cat_name'] as String? ?? 'Unknown'] =
          (row['total'] as num).toDouble();
    }
    return map;
  }

  Future<double> getCategorySpentThisMonth(int categoryId, String month) async {
    final r = await (await database).rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE type='expense' AND category_id=? AND date LIKE ?",
        [categoryId, '$month%']);
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getRangeIncome(String? from, String? to,
      {int? accountId}) async {
    final db = await database;
    final wheres = <String>["type='income'"];
    final args = <dynamic>[];
    if (from != null) {
      wheres.add('date >= ?');
      args.add(from);
    }
    if (to != null) {
      wheres.add('date <= ?');
      args.add(to);
    }
    if (accountId != null) {
      wheres.add('account_id=?');
      args.add(accountId);
    }
    final r = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE ${wheres.join(' AND ')}",
        args);
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getRangeExpense(String? from, String? to,
      {int? accountId}) async {
    final db = await database;
    final wheres = <String>["type='expense'"];
    final args = <dynamic>[];
    if (from != null) {
      wheres.add('date >= ?');
      args.add(from);
    }
    if (to != null) {
      wheres.add('date <= ?');
      args.add(to);
    }
    if (accountId != null) {
      wheres.add('account_id=?');
      args.add(accountId);
    }
    final r = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE ${wheres.join(' AND ')}",
        args);
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getRangeCategoryExpenses(String? from, String? to,
      {int? accountId}) async {
    final db = await database;
    final wheres = <String>["t.type='expense'"];
    final args = <dynamic>[];
    if (from != null) {
      wheres.add('t.date >= ?');
      args.add(from);
    }
    if (to != null) {
      wheres.add('t.date <= ?');
      args.add(to);
    }
    if (accountId != null) {
      wheres.add('t.account_id=?');
      args.add(accountId);
    }
    final r = await db.rawQuery(
        "SELECT c.name as cat_name, SUM(t.amount) as total FROM transactions t LEFT JOIN categories c ON t.category_id=c.id WHERE ${wheres.join(' AND ')} GROUP BY t.category_id",
        args);
    final map = <String, double>{};
    for (final row in r) {
      map[row['cat_name'] as String? ?? 'Unknown'] =
          (row['total'] as num).toDouble();
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> getTransactionsByRange(
      String? from, String? to,
      {int? accountId}) async {
    final db = await database;
    final wheres = <String>[];
    final args = <dynamic>[];
    if (from != null) {
      wheres.add('t.date >= ?');
      args.add(from);
    }
    if (to != null) {
      wheres.add('t.date <= ?');
      args.add(to);
    }
    if (accountId != null) {
      wheres.add('t.account_id=?');
      args.add(accountId);
    }
    final where = wheres.isNotEmpty ? 'WHERE ${wheres.join(' AND ')}' : '';
    return db.rawQuery(
        'SELECT t.*, a.name as account_name, c.name as category_name FROM transactions t LEFT JOIN accounts a ON t.account_id=a.id LEFT JOIN categories c ON t.category_id=c.id $where ORDER BY t.date DESC',
        args);
  }

  Future<void> resetAccount(int accountId,
      {required double resetAmount}) async {
    final prefs = await SharedPreferences.getInstance();
    final acc = await getAccountById(accountId);
    if (acc == null) return;
    final reportBase = (acc['balance'] as num).toDouble();
    await prefs.setString(
        'reset_date_$accountId', DateTime.now().toIso8601String());
    await prefs.setDouble('reset_amount_$accountId', resetAmount);
    await prefs.setDouble('reset_report_base_$accountId', reportBase);
    await prefs.setDouble('reset_balance_$accountId', reportBase);
  }

  Future<Map<String, double>> resetAccountFromTransaction(
    int accountId,
    Map<String, dynamic> transaction,
  ) async {
    final db = await database;
    final prefs = await SharedPreferences.getInstance();
    final resetAmount =
        ((transaction['amount'] as num?)?.toDouble() ?? 0).abs();
    final resetDateRaw =
        transaction['date'] as String? ?? DateTime.now().toIso8601String();
    final resetDate = DateTime.tryParse(resetDateRaw) ?? DateTime.now();
    final resetId = transaction['id'] as int? ?? 0;

    final previousRows = await db.query(
      'transactions',
      columns: ['type', 'amount'],
      where: 'account_id=? AND (date < ? OR (date = ? AND id < ?))',
      whereArgs: [accountId, resetDateRaw, resetDateRaw, resetId],
    );

    double opening = 0;
    for (final row in previousRows) {
      opening += _balanceEffectForTransaction(
        row['type'] as String? ?? 'expense',
        (row['amount'] as num?)?.toDouble() ?? 0,
      );
    }

    final reportBase = opening + resetAmount;
    final cutoffDate =
        resetDate.add(const Duration(microseconds: 1)).toIso8601String();
    await prefs.setString('reset_date_$accountId', cutoffDate);
    await prefs.setInt('reset_transaction_id_$accountId', resetId);
    await prefs.setString('reset_transaction_date_$accountId', resetDateRaw);
    await prefs.setDouble('reset_amount_$accountId', resetAmount);
    await prefs.setDouble('reset_opening_balance_$accountId', opening);
    await prefs.setDouble('reset_report_base_$accountId', reportBase);
    await prefs.setDouble('reset_balance_$accountId', reportBase);
    return {'amount': resetAmount, 'opening': opening, 'base': reportBase};
  }

  Future<String?> getResetDate(int accountId) async {
    return (await SharedPreferences.getInstance())
        .getString('reset_date_$accountId');
  }

  Future<double> getResetAmount(int accountId) async {
    return (await SharedPreferences.getInstance())
            .getDouble('reset_amount_$accountId') ??
        0.0;
  }

  Future<double> getResetOpeningBalance(int accountId) async {
    return (await SharedPreferences.getInstance())
            .getDouble('reset_opening_balance_$accountId') ??
        0.0;
  }

  Future<Set<int>> getResetTransactionIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = <int>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('reset_transaction_id_')) {
        final id = prefs.getInt(key);
        if (id != null) ids.add(id);
      }
    }
    return ids;
  }

  Future<double> getResetReportBase(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('reset_report_base_$accountId') ??
        prefs.getDouble('reset_balance_$accountId') ??
        0.0;
  }

  Future<void> clearAccountReset(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = [
      'reset_date_$accountId',
      'reset_amount_$accountId',
      'reset_report_base_$accountId',
      'reset_balance_$accountId',
      'reset_transaction_id_$accountId',
      'reset_transaction_date_$accountId',
      'reset_opening_balance_$accountId',
    ];
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<double> getResetBalance(int accountId) async {
    return getResetReportBase(accountId);
  }

  Future<void> resetAllData() async {
    debugPrint('[ResetAllData] Reset App Data started');
    final prefs = await SharedPreferences.getInstance();
    final defaultAccountId = prefs.getInt('default_account_id');
    const resetPrefixes = [
      'reset_date_',
      'reset_amount_',
      'reset_report_base_',
      'reset_balance_',
      'reset_transaction_id_',
      'reset_transaction_date_',
      'reset_opening_balance_',
    ];

    for (final key in prefs.getKeys()) {
      if (resetPrefixes.any(key.startsWith)) {
        await prefs.remove(key);
        debugPrint('[ResetAllData] cleared report reset preference key: $key');
      }
    }
    debugPrint('[ResetAllData] default account preserved: $defaultAccountId');

    final db = await database;
    await db.delete('transactions');
    await db.delete('transfers');
    await db.rawUpdate('UPDATE accounts SET balance=0');
    debugPrint('[ResetAllData] Reset App Data finished');
  }

  // ── PhonePe import ────────────────────────────────────────────────────────

  /// Builds dedupe keys for EVERY existing transaction in the DB (both
  /// PhonePe-imported and manually-entered ones), so that re-running sync
  /// never creates duplicates even if a transaction was manually entered
  /// before the PhonePe statement was imported.
  Future<Set<String>> _existingDedupeKeys() async {
    final db = await database;
    final rows = await db.query('transactions', columns: [
      'dedupe_key',
      'transaction_id',
      'date',
      'amount',
      'type',
      'description'
    ]);
    final keys = <String>{};
    for (final r in rows) {
      final storedKey = r['dedupe_key'] as String?;
      if (storedKey != null && storedKey.isNotEmpty) {
        keys.add(storedKey);
        continue;
      }
      // Fallback for old rows without dedupe_key: build the same composite
      // key shape used by PhonePeTransaction.dedupeKey so manual entries
      // also block duplicate PhonePe imports.
      final txnId = r['transaction_id'] as String?;
      if (txnId != null && txnId.isNotEmpty) {
        keys.add('txn_$txnId');
        continue;
      }
      final date = DateTime.tryParse(r['date'] as String? ?? '');
      if (date == null) continue;
      final dateStr =
          '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}'
          '${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}';
      final amount = (r['amount'] as num?)?.toDouble() ?? 0;
      final amtStr = amount.toStringAsFixed(2).replaceAll('.', '_');
      final desc = (r['description'] as String? ?? '')
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
      final type = r['type'] as String? ?? '';
      keys.add('${dateStr}_${amtStr}_${desc}_$type');
    }
    return keys;
  }

  /// Given a list of dedupe keys parsed from a PhonePe statement, returns
  /// the subset that are NEW (i.e. not already present in the app DB).
  Future<Set<String>> filterNewDedupeKeys(List<String> dedupeKeys) async {
    if (dedupeKeys.isEmpty) return {};
    final existing = await _existingDedupeKeys();
    return dedupeKeys.toSet().difference(existing);
  }

  /// Inserts only transactions whose dedupe_key is not already present.
  /// Maps PhonePe type ('expense'/'income') directly. Category is left
  /// null/"Unknown" unless a matching rule keyword is found.
  /// Returns the count of newly inserted rows.
  Future<int> insertPhonePeTransactions(
    List<Map<String, dynamic>> txnMaps, {
    required int accountId,
  }) async {
    final db = await database;
    final importAccount =
        await resolveImportAccount(preferredAccountId: accountId);
    if (importAccount == null) {
      debugPrint('[PhonePeImport] No valid account found. Nothing inserted.');
      return 0;
    }
    final validAccountId = importAccount['id'] as int;
    int inserted = 0;

    await db.transaction((txn) async {
      for (final t in txnMaps) {
        final appType = (t['type'] as String? ?? 'expense') == 'income'
            ? 'income'
            : 'expense';
        final amount = (t['amount'] as num).toDouble();
        final desc = t['description'] as String? ?? 'PhonePe Transaction';
        final dateStr = t['date'] as String; // ISO string with real date/time

        final categoryId = await _inferCategoryId(txn, desc);

        final accRows = await txn
            .query('accounts', where: 'id=?', whereArgs: [validAccountId]);
        if (accRows.isEmpty) continue;
        final oldBal = (accRows.first['balance'] as num).toDouble();
        final newBal = appType == 'expense' ? oldBal - amount : oldBal + amount;
        await txn.update('accounts', {'balance': newBal},
            where: 'id=?', whereArgs: [validAccountId]);

        try {
          final insertedId = await txn.insert(
              'transactions',
              {
                'account_id': validAccountId,
                'category_id':
                    categoryId, // null if no rule/keyword matched ("Unknown")
                'type': appType,
                'amount': amount,
                'description': desc,
                'date':
                    dateStr, // real PhonePe transaction date/time, NOT import time
                'balance_after': newBal,
                'source': 'phonepe',
                'transaction_id': t['transaction_id'],
                'dedupe_key': t['dedupe_key'],
              },
              conflictAlgorithm: ConflictAlgorithm.ignore);
          if (insertedId > 0) {
            inserted++;
            debugPrint(
                '[PhonePeImport] inserted: description="$desc", amount=$amount, type=$appType, account_id=$validAccountId');
          } else {
            await txn.update('accounts', {'balance': oldBal},
                where: 'id=?', whereArgs: [validAccountId]);
          }
        } catch (_) {
          // dedupe_key conflict — already imported; roll back the balance bump.
          await txn.update('accounts', {'balance': oldBal},
              where: 'id=?', whereArgs: [validAccountId]);
        }
      }
    });
    debugPrint('[PhonePeImport] saved count=$inserted');
    return inserted;
  }

  /// Checks user-defined rules first, then a built-in keyword map.
  /// Returns null (saved as "Unknown" in UI) if nothing matches.
  Future<int?> _inferCategoryId(DatabaseExecutor db, String description) async {
    final lower = description.toLowerCase();
    final rules = await db.query('rules');
    for (final r in rules) {
      if (lower.contains(r['keyword'] as String))
        return r['category_id'] as int;
    }
    String? catName;
    if (_matchesAny(
        lower, ['swiggy', 'zomato', 'food', 'restaurant', 'cafe', 'dhaba']))
      catName = 'Food';
    else if (_matchesAny(lower, [
      'uber',
      'ola',
      'rapido',
      'metro',
      'bus',
      'auto',
      'cab',
      'petrol',
      'fuel'
    ]))
      catName = 'Transport';
    else if (_matchesAny(
        lower, ['amazon', 'flipkart', 'myntra', 'ajio', 'meesho']))
      catName = 'Shopping';
    else if (_matchesAny(lower, [
      'electricity',
      'water',
      'gas',
      'internet',
      'broadband',
      'jio',
      'airtel',
      'vi ',
      'bsnl',
      'dth',
      'recharge'
    ]))
      catName = 'Bills';
    else if (_matchesAny(lower,
        ['hospital', 'pharmacy', 'medical', 'doctor', 'clinic', 'apollo']))
      catName = 'Health';
    else if (_matchesAny(lower, [
      'movie',
      'bookmyshow',
      'pvr',
      'inox',
      'netflix',
      'hotstar',
      'spotify'
    ])) catName = 'Entertainment';
    if (catName == null) return null;
    final rows =
        await db.query('categories', where: 'name=?', whereArgs: [catName]);
    return rows.isNotEmpty ? rows.first['id'] as int : null;
  }

  static bool _matchesAny(String text, List<String> kws) =>
      kws.any(text.contains);

  // ── End PhonePe import ────────────────────────────────────────────────────

  Future<String> exportCsv() async {
    final txs = await getTransactions();
    final buf = StringBuffer('date,type,amount,account,category,description\n');
    for (final t in txs) {
      buf.write(
          '${t['date']},${t['type']},${t['amount']},${t['account_name'] ?? ''},${t['category_name'] ?? ''},${(t['description'] ?? '').toString().replaceAll(',', ';')}\n');
    }
    return buf.toString();
  }
}
