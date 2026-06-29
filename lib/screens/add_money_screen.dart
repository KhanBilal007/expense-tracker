import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../services/sheets_service.dart';

class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({super.key});
  @override State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final _db = DatabaseHelper(); final _sheets = SheetsService();
  final _amountCtrl = TextEditingController(), _descCtrl = TextEditingController();
  List<Map<String, dynamic>> _accounts = [];
  int? _selectedAccount; bool _saving = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _amountCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final accounts = await _db.getAccounts();
    final defAccId = await _db.getDefaultAccountId();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _selectedAccount = (defAccId != null && accounts.any((a) => a['id'] == defAccId)) ? defAccId : (accounts.isNotEmpty ? accounts.first['id'] as int : null);
    });
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) { _snack('Enter a valid amount'); return; }
    if (_selectedAccount == null) { _snack('Select an account'); return; }
    setState(() => _saving = true);
    try {
      final account = _accounts.firstWhere((a) => a['id'] == _selectedAccount);
      final newBalance = (account['balance'] as num).toDouble() + amount;
      await _db.updateAccountBalance(_selectedAccount!, newBalance);
      final txData = {'account_id': _selectedAccount, 'category_id': null, 'type': 'income', 'amount': amount, 'description': _descCtrl.text.trim().isEmpty ? 'Income' : _descCtrl.text.trim(), 'date': DateTime.now().toIso8601String(), 'balance_after': newBalance};
      final id = await _db.insertTransaction(txData);
      // Item 9: sync to Google Sheets
      final txs = await _db.getTransactions(limit: 1);
      if (txs.isNotEmpty) await _sheets.appendTransaction(txs.first);
      if (mounted) { _snack('Money added!'); Navigator.pop(context); }
    } finally { if (mounted) setState(() => _saving = false); }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; final fmt = NumberFormat('#,##0.00');
    return Scaffold(
      appBar: AppBar(title: const Text('Add Money'), backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: _amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), autofocus: true,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            decoration: InputDecoration(prefixText: '₹ ', prefixStyle: TextStyle(fontSize: 26, color: cs.primary, fontWeight: FontWeight.bold), hintText: '0.00', border: InputBorder.none)),
        ])),
        const SizedBox(height: 14),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('To Account *', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6),
          DropdownButtonHideUnderline(child: DropdownButton<int>(isExpanded: true, value: _selectedAccount, hint: const Text('Select account'),
            items: _accounts.map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text('${a['name']}  ₹${fmt.format(a['balance'])}'))).toList(),
            onChanged: (v) => setState(() => _selectedAccount = v))),
        ])),
        const SizedBox(height: 14),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Description (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: _descCtrl, decoration: const InputDecoration(hintText: 'e.g. Salary, Freelance…', border: InputBorder.none)),
        ])),
        const SizedBox(height: 26),
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
            child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Add Money', style: TextStyle(fontSize: 16)))),
      ])),
    );
  }
  Widget _card(Widget child) => Card(child: Padding(padding: const EdgeInsets.fromLTRB(16,14,16,14), child: child));
}
