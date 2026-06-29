import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseHelper();
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to   = DateTime.now();
  double _accountTotal = 0, _expense = 0, _balance = 0;
  String? _resetDate; double _resetBalance = 0;
  Map<String, double> _catExp = {};
  List<Map<String, dynamic>> _txs = [], _accounts = [];
  int? _selectedAccountId; String? _selectedAccountName;
  bool _loading = true;

  @override void initState() { super.initState(); _loadAccounts(); }

  Future<void> _loadAccounts() async {
    final a = await _db.getAccounts();
    if (!mounted) return;
    setState(() => _accounts = a);
    _load();
  }

  String get _fromStr => '${DateFormat('yyyy-MM-dd').format(_from)}T00:00:00.000';
  String get _toStr   => '${DateFormat('yyyy-MM-dd').format(_to)}T23:59:59.999';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      double total = 0; String? resetDate; double resetBal = 0;
      if (_selectedAccountId != null) {
        final acc = await _db.getAccountById(_selectedAccountId!);
        total     = acc != null ? (acc['balance'] as num).toDouble() : 0;
        resetDate = await _db.getResetDate(_selectedAccountId!);
        resetBal  = await _db.getResetBalance(_selectedAccountId!);
      } else {
        total = await _db.getTotalBalance();
      }
      final effectiveFrom = (resetDate != null && resetDate.compareTo(_fromStr) > 0)
          ? resetDate : _fromStr;
      final expense = await _db.getRangeExpense(effectiveFrom, _toStr, accountId: _selectedAccountId);
      final catExp  = await _db.getRangeCategoryExpenses(effectiveFrom, _toStr, accountId: _selectedAccountId);
      final txs     = await _db.getTransactionsByRange(effectiveFrom, _toStr, accountId: _selectedAccountId);
      if (!mounted) return;
      setState(() {
        _accountTotal = total; _expense = expense; _balance = total;
        _resetDate = resetDate; _resetBalance = resetBal;
        _catExp = catExp; _txs = txs;
      });
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(context: context, initialDate: _from, firstDate: DateTime(2020), lastDate: _to);
    if (d != null) { setState(() => _from = d); _load(); }
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(context: context, initialDate: _to, firstDate: _from, lastDate: DateTime.now());
    if (d != null) { setState(() => _to = d); _load(); }
  }

  void _confirmReset() {
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an account first'), backgroundColor: Colors.orange));
      return;
    }
    final fmt = NumberFormat('#,##0.00');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Reset account view'),
      content: Text(
        'All transactions for "$_selectedAccountName" will be hidden from the screen.\n\n'
        'Current balance ₹${fmt.format(_accountTotal)} becomes the new opening balance.\n\n'
        'Transactions are NOT deleted from the database.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            Navigator.pop(ctx);
            await _db.resetAccount(_selectedAccountId!);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('$_selectedAccountName has been reset'),
                backgroundColor: Colors.green,
              ));
              _load();
            }
          },
          child: const Text('Reset'),
        ),
      ],
    ));
  }

  void _showAccountPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Filter by account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ListTile(
          leading: CircleAvatar(backgroundColor: Colors.teal.withValues(alpha: 0.1), child: const Icon(Icons.all_inclusive, color: Colors.teal)),
          title: const Text('All accounts'),
          trailing: _selectedAccountId == null ? const Icon(Icons.check, color: Colors.teal) : null,
          onTap: () { setState(() { _selectedAccountId = null; _selectedAccountName = null; }); Navigator.pop(context); _load(); },
        ),
        ..._accounts.map((a) => ListTile(
          leading: CircleAvatar(backgroundColor: Colors.indigo.withValues(alpha: 0.1), child: const Icon(Icons.account_balance_wallet, color: Colors.indigo)),
          title: Text(a['name'] as String),
          subtitle: Text('₹${NumberFormat('#,##0.00').format(a['balance'])}'),
          trailing: _selectedAccountId == a['id'] ? const Icon(Icons.check, color: Colors.teal) : null,
          onTap: () { setState(() { _selectedAccountId = a['id'] as int; _selectedAccountName = a['name'] as String; }); Navigator.pop(context); _load(); },
        )),
        const SizedBox(height: 8),
      ])),
    );
  }

  Color    _txColor(String t) => (t=='income'||t=='transfer_in') ? Colors.green : (t=='expense'||t=='transfer_out') ? Colors.red : Colors.blue;
  IconData _txIcon(String t)  => (t=='income'||t=='transfer_in') ? Icons.arrow_downward : Icons.arrow_upward;
  String   _txSign(String t)  => (t=='income'||t=='transfer_in') ? '+' : '-';

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final fmt    = NumberFormat('#,##0.00');
    final dayFmt = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.teal, foregroundColor: Colors.white,
        actions: [
          if (_selectedAccountId != null)
            TextButton.icon(
              onPressed: _confirmReset,
              icon: const Icon(Icons.restart_alt, color: Colors.white, size: 18),
              label: const Text('Reset', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          TextButton.icon(
            onPressed: _showAccountPicker,
            icon: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 18),
            label: Text(_selectedAccountName ?? 'All', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(children: [

            // Account filter banner
            if (_selectedAccountName != null)
              Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.filter_alt, color: Colors.teal, size: 16), const SizedBox(width: 6),
                  Text('Showing: $_selectedAccountName', style: const TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () { setState(() { _selectedAccountId = null; _selectedAccountName = null; }); _load(); },
                    child: const Text('Clear', style: TextStyle(color: Colors.teal, fontSize: 12)),
                  ),
                ])),

            // Reset info banner
            if (_resetDate != null && _selectedAccountId != null)
              Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Colors.green, size: 16), const SizedBox(width: 6),
                  Expanded(child: Text(
                    'Reset on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_resetDate!))}. Opening balance ₹${fmt.format(_resetBalance)}.',
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                  )),
                ])),

            // Date range picker
            Card(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                const Icon(Icons.date_range, color: Colors.teal, size: 18), const SizedBox(width: 8),
                Expanded(child: GestureDetector(
                  onTap: _pickFrom,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('From', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(dayFmt.format(_from), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to', style: TextStyle(fontSize: 14, color: Colors.grey))),
                Expanded(child: GestureDetector(
                  onTap: _pickTo,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('To', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(dayFmt.format(_to), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )),
              ]),
            )),
            const SizedBox(height: 16),

            // Summary cards
            Row(children: [
              _summaryCard(_selectedAccountId != null ? (_selectedAccountName ?? 'Account') : 'Total', _accountTotal, Colors.blue, Icons.account_balance_wallet, fmt),
              const SizedBox(width: 8),
              _summaryCard('Expense', _expense, Colors.red, Icons.arrow_upward, fmt),
              const SizedBox(width: 8),
              _summaryCard('Balance', _balance, _balance >= 0 ? Colors.green : Colors.orange, Icons.savings, fmt),
            ]),
            const SizedBox(height: 20),

            // Category breakdown
            if (_catExp.isNotEmpty) ...[
              _secHeader('Expense by category'), const SizedBox(height: 10),
              ..._catExp.entries.map((e) {
                final pct = _expense > 0 ? (e.value / _expense).clamp(0.0, 1.0) : 0.0;
                return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('₹${fmt.format(e.value)}  ${(pct*100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary))),
                ]));
              }),
              const SizedBox(height: 10),
            ],

            // Transaction list
            _secHeader('Transactions (${_txs.length})'), const SizedBox(height: 8),
            if (_txs.isEmpty)
              Padding(padding: const EdgeInsets.all(24), child: Column(children: [
                Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(_resetDate != null ? 'No transactions after reset' : 'No transactions in selected range',
                  style: const TextStyle(color: Colors.grey)),
              ]))
            else ..._txs.map((t) {
              final type = t['type'] as String? ?? 'expense';
              final col  = _txColor(type);
              final displayAmount = ((t['amount'] as num).toDouble()).abs();
              final date = DateTime.tryParse(t['date'] ?? '') ?? DateTime.now();
              final desc = t['description']?.toString().isNotEmpty == true ? t['description'] as String : (t['category_name'] as String? ?? type);
              final cat  = t['category_name'] as String?;
              return Card(margin: const EdgeInsets.symmetric(vertical: 3), child: ListTile(dense: true,
                leading: Icon(_txIcon(type), color: col, size: 18),
                title: Text(desc, style: const TextStyle(fontSize: 13)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (cat != null && cat.isNotEmpty && desc != cat) Text(cat, style: TextStyle(fontSize: 11, color: cs.primary)),
                  Text(DateFormat('dd MMM, hh:mm a').format(date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
                trailing: Text('${_txSign(type)}₹${fmt.format(displayAmount)}',
                  style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 13))));
            }),
          ]),
        ),
      ),
    );
  }

  Widget _summaryCard(String label, double val, Color color, IconData icon, NumberFormat fmt) =>
    Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 18), const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
      Text('₹${fmt.format(val.abs())}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    ]))));

  Widget _secHeader(String t) => Align(alignment: Alignment.centerLeft,
    child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)));
}
