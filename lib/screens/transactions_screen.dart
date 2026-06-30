import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../services/downloads_scanner_service.dart';
import '../services/phonepe_statement_parser.dart';
import 'import_review_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _all = [], _filtered = [], _accounts = [], _categories = [];
  String  _filterType = 'all';
  int?    _filterAccount, _filterCategory;
  DateTime? _fromDate, _toDate;   // item 12: date range
  bool _syncing = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final txs  = await _db.getTransactions();
    final accs = await _db.getAccounts();
    final cats = await _db.getCategories();
    if (!mounted) return;
    _all = txs; _accounts = accs; _categories = cats; _applyFilter(); setState(() {});
  }

  void _applyFilter() {
    _filtered = _all.where((t) {
      final type = t['type'] as String? ?? '';
      // item 14: filter only shows income/expense, not transfer types
      if (_filterType == 'income'  && type != 'income')  return false;
      if (_filterType == 'expense' && type != 'expense') return false;
      if (_filterAccount  != null && t['account_id']  != _filterAccount)  return false;
      if (_filterCategory != null && t['category_id'] != _filterCategory) return false;
      // item 12: date range
      if (_fromDate != null || _toDate != null) {
        final date = DateTime.tryParse(t['date'] ?? '');
        if (date == null) return false;
        if (_fromDate != null && date.isBefore(_fromDate!)) return false;
        if (_toDate   != null && date.isAfter(_toDate!.add(const Duration(days: 1)))) return false;
      }
      return true;
    }).toList();
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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => SingleChildScrollView(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Filter Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
          // item 14: only all/income/expense chips
          Wrap(spacing: 8, children: ['all','income','expense'].map((t) => ChoiceChip(
            label: Text(t == 'all' ? 'All' : t[0].toUpperCase() + t.substring(1)),
            selected: _filterType == t,
            onSelected: (_) { setS(() => _filterType = t); setState(() { _applyFilter(); }); },
          )).toList()),
          const SizedBox(height: 12),
          // item 12: date range pickers (from x to y)
          const Text('Date Range', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text(_fromDate != null ? DateFormat('dd MMM yy').format(_fromDate!) : 'From', style: const TextStyle(fontSize: 12)),
              onPressed: () async {
                final d = await showDatePicker(context: ctx, initialDate: _fromDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                if (d != null) { setS(() => _fromDate = d); setState(() { _applyFilter(); }); }
              },
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text(_toDate != null ? DateFormat('dd MMM yy').format(_toDate!) : 'To', style: const TextStyle(fontSize: 12)),
              onPressed: () async {
                final d = await showDatePicker(context: ctx, initialDate: _toDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) { setS(() => _toDate = d); setState(() { _applyFilter(); }); }
              },
            )),
            if (_fromDate != null || _toDate != null)
              IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () { setS(() { _fromDate = null; _toDate = null; }); setState(() { _applyFilter(); }); }),
          ]),
          const SizedBox(height: 12),
          const Text('Account', style: TextStyle(fontWeight: FontWeight.w600)),
          DropdownButtonHideUnderline(child: DropdownButton<int?>(isExpanded: true, value: _filterAccount, hint: const Text('All accounts'),
            items: [const DropdownMenuItem<int?>(value: null, child: Text('All accounts')), ..._accounts.map((a) => DropdownMenuItem<int?>(value: a['id'] as int, child: Text(a['name'] as String)))],
            onChanged: (v) { setS(() => _filterAccount = v); setState(() { _applyFilter(); }); })),
          const SizedBox(height: 12),
          const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
          DropdownButtonHideUnderline(child: DropdownButton<int?>(isExpanded: true, value: _filterCategory, hint: const Text('All categories'),
            items: [const DropdownMenuItem<int?>(value: null, child: Text('All categories')), ..._categories.map((c) => DropdownMenuItem<int?>(value: c['id'] as int, child: Text(c['name'] as String)))],
            onChanged: (v) { setS(() => _filterCategory = v); setState(() { _applyFilter(); }); })),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: () { setState(() { _filterType = 'all'; _filterAccount = null; _filterCategory = null; _fromDate = null; _toDate = null; _applyFilter(); }); Navigator.pop(context); },
            child: const Text('Clear All Filters'))),
          const SizedBox(height: 8),
        ]),
      )),
    );
  }

  // PhonePe statement sync (replaces the old SMS paste feature)
  Future<void> _syncPhonePe() async {
    if (_syncing) return;
    debugPrint('[TransactionsScreen] ===== Sync PhonePe button tapped =====');
    setState(() => _syncing = true);
    try {
      debugPrint('[TransactionsScreen] Calling DownloadsScannerService.findLatestStatement()...');
      final scanResult = await DownloadsScannerService.findLatestStatement(
        onNeedFolderPick: _showFolderPickDialog,
      );
      if (!scanResult.success) {
        debugPrint('[TransactionsScreen] Scan failed: ${scanResult.error}');
        final msg = scanResult.error ??
            'No PhonePe statement found in Downloads. Please download the latest PhonePe statement and try again.';
        _snack(msg, error: true);
        return;
      }

      final file = scanResult.file!;
      final ext  = file.path.split('.').last.toLowerCase();
      debugPrint('[TransactionsScreen] Statement file found: ${file.path} (extension: .$ext)');

      List<PhonePeTransaction> parsed;
      try {
        parsed = ext == 'pdf'
            ? await PhonePeStatementParser.parsePdf(file)
            : await PhonePeStatementParser.parseCsv(file);
      } catch (e) {
        debugPrint('[TransactionsScreen] Parser threw an exception: $e');
        _snack('Could not parse statement: $e', error: true);
        return;
      }
      debugPrint('[TransactionsScreen] Parser finished. Transactions parsed: ${parsed.length}');

      if (parsed.isEmpty) {
        _snack('Statement found, but no transactions could be detected.', error: false);
        return;
      }

      final allKeys   = parsed.map((t) => t.dedupeKey).toList();
      final newKeySet = await _db.filterNewDedupeKeys(allKeys);
      final newTxns   = parsed.where((t) => newKeySet.contains(t.dedupeKey)).toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime)); // newest first
      final skippedCount = parsed.length - newTxns.length;
      debugPrint('[TransactionsScreen] New: ${newTxns.length}, skipped duplicates: $skippedCount');

      if (newTxns.isEmpty) {
        _snack('No new transactions found', error: false);
        return;
      }

      final accounts = await _db.getAccounts();
      if (accounts.isEmpty) {
        _snack('Please create an account first.', error: true);
        return;
      }

      final defaultAccountId = await _db.getDefaultAccountId();
      int accountId = accounts.first['id'] as int;

      if (defaultAccountId != null) {
        final matchingDefault = accounts.where((a) => a['id'] == defaultAccountId);
        if (matchingDefault.isNotEmpty) {
          accountId = matchingDefault.first['id'] as int;
        }
      }
      final selectedAccountName = accounts.firstWhere((a) => a['id'] == accountId)['name'];
      debugPrint('[TransactionsScreen] PhonePe import account selected: $selectedAccountName ($accountId)');

      if (!mounted) return;
      debugPrint('[TransactionsScreen] Opening review screen with ${newTxns.length} new transaction(s)...');
      final result = await Navigator.of(context).push<ImportResult>(
        MaterialPageRoute(
          builder: (_) => ImportReviewScreen(
            newTransactions      : newTxns,
            skippedDuplicateCount: skippedCount,
            accountId            : accountId,
          ),
        ),
      );
      debugPrint('[TransactionsScreen] Review screen closed. Result: $result');

      if (result != null && result.savedCount > 0) {
        await _load(); // refresh transaction list, newest first (already sorted by DB query)
        _snack('Imported ${result.savedCount} new transaction${result.savedCount == 1 ? '' : 's'}'
            '${result.skippedCount > 0 ? '. Skipped ${result.skippedCount} duplicate${result.skippedCount == 1 ? '' : 's'}' : ''}');
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
      debugPrint('[TransactionsScreen] ===== Sync PhonePe flow finished =====');
    }
  }


  Future<void> _showChangeAccountDialog(Map<String, dynamic> transaction) async {
    if (_accounts.isEmpty) {
      _snack('Please create an account first.', error: true);
      return;
    }

    final transactionId = transaction['id'] as int?;
    if (transactionId == null) {
      _snack('Transaction id missing.', error: true);
      return;
    }

    int? selectedAccountId = transaction['account_id'] as int?;
    if (selectedAccountId == null || !_accounts.any((a) => a['id'] == selectedAccountId)) {
      selectedAccountId = _accounts.first['id'] as int;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Account'),
          content: DropdownButtonFormField<int>(
            value: selectedAccountId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Account',
              border: OutlineInputBorder(),
            ),
            items: _accounts
                .map((a) => DropdownMenuItem<int>(
                      value: a['id'] as int,
                      child: Text(a['name'] as String),
                    ))
                .toList(),
            onChanged: (v) => setDialogState(() => selectedAccountId = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedAccountId == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || selectedAccountId == null) return;

    final oldAccountId = transaction['account_id'] as int?;
    if (oldAccountId == selectedAccountId) {
      _snack('Account already selected.');
      return;
    }

    try {
      await _db.updateTransactionAccount(transactionId, selectedAccountId!);
      await _load();
      _snack('Transaction account updated.');
    } catch (e) {
      debugPrint('[TransactionsScreen] Could not update transaction account: $e');
      _snack('Could not update account: $e', error: true);
    }
  }

  Future<bool> _showFolderPickDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select PhonePe Statement'),
        content: const Text(
          'Your Downloads folder could not be accessed directly.\n\n'
          'Please select your PhonePe statement file once. The app will '
          'remember the folder and find new statements automatically next time.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00');
    final filtersActive = _filterType != 'all' || _filterAccount != null || _filterCategory != null || _fromDate != null || _toDate != null;
    return Scaffold(
      appBar: AppBar(
        title: Text('Transactions${_filtered.length != _all.length ? ' (${_filtered.length})' : ''}'),
        backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
        actions: [
          _syncing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
                )
              : IconButton(icon: const Icon(Icons.sync_alt_rounded), tooltip: 'Sync PhonePe', onPressed: _syncPhonePe),
          Stack(alignment: Alignment.topRight, children: [
            IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilterSheet),
            if (filtersActive) Positioned(top: 8, right: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
          ]),
        ],
      ),
      body: _filtered.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey),
              const SizedBox(height: 10),
              const Text('No transactions found', style: TextStyle(color: Colors.grey)),
              if (filtersActive) TextButton(onPressed: () => setState(() { _filterType = 'all'; _filterAccount = null; _filterCategory = null; _fromDate = null; _toDate = null; _applyFilter(); }), child: const Text('Clear filters')),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final t    = _filtered[i];
                final type = t['type'] as String? ?? 'expense';
                final col  = _txColor(type);
                final sign = _txSign(type);
                final displayAmount = ((t['amount'] as num).toDouble()).abs();
                final date = DateTime.tryParse(t['date'] ?? '') ?? DateTime.now();
                final desc = t['description']?.toString().isNotEmpty == true ? t['description'] as String : (t['category_name'] as String? ?? 'Transaction');
                final cat  = t['category_name'] as String?;
                return Card(margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(
                  onTap: () => _showChangeAccountDialog(t),
                  leading: CircleAvatar(backgroundColor: col.withValues(alpha: 0.1), child: Icon(_txIcon(type), color: col, size: 18)),
                  title: Text(desc, style: const TextStyle(fontWeight: FontWeight.w500)),
                  // item 6: category shown in subtitle
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (cat != null && cat.isNotEmpty && desc != cat) Text(cat, style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w500)),
                    Text('${t['account_name'] ?? ''} • ${DateFormat('dd MMM yyyy, hh:mm a').format(date)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
                  // item 10: NO delete button
                  trailing: Text('$sign₹${fmt.format(displayAmount)}', style: TextStyle(color: col, fontWeight: FontWeight.bold)),
                ));
              }),
    );
  }
}
