import '../utils/money_formatter.dart';
import 'ai_vault_reader_service.dart';

class AiTransactionQueryEngine {
  final AiVaultReaderService _vault;

  AiTransactionQueryEngine({AiVaultReaderService? vault})
      : _vault = vault ?? AiVaultReaderService();

  Future<String> answer(String question) async {
    final query = _TransactionQuery.parse(question);
    final accountResult = await _resolveAccount(query);
    if (accountResult.message != null) return accountResult.message!;

    final account = accountResult.account;
    final accountId = _toInt(account?['id']);
    final accountName = account?['name']?.toString();
    final keyword = _extractKeyword(question, query, accountName);
    final displayLimit = query.limit.clamp(1, 10).toInt();

    final transactions = await _vault.queryTransactionsForAi(
      keyword: keyword,
      type: query.type,
      accountId: accountId,
      from: query.from,
      to: query.to,
      limit: displayLimit + 1,
    );

    if (transactions.isEmpty) {
      return _emptyMessage(query, accountName, keyword);
    }

    final hasMore = transactions.length > displayLimit;
    final visible = transactions.take(displayLimit).toList();
    final lines = visible
        .asMap()
        .entries
        .map((entry) => _formatTransactionLine(entry.key, entry.value))
        .join('\n');
    final suffix = hasMore ? '\nShowing latest $displayLimit.' : '';

    return '${_heading(query, visible.length, accountName, keyword)}\n$lines$suffix';
  }

  Future<_AccountResult> _resolveAccount(_TransactionQuery query) async {
    final candidate = query.accountCandidate;
    if (candidate == null || candidate.isEmpty) {
      return const _AccountResult();
    }

    final matches = await _vault.findAccountsByName(candidate);
    if (matches.isEmpty) {
      if (query.accountWasExplicit) {
        return const _AccountResult(
          message:
              'I could not confidently match the account name. Which account should I check?',
        );
      }
      return const _AccountResult();
    }

    if (matches.length > 1) {
      final names = matches.map((account) => account['name']).join(' or ');
      return _AccountResult(message: 'Which account do you mean: $names?');
    }

    return _AccountResult(account: matches.first);
  }

  String? _extractKeyword(
    String question,
    _TransactionQuery query,
    String? accountName,
  ) {
    var text = _clean(question).toLowerCase();
    text = _removeDateAndPeriodPhrases(text);

    if (query.accountCandidate != null) {
      text = text.replaceAll(query.accountCandidate!.toLowerCase(), ' ');
    }
    if (accountName != null) {
      text = text.replaceAll(accountName.toLowerCase(), ' ');
    }

    text = text
        .replaceAll(RegExp(r'\b(show|list|find|give|latest|recent|last)\b'), ' ')
        .replaceAll(RegExp(r'\b(transactions?|entries)\b'), ' ')
        .replaceAll(RegExp(r'\b(expenses?|spent|spending)\b'), ' ')
        .replaceAll(RegExp(r'\b(money\s+added|income|added)\b'), ' ')
        .replaceAll(RegExp(r'\b(containing|contains|with|for|from|of|to|in|on)\b'), ' ')
        .replaceAll(RegExp(r'\b(one|two|three|four|five|ten|\d{1,2})\b'), ' ');

    text = _clean(text);
    return text.isEmpty ? null : text;
  }

  String _heading(
    _TransactionQuery query,
    int count,
    String? accountName,
    String? keyword,
  ) {
    final accountText = accountName == null ? '' : ' for $accountName';
    final keywordText = keyword == null ? '' : ' matching $keyword';
    final dateText = query.dateLabel == null ? '' : ' ${query.dateLabel}';

    if (query.isRecent) {
      return 'Latest $count transaction${count == 1 ? '' : 's'}$accountText$keywordText:';
    }

    final typeLabel = query.type == 'expense'
        ? 'expense transaction'
        : query.type == 'income'
            ? 'money-added transaction'
            : 'transaction';
    return 'Found $count $typeLabel${count == 1 ? '' : 's'}$accountText$keywordText$dateText:';
  }

