import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../navigation/app_routes.dart';
import '../utils/money_formatter.dart';

class HomeScreen extends StatefulWidget {
  final List<String> recurringProcessed;
  const HomeScreen({super.key, this.recurringProcessed = const []});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper();

  double _totalBalance = 0;
  double _todayExpense = 0;
  double _monthlyExpense = 0;
  double _monthlyIncome = 0;
  double _accountSpent = 0;
  List<Map<String, dynamic>> _recent = [];
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _homeAccounts = [];
  Map<int, Map<String, double>> _homeAccountSummaries = {};
  bool _loading = true;

  static const _bgTop = Color(0xFF071B35);
  static const _bgBottom = Color(0xFF020811);
  static const _card = Color(0xAA0C1A2A);
  static const _card2 = Color(0xCC0B1726);
  static const _line = Color(0xFF0D7DFF);
  static const _blue = Color(0xFF2D8CFF);
  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFFF4444);
  static const _purple = Color(0xFFA855F7);
  static const _orange = Color(0xFFF59E0B);
  static const _cyan = Color(0xFF20D7E8);
  static const _textMain = Colors.white;
  static const _textSub = Color(0xFFB8C2CF);
  static const _aiIconAsset = 'assets/icons/ai_agent_option_2_icon.png';

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.recurringProcessed.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Auto-processed: ${widget.recurringProcessed.join(', ')}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final recent = await _db.getTransactions(limit: 5);
      final accounts = await _db.getAccounts();
      final homeAccounts = await _db.getHomeAccounts();
      final summaries = <int, Map<String, double>>{};
      double selectedCurrentBalance = 0;
      double selectedTotalMoneyAdded = 0;
      double selectedSpent = 0;
      double selectedTodayExpenses = 0;
      double selectedThisMonthExpenses = 0;
      for (final account in homeAccounts) {
        final id = account['id'] as int;
        final summary = await _db.getAccountSummary(id);
        summaries[id] = summary;
        selectedCurrentBalance += summary['currentBalance'] ?? 0;
        selectedTotalMoneyAdded += summary['totalMoneyAdded'] ?? 0;
        selectedSpent += summary['spent'] ?? 0;
        selectedTodayExpenses += summary['todayExpenses'] ?? 0;
        selectedThisMonthExpenses += summary['thisMonthExpenses'] ?? 0;
      }
      if (!mounted) return;
      setState(() {
        _totalBalance = selectedCurrentBalance;
        _todayExpense = selectedTodayExpenses;
        _monthlyExpense = selectedThisMonthExpenses;
        _monthlyIncome = selectedTotalMoneyAdded;
        _accountSpent = selectedSpent;
        _recent = recent;
        _accounts = accounts;
        _homeAccounts = homeAccounts;
        _homeAccountSummaries = summaries;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(num value) => '₹${formatMoneyWhole(value)}';

  Color _txColor(String t) => (t == 'income' || t == 'transfer_in')
      ? _green
      : (t == 'expense' || t == 'transfer_out')
          ? _red
          : _blue;

  IconData _txIcon(String t) => (t == 'income' || t == 'transfer_in')
      ? Icons.arrow_downward_rounded
      : Icons.arrow_upward_rounded;

  String _txSign(String t) => (t == 'income' || t == 'transfer_in') ? '+' : '-';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBottom,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : RefreshIndicator(
              onRefresh: _load,
              color: _blue,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_bgTop, _bgBottom],
                  ),
                ),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 96),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 112),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _header(context),
                              const SizedBox(height: 2),
                              _accountsHeader(),
                              const SizedBox(height: 4),
                              _accountsSection(),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: _summaryCard(
                                      title: 'Total Money Added',
                                      amount: _money(_monthlyIncome),
                                      icon:
                                          Icons.account_balance_wallet_rounded,
                                      color: _blue,
                                      amountColor: _textMain,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _summaryCard(
                                      title: 'Current Balance',
                                      amount: _money(_totalBalance),
                                      icon:
                                          Icons.account_balance_wallet_rounded,
                                      color: _green,
                                      amountColor: _textMain,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: _miniCard(
                                      title: 'Today',
                                      amount: _money(_todayExpense),
                                      icon: Icons.calendar_month_rounded,
                                      color: _orange,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: _miniCard(
                                      title: 'Expenses',
                                      amount: _money(_accountSpent),
                                      icon: Icons.remove_circle_rounded,
                                      color: _red,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: _miniCard(
                                      title: 'This Month',
                                      amount: _money(_monthlyExpense),
                                      icon: Icons.calendar_month_rounded,
                                      color: _purple,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Quick Actions',
                                style: TextStyle(
                                    color: _textMain,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              _quickActions(),
                              const SizedBox(height: 6),
                              _sectionHeader(
                                title: 'Recent Transactions',
                                action: 'See All',
                                onTap: () => Navigator.pushNamed(
                                        context, AppRoutes.transactions)
                                    .then((_) => _load()),
                              ),
                              const SizedBox(height: 4),
                              _recentSection(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _bottomNav(context),
    );
  }

  Widget _header(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -60,
            left: 50,
            right: 40,
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _blue.withOpacity(0.28),
                    _blue.withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Expense Tracker',
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w900),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 0),
                child: IconButton(
                  icon: const Icon(Icons.settings, color: _textMain, size: 32),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.settings)
                          .then((_) => _load()),
                ),
              ),
            ],
          ),
          Positioned(
            left: -18,
            right: -18,
            top: 44,
            height: 42,
            child: CustomPaint(painter: _WavePainter()),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(
      {required String title,
      required String action,
      required VoidCallback onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                color: _textMain, fontSize: 19, fontWeight: FontWeight.w800)),
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Text(action,
                  style: const TextStyle(
                      color: _blue, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: _blue, size: 22),
            ],
          ),
        ),
      ],
    );
  }

  Widget _accountsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Accounts',
            style: TextStyle(
                color: _textMain, fontSize: 19, fontWeight: FontWeight.w800)),
        GestureDetector(
          onTap: _chooseHomeAccounts,
          child: const Row(
            children: [
              Icon(Icons.edit_rounded, color: _blue, size: 16),
              SizedBox(width: 3),
              Text('Choose',
                  style: TextStyle(
                      color: _blue,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _chooseHomeAccounts() async {
    if (_accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No accounts yet')),
      );
      return;
    }

    final selectedIds = _homeAccounts
        .map((a) => a['id'] as int?)
        .whereType<int>()
        .take(2)
        .toList();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _card2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Choose Home Accounts',
                            style: TextStyle(
                                color: _textMain,
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _accounts.length,
                        itemBuilder: (_, i) {
                          final account = _accounts[i];
                          final id = account['id'] as int;
                          final selected = selectedIds.contains(id);
                          return CheckboxListTile(
                            value: selected,
                            dense: true,
                            activeColor: _blue,
                            checkColor: _textMain,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              account['name']?.toString() ?? 'Account',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _textMain,
                                  fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              _money((account['balance'] as num?) ?? 0),
                              style: const TextStyle(color: _textSub),
                            ),
                            onChanged: (_) {
                              if (selected) {
                                setSheetState(() => selectedIds.remove(id));
                                return;
                              }
                              if (selectedIds.length >= 2) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'You can show maximum 2 accounts on Home.'),
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => selectedIds.add(id));
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          await _db.setHomeAccounts(selectedIds);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop(true);
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      await _load();
    }
  }

  Widget _accountsSection() {
    final shown = _homeAccounts.take(2).toList();
    if (shown.isEmpty) {
      return _glassCard(
        height: 90,
        child: const Center(
            child: Text('No accounts yet',
                style: TextStyle(color: _textSub, fontSize: 15))),
      );
    }
    return _glassCard(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Column(
        children: [
          for (int i = 0; i < shown.length; i++) ...[
            Expanded(
              child: _accountRow(shown[i], i == 0 ? _blue : _green),
            ),
            if (i != shown.length - 1)
              Divider(color: Colors.white.withOpacity(0.08), height: 2),
          ],
        ],
      ),
    );
  }

  Widget _accountRow(Map<String, dynamic> account, Color color) {
    final accountId = account['id'] as int?;
    final summary =
        accountId == null ? null : _homeAccountSummaries[accountId];
    final bal = summary?['currentBalance'] ??
        (account['balance'] as num?)?.toDouble() ??
        0;
    final name = account['name']?.toString() ?? 'Account';
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.accounts).then((_) => _load()),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _iconBox(Icons.account_balance_wallet_rounded, color,
                size: 18, iconSize: 11),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              _money(bal),
              style: const TextStyle(
                  color: _textMain, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: _textSub.withOpacity(0.85), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    required Color amountColor,
  }) {
    return _glassCard(
      height: 86,
      borderColor: color.withOpacity(0.55),
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Positioned(
            left: -6,
            right: -6,
            bottom: -2,
            height: 20,
            child: CustomPaint(
                painter: _SmallWavePainter(color.withOpacity(0.85))),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconBox(icon, color, size: 26, iconSize: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _textSub,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(amount,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                        color: amountColor,
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniCard(
      {required String title,
      required String amount,
      required IconData icon,
      required Color color}) {
    return _glassCard(
      height: 55,
      borderColor: color.withOpacity(0.42),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(amount,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return _glassCard(
      height: 120,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          _quickAction(
              Icons.add_rounded, 'Add Money', _green, AppRoutes.addMoney),
          _dividerVertical(),
          _quickAction(Icons.remove_circle_rounded, 'Add Expense', _red,
              AppRoutes.addExpense),
          _dividerVertical(),
          _quickAction(
              Icons.swap_horiz_rounded, 'Transfer', _blue, AppRoutes.transfer),
          _dividerVertical(),
          _quickAction(
              Icons.bar_chart_rounded, 'Reports', _purple, AppRoutes.reports),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, String route) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.pushNamed(context, route).then((_) => _load()),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [color.withOpacity(0.95), color.withOpacity(0.70)]),
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(0.20),
                      blurRadius: 12,
                      spreadRadius: 1)
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _recentSection() {
    if (_recent.isEmpty) {
      return _glassCard(
        height: 86,
        child: const Center(
            child: Text('No transactions yet',
                style: TextStyle(color: _textSub, fontSize: 15))),
      );
    }
    final shown = _recent.take(2).toList();
    return _glassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          for (int i = 0; i < shown.length; i++) ...[
            _txTile(shown[i]),
            if (i != shown.length - 1)
              Divider(color: Colors.white.withOpacity(0.08), height: 12),
          ],
        ],
      ),
    );
  }

  Widget _txTile(Map<String, dynamic> t) {
    final type = t['type'] as String? ?? 'expense';
    final color = _txColor(type);
    final displayAmount = ((t['amount'] as num?)?.toDouble() ?? 0).abs();
    final date =
        DateTime.tryParse(t['date']?.toString() ?? '') ?? DateTime.now();
    final desc = type == 'income'
        ? 'Money Added'
        : type == 'expense'
            ? (t['category_name'] as String? ?? 'Expense')
            : (t['description']?.toString().isNotEmpty == true
                ? t['description'].toString()
                : 'Transaction');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pushNamed(context, AppRoutes.transactions)
          .then((_) => _load()),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            _iconBox(_txIcon(type), color, size: 42, iconSize: 23),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _textMain,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${t['account_name'] ?? ''} • ${DateFormat('dd MMM, hh:mm a').format(date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textSub, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '${_txSign(type)}${_money(displayAmount)}',
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: _textSub.withOpacity(0.8), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _bottomNav(BuildContext context) {
    return Container(
      height: 86,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, 'Home', _blue, () {}),
          _navItem(
              Icons.smart_toy_outlined,
              'AI',
              _textSub,
              () => Navigator.pushNamed(context, AppRoutes.ai)
                  .then((_) => _load()),
              assetPath: _aiIconAsset),
          _navItem(Icons.sync_rounded, 'Sync', _textSub, () => _load()),
        ],
      ),
    );
  }

  Widget _navItem(
      IconData icon, String label, Color color, VoidCallback onTap,
      {String? assetPath}) {
    final active = color == _blue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 78,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color:
              active ? _blue.withOpacity(0.18) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? _blue.withOpacity(0.42) : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (assetPath == null)
              Icon(icon, color: color, size: 26)
            else
              Image.asset(
                assetPath,
                width: 26,
                height: 26,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(icon, color: color, size: 26),
              ),
            const SizedBox(height: 5),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    double? height,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
    Color? borderColor,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: borderColor ?? Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 14,
              offset: const Offset(0, 8))
        ],
      ),
      child: child,
    );
  }

  Widget _iconBox(IconData icon, Color color,
      {double size = 44, double iconSize = 24}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
            colors: [color.withOpacity(0.95), color.withOpacity(0.55)]),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.15), blurRadius: 10, spreadRadius: 1)
        ],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }

  Widget _dividerVertical() =>
      Container(width: 1, height: 24, color: Colors.white.withOpacity(0.06));
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.55);
    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.55 + math.sin((x / size.width * math.pi * 3.5)) * 9;
      path.lineTo(x, y);
    }

    final glow = Paint()
      ..color = const Color(0xFF2D8CFF).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glow);

    final paint = Paint()
      ..shader = const LinearGradient(
              colors: [Color(0xFF0D7DFF), Color(0xFF5CE1FF), Color(0xFF0D7DFF)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SmallWavePainter extends CustomPainter {
  final Color color;
  _SmallWavePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.65);
    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.65 + math.sin((x / size.width * math.pi * 4)) * 4;
      path.lineTo(x, y);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SmallWavePainter oldDelegate) =>
      oldDelegate.color != color;
}
