import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../navigation/app_routes.dart';

class HomeScreen extends StatefulWidget {
  final List<String> recurringProcessed;
  const HomeScreen({super.key, this.recurringProcessed = const []});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper();
  double _totalBalance = 0,
      _todayExpense = 0,
      _monthlyExpense = 0,
      _monthlyIncome = 0;
  List<Map<String, dynamic>> _recent = [], _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.recurringProcessed.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Auto-processed: ${widget.recurringProcessed.join(', ')}'),
            duration: const Duration(seconds: 4)));
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final month = DateFormat('yyyy-MM').format(DateTime.now());
      final balance = await _db.getTotalBalance();
      final today = await _db.getTodayExpense();
      final mExp = await _db.getMonthlyExpense(month);
      final mInc = await _db.getMonthlyIncome(month);
      final recent = await _db.getTransactions(limit: 5);
      final accounts = await _db.getAccounts();
      if (!mounted) return;
      setState(() {
        _totalBalance = balance;
        _todayExpense = today;
        _monthlyExpense = mExp;
        _monthlyIncome = mInc;
        _recent = recent;
        _accounts = accounts;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _txColor(String t) => (t == 'income' || t == 'transfer_in')
      ? Colors.green
      : (t == 'expense' || t == 'transfer_out')
          ? Colors.red
          : Colors.blue;
  IconData _txIcon(String t) => (t == 'income' || t == 'transfer_in')
      ? Icons.arrow_downward
      : Icons.arrow_upward;
  String _txSign(String t) => (t == 'income' || t == 'transfer_in') ? '+' : '-';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.settings)
                  .then((_) => _load()))
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Item 16: Attractive dashboard ────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [
                                cs.primary,
                                cs.primary.withValues(alpha: 0.75)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: cs.primary.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 8))
                          ],
                        ),
                        padding: const EdgeInsets.all(22),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Current Balance',
                                        style: TextStyle(
                                            color: cs.onPrimary
                                                .withValues(alpha: 0.8),
                                            fontSize: 13,
                                            letterSpacing: .5)),
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.18),
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        child: Text(
                                            DateFormat('MMM yyyy')
                                                .format(DateTime.now()),
                                            style: TextStyle(
                                                color: cs.onPrimary,
                                                fontSize: 11))),
                                  ]),
                              const SizedBox(height: 6),
                              Text('₹${fmt.format(_totalBalance)}',
                                  style: TextStyle(
                                      color: cs.onPrimary,
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5)),
                              const SizedBox(height: 18),
                              // Item 5: per-account balances
                              ..._accounts.map((a) {
                                final bal = (a['balance'] as num).toDouble();
                                return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(children: [
                                            Container(
                                                width: 7,
                                                height: 7,
                                                decoration: const BoxDecoration(
                                                    color: Colors.white54,
                                                    shape: BoxShape.circle)),
                                            const SizedBox(width: 7),
                                            Text(a['name'] as String,
                                                style: TextStyle(
                                                    color: cs.onPrimary
                                                        .withValues(
                                                            alpha: 0.85),
                                                    fontSize: 12)),
                                          ]),
                                          Text('₹${fmt.format(bal)}',
                                              style: TextStyle(
                                                  color: bal >= 0
                                                      ? Colors.greenAccent
                                                      : Colors.redAccent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600)),
                                        ]));
                              }),
                              const SizedBox(height: 14),
                              const Divider(color: Colors.white24, height: 1),
                              const SizedBox(height: 14),
                              Row(children: [
                                Expanded(
                                    child: _miniStatBox(
                                        cs,
                                        'Total Money Added',
                                        '₹${fmt.format(_monthlyIncome)}',
                                        Colors.greenAccent)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _miniStatBox(
                                        cs,
                                        'Total Expenses',
                                        '₹${fmt.format(_monthlyExpense)}',
                                        Colors.redAccent)),
                              ]),
                            ]),
                      ),
                      const SizedBox(height: 16),

                      // ── Stat row ─────────────────────────────────────────────────────
                      Row(children: [
                        _statCard('Today', '₹${fmt.format(_todayExpense)}',
                            Icons.today, Colors.orange),
                        const SizedBox(width: 12),
                        _statCard(
                            'This Month',
                            '₹${fmt.format(_monthlyExpense)}',
                            Icons.calendar_month,
                            Colors.purple),
                      ]),
                      const SizedBox(height: 20),

                      // ── Quick actions (item 7: Rules removed, item 15: no bottom FABs) ─
                      Text('Quick Actions',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.85,
                        children: [
                          _actionTile(context, Icons.add_circle, 'Add\nMoney',
                              cs.primary, AppRoutes.addMoney),
                          _actionTile(context, Icons.remove_circle,
                              'Add\nExpense', Colors.red, AppRoutes.addExpense),
                          _actionTile(context, Icons.swap_horiz, 'Transfer',
                              Colors.blue, AppRoutes.transfer),
                          _actionTile(context, Icons.bar_chart, 'Reports',
                              Colors.teal, AppRoutes.reports),
                          _actionTile(context, Icons.account_balance_wallet,
                              'Accounts', Colors.indigo, AppRoutes.accounts),
                          _actionTile(context, Icons.category, 'Categories',
                              Colors.pink, AppRoutes.categories),
                          _actionTile(context, Icons.repeat, 'Recurring',
                              Colors.orange, AppRoutes.recurring),
                          _actionTile(context, Icons.savings, 'Budgets',
                              Colors.teal, AppRoutes.budgets),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Recent ───────────────────────────────────────────────────────
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Recent Transactions',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            TextButton(
                                onPressed: () => Navigator.pushNamed(
                                        context, AppRoutes.transactions)
                                    .then((_) => _load()),
                                child: const Text('See All')),
                          ]),
                      if (_recent.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                                child: Text('No transactions yet',
                                    style: TextStyle(color: Colors.grey))))
                      else
                        for (final t in _recent) _txTile(t, fmt, cs),
                    ]),
              ),
            ),
      // Item 15: NO floating action buttons
    );
  }

  Widget _miniStatBox(
          ColorScheme cs, String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: cs.onPrimary.withValues(alpha: 0.7), fontSize: 11)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _statCard(String label, String value, IconData icon, Color color) =>
      Expanded(
          child: Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(icon, color: color, size: 20)),
                    const SizedBox(width: 10),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          Text(value,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold))
                        ]),
                  ]))));

  Widget _actionTile(BuildContext context, IconData icon, String label,
          Color color, String route) =>
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, route).then((_) => _load()),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11)),
        ]),
      );

  Widget _txTile(Map<String, dynamic> t, NumberFormat fmt, ColorScheme cs) {
    final type = t['type'] as String? ?? 'expense';
    final color = _txColor(type);
    final displayAmount = ((t['amount'] as num).toDouble()).abs();
    final date = DateTime.tryParse(t['date'] ?? '') ?? DateTime.now();
    final desc = type == 'income'
        ? 'Money Added'
        : type == 'expense'
            ? 'Expense'
            : t['description']?.toString().isNotEmpty == true
                ? t['description'] as String
                : (t['category_name'] as String? ?? 'Transaction');
    final cat = t['category_name'] as String?;
    return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(_txIcon(type), color: color, size: 18)),
          title:
              Text(desc, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (cat != null && cat.isNotEmpty && desc != cat)
              Text(cat, style: TextStyle(fontSize: 11, color: cs.primary)),
            Text(
                '${t['account_name'] ?? ''} • ${DateFormat('dd MMM, hh:mm a').format(date)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
          trailing: Text('${_txSign(type)}₹${fmt.format(displayAmount)}',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ));
  }
}
