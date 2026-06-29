import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});
  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _items      = [];
  List<Map<String, dynamic>> _accounts   = [];
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final items      = await _db.getRecurring();
    final accounts   = await _db.getAccounts();
    final categories = await _db.getCategories();
    if (!mounted) return;
    setState(() { _items = items; _accounts = accounts; _categories = categories; });
  }

  // FIX #15 + #16 + #38: full dialog with account, category, type, date picker
  void _addDialog() {
    final nameCtrl = TextEditingController();
    final amtCtrl  = TextEditingController();
    String  freq       = 'Monthly';
    String  type       = 'expense';
    int?    accountId;
    int?    categoryId;
    DateTime nextDate  = DateTime.now().add(const Duration(days: 1));

    if (_accounts.isNotEmpty) accountId  = _accounts.first['id'] as int;
    if (_categories.isNotEmpty) categoryId = _categories.first['id'] as int;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('Add Recurring'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name (e.g. Rent, Netflix)')),
          TextField(controller: amtCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₹)')),
          const SizedBox(height: 8),
          // Type toggle
          Row(children: [
            const Text('Type: ', style: TextStyle(fontWeight: FontWeight.w600)),
            ChoiceChip(label: const Text('Expense'), selected: type == 'expense',
                onSelected: (_) => setS(() => type = 'expense')),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('Income'),  selected: type == 'income',
                onSelected: (_) => setS(() => type = 'income')),
          ]),
          const SizedBox(height: 8),
          // Account
          DropdownButtonHideUnderline(child: DropdownButton<int>(
            isExpanded: true, value: accountId,
            hint: const Text('Account'),
            items: _accounts.map((a) => DropdownMenuItem<int>(
                value: a['id'] as int, child: Text(a['name'] as String))).toList(),
            onChanged: (v) => setS(() => accountId = v),
          )),
          // Category (for expense)
          if (type == 'expense')
            DropdownButtonHideUnderline(child: DropdownButton<int>(
              isExpanded: true, value: categoryId,
              hint: const Text('Category'),
              items: _categories.map((c) => DropdownMenuItem<int>(
                  value: c['id'] as int, child: Text(c['name'] as String))).toList(),
              onChanged: (v) => setS(() => categoryId = v),
            )),
          const SizedBox(height: 8),
          // Frequency
          DropdownButtonHideUnderline(child: DropdownButton<String>(
            isExpanded: true, value: freq,
            items: ['Daily', 'Weekly', 'Monthly', 'Yearly']
                .map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setS(() => freq = v!),
          )),
          const SizedBox(height: 8),
          // FIX #38: user picks first due date
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('First due date', style: TextStyle(fontSize: 13)),
            subtitle: Text(DateFormat('dd MMM yyyy').format(nextDate)),
            trailing: const Icon(Icons.calendar_today, size: 18),
            onTap: () async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: nextDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setS(() => nextDate = picked);
            },
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final amt  = double.tryParse(amtCtrl.text.trim());
              if (name.isEmpty || amt == null || amt <= 0 || accountId == null) return;
              await _db.insertRecurring({
                'name':        name,
                'amount':      amt,
                'frequency':   freq,
                'next_date':   nextDate.toIso8601String(),
                'account_id':  accountId,
                'category_id': type == 'expense' ? categoryId : null,
                
                'type':        type,
              });
              if (context.mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Add'),
          ),
        ],
      )),
    ).then((_) { nameCtrl.dispose(); amtCtrl.dispose(); });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Payments'),
          backgroundColor: Colors.orange, foregroundColor: Colors.white),
      body: _items.isEmpty
          ? const Center(child: Text('No recurring payments.\nTap + to add one.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final r    = _items[i];
                final next = DateTime.tryParse(r['next_date'] ?? '') ?? DateTime.now();
                final isDue = next.isBefore(DateTime.now());
                final type = r['type'] as String? ?? 'expense';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      child: Icon(type == 'income' ? Icons.arrow_downward : Icons.arrow_upward,
                          color: type == 'income' ? Colors.green : Colors.orange),
                    ),
                    title: Text(r['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${r['frequency']} • ${r['account_name'] ?? ''}'),
                      Text(
                        isDue ? '⚠ Due now!' : 'Next: ${DateFormat('dd MMM yyyy').format(next)}',
                        style: TextStyle(fontSize: 11,
                            color: isDue ? Colors.red : Colors.grey,
                            fontWeight: isDue ? FontWeight.bold : FontWeight.normal),
                      ),
                    ]),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('₹${fmt.format(r['amount'])}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () async { await _db.deleteRecurring(r['id'] as int); _load(); },
                      ),
                    ]),
                  ),
                );
              }),
      floatingActionButton: FloatingActionButton(onPressed: _addDialog, child: const Icon(Icons.add)),
    );
  }
}
