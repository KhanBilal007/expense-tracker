import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../services/sms_parser.dart';

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

  // Item 2: paste SMS dialog  
  void _showSmsDialog() async {
    final smsCtrl  = TextEditingController();
    final accounts = await _db.getAccounts();
    final cats     = await _db.getCategories();
    final defAccId = await _db.getDefaultAccountId();
    int? selAcc    = (defAccId != null && accounts.any((a) => a['id'] == defAccId)) ? defAccId : (accounts.isNotEmpty ? accounts.first['id'] as int : null);
    int? selCat    = cats.isNotEmpty ? cats.first['id'] as int : null;
    if (!mounted) return;
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setS) {
      Map<String, dynamic>? parsed;
      return AlertDialog(
        title: const Text('Paste PhonePe / UPI SMS'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Paste your SMS text below:', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(controller: smsCtrl, maxLines: 4, decoration: const InputDecoration(hintText: 'Rs.500 debited…', border: OutlineInputBorder()),
            onChanged: (val) { setS(() => parsed = SmsParser.parse(val)); }),
          if (parsed != null) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('✓ ${parsed!['type']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                Text('₹${parsed!['amount']}  •  ${parsed!['merchant']}'),
              ])),
            const SizedBox(height: 8),
            DropdownButtonHideUnderline(child: DropdownButton<int>(isExpanded: true, value: selAcc, items: accounts.map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['name'] as String))).toList(), onChanged: (v) => setS(() => selAcc = v))),
            if (parsed!['type'] == 'expense') DropdownButtonHideUnderline(child: DropdownButton<int>(isExpanded: true, value: selCat, items: cats.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['name'] as String))).toList(), onChanged: (v) => setS(() => selCat = v))),
          ],
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: parsed == null || selAcc == null ? null : () async {
              final amount = (parsed!['amount'] as num).toDouble(); final type = parsed!['type'] as String;
              final acc = accounts.firstWhere((a) => a['id'] == selAcc); final bal = (acc['balance'] as num).toDouble();
              final newBal = type == 'expense' ? bal - amount : bal + amount;
              await _db.updateAccountBalance(selAcc!, newBal);
              await _db.insertTransaction({'account_id': selAcc, 'category_id': type == 'expense' ? selCat : null, 'type': type, 'amount': amount, 'description': parsed!['merchant'], 'date': DateTime.now().toIso8601String(), 'balance_after': newBal});
              if (context.mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Add')),
        ],
      );
    })).then((_) => smsCtrl.dispose());
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
          IconButton(icon: const Icon(Icons.sms), tooltip: 'Paste SMS', onPressed: _showSmsDialog),
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
