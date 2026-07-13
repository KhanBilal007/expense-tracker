import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../utils/money_formatter.dart';

enum _ResetChoice { date, amount }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseHelper();
  DateTime? _from;
  DateTime? _to;
  double _accountTotal = 0, _expense = 0, _balance = 0;
  String? _resetDate;
  double _resetBase = 0, _resetAmount = 0, _balanceBeforeReset = 0;
  Map<String, double> _catExp = {};
  List<Map<String, dynamic>> _txs = [], _accounts = [];
  Set<int> _resetTransactionIds = {};
  int? _selectedAccountId;
  String? _selectedAccountName;
  bool _loading = true;
  bool _selectingReset = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final a = await _db.getAccounts();
    if (!mounted) return;
    setState(() => _accounts = a);
    _load();
  }

  String? get _fromStr => _from == null
      ? null
      : '${DateFormat('yyyy-MM-dd').format(_from!)}T00:00:00.000';
  String? get _toStr => _to == null
      ? null
      : '${DateFormat('yyyy-MM-dd').format(_to!)}T23:59:59.999';

  String? _laterDate(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.compareTo(b) > 0 ? a : b;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      String? resetDate;
      double resetBase = 0, resetAmount = 0, balanceBeforeReset = 0;
      double reportTotal = 0, expense = 0, reportBalance = 0;
      if (_selectedAccountId != null) {
        final summary = await _db.getAccountSummary(_selectedAccountId!);
        reportTotal = summary['availableFunds'] ?? 0;
        expense = summary['spent'] ?? 0;
        reportBalance = summary['currentBalance'] ?? 0;
        resetDate = await _db.getResetDate(_selectedAccountId!);
        resetBase = await _db.getResetReportBase(_selectedAccountId!);
        resetAmount = await _db.getResetAmount(_selectedAccountId!);
        balanceBeforeReset =
            await _db.getResetBalanceBeforeReset(_selectedAccountId!);
      } else {
        final accounts =
            _accounts.isNotEmpty ? _accounts : await _db.getAccounts();
        for (final account in accounts) {
          final summary = await _db.getAccountSummary(account['id'] as int);
          reportTotal += summary['availableFunds'] ?? 0;
          expense += summary['spent'] ?? 0;
          reportBalance += summary['currentBalance'] ?? 0;
        }
      }
      final rangeFrom =
          resetDate == null ? _fromStr : _laterDate(resetDate, _fromStr);
      final catExp = await _db.getRangeCategoryExpenses(rangeFrom, _toStr,
          accountId: _selectedAccountId);
      final txs = await _db.getTransactionsByRange(rangeFrom, _toStr,
          accountId: _selectedAccountId);
      final resetIds = await _db.getResetTransactionIds();
      if (!mounted) return;
      setState(() {
        _accountTotal = reportTotal;
        _expense = expense;
        _balance = reportBalance;
        _resetDate = resetDate;
        _resetBase = resetBase;
        _resetAmount = resetAmount;
        _balanceBeforeReset = balanceBeforeReset;
        _resetTransactionIds = resetIds;
        _catExp = catExp;
        _txs = txs;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _from ?? _to ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: _to ?? DateTime.now(),
        locale: const Locale('en'));
    if (d != null) {
      setState(() => _from = d);
      _load();
    }
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _to ?? DateTime.now(),
        firstDate: _from ?? DateTime(2020),
        lastDate: DateTime.now(),
        locale: const Locale('en'));
    if (d != null) {
      setState(() => _to = d);
      _load();
    }
  }

  double? _parseAmount(String value) {
    return double.tryParse(value.replaceAll(',', '').trim());
  }

  void _confirmResetOld() async {
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select an account first'),
          backgroundColor: Colors.orange));
      return;
    }
    final account = await _db.getAccountById(_selectedAccountId!);
    if (!mounted) return;
    final currentAccountBalance =
        account == null ? 0.0 : (account['balance'] as num).toDouble();
    final amountCtrl = TextEditingController();
    String? errorText;

    final resetAmount = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reset account view'),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Current account balance for "$_selectedAccountName" is ₹${formatMoneyWhole(currentAccountBalance)}.'),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Reset from amount',
                    prefixText: '₹ ',
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                    'Transactions are not deleted. The entered amount becomes part of the fixed report base.'),
              ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                final amount = _parseAmount(amountCtrl.text);
                if (amount == null || amount <= 0) {
                  setDialogState(() => errorText = 'Enter a valid amount');
                  return;
                }
                Navigator.pop(ctx, amount);
              },
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
    amountCtrl.dispose();
    if (resetAmount == null) return;

    await _db.resetAccount(_selectedAccountId!, resetAmount: resetAmount);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Reset on ${DateFormat('dd MMM yyyy', 'en').format(DateTime.now())} from amount ₹${formatMoneyWhole(resetAmount)}'),
        backgroundColor: Colors.green,
      ));
      _load();
    }
  }

  Future<void> _confirmReset() async {
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select an account first'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final choice = await showDialog<_ResetChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset account'),
        content: const Text('How do you want to reset this account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ResetChoice.date),
            child: const Text('Reset by Date'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ResetChoice.amount),
            child: const Text('Reset by Amount'),
          ),
        ],
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == _ResetChoice.date) {
      await _confirmResetByDate();
      return;
    }
    _startResetByAmount();
  }

  void _startResetByAmount() {
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select an account first'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() => _selectingReset = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tap a transaction to use as reset amount')),
    );
  }

  Future<void> _confirmResetByDate() async {
    final accountId = _selectedAccountId;
    final accountName = _selectedAccountName ?? 'selected account';
    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select an account first'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _to ?? _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('en'),
    );
    if (selectedDate == null) return;

    final preview =
        await _db.calculateAccountBalanceAtDate(accountId, selectedDate);
    if (!mounted) return;
    if (preview == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not calculate reset balance for this account.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final balance = preview['balance'] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Reset by Date'),
        content: Text(
          'Recalculate "$accountName" balance up to ${DateFormat('dd MMM yyyy', 'en').format(selectedDate)} as ₹${formatMoneyWhole(balance)}?\n\nTransactions will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _db.resetAccountByDate(accountId, selectedDate);
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reset by Date failed.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _selectingReset = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Reset by Date applied. Balance recalculated to ₹${formatMoneyWhole(result['balance'] ?? 0)}.'),
      backgroundColor: Colors.green,
    ));
    await _load();
  }

  Future<void> _resetFromTransaction(Map<String, dynamic> tx) async {
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select an account first'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final reset =
        await _db.resetAccountFromTransaction(_selectedAccountId!, tx);
    final amount = reset['amount'] ?? 0;
    final balanceBeforeReset = reset['balanceBeforeReset'] ?? 0;

    if (!mounted) return;
    setState(() => _selectingReset = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Balance Reset Successful\n\nBalance Before Reset: ₹${formatMoneyWhole(balanceBeforeReset)}\nNew Starting Balance: ₹${formatMoneyWhole(amount)}\n\nPrevious transactions are preserved.\nFuture balances will be calculated from the new starting balance.'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 7),
    ));
    _load();
  }

  Future<void> _confirmUndoReset() async {
    final accountId = _selectedAccountId;
    if (accountId == null || _resetDate == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo reset?'),
        content: const Text(
          'This will remove the report reset for this account. Old transactions will be visible again. This will not delete transactions or change account balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Undo Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _db.clearAccountReset(accountId);
    if (!mounted) return;
    setState(() => _selectingReset = false);
    _load();
  }

  void _showAccountPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter by account',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ListTile(
                  leading: CircleAvatar(
                      backgroundColor: Colors.teal.withValues(alpha: 0.1),
                      child:
                          const Icon(Icons.all_inclusive, color: Colors.teal)),
                  title: const Text('All accounts'),
                  trailing: _selectedAccountId == null
                      ? const Icon(Icons.check, color: Colors.teal)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedAccountId = null;
                      _selectedAccountName = null;
                      _selectingReset = false;
                      _selectingReset = false;
                    });
                    Navigator.pop(context);
                    _load();
                  },
                ),
                ..._accounts.map((a) => ListTile(
                      leading: CircleAvatar(
                          backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                          child: const Icon(Icons.account_balance_wallet,
                              color: Colors.indigo)),
                      title: Text(a['name'] as String),
                      subtitle: Text(
                          '₹${formatMoneyWhole(a['balance'] as num)}'),
                      trailing: _selectedAccountId == a['id']
                          ? const Icon(Icons.check, color: Colors.teal)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedAccountId = a['id'] as int;
                          _selectedAccountName = a['name'] as String;
                          _selectingReset = false;
                        });
                        Navigator.pop(context);
                        _load();
                      },
                    )),
                const SizedBox(height: 8),
              ])),
    );
  }

  Color _txColor(String t) => (t == 'income' || t == 'transfer_in')
      ? Colors.green
      : (t == 'expense' || t == 'transfer_out')
          ? Colors.red
          : Colors.blue;
  IconData _txIcon(String t) => (t == 'income' || t == 'transfer_in')
      ? Icons.arrow_downward
      : Icons.arrow_upward;
  String _txSign(String t) => (t == 'income' || t == 'transfer_in') ? '+' : '-';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dayFmt = DateFormat('dd MMM yyyy', 'en');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: (_selectedAccountId != null && _resetDate != null)
                ? _confirmUndoReset
                : _confirmReset,
            icon: const Icon(Icons.restart_alt, color: Colors.white, size: 18),
            label: Text(
              (_selectedAccountId != null && _resetDate != null)
                  ? 'Undo Reset'
                  : 'Reset',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          TextButton.icon(
            onPressed: _showAccountPicker,
            icon: const Icon(Icons.account_balance_wallet,
                color: Colors.white, size: 18),
            label: Text(_selectedAccountName ?? 'All',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  // Reset info banner
                  if (_resetDate != null && _selectedAccountId != null)
                    Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(
                            'Reset on ${DateFormat('dd MMM yyyy', 'en').format(DateTime.parse(_resetDate!))}. Balance Before Reset ₹${formatMoneyWhole(_balanceBeforeReset)}. Reset Amount ₹${formatMoneyWhole(_resetAmount)}',
                            style: const TextStyle(
                                color: Colors.green, fontSize: 12),
                          )),
                        ])),

                  // Date range picker
                  Card(
                      child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(children: [
                      const Icon(Icons.date_range,
                          color: Colors.teal, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: GestureDetector(
                        onTap: _pickFrom,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('From',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                Text(
                                    _from == null
                                        ? 'From'
                                        : dayFmt.format(_from!),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ]),
                        ),
                      )),
                      const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('to',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey))),
                      Expanded(
                          child: GestureDetector(
                        onTap: _pickTo,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('To',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                Text(_to == null ? 'To' : dayFmt.format(_to!),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ]),
                        ),
                      )),
                      if (_from != null || _to != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Clear dates',
                          onPressed: () {
                            setState(() {
                              _from = null;
                              _to = null;
                            });
                            _load();
                          },
                        ),
                    ]),
                  )),
                  const SizedBox(height: 16),

                  // Summary cards
                  Row(children: [
                    _summaryCard('Available Funds', _accountTotal, Colors.blue,
                        Icons.account_balance_wallet),
                    const SizedBox(width: 8),
                    _summaryCard(
                        'Spent', _expense, Colors.red, Icons.arrow_upward),
                    const SizedBox(width: 8),
                    _summaryCard(
                        'Current Balance',
                        _balance,
                        _balance >= 0 ? Colors.green : Colors.orange,
                        Icons.account_balance_wallet),
                  ]),
                  const SizedBox(height: 20),

                  // Category breakdown
                  if (_catExp.isNotEmpty) ...[
                    _secHeader('Expense by category'),
                    const SizedBox(height: 10),
                    ..._catExp.entries.map((e) {
                      final pct = _expense > 0
                          ? (e.value / _expense).clamp(0.0, 1.0)
                          : 0.0;
                      return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(e.key,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500)),
                                      Text(
                                          '₹${formatMoneyWhole(e.value)}  ${(pct * 100).toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    ]),
                                const SizedBox(height: 4),
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                        value: pct,
                                        minHeight: 8,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                cs.primary))),
                              ]));
                    }),
                    const SizedBox(height: 10),
                  ],

                  // Transaction list
                  _secHeader('Transactions (${_txs.length})'),
                  const SizedBox(height: 8),
                  if (_txs.isEmpty)
                    Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                              _resetDate != null
                                  ? 'No transactions after reset'
                                  : 'No transactions in selected range',
                              style: const TextStyle(color: Colors.grey)),
                        ]))
                  else
                    ..._txs.map((t) {
                      final type = t['type'] as String? ?? 'expense';
                      final col = _txColor(type);
                      final displayAmount =
                          ((t['amount'] as num).toDouble()).abs();
                      final date =
                          DateTime.tryParse(t['date'] ?? '') ?? DateTime.now();
                      final desc =
                          t['description']?.toString().isNotEmpty == true
                              ? t['description'] as String
                              : (t['category_name'] as String? ?? type);
                      final cat = t['category_name'] as String?;
                      final txId = t['id'] as int?;
                      final displayDesc = _resetTransactionIds.contains(txId)
                          ? 'Balance Reset'
                          : type == 'income'
                              ? 'Money Added'
                              : type == 'expense'
                                  ? 'Expense'
                                  : desc;
                      return Card(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          child: ListTile(
                              dense: true,
                              onTap: _selectingReset
                                  ? () => _resetFromTransaction(t)
                                  : null,
                              leading:
                                  Icon(_txIcon(type), color: col, size: 18),
                              title: Text(displayDesc,
                                  style: const TextStyle(fontSize: 13)),
                              subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (cat != null &&
                                        cat.isNotEmpty &&
                                        desc != cat)
                                      Text(cat,
                                          style: TextStyle(
                                              fontSize: 11, color: cs.primary)),
                                    Text(
                                        DateFormat('dd MMM, hh:mm a', 'en')
                                            .format(date),
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey)),
                                  ]),
                              trailing: Text(
                                  '${_txSign(type)}₹${formatMoneyWhole(displayAmount)}',
                                  style: TextStyle(
                                      color: col,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13))));
                    }),
                ]),
              ),
            ),
    );
  }

  Widget _summaryCard(String label, double val, Color color, IconData icon) =>
      Expanded(
          child: Card(
              child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: color, size: 18),
                        const SizedBox(height: 4),
                        Text(label,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                            maxLines: 2,
                            softWrap: true),
                        Text('₹${formatMoneyWhole(val.abs())}',
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ]))));

  Widget _secHeader(String t) => Align(
      alignment: Alignment.centerLeft,
      child: Text(t,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)));
}
