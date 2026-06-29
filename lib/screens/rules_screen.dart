import 'package:flutter/material.dart';
import '../db/database_helper.dart';

/// Smart Rules screen (Spec §19)
/// User defines keyword → category mappings.
/// When adding an expense, typing a matching keyword auto-fills the category.
class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});
  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _rules      = [];
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final rules      = await _db.getRules();
    final categories = await _db.getCategories();
    if (!mounted) return;
    setState(() { _rules = rules; _categories = categories; });
  }

  void _addDialog() {
    final keyCtrl = TextEditingController();
    int?  selectedCat;
    if (_categories.isNotEmpty) selectedCat = _categories.first['id'] as int;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('Add Rule'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: keyCtrl,
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(
              labelText: 'Keyword (e.g. "tea shop", "petrol")',
              helperText: 'Case-insensitive. Matches anywhere in description.',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonHideUnderline(child: DropdownButton<int>(
            isExpanded: true, value: selectedCat,
            hint: const Text('Map to Category'),
            items: _categories.map((c) => DropdownMenuItem<int>(
                value: c['id'] as int, child: Text(c['name'] as String))).toList(),
            onChanged: (v) => setS(() => selectedCat = v),
          )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final kw = keyCtrl.text.trim();
              if (kw.isEmpty || selectedCat == null) return;
              await _db.insertRule(kw, selectedCat!);
              if (context.mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Add'),
          ),
        ],
      )),
    ).then((_) => keyCtrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Rules'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        // Info banner
        Container(
          width: double.infinity,
          color: Colors.purple.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Text(
            '💡 When you type a description in Add Expense, matching keywords auto-fill the category.',
            style: TextStyle(fontSize: 12, color: Colors.purple),
          ),
        ),
        Expanded(
          child: _rules.isEmpty
              ? const Center(child: Text('No rules yet.\nTap + to add a keyword → category mapping.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _rules.length,
                  itemBuilder: (_, i) {
                    final r = _rules[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.withValues(alpha: 0.1),
                          child: const Icon(Icons.auto_fix_high, color: Colors.purple, size: 18),
                        ),
                        title: Text('"${r['keyword']}"',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        subtitle: Row(children: [
                          const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(r['category_name'] as String? ?? 'Unknown',
                              style: const TextStyle(color: Colors.purple)),
                        ]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          onPressed: () async { await _db.deleteRule(r['id'] as int); _load(); },
                        ),
                      ),
                    );
                  }),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purple,
        onPressed: _addDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
