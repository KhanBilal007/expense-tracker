import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../services/sheets_service.dart';
import '../utils/money_formatter.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});
  @override State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _db = DatabaseHelper(); final _sheets = SheetsService();
  final _amountCtrl = TextEditingController(), _descCtrl = TextEditingController();
  List<Map<String, dynamic>> _accounts = [], _categories = [];
  int? _selectedAccount, _selectedCategory; bool _saving = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _amountCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final accounts = await _db.getManualEntryAccounts(); final categories = await _db.getCategories(); final defAccId = await _db.getDefaultAccountId();
    if (!mounted) return;
    setState(() {
      _accounts = accounts; _categories = categories;
      _selectedAccount  = (defAccId != null && accounts.any((a) => a['id'] == defAccId)) ? defAccId : (accounts.isNotEmpty ? accounts.first['id'] as int : null);
      if (categories.isNotEmpty) _selectedCategory = categories.first['id'] as int;
    });
    if (accounts.isEmpty && mounted) {
      _snack('Please create another account for manual entries. PhonePe is managed by Sync.');
    }
  }

  Future<void> _checkBudget(int? catId) async {
    if (catId == null || !mounted) return;
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final budget = await _db.getBudgetForCategory(catId, month); if (budget == null) return;
    final spent = await _db.getCategorySpentThisMonth(catId, month);
    final limit = (budget['limit_amount'] as num).toDouble();
    if (!mounted || spent <= limit) return;
    final cat = _categories.firstWhere((c) => c['id'] == catId, orElse: () => {'name': 'This category'});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text('⚠ Budget exceeded for ${cat['name']}! ₹${formatMoneyWhole(spent)} of ₹${formatMoneyWhole(limit)}'), duration: const Duration(seconds: 4)));
  }

  Future<void> _onDescChanged(String val) async {
    if (val.length < 3) return;
    final matched = await _db.matchRule(val);
    if (matched != null && mounted) setState(() => _selectedCategory = matched);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) { _snack('Enter a valid amount'); return; }
    if (_selectedAccount == null) { _snack('Please create another account for manual entries. PhonePe is managed by Sync.'); return; }
    if (_selectedCategory == null) { _snack('Select a category'); return; }
    final account = _accounts.firstWhere((a) => a['id'] == _selectedAccount);
    final balance = (account['balance'] as num).toDouble();
    if (amount > balance) { _snack('Insufficient balance in ${account['name']} (₹${formatMoneyWhole(balance)})'); return; }
    setState(() => _saving = true);
    try {
      final newBalance = balance - amount;
      await _db.updateAccountBalance(_selectedAccount!, newBalance);
      await _db.insertTransaction({'account_id': _selectedAccount, 'category_id': _selectedCategory, 'type': 'expense', 'amount': amount, 'description': _descCtrl.text.trim().isEmpty ? 'Expense' : _descCtrl.text.trim(), 'date': DateTime.now().toIso8601String(), 'balance_after': newBalance});
      // Item 9: sync to Sheets
      final txs = await _db.getTransactions(limit: 1); if (txs.isNotEmpty) await _sheets.appendTransaction(txs.first);
      await _checkBudget(_selectedCategory);
      if (mounted) { _snack('Expense added!'); Navigator.pop(context); }
    } finally { if (mounted) setState(() => _saving = false); }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense'), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: _amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), autofocus: true,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(prefixText: '₹ ', hintText: '0', border: InputBorder.none, prefixStyle: TextStyle(fontSize: 26, color: Colors.red, fontWeight: FontWeight.bold))),
        ])),
        const SizedBox(height: 14),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('From Account *', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6),
          DropdownButtonHideUnderline(child: DropdownButton<int>(isExpanded: true, value: _selectedAccount, hint: const Text('Select account'),
            items: _accounts.map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text('${a['name']}  ₹${formatMoneyWhole(a['balance'] as num)}'))).toList(),
            onChanged: _accounts.isEmpty ? null : (v) => setState(() => _selectedAccount = v))),
        ])),
        const SizedBox(height: 14),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Category *', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6),
          DropdownButtonHideUnderline(child: DropdownButton<int>(isExpanded: true, value: _selectedCategory, hint: const Text('Select category'),
            items: _categories.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['name'] as String))).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v))),
        ])),
        const SizedBox(height: 14),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Description (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: _descCtrl, onChanged: _onDescChanged, decoration: const InputDecoration(hintText: 'e.g. Tea Shop… (auto-fills category)', border: InputBorder.none)),
        ])),
        const SizedBox(height: 26),
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Add Expense', style: TextStyle(fontSize: 16)))),
      ])),
    );
  }
  Widget _card(Widget child) => Card(child: Padding(padding: const EdgeInsets.fromLTRB(16,14,16,14), child: child));
}
