import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});
  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final _db    = DatabaseHelper();
  final _month = DateFormat('yyyy-MM').format(DateTime.now());
  List<Map<String, dynamic>> _budgets    = [];
  List<Map<String, dynamic>> _categories = [];
  // FIX #17: keyed by category_id (int) not name string
  Map<int, double> _spent = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final budgets    = await _db.getBudgets(_month);
    final categories = await _db.getCategories();
    final spent      = await _db.getCategoryExpensesById(_month);
    if (!mounted) return;
    setState(() { _budgets = budgets; _categories = categories; _spent = spent; });
  }

  void _addDialog() {
    int?   selectedCat;
    final  limitCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('Set Budget'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonHideUnderline(child: DropdownButton<int>(
            isExpanded: true, value: selectedCat,
            hint: const Text('Select Category'),
            items: _categories.map((c) => DropdownMenuItem<int>(
                value: c['id'] as int, child: Text(c['name'] as String))).toList(),
            onChanged: (v) => setS(() => selectedCat = v),
          )),
          const SizedBox(height: 10),
          TextField(controller: limitCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monthly Limit (₹)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final limit = double.tryParse(limitCtrl.text.trim());
              if (selectedCat == null || limit == null || limit <= 0) return;
              await _db.upsertBudget(selectedCat!, limit, _month);
              if (context.mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Set'),
          ),
        ],
      )),
    ).then((_) => limitCtrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00');
    return Scaffold(
      appBar: AppBar(
        title: Text('Budgets — ${DateFormat('MMM yyyy').format(DateTime.now())}'),
        backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
      ),
      body: _budgets.isEmpty
          ? const Center(child: Text('No budgets set yet.\nTap + to set a limit.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _budgets.length,
              itemBuilder: (_, i) {
                final b       = _budgets[i];
                final catId   = b['category_id'] as int;
                final catName = b['category_name'] as String? ?? 'Unknown';
                final limit   = (b['limit_amount'] as num).toDouble();
                // FIX #17: look up by int ID, not string name
                final spent   = _spent[catId] ?? 0.0;
                final pct     = (spent / limit).clamp(0.0, 1.0);
                final over    = spent > limit;
                return Card(
                  child: Padding(padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(catName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          if (over)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text('⚠ Over Budget', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                            )
                          else
                            Text('${(pct * 100).toStringAsFixed(0)}% used',
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            onPressed: () async { await _db.deleteBudget(b['id'] as int); _load(); },
                          ),
                        ]),
                      ]),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct, minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(over ? Colors.red : cs.primary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Spent: ₹${fmt.format(spent)}',
                            style: TextStyle(fontSize: 12, color: over ? Colors.red : Colors.grey.shade700)),
                        Text('Remaining: ₹${fmt.format((limit - spent).clamp(0, double.infinity))}',
                            style: TextStyle(fontSize: 12, color: over ? Colors.red : Colors.green)),
                        Text('Limit: ₹${fmt.format(limit)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                    ]),
                  ),
                );
              }),
      floatingActionButton: FloatingActionButton(onPressed: _addDialog, child: const Icon(Icons.add)),
    );
  }
}
