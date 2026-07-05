import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../utils/money_formatter.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _accounts = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final a = await _db.getAccounts();
    if (mounted) setState(() => _accounts = a);
  }

// FIX #25: opening balance distinct label
Future<void> _addDialog() async {
  final nameCtrl = TextEditingController();
  final balCtrl = TextEditingController();

  try {
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Account'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Account Name (e.g. Cash, SBI Bank)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: balCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Opening Balance',
                prefixText: '₹ ',
                helperText: 'Current balance in this account',
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final bal = double.tryParse(balCtrl.text.trim()) ?? 0.0;
                await _db.insertAccount(name, bal);

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (added == true) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await _load();
    }
  } finally {
    nameCtrl.dispose();
    balCtrl.dispose();
  }
}

// FIX #22: edit account name
Future<void> _editDialog(Map<String, dynamic> account) async {
  final ctrl = TextEditingController(text: account['name'] as String);

  try {
    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Account'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Account Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;

              await _db.updateAccount(account['id'] as int, name);

              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated == true && mounted) {
      await _load();
    }
  } finally {
    ctrl.dispose();
  }
}

  // FIX #2: show error if account has transactions
  Future<void> _delete(Map<String, dynamic> account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text('Delete "${account['name']}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await _db.deleteAccount(account['id'] as int);
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cannot delete: account has transactions'),
          backgroundColor: Colors.orange));
    }
    if (deleted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts'), backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
      body: _accounts.isEmpty
          ? const Center(child: Text('No accounts yet.\nTap + to add one.', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _accounts.length,
              itemBuilder: (_, i) {
                final a   = _accounts[i];
                final bal = (a['balance'] as num).toDouble();
                final name = a['name'] as String;
                return Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: cs.primary.withValues(alpha: 0.1),
                          child: Icon(Icons.account_balance_wallet,
                              color: cs.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text('Balance',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text('₹${formatMoneyWhole(bal)}',
                                style: TextStyle(
                                    color: bal >= 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                        ),
                        IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _editDialog(a)),
                        IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 18),
                            onPressed: () => _delete(a)),
                      ],
                    ),
                  ),
                );
              }),
      floatingActionButton: FloatingActionButton(onPressed: _addDialog, child: const Icon(Icons.add)),
    );
  }
}
