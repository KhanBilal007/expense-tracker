import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/phonepe_statement_parser.dart';
import '../db/database_helper.dart';

class ImportResult {
  final int savedCount;
  final int skippedCount;
  const ImportResult({required this.savedCount, required this.skippedCount});
}

/// Shows ONLY new/missing transactions (per the spec: "Do not show already
/// existing/duplicate transactions as importable"). Sorted newest first.
class ImportReviewScreen extends StatefulWidget {
  final List<PhonePeTransaction>
      newTransactions; // already filtered to new-only
  final int skippedDuplicateCount;
  final int accountId;

  const ImportReviewScreen({
    super.key,
    required this.newTransactions,
    required this.skippedDuplicateCount,
    required this.accountId,
  });

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  late final List<_Item> _items;
  bool _saving = false;
  List<Map<String, dynamic>> _accounts = [];
  late int _selectedAccountId;
  String _selectedAccountName = '';
  final _db = DatabaseHelper();
  final _fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.accountId;
    _loadAccounts();
    // Already sorted newest-first by the parser, but re-sort defensively.
    final sorted = [...widget.newTransactions]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    _items = sorted.map((t) => _Item(t, selected: true)).toList();
  }

  int get _selectedCount => _items.where((i) => i.selected).length;

  Future<void> _import() async {
    setState(() => _saving = true);
    try {
      final selected =
          _items.where((i) => i.selected).map((i) => i.txn.toMap()).toList();
      final count = await _db.insertPhonePeTransactions(selected,
          accountId: _selectedAccountId);
      debugPrint('[PhonePeImport] saved count=$count');
      if (mounted) {
        Navigator.of(context).pop(ImportResult(
            savedCount: count, skippedCount: widget.skippedDuplicateCount));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadAccounts() async {
    final accounts = await _db.getAccounts();
    final resolved =
        await _db.resolveImportAccount(preferredAccountId: _selectedAccountId);
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      if (resolved != null) {
        _selectedAccountId = resolved['id'] as int;
        _selectedAccountName = resolved['name'] as String;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review PhonePe Import'),
        actions: [
          if (_accounts.isNotEmpty)
            PopupMenuButton<int>(
              tooltip: 'Import account',
              initialValue: _selectedAccountId,
              onSelected: (id) async {
                final selected = _accounts.firstWhere((a) => a['id'] == id);
                await _db.setDefaultAccountId(id);
                if (!mounted) return;
                setState(() {
                  _selectedAccountId = id;
                  _selectedAccountName = selected['name'] as String;
                });
                debugPrint('[PhonePeImport] selected import accountId=$id');
                debugPrint(
                    '[PhonePeImport] selected import account name=$_selectedAccountName');
              },
              itemBuilder: (_) => _accounts
                  .map((a) => PopupMenuItem<int>(
                        value: a['id'] as int,
                        child: Text(a['name'] as String),
                      ))
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    _selectedAccountName.isEmpty
                        ? 'Account'
                        : _selectedAccountName,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.teal.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(spacing: 16, runSpacing: 4, children: [
              _pill('${_items.length} new', Colors.green),
              if (widget.skippedDuplicateCount > 0)
                _pill('${widget.skippedDuplicateCount} already in app',
                    Colors.orange),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No new transactions to import.\nEverything in this statement is already in your app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 56),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final t = item.txn;
                      final isExp = t.type == 'expense';
                      final color =
                          isExp ? Colors.red.shade700 : Colors.green.shade700;
                      return CheckboxListTile(
                        value: item.selected,
                        onChanged: (v) =>
                            setState(() => item.selected = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        title: Row(children: [
                          Expanded(
                              child: Text(t.description,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          Text('${isExp ? '−' : '+'}₹${_fmt.format(t.amount)}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        ]),
                        subtitle: Row(children: [
                          Text(
                              DateFormat('dd MMM yyyy, hh:mm a')
                                  .format(t.dateTime),
                              style: const TextStyle(fontSize: 11)),
                          if (t.transactionId != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text('ID: ${t.transactionId}',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                          ],
                        ]),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: _saving || _selectedCount == 0 ? null : _import,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          _items.isEmpty
                              ? 'Nothing to import'
                              : 'Import Selected ($_selectedCount)',
                          style: const TextStyle(fontSize: 15),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      );
}

class _Item {
  final PhonePeTransaction txn;
  bool selected;
  _Item(this.txn, {required this.selected});
}
