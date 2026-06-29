import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/database_helper.dart';
import 'services/sms_service.dart';
import 'screens/home_screen.dart';
import 'screens/add_money_screen.dart';
import 'screens/add_expense_screen.dart';
import 'screens/accounts_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/budgets_screen.dart';
import 'screens/recurring_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/rules_screen.dart';
import 'navigation/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs    = await SharedPreferences.getInstance();
  final isDark   = prefs.getBool('darkMode') ?? false;
  final isHindi  = prefs.getBool('hindi') ?? false;
  final db       = DatabaseHelper();
  final processed = await db.processDueRecurring();
  // Item 2: start SMS listener
  SmsService().startListening((_) {});
  runApp(ExpenseApp(isDark: isDark, isHindi: isHindi, recurringProcessed: processed));
}

class ExpenseApp extends StatefulWidget {
  final bool isDark, isHindi;
  final List<String> recurringProcessed;
  const ExpenseApp({super.key, required this.isDark, required this.isHindi, required this.recurringProcessed});
  static _ExpenseAppState? of(BuildContext context) => context.findAncestorStateOfType<_ExpenseAppState>();
  @override State<ExpenseApp> createState() => _ExpenseAppState();
}

class _ExpenseAppState extends State<ExpenseApp> {
  late bool _isDark, _isHindi;
  @override void initState() { super.initState(); _isDark = widget.isDark; _isHindi = widget.isHindi; }

  void toggleTheme(bool v) async { setState(() => _isDark = v); final p = await SharedPreferences.getInstance(); await p.setBool('darkMode', v); }
  // Item 4: toggle language Hindi/English
  void toggleLanguage(bool hindi) async { setState(() => _isHindi = hindi); final p = await SharedPreferences.getInstance(); await p.setBool('hindi', hindi); }
  bool get isHindi => _isHindi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expense Tracker',
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      locale: _isHindi ? const Locale('hi') : const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)), useMaterial3: true, cardTheme: const CardThemeData(elevation: 2)),
      darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E), brightness: Brightness.dark), useMaterial3: true, cardTheme: const CardThemeData(elevation: 2)),
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home:         (_) => HomeScreen(recurringProcessed: widget.recurringProcessed),
        AppRoutes.addMoney:     (_) => const AddMoneyScreen(),
        AppRoutes.addExpense:   (_) => const AddExpenseScreen(),
        AppRoutes.accounts:     (_) => const AccountsScreen(),
        AppRoutes.categories:   (_) => const CategoriesScreen(),
        AppRoutes.transactions: (_) => const TransactionsScreen(),
        AppRoutes.reports:      (_) => const ReportsScreen(),
        AppRoutes.settings:     (_) => const SettingsScreen(),
        AppRoutes.budgets:      (_) => const BudgetsScreen(),
        AppRoutes.recurring:    (_) => const RecurringScreen(),
        AppRoutes.transfer:     (_) => const TransferScreen(),
        AppRoutes.rules:        (_) => const RulesScreen(),
      },
    );
  }
}
