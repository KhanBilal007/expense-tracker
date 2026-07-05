import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../utils/money_formatter.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  static const _aiIconAsset = 'assets/icons/ai_agent_option_2_icon.png';

  final _db = DatabaseHelper();
  final _inputCtrl = TextEditingController();
  final List<_AiMessage> _messages = [
    const _AiMessage(
      text: 'Ask about your expenses, balances, reports, or how to use the app.',
      fromUser: false,
    ),
  ];

  static const _suggestions = [
    'Balance of Mahmood Bhai',
    'This month expense',
    'Today expense',
    'Sum account balances',
    'How to sync PDF?',
    'How to reset by date?',
  ];

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _useSuggestion(String text) {
    _inputCtrl.text = text;
    _send();
  }

  Future<void> _send() async {
    final question = _inputCtrl.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _messages.add(_AiMessage(text: question, fromUser: true));
    });
    _inputCtrl.clear();

    final answer = await _answer(question);
    if (!mounted) return;

    setState(() {
      _messages.add(_AiMessage(text: answer, fromUser: false));
    });
  }

  Future<String> _answer(String question) async {
    final q = question.toLowerCase();
    switch (_detectIntent(q)) {
      case _AiIntent.currentAccountBalance:
      case _AiIntent.accountBalanceOnDate:
        return _answerBalance(question);
      case _AiIntent.sumAccountBalances:
        return _answerSumBalance(question);
      case _AiIntent.todayExpense:
        return _answerExpensePeriod(question, today: true);
      case _AiIntent.thisMonthExpense:
        return _answerExpensePeriod(question, today: false);
      case _AiIntent.accountSpent:
        return _answerSpent(question);
      case _AiIntent.accountMoneyAdded:
        return _answerMoneyAdded(question);
      case _AiIntent.accountSummary:
        return _answerAccountSummary(question);
      case _AiIntent.transactionSearch:
        return _answerTransactionSearch(question);
      case _AiIntent.appHelp:
        return _answerAppHelp(q);
      case _AiIntent.clarificationNeeded:
        return 'Which account do you mean?';
      case _AiIntent.unsupported:
        return 'I can answer balances, expenses, money added, transactions, and app-help questions for now.';
    }
  }

  _AiIntent _detectIntent(String q) {
    final text = _cleanText(q).toLowerCase();

    if (_isAppHelpQuestion(text)) return _AiIntent.appHelp;
    if (_isTodayExpenseQuestion(text)) return _AiIntent.todayExpense;
    if (_isThisMonthExpenseQuestion(text)) return _AiIntent.thisMonthExpense;
    if (_isSumBalanceQuestion(text)) return _AiIntent.sumAccountBalances;
    if (_isAccountSummaryQuestion(text)) return _AiIntent.accountSummary;
    if (_isTransactionQuestion(text)) return _AiIntent.transactionSearch;
    if (_isMoneyAddedQuestion(text)) return _AiIntent.accountMoneyAdded;
    if (_isSpentQuestion(text)) return _AiIntent.accountSpent;
    if (_isBalanceQuestion(text)) {
      return text.contains(' on ')
          ? _AiIntent.accountBalanceOnDate
          : _AiIntent.currentAccountBalance;
    }

    if (text.contains('account') &&
        (text.contains('which') || text.contains('what'))) {
      return _AiIntent.clarificationNeeded;
    }

    return _AiIntent.unsupported;
  }

  String _answerAppHelp(String q) {
    if (q.contains('add account') || q.contains('new account')) {
      return 'Open Accounts, tap +, enter the account name and opening balance, then tap Add.';
    }
    if (q.contains('add expense') || q.contains('expense add')) {
      return 'Use Add Expense from Home quick actions. Enter amount, account, category, date, and save.';
    }
    if (q.contains('add money') ||
        q.contains('money add') ||
        q.contains('income')) {
      return 'Use the add-money flow, choose the account, enter the amount, and save it as income.';
    }
    if (q.contains('transfer')) {
      return 'Use Transfer to move money between accounts. Transfers affect balances but do not create spending.';
    }
    if (q.contains('sync') || q.contains('pdf') || q.contains('phonepe')) {
      return 'You can sync PDF from the Transactions tab by tapping Sync.';
    }
    if (q.contains('report')) {
      return 'Open Reports to review available funds, spent amount, current balance, category totals, and reset options.';
    }
    if (q.contains('reset by date')) {
      return 'Open Reports, tap Reset Account, choose Reset by Date, select the account and date, then confirm.';
    }
    if (q.contains('reset by amount')) {
      return 'Open Reports, tap Reset Account, choose Reset by Amount, enter the amount, then confirm.';
    }
    if (q.contains('reset')) {
      return 'Open Reports and tap Reset Account. You can choose Reset by Date or Reset by Amount.';
    }
    if (q.contains('choose') && q.contains('home')) {
      return 'On Home, use Choose near the accounts section and select up to two accounts to display.';
    }
    if (q.contains('ai')) {
      return 'Ask me short questions about balances, expenses, money added, transactions, dates, or how to use the app.';
    }
    if (q.contains('what can i ask') || q.contains('help')) {
      return 'Ask about balances, account sums, expenses, money added, transactions, reports, resets, PDF sync, or app usage.';
    }

    return 'I can help with accounts, expenses, add money, transfers, PDF sync, reports, resets, Home account choices, and AI tab usage.';
  }

  Future<String> _answerTransactionSearch(String question) async {
    final date = _parseQuestionDate(question);
    final accountName = _extractOptionalTransactionAccountName(question);
    int? accountId;

    if (accountName != null && accountName.isNotEmpty) {
      final lookup = await _lookupSingleAccount(accountName);
      if (lookup.message != null) return lookup.message!;
      accountId = lookup.account!['id'] as int;
    }

    final cleanQuery = _transactionSearchTerm(question);
    final type = _transactionTypeFilter(question);
    final txns = await _db.searchTransactionsForAi(
      query: cleanQuery,
      type: type,
      accountId: accountId,
      from: date,
      to: date,
      limit: 5,
    );

    if (txns.isEmpty) {
      return 'I did not find matching transactions.';
    }

    final lines = txns.map(_formatTransactionLine).join('\n');
    return 'I found ${txns.length} transaction${txns.length == 1 ? '' : 's'}:\n$lines';
  }

  Future<String> _answerBalance(String question) async {
    final dateSplit = _splitDateQuestion(question);
    final accountName = _stripBalancePhrases(dateSplit.accountText);

    if (accountName.isEmpty) {
      return 'Which account do you mean?';
    }

    final lookup = await _lookupSingleAccount(accountName);
    if (lookup.message != null) return lookup.message!;

    final account = lookup.account!;
    final accountId = account['id'] as int;
    final accountDisplayName = account['name'] as String;

    if (dateSplit.askedForDate) {
      final date = _parseQuestionDate(dateSplit.dateText);
      if (date == null) {
        return 'Which date should I use?';
      }

      final balance = await _db.getAccountBalanceOnDate(accountId, date);
      if (balance == null) {
        return 'Account "$accountDisplayName" not found.';
      }

      return '$accountDisplayName balance on ${_formatDate(date)} was ${_formatMoney(balance)}.';
    }

    final balance = await _db.getAccountCurrentBalance(accountId);
    if (balance == null) {
      return 'Account "$accountDisplayName" not found.';
    }

    return '$accountDisplayName balance is ${_formatMoney(balance)}.';
  }

  Future<String> _answerSumBalance(String question) async {
    final accountNames = _extractSumAccountNames(question);
    if (accountNames.length < 2) {
      return 'Please include at least two account names.';
    }

    final accounts = <Map<String, dynamic>>[];
    for (final accountName in accountNames) {
      final lookup = await _lookupSingleAccount(accountName);
      if (lookup.message != null) return lookup.message!;
      accounts.add(lookup.account!);
    }

    final accountIds = accounts.map((account) => account['id'] as int).toList();
    final total = await _db.sumCurrentBalancesForAccounts(accountIds);
    final names = accounts.map((account) => account['name'] as String).join(' and ');

    return 'Total balance of $names is ${_formatMoney(total)}.';
  }

  Future<String> _answerExpensePeriod(
    String question, {
    required bool today,
  }) async {
    final accountName = _extractOptionalExpenseAccountName(question);
    if (accountName != null && accountName.isNotEmpty) {
      final lookup = await _lookupSingleAccount(accountName);
      if (lookup.message != null) return lookup.message!;

      final account = lookup.account!;
      final summary = await _db.getAccountSummary(account['id'] as int);
      final amount =
          summary[today ? 'todayExpenses' : 'thisMonthExpenses'] ?? 0;
      final label = today ? 'Today expense' : 'This month expense';
      return '$label for ${account['name']} is ${_formatMoney(amount)}.';
    }

    final amount = today
        ? await _db.getTodayExpenseTotal()
        : await _db.getThisMonthExpenseTotal();
    final label = today ? 'Today expense' : 'This month expense';
    return '$label is ${_formatMoney(amount)}.';
  }

  Future<String> _answerSpent(String question) async {
    final accountName = _stripSpentPhrases(question);
    if (accountName.isEmpty) {
      return 'Which account do you mean?';
    }

    final lookup = await _lookupSingleAccount(accountName);
    if (lookup.message != null) return lookup.message!;

    final account = lookup.account!;
    final spent = await _db.getTotalSpentForAccount(account['id'] as int);
    if (spent == null) {
      return 'Account "${account['name']}" not found.';
    }

    return 'Spent from ${account['name']} is ${_formatMoney(spent)}.';
  }

  Future<String> _answerMoneyAdded(String question) async {
    final accountName = _stripMoneyAddedPhrases(question);
    if (accountName.isEmpty) {
      return 'Which account do you mean?';
    }

    final lookup = await _lookupSingleAccount(accountName);
    if (lookup.message != null) return lookup.message!;

    final account = lookup.account!;
    final added = await _db.getTotalMoneyAddedForAccount(account['id'] as int);
    if (added == null) {
      return 'Account "${account['name']}" not found.';
    }

    return 'Money added to ${account['name']} is ${_formatMoney(added)}.';
  }

  Future<String> _answerAccountSummary(String question) async {
    final accountName = _stripSummaryPhrases(question);
    if (accountName.isEmpty) {
      return 'Which account do you mean?';
    }

    final lookup = await _lookupSingleAccount(accountName);
    if (lookup.message != null) return lookup.message!;

    final account = lookup.account!;
    final summary = await _db.getAccountSummary(account['id'] as int);
    return '${account['name']} summary: available ${_formatMoney(summary['availableFunds'] ?? 0)}, spent ${_formatMoney(summary['spent'] ?? 0)}, money added ${_formatMoney(summary['totalMoneyAdded'] ?? 0)}, balance ${_formatMoney(summary['currentBalance'] ?? 0)}.';
  }

  Future<_AccountLookupResult> _lookupSingleAccount(String accountName) async {
    final cleanName = _cleanText(accountName);
    var matches = await _db.findAccountsByName(cleanName);
    if (matches.isEmpty &&
        cleanName.toLowerCase().startsWith('account ')) {
      matches = await _db.findAccountsByName(cleanName.substring(8));
    }

    if (matches.isEmpty) {
      return _AccountLookupResult(message: 'Account "$cleanName" not found.');
    }

    if (matches.length > 1) {
      final names = matches.map((account) => '- ${account['name']}').join('\n');
      return _AccountLookupResult(
        message:
            'I found multiple accounts matching $cleanName. Which one should I use?\n$names',
      );
    }

    return _AccountLookupResult(account: matches.first);
  }

  bool _isBalanceQuestion(String q) {
    return q.contains('balance') ||
        q.contains('money in ') ||
        q.contains('money available') ||
        q.contains('available in ') ||
        q.contains('how much money in ');
  }

  bool _isSumBalanceQuestion(String q) {
    return (q.contains('balance') || q.contains('money')) &&
        (q.contains('sum ') ||
            q.contains('total balance') ||
            q.contains('sum of balance') ||
            q.contains('sum balance') ||
            q.contains('total money'));
  }

  bool _isTodayExpenseQuestion(String q) {
    return q.contains('today') &&
        (q.contains('expense') || q.contains('spent'));
  }

  bool _isThisMonthExpenseQuestion(String q) {
    return (q.contains('this month') || q.contains('monthly')) &&
        (q.contains('expense') || q.contains('spent'));
  }

  bool _isSpentQuestion(String q) {
    return q.contains('spent');
  }

  bool _isMoneyAddedQuestion(String q) {
    return q.contains('money added') ||
        q.contains('added to') ||
        q.contains('income');
  }

  bool _isAccountSummaryQuestion(String q) {
    return q.contains('summary') ||
        q.contains('overview') ||
        q.contains('account report');
  }

  bool _isTransactionQuestion(String q) {
    return q.contains('transaction') ||
        q.contains('transactions') ||
        q.contains('entries') ||
        q.contains('show expense') ||
        q.contains('show income') ||
        q.contains('expense on') ||
        q.contains('expenses on') ||
        q.contains('income on') ||
        q.contains('recent expense') ||
        q.contains('recent income');
  }

  bool _isAppHelpQuestion(String q) {
    return q.contains('how to') ||
        q.contains('how do i') ||
        q.contains('where do i') ||
        q.contains('where to') ||
        q.contains('what can i ask') ||
        q.contains('help') ||
        q.contains('guide') ||
        q.contains('use app') ||
        q.contains('use the app');
  }

  _DateQuestionParts _splitDateQuestion(String question) {
    final match = RegExp(r'\bon\b', caseSensitive: false).firstMatch(question);
    if (match == null) {
      return _DateQuestionParts(accountText: question);
    }

    return _DateQuestionParts(
      accountText: question.substring(0, match.start),
      dateText: question.substring(match.end),
      askedForDate: true,
    );
  }

  String _stripBalancePhrases(String value) {
    var text = _cleanText(value);
    final patterns = [
      r'^how\s+much\s+money\s+(is\s+)?(in|available\s+in)\s+',
      r'^what\s+(is|was)\s+the\s+current\s+balance\s+of\s+',
      r'^what\s+(is|was)\s+current\s+balance\s+of\s+',
      r'^what\s+(is|was)\s+the\s+balance\s+of\s+',
      r'^what\s+(is|was)\s+balance\s+(in|of|for)\s+',
      r'^current\s+balance\s+of\s+',
      r'^current\s+balance\s+in\s+',
      r'^balance\s+of\s+',
      r'^balance\s+for\s+',
      r'^balance\s+in\s+',
      r'^money\s+in\s+',
      r'^available\s+in\s+',
      r'^what\s+(is|was)\s+',
      r'^show\s+',
      r'^tell\s+me\s+',
    ];

    for (final pattern in patterns) {
      text = text.replaceFirst(RegExp(pattern, caseSensitive: false), '');
    }

    text = text.replaceFirst(RegExp(r'\s+balance$', caseSensitive: false), '');
    return _cleanText(text);
  }

  String _stripSpentPhrases(String value) {
    var text = _cleanText(value);
    final patterns = [
      r'^how\s+much\s+was\s+spent\s+(from|by|for)\s+',
      r'^how\s+much\s+spent\s+(from|by|for)\s+',
      r'^spent\s+(from|by|for)\s+',
      r'^total\s+spent\s+(from|by|for)\s+',
      r'^expense\s+(from|for)\s+',
    ];

    for (final pattern in patterns) {
      text = text.replaceFirst(RegExp(pattern, caseSensitive: false), '');
    }

    return _cleanText(text);
  }

  String _stripMoneyAddedPhrases(String value) {
    var text = _cleanText(value);
    final patterns = [
      r'^how\s+much\s+money\s+was\s+added\s+(to|for)\s+',
      r'^how\s+much\s+was\s+added\s+(to|for)\s+',
      r'^money\s+added\s+(to|for)\s+',
      r'^added\s+(to|for)\s+',
      r'^income\s+(to|for|of)\s+',
      r'^total\s+income\s+(to|for|of)\s+',
    ];

    for (final pattern in patterns) {
      text = text.replaceFirst(RegExp(pattern, caseSensitive: false), '');
    }

    return _cleanText(text);
  }

  String _stripSummaryPhrases(String value) {
    var text = _cleanText(value);
    final patterns = [
      r'^account\s+summary\s+(of|for)\s+',
      r'^summary\s+(of|for)\s+',
      r'^account\s+report\s+(of|for)\s+',
      r'^overview\s+(of|for)\s+',
      r'^show\s+',
      r'^tell\s+me\s+',
      r'^what\s+(is|was)\s+',
    ];

    for (final pattern in patterns) {
      text = text.replaceFirst(RegExp(pattern, caseSensitive: false), '');
    }

    text = text
        .replaceFirst(RegExp(r'^account\s+', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s+summary$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s+overview$', caseSensitive: false), '');
    return _cleanText(text);
  }

  String? _extractOptionalExpenseAccountName(String value) {
    final match = RegExp(
      r'\b(?:for|from|of)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(value);

    if (match == null) return null;
    return _cleanText(match.group(1) ?? '');
  }

  String? _extractOptionalTransactionAccountName(String value) {
    final clean = _cleanText(value);
    final match = RegExp(
      r'\b(?:for|from|of|in)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(clean);

    if (match == null) return null;

    final accountText = (match.group(1) ?? '')
        .replaceFirst(RegExp(r'\bon\b.*$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\btoday\b.*$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\byesterday\b.*$', caseSensitive: false), '');
    return _cleanText(accountText);
  }

  String? _transactionSearchTerm(String value) {
    var text = _cleanText(value).toLowerCase();
    final accountName = _extractOptionalTransactionAccountName(text);

    text = text
        .replaceAll(RegExp(r'\b(show|list|find|recent|last|latest)\b'), '')
        .replaceAll(RegExp(r'\b(transactions?|entries)\b'), '')
        .replaceAll(RegExp(r'\bon\b.*$'), '')
        .replaceAll(RegExp(r'\btoday\b'), '')
        .replaceAll(RegExp(r'\byesterday\b'), '')
        .replaceAll(RegExp(r'\bthis\s+month\b'), '')
        .replaceAll(RegExp(r'\b(expenses?|income|spending)\b'), '')
        .replaceAll(RegExp(r'\b(for|from|of|in)\b'), '');

    if (accountName != null && accountName.isNotEmpty) {
      text = text.replaceAll(accountName.toLowerCase(), '');
    }

    text = _cleanText(text);
    return text.isEmpty ? null : text;
  }

  String? _transactionTypeFilter(String value) {
    final text = _cleanText(value).toLowerCase();
    if (text.contains('expense') || text.contains('spent')) return 'expense';
    if (text.contains('income') || text.contains('money added')) return 'income';
    return null;
  }

  String _formatTransactionLine(Map<String, dynamic> transaction) {
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
    final type = transaction['type']?.toString() ?? 'expense';
    final sign = type == 'income' || type == 'transfer_in' ? '+' : '-';
    final description = transaction['description']?.toString().trim();
    final category = transaction['category_name']?.toString().trim();
    final account = transaction['account_name']?.toString().trim();
    final title = description != null && description.isNotEmpty
        ? description
        : category != null && category.isNotEmpty
            ? category
            : type;
    final accountText = account != null && account.isNotEmpty ? ' - $account' : '';

    return '- ${_formatStoredDate(transaction['date']?.toString())}: $sign${_formatMoney(amount.abs())} $title$accountText';
  }

  List<String> _extractSumAccountNames(String value) {
    var text = _cleanText(value);
    final patterns = [
      r'^what\s+(is|was)\s+the\s+',
      r'^what\s+(is|was)\s+',
      r'^show\s+',
      r'^tell\s+me\s+',
      r'^(sum|total)\s+(of\s+)?(current\s+)?balances?\s+(of\s+)?',
      r'^(current\s+)?balances?\s+(of\s+)?',
    ];

    for (final pattern in patterns) {
      text = text.replaceFirst(RegExp(pattern, caseSensitive: false), '');
    }

    return text
        .split(RegExp(r'\s+(?:and|&)\s+|,', caseSensitive: false))
        .map(_cleanText)
        .where((part) => part.isNotEmpty)
        .toList();
  }

  DateTime? _parseQuestionDate(String value) {
    final text = _cleanText(value).toLowerCase();
    final now = DateTime.now();

    if (text.contains('today')) {
      return DateTime(now.year, now.month, now.day);
    }
    if (text.contains('yesterday')) {
      return DateTime(now.year, now.month, now.day - 1);
    }

    final slashMatch =
        RegExp(r'\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b')
            .firstMatch(text);
    if (slashMatch != null) {
      final day = int.tryParse(slashMatch.group(1) ?? '');
      final month = int.tryParse(slashMatch.group(2) ?? '');
      var year = int.tryParse(slashMatch.group(3) ?? '') ?? now.year;
      if (year < 100) year += 2000;
      return _safeDate(year, month, day);
    }

    for (final entry in _monthNumbers.entries) {
      final monthName = entry.key;
      final month = entry.value;
      final dayFirst = RegExp(
        r'\b(\d{1,2})\s+' + monthName + r'(?:\s+(\d{2,4}))?\b',
      ).firstMatch(text);
      if (dayFirst != null) {
        var year = int.tryParse(dayFirst.group(2) ?? '') ?? now.year;
        if (year < 100) year += 2000;
        return _safeDate(year, month, int.tryParse(dayFirst.group(1) ?? ''));
      }

      final monthFirst = RegExp(
        monthName + r'\s+(\d{1,2})(?:\s+(\d{2,4}))?\b',
      ).firstMatch(text);
      if (monthFirst != null) {
        var year = int.tryParse(monthFirst.group(2) ?? '') ?? now.year;
        if (year < 100) year += 2000;
        return _safeDate(
          year,
          month,
          int.tryParse(monthFirst.group(1) ?? ''),
        );
      }
    }

    return null;
  }

  DateTime? _safeDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }

  String _formatMoney(num amount) {
    return '₹${formatMoneyWhole(amount)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_monthLabels[date.month - 1]}';
  }

  String _formatStoredDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'Unknown date';

    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;

    return _formatDate(parsed);
  }

  String _cleanText(String value) {
    return value
        .replaceAll(RegExp(r'[?!.]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'\s+only$', caseSensitive: false), '')
        .trim();
  }

  static const _monthLabels = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _monthNumbers = {
    'january': 1,
    'jan': 1,
    'february': 2,
    'feb': 2,
    'march': 3,
    'mar': 3,
    'april': 4,
    'apr': 4,
    'may': 5,
    'june': 6,
    'jun': 6,
    'july': 7,
    'jul': 7,
    'august': 8,
    'aug': 8,
    'september': 9,
    'sep': 9,
    'october': 10,
    'oct': 10,
    'november': 11,
    'nov': 11,
    'december': 12,
    'dec': 12,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                _aiIconAsset,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.smart_toy_outlined, size: 26),
              ),
            ),
            const SizedBox(width: 8),
            const Text('AI Assistant'),
          ],
        ),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ask about your expenses, balances, reports, or how to use the app.',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final suggestion in _suggestions)
                        ActionChip(
                          label: Text(suggestion),
                          onPressed: () => _useSuggestion(suggestion),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final message = _messages[i];
                  return Align(
                    alignment: message.fromUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: message.fromUser
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: message.fromUser
                              ? cs.onPrimary
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        _send();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Ask a question',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: () {
                      _send();
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiMessage {
  final String text;
  final bool fromUser;

  const _AiMessage({required this.text, required this.fromUser});
}

class _AccountLookupResult {
  final Map<String, dynamic>? account;
  final String? message;

  const _AccountLookupResult({this.account, this.message});
}

class _DateQuestionParts {
  final String accountText;
  final String dateText;
  final bool askedForDate;

  const _DateQuestionParts({
    required this.accountText,
    this.dateText = '',
    this.askedForDate = false,
  });
}

enum _AiIntent {
  currentAccountBalance,
  sumAccountBalances,
  accountBalanceOnDate,
  todayExpense,
  thisMonthExpense,
  accountSpent,
  accountMoneyAdded,
  accountSummary,
  transactionSearch,
  appHelp,
  clarificationNeeded,
  unsupported,
}
