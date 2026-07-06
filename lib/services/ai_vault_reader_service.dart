import 'local_data_vault_service.dart';

class AiVaultReaderService {
  final LocalDataVaultService _vault;

  AiVaultReaderService({LocalDataVaultService? vault})
      : _vault = vault ?? LocalDataVaultService();

  Future<bool> hasReadableData() async {
    final snapshot = await _readSnapshot();
    return snapshot.accounts.isNotEmpty ||
        snapshot.transactions.isNotEmpty ||
        snapshot.metadata.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> findAccountsByName(String query) async {
    final snapshot = await _readSnapshot();
    final accounts = snapshot.accounts;
    final cleanQuery = _normalize(query);
    if (cleanQuery.isEmpty || accounts.isEmpty) return [];

    final exactMatches = accounts
        .where((account) =>
            _normalize(account['name']?.toString() ?? '') == cleanQuery)
        .toList();
    if (exactMatches.isNotEmpty) return exactMatches;

    final containsMatches = accounts
        .where((account) {
          final name = _normalize(account['name']?.toString() ?? '');
          return name.contains(cleanQuery) || cleanQuery.contains(name);
        })
        .toList();
    if (containsMatches.length == 1) return containsMatches;
    if (containsMatches.length > 1) return containsMatches;

    final scored = accounts
        .map((account) {
          final name = account['name']?.toString() ?? '';
          return _ScoredAccount(
            account: account,
            score: _accountScore(cleanQuery, name),
          );
        })
        .where((item) => item.score >= 0.66)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty) return [];

    final topScore = scored.first.score;
    if (topScore < 0.70) return [];
    if (scored.length == 1) return [scored.first.account];

    final secondScore = scored[1].score;
    if (topScore - secondScore >= 0.16) {
      return [scored.first.account];
    }

    return scored
        .where((item) => topScore - item.score <= 0.10)
        .map((item) => item.account)
        .toList();
  }

  Future<double?> getAccountCurrentBalance(int accountId) async {
    final snapshot = await _readSnapshot();
    final account = _accountById(snapshot.accounts, accountId);
    return account == null ? null : _toDouble(account['currentBalance']);
  }

  Future<double?> getAccountBalanceOnDate(int accountId, DateTime date) async {
    final snapshot = await _readSnapshot();
    final account = _accountById(snapshot.accounts, accountId);
    if (account == null) return null;

    final currentBalance = _toDouble(account['currentBalance']);
    final transactions = snapshot.transactions
        .where((txn) => _toInt(txn['accountId']) == accountId)
        .toList();
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    );

    double allEffects = 0;
    double selectedDateEffects = 0;
    for (final txn in transactions) {
      final effect = _balanceEffect(
        txn['type']?.toString(),
        _toDouble(txn['amount']),
      );
      allEffects += effect;

      final rawDate = txn['date']?.toString();
      final txnDate = rawDate == null ? null : DateTime.tryParse(rawDate);
      if (txnDate != null && !txnDate.isAfter(endOfDay)) {
        selectedDateEffects += effect;
      }
    }

