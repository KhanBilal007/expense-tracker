import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _categories = [];

  static const _palette = [
    Colors.orange, Colors.blue, Colors.pink, Colors.purple,
    Colors.red, Colors.teal, Colors.indigo, Colors.brown, Colors.cyan, Colors.grey,
  ];
  static const _icons = [
    Icons.fastfood, Icons.directions_bus, Icons.shopping_bag, Icons.receipt_long,
    Icons.health_and_safety, Icons.movie, Icons.local_gas_station,
    Icons.water_drop, Icons.local_cafe, Icons.more_horiz,
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final c = await _db.getCategories();
    if (mounted) setState(() => _categories = c);
  }

  void _addDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(controller: ctrl,
            decoration: const InputDecoration(labelText: 'Category name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await _db.insertCategory(ctrl.text.trim());
              if (context.mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  // FIX #24: edit category name
  void _editDialog(Map<String, dynamic> cat) {
    final ctrl = TextEditingController(text: cat['name'] as String);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(controller: ctrl,
            decoration: const InputDecoration(labelText: 'Category name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await _db.updateCategory(cat['id'] as int, ctrl.text.trim());
              if (context.mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Categories'),
          backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
      body: _categories.isEmpty
          ? const Center(child: Text('No categories', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final c    = _categories[i];
                final idx  = i % _palette.length;
                final col  = _palette[idx];
                final icon = _icons[idx];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: col.withValues(alpha: 0.1),
                      child: Icon(icon, color: col),
                    ),
                    title: Text(c['name'] as String),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _editDialog(c)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        onPressed: () async {
                          await _db.deleteCategory(c['id'] as int);
                          _load();
                        },
                      ),
                    ]),
                  ),
                );
              }),
      floatingActionButton: FloatingActionButton(onPressed: _addDialog, child: const Icon(Icons.add)),
    );
  }
}
