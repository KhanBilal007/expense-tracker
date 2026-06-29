import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../services/sheets_service.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});
  @override State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _db         = DatabaseHelper();
  final _sheets     = SheetsService();
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();
  List<Map<String, dynamic>> _accounts = [];
  int? _fromAccount, _toAccount;
  bool _saving = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _amountCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    // Always reload fresh balances from DB
    final a = await _db.getAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = a;
      if (a.isNotEmpty) _fromAccount = a[0]['id'] as int;
      if (a.length >= 2) _toAccount  = a[1]['id'] as int;
    });
  }

  Future<void> _transfer() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0)           { _snack('Enter a valid amount'); return; }
    if (_fromAccount == null || _toAccount == null) { _snack('Select both accounts'); return; }
    if (_fromAccount == _toAccount)              { _snack('Cannot transfer to same account'); return; }

    // Always read FRESH balances from DB right before transfer
    final freshAccounts = await _db.getAccounts();
    final from = freshAccounts.firstWhere(
      (a) => a['id'] == _fromAccount,
      orElse: () => <String, dynamic>{},
    );
    if (from.isEmpty) { _snack('Account not found'); return; }

    final fromBal = (from['balance'] as num).toDouble();
    if (amount > fromBal) {
      _snack('Insufficient balance in ${from['name']} (₹${fromBal.toStringAsFixed(2)})');
      return;
    }

    setState(() => _saving = true);
    try {
      await _db.doTransfer(
        fromId: _fromAccount!,
        toId:   _toAccount!,
        amount: amount,
        note:   _noteCtrl.text.trim(),
      );
      // Sync to Sheets
      final txs = await _db.getTransactions(limit: 2);
      for (final t in txs) { await _sheets.appendTransaction(t); }

      // Reload so dropdowns show updated balances
      await _load();
      if (mounted) { _snack('Transfer complete!'); Navigator.pop(context); }
    } catch (e) {
      if (mounted) _snack('Transfer failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Money'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _accounts.length < 2
          ? const Center(child: Text('Add at least 2 accounts to transfer.',
              style: TextStyle(color: Colors.grey)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'Transfer shows sender as negative and receiver as positive.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),

                // Amount
                _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _amountCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      prefixText: '₹ ', hintText: '0.00', border: InputBorder.none,
                      prefixStyle: TextStyle(fontSize: 26, color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                ])),
                const SizedBox(height: 14),

                // From account
                _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('From Account  (deducted)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonHideUnderline(child: DropdownButton<int>(
                    isExpanded: true,
                    value: _fromAccount,
                    items: _accounts.map((a) {
                      final bal = (a['balance'] as num).toDouble();
                      return DropdownMenuItem<int>(
                        value: a['id'] as int,
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(a['name'] as String),
                          Text('₹${fmt.format(bal)}',
                              style: TextStyle(
                                color: bal >= 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              )),
                        ]),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _fromAccount = v),
                  )),
                ])),

                const SizedBox(height: 6),
                const Icon(Icons.arrow_downward, color: Colors.blue, size: 30),
                const SizedBox(height: 6),

                // To account
                _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('To Account  (receives money)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonHideUnderline(child: DropdownButton<int>(
                    isExpanded: true,
                    value: _toAccount,
                    items: _accounts.map((a) {
                      final bal = (a['balance'] as num).toDouble();
                      return DropdownMenuItem<int>(
                        value: a['id'] as int,
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(a['name'] as String),
                          Text('₹${fmt.format(bal)}',
                              style: TextStyle(
                                color: bal >= 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              )),
                        ]),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _toAccount = v),
                  )),
                ])),

                const SizedBox(height: 14),

                // Note
                _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Note (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. ATM withdrawal', border: InputBorder.none),
                  ),
                ])),

                const SizedBox(height: 26),
                SizedBox(width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _transfer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Transfer', style: TextStyle(fontSize: 16)),
                  )),
              ]),
            ),
    );
  }

  Widget _card(Widget child) =>
      Card(child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 14), child: child));
}