    final opening = currentBalance - allEffects;
    return opening + selectedDateEffects;
  }

  Future<double> sumCurrentBalancesForAccounts(List<int> accountIds) async {
    double total = 0;
    for (final accountId in accountIds) {
      total += await getAccountCurrentBalance(accountId) ?? 0;
    }
    return total;
  }

  Future<double> getTotalCurrentBalance() async {
    final snapshot = await _readSnapshot();
    return snapshot.accounts.fold<double>(
      0,
      (total, account) => total + _toDouble(account['currentBalance']),
    );
  }

  Future<Map<String, double>> getAccountSummary(int accountId) async {
    final currentBalance = await getAccountCurrentBalance(accountId) ?? 0;
    final spent = await getTotalSpentForAccount(accountId) ?? 0;
    final moneyAdded = await getTotalMoneyAddedForAccount(accountId) ?? 0;
    final today = DateTime.now();
    final monthStart = DateTime(today.year, today.month);

    return {
      'availableFunds': currentBalance + spent,
      'spent': spent,
      'todayExpenses': await getRangeExpense(
        _startOfDayIso(today),
        _endOfDayIso(today),
        accountId: accountId,
      ),
      'thisMonthExpenses': await getRangeExpense(
        _startOfDayIso(monthStart),
        _endOfDayIso(DateTime(today.year, today.month + 1, 0)),
        accountId: accountId,
      ),
      'currentBalance': currentBalance,
      'totalMoneyAdded': moneyAdded,
    };
  }

  Future<double> getTodayExpenseTotal() async {
    final now = DateTime.now();
    return getRangeExpense(_startOfDayIso(now), _endOfDayIso(now));
  }

  Future<double> getThisMonthExpenseTotal() async {
    final now = DateTime.now();
    return getRangeExpense(
      _startOfDayIso(DateTime(now.year, now.month)),
      _endOfDayIso(DateTime(now.year, now.month + 1, 0)),
    );
  }

  Future<double?> getTotalSpentForAccount(int accountId) async {
    final snapshot = await _readSnapshot();
    if (_accountById(snapshot.accounts, accountId) == null) return null;

    return snapshot.transactions
        .where((txn) =>
            _toInt(txn['accountId']) == accountId &&
            txn['type']?.toString() == 'expense')
        .fold<double>(0, (total, txn) => total + _toDouble(txn['amount']));
  }

  Future<double?> getTotalMoneyAddedForAccount(int accountId) async {
    final snapshot = await _readSnapshot();
    if (_accountById(snapshot.accounts, accountId) == null) return null;

    return snapshot.transactions
        .where((txn) =>
            _toInt(txn['accountId']) == accountId &&
            txn['type']?.toString() == 'income')
        .fold<double>(0, (total, txn) => total + _toDouble(txn['amount']));
  }

  Future<double> getRangeExpense(
    String? from,
    String? to, {
    int? accountId,
  }) async {
    final snapshot = await _readSnapshot();
    final fromDate = from == null ? null : DateTime.tryParse(from);
    final toDate = to == null ? null : DateTime.tryParse(to);

    return snapshot.transactions
        .where((txn) => txn['type']?.toString() == 'expense')
        .where((txn) => accountId == null || _toInt(txn['accountId']) == accountId)
        .where((txn) => _isWithinRange(txn['date']?.toString(), fromDate, toDate))
        .fold<double>(0, (total, txn) => total + _toDouble(txn['amount']));
  }

  Future<List<Map<String, dynamic>>> searchTransactionsForAi({
    String? query,
    String? type,
    int? accountId,
    DateTime? from,
    DateTime? to,
    int limit = 5,
  }) async {
    return queryTransactionsForAi(
      keyword: query,
      type: type,
      accountId: accountId,
      from: from,
      to: to,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> queryTransactionsForAi({
    String? keyword,
    String? type,
    int? accountId,
    DateTime? from,
    DateTime? to,
    int limit = 10,
  }) async {
    final snapshot = await _readSnapshot();
    final cleanQuery = _normalize(keyword ?? '');
    final safeLimit = limit.clamp(1, 20).toInt();

    final matches = snapshot.transactions
        .where((txn) => type == null || txn['type']?.toString() == type)
        .where((txn) => accountId == null || _toInt(txn['accountId']) == accountId)
        .where((txn) => from == null && to == null
            ? true
            : _isWithinRange(_bestDateValue(txn), from, to))
        .where((txn) {
          if (cleanQuery.isEmpty) return true;
          final haystack = _normalize([
            txn['description'],
            txn['type'],
            txn['accountName'],
            txn['category'],
            txn['categoryName'],
            txn['source'],
            txn['importSource'],
          ].whereType<Object>().join(' '));
          return haystack.contains(cleanQuery);
        })
        .toList()
      ..sort(_compareTransactionsLatestFirst);

    return matches.take(safeLimit).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentTransactionsForAi({
    int? accountId,
    int limit = 5,
  }) async {
    final snapshot = await _readSnapshot();
    final safeLimit = limit.clamp(1, 10).toInt();
    final transactions = snapshot.transactions
        .where((txn) => accountId == null || _toInt(txn['accountId']) == accountId)
        .toList()
      ..sort(_compareTransactionsLatestFirst);

    return transactions.take(safeLimit).toList();
  }

  Future<_VaultSnapshot> _readSnapshot() async {
    try {
      return _VaultSnapshot(
        accounts: await _vault.readAccounts(),
        transactions: await _vault.readTransactions(),
        expenses: await _vault.readExpenses(),
        moneyAdded: await _vault.readMoneyAdded(),
        summaries: await _vault.readSummaries(),
        metadata: await _vault.readMetadata(),
      );
    } catch (_) {
      return const _VaultSnapshot();
    }
  }

  Map<String, dynamic>? _accountById(
    List<Map<String, dynamic>> accounts,
    int accountId,
  ) {
    for (final account in accounts) {
      if (_toInt(account['id']) == accountId) return account;
    }
    return null;
  }

  double _accountScore(String normalizedQuery, String accountName) {
    final normalizedName = _normalize(accountName);
    if (normalizedName.isEmpty) return 0;
    if (normalizedName == normalizedQuery) return 1;
    if (normalizedName.contains(normalizedQuery)) return 0.92;
    if (normalizedQuery.contains(normalizedName)) return 0.88;

    final queryTokens =
        normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();
    final nameTokens =
        normalizedName.split(' ').where((t) => t.isNotEmpty).toList();
    double tokenScoreTotal = 0;
    for (final queryToken in queryTokens) {
      double bestTokenScore = 0;
      for (final nameToken in nameTokens) {
        final score = _tokenScore(queryToken, nameToken);
        if (score > bestTokenScore) bestTokenScore = score;
      }
      tokenScoreTotal += bestTokenScore;
    }

    final tokenScore =
        queryTokens.isEmpty ? 0 : tokenScoreTotal / queryTokens.length;
    final similarityScore = _similarity(normalizedQuery, normalizedName);
    final initialsScore = _initialsScore(normalizedQuery, normalizedName);
    final best = [
      tokenScore,
      similarityScore,
      initialsScore,
    ].reduce((a, b) => a > b ? a : b);
    return best.toDouble();
  }

  double _tokenScore(String queryToken, String nameToken) {
    if (queryToken == nameToken) return 1;
    if (nameToken.startsWith(queryToken)) return 0.92;
    if (queryToken.startsWith(nameToken)) return 0.86;
    final similarity = _similarity(queryToken, nameToken);
    if (similarity >= 0.78) return similarity;
    if (_isVowelLooseMatch(queryToken, nameToken)) return 0.82;
    return similarity;
  }

  double _initialsScore(String normalizedQuery, String normalizedName) {
    final queryCompact = normalizedQuery.replaceAll(' ', '');
    final initials = normalizedName
        .split(' ')
        .where((token) => token.isNotEmpty)
        .map((token) => token[0])
        .join();
    if (initials.isEmpty || queryCompact.length < 2) return 0;
    if (queryCompact == initials) return 0.88;
    if (normalizedName.replaceAll(' ', '').contains(queryCompact)) return 0.84;
    return 0;
  }

  bool _isVowelLooseMatch(String a, String b) {
    String stripVowels(String value) => value.replaceAll(RegExp(r'[aeiou]'), '');
    final strippedA = stripVowels(a);
    final strippedB = stripVowels(b);
    if (strippedA.length < 3 || strippedB.length < 3) return false;
    return strippedA == strippedB || _similarity(strippedA, strippedB) >= 0.82;
  }

  double _balanceEffect(String? type, double amount) {
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

  bool _isWithinRange(String? rawDate, DateTime? from, DateTime? to) {
    final date = rawDate == null ? null : DateTime.tryParse(rawDate);
    if (date == null) return false;
    if (from != null && date.isBefore(from)) return false;
    if (to != null) {
      final inclusiveTo = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
      if (date.isAfter(inclusiveTo)) return false;
    }
    return true;
  }

  int _compareTransactionsLatestFirst(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aDate = _transactionSortDate(a);
    final bDate = _transactionSortDate(b);
    if (aDate != null && bDate != null) {
      final dateCompare = bDate.compareTo(aDate);
      if (dateCompare != 0) return dateCompare;
    } else if (aDate != null) {
      return -1;
    } else if (bDate != null) {
      return 1;
    }

    final aId = _transactionSortId(a);
    final bId = _transactionSortId(b);
    return bId.compareTo(aId);
  }

  DateTime? _transactionSortDate(Map<String, dynamic> transaction) {
    final value = _bestDateValue(transaction);
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
    return null;
  }

  String? _bestDateValue(Map<String, dynamic> transaction) {
    for (final key in ['date', 'transactionDate', 'createdAt', 'updatedAt']) {
      final value = transaction[key]?.toString();
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  int _transactionSortId(Map<String, dynamic> transaction) {
    return _toInt(transaction['transactionId']) ??
        _toInt(transaction['id']) ??
        _toInt(transaction['sourceTransactionId']) ??
        0;
  }

  String _startOfDayIso(DateTime date) {
    return DateTime(date.year, date.month, date.day).toIso8601String();
  }

  String _endOfDayIso(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).toIso8601String();
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final distance = _levenshtein(a, b);
    final longest = a.length > b.length ? a.length : b.length;
    return 1 - (distance / longest);
  }

  int _levenshtein(String a, String b) {
    final previous = List<int>.generate(b.length + 1, (i) => i);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final insert = current[j] + 1;
        final delete = previous[j + 1] + 1;
        final replace = previous[j] + (a[i] == b[j] ? 0 : 1);
        current[j + 1] = [insert, delete, replace].reduce((x, y) => x < y ? x : y);
      }
      for (var j = 0; j < previous.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous[b.length];
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _VaultSnapshot {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> moneyAdded;
  final Map<String, dynamic> summaries;
  final Map<String, dynamic> metadata;

  const _VaultSnapshot({
    this.accounts = const [],
    this.transactions = const [],
    this.expenses = const [],
    this.moneyAdded = const [],
    this.summaries = const {},
    this.metadata = const {},
  });
}

class _ScoredAccount {
  final Map<String, dynamic> account;
  final double score;

  const _ScoredAccount({required this.account, required this.score});
}