  String _emptyMessage(
    _TransactionQuery query,
    String? accountName,
    String? keyword,
  ) {
    final accountText = accountName == null ? '' : ' for $accountName';
    final dateText = query.dateLabel == null ? '' : ' ${query.dateLabel}';
    final keywordText = keyword == null ? '' : ' $keyword';

    if (query.type == 'expense') {
      return 'I found no$keywordText expense transactions$accountText$dateText.';
    }
    if (query.type == 'income') {
      return 'I found no money-added transactions$accountText$dateText.';
    }
    return 'I found no$keywordText transactions$accountText$dateText.';
  }

  String _formatTransactionLine(int index, Map<String, dynamic> transaction) {
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
    final type = transaction['type']?.toString() ?? 'expense';
    final account = (transaction['accountName'] ?? transaction['account_name'])
            ?.toString()
            .trim();
    final description = transaction['description']?.toString().trim();
    final category =
        (transaction['category'] ?? transaction['category_name'])?.toString().trim();
    final detail = description != null && description.isNotEmpty
        ? description
        : category != null && category.isNotEmpty
            ? category
            : 'No description';

    return '${index + 1}. ${_formatDate(_bestTransactionDate(transaction))} - ${account != null && account.isNotEmpty ? account : 'Unknown account'} - ${_typeLabel(type)} - ₹${formatMoneyWhole(amount.abs())} - $detail';
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'income':
        return 'Money Added';
      case 'expense':
        return 'Expense';
      case 'transfer_in':
        return 'Transfer In';
      case 'transfer_out':
        return 'Transfer Out';
      default:
        return _titleCase(type.replaceAll('_', ' '));
    }
  }

  String? _bestTransactionDate(Map<String, dynamic> transaction) {
    for (final key in ['date', 'transactionDate', 'createdAt', 'updatedAt']) {
      final value = transaction[key]?.toString();
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'Unknown date';
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;

    final day = parsed.day.toString().padLeft(2, '0');
    final month = _monthLabels[parsed.month - 1].substring(0, 3);
    return '$day $month ${parsed.year}';
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _removeDateAndPeriodPhrases(String value) {
    var text = value
        .replaceAll(RegExp(r'\b(today|yesterday|this week|last week|this month|last month)\b'), ' ')
        .replaceAll(RegExp(r'\b\d{1,3}\s+days?\s+ago\b'), ' ')
        .replaceAll(RegExp(r'\b\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?\b'), ' ')
        .replaceAll(RegExp(r'\bbetween\b.*$'), ' ');

    for (final month in _monthNumbers.keys) {
      text = text
          .replaceAll(RegExp(r'\b\d{1,2}\s+' + month + r'(?:\s+\d{2,4})?\b'), ' ')
          .replaceAll(RegExp(month + r'\s+\d{1,2}(?:\s+\d{2,4})?\b'), ' ');
    }

    return _clean(text);
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _clean(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[?!.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
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
}

class _TransactionQuery {
  final String raw;
  final String? type;
  final String? accountCandidate;
  final bool accountWasExplicit;
  final DateTime? from;
  final DateTime? to;
  final String? dateLabel;
  final int limit;
  final bool isRecent;

  const _TransactionQuery({
    required this.raw,
    this.type,
    this.accountCandidate,
    this.accountWasExplicit = false,
    this.from,
    this.to,
    this.dateLabel,
    required this.limit,
    required this.isRecent,
  });

  factory _TransactionQuery.parse(String question) {
    final text = _cleanStatic(question);
    final range = _parseDateRange(text);
    final isRecent = _isRecentQuestion(text);
    final type = _parseType(text);
    final account = _extractAccountCandidate(text);
    final explicitCount = _parseCount(text);
    final limit = explicitCount ??
        (_isSingleLatestQuestion(text)
            ? 1
            : isRecent
                ? 5
                : 10);

    return _TransactionQuery(
      raw: text,
      type: type,
      accountCandidate: account.candidate,
      accountWasExplicit: account.explicit,
      from: range?.from,
      to: range?.to,
      dateLabel: range?.label,
      limit: limit.clamp(1, 10).toInt(),
      isRecent: isRecent || explicitCount != null,
    );
  }

  static String? _parseType(String text) {
    if (text.contains('money added') ||
        text.contains('income') ||
        text.contains('added to')) {
      return 'income';
    }
    if (text.contains('expense') ||
        text.contains('expenses') ||
        text.contains('spent') ||
        text.contains('spending')) {
      return 'expense';
    }
    return null;
  }

  static int? _parseCount(String text) {
    final countText = _removeDatesForCountParsing(text);
    final match =
        RegExp(r'\b(\d{1,2}|one|two|three|four|five|ten)\b').firstMatch(countText);
    if (match == null) return null;

    switch (match.group(1) ?? '') {
      case 'one':
        return 1;
      case 'two':
        return 2;
      case 'three':
        return 3;
      case 'four':
        return 4;
      case 'five':
        return 5;
      case 'ten':
        return 10;
      default:
        return int.tryParse(match.group(1) ?? '');
    }
  }

  static bool _isRecentQuestion(String text) {
    return text.contains('recent') ||
        text.contains('latest') ||
        RegExp(r'\blast\s+(\d{1,2}|one|two|three|four|five|ten)\s+(transactions?|entries|expenses?|income|money\s+added)\b')
            .hasMatch(text) ||
        RegExp(r'\blast\s+(transaction|transactions|entry|entries|expense|expenses|income|money\s+added)\b')
            .hasMatch(text);
  }

  static bool _isSingleLatestQuestion(String text) {
    return RegExp(r'\blast\s+(transaction|entry|expense|income|money\s+added)\b')
        .hasMatch(text);
  }

  static String _removeDatesForCountParsing(String text) {
    var value = text
        .replaceAll(RegExp(r'\b\d{1,3}\s+days?\s+ago\b'), ' ')
        .replaceAll(RegExp(r'\b\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?\b'), ' ')
        .replaceAll(RegExp(r'\bbetween\b.*$'), ' ');

    for (final month in AiTransactionQueryEngine._monthNumbers.keys) {
      value = value
          .replaceAll(RegExp(r'\b\d{1,2}\s+' + month + r'(?:\s+\d{2,4})?\b'), ' ')
          .replaceAll(RegExp(month + r'\s+\d{1,2}(?:\s+\d{2,4})?\b'), ' ');
    }

    return _cleanStatic(value);
  }

  static _AccountCandidate _extractAccountCandidate(String text) {
    final explicit = RegExp(r'\b(?:of|from|for|to|in)\s+(.+)$').firstMatch(text);
    if (explicit != null) {
      final candidate = _cleanAccountCandidate(explicit.group(1) ?? '');
      if (candidate.isNotEmpty) {
        return _AccountCandidate(candidate: candidate, explicit: true);
      }
    }

    final leading = RegExp(
      r'^(?:show|list|find|give)?\s*(.+?)\s+(?:transactions?|entries|expenses?|income|money\s+added)\b',
    ).firstMatch(text);
    if (leading != null) {
      final candidate = _cleanAccountCandidate(leading.group(1) ?? '');
      if (candidate.isNotEmpty) {
        return _AccountCandidate(candidate: candidate, explicit: false);
      }
    }

    return const _AccountCandidate();
  }

  static String _cleanAccountCandidate(String value) {
    var text = value
        .replaceAll(RegExp(r'\b(today|yesterday|this week|last week|this month|last month)\b'), ' ')
        .replaceAll(RegExp(r'\b\d{1,3}\s+days?\s+ago\b'), ' ')
        .replaceAll(RegExp(r'\b\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?\b'), ' ')
        .replaceAll(RegExp(r'\bon\b.*$'), ' ')
        .replaceAll(RegExp(r'\bbetween\b.*$'), ' ')
        .replaceAll(RegExp(r'\b(last|latest|recent|show|list|find|give)\b'), ' ')
        .replaceAll(RegExp(r'\b(one|two|three|four|five|ten|\d{1,2})\b'), ' ')
        .replaceAll(RegExp(r'\b(transactions?|entries|expenses?|expense|income|money\s+added|spent|spending)\b'), ' ');

    for (final month in AiTransactionQueryEngine._monthNumbers.keys) {
      text = text
          .replaceAll(RegExp(r'\b\d{1,2}\s+' + month + r'(?:\s+\d{2,4})?\b'), ' ')
          .replaceAll(RegExp(month + r'\s+\d{1,2}(?:\s+\d{2,4})?\b'), ' ');
    }

    return _cleanStatic(text);
  }

  static _DateRange? _parseDateRange(String text) {
    final betweenIndex = text.indexOf('between ');
    if (betweenIndex >= 0) {
      final rangeText = text.substring(betweenIndex + 'between '.length);
      final parts = rangeText.split(RegExp(r'\s+and\s+'));
      if (parts.length >= 2) {
        final from = _parseSingleDate(parts.first);
        final to = _parseSingleDate(parts.sublist(1).join(' and '));
        if (from != null && to != null) {
          final first = from.isAfter(to) ? to : from;
          final second = from.isAfter(to) ? from : to;
          return _DateRange(
            from: _startOfDay(first),
            to: _endOfDay(second),
            label: 'between ${_shortDate(first)} and ${_shortDate(second)}',
          );
        }
      }
    }

    final period = _parsePeriod(text);
    if (period != null) return period;

    final date = _parseSingleDate(text);
    if (date != null) {
      final label = text.contains('today')
          ? 'for today'
          : text.contains('yesterday')
              ? 'for yesterday'
              : 'on ${_shortDate(date)}';
      return _DateRange(from: _startOfDay(date), to: _endOfDay(date), label: label);
    }

    return null;
  }

  static _DateRange? _parsePeriod(String text) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (text.contains('this week')) {
      final from = today.subtract(Duration(days: today.weekday - 1));
      return _DateRange(from: _startOfDay(from), to: _endOfDay(today), label: 'this week');
    }
    if (text.contains('last week')) {
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final from = thisWeekStart.subtract(const Duration(days: 7));
      final to = thisWeekStart.subtract(const Duration(days: 1));
      return _DateRange(from: _startOfDay(from), to: _endOfDay(to), label: 'last week');
    }
    if (text.contains('this month')) {
      final from = DateTime(now.year, now.month);
      final to = DateTime(now.year, now.month + 1, 0);
      return _DateRange(from: _startOfDay(from), to: _endOfDay(to), label: 'this month');
    }
    if (text.contains('last month')) {
      final from = DateTime(now.year, now.month - 1);
      final to = DateTime(now.year, now.month, 0);
      return _DateRange(from: _startOfDay(from), to: _endOfDay(to), label: 'last month');
    }

    return null;
  }

  static DateTime? _parseSingleDate(String value) {
    final text = _cleanStatic(value);
    final now = DateTime.now();

    if (text.contains('today')) return DateTime(now.year, now.month, now.day);
    if (text.contains('yesterday')) return DateTime(now.year, now.month, now.day - 1);

    final daysAgo = RegExp(r'\b(\d{1,3})\s+days?\s+ago\b').firstMatch(text);
    if (daysAgo != null) {
      final days = int.tryParse(daysAgo.group(1) ?? '');
      if (days != null) {
        return DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
      }
    }

    final numeric =
        RegExp(r'\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b').firstMatch(text);
    if (numeric != null) {
      final day = int.tryParse(numeric.group(1) ?? '');
      final month = int.tryParse(numeric.group(2) ?? '');
      var year = int.tryParse(numeric.group(3) ?? '') ?? now.year;
      if (year < 100) year += 2000;
      return _safeDate(year, month, day);
    }

    for (final entry in AiTransactionQueryEngine._monthNumbers.entries) {
      final monthName = entry.key;
      final month = entry.value;
      final dayFirst =
          RegExp(r'\b(\d{1,2})\s+' + monthName + r'(?:\s+(\d{2,4}))?\b')
              .firstMatch(text);
      if (dayFirst != null) {
        var year = int.tryParse(dayFirst.group(2) ?? '') ?? now.year;
        if (year < 100) year += 2000;
        return _safeDate(year, month, int.tryParse(dayFirst.group(1) ?? ''));
      }
    }

    return null;
  }

  static DateTime? _safeDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) return null;
    return date;
  }

  static DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  static String _shortDate(DateTime date) {
    return '${date.day} ${AiTransactionQueryEngine._monthLabels[date.month - 1].substring(0, 3)}';
  }

  static String _cleanStatic(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[?!.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _DateRange {
  final DateTime from;
  final DateTime to;
  final String label;

  const _DateRange({
    required this.from,
    required this.to,
    required this.label,
  });
}

class _AccountCandidate {
  final String? candidate;
  final bool explicit;

  const _AccountCandidate({this.candidate, this.explicit = false});
}

class _AccountResult {
  final Map<String, dynamic>? account;
  final String? message;

  const _AccountResult({this.account, this.message});
}
