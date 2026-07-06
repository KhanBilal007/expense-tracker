# Home Screen Dark Mode Code Package

Date: 2026-07-06

Point No: 53

Purpose: provide Claude with the current Home screen dark-mode code and exact layout values so Claude can create a light theme version by changing only colors/theme.

## Files Inspected

- `lib/screens/home_screen.dart`
- `lib/main.dart`
- `pubspec.yaml`

No Flutter app files were changed for this package.

## Critical Claude Rule

Change only colors/theme. Do not change dimensions, layout, spacing, card heights, font sizes, navigation height, routes, calculations, sync logic, AI logic, or functionality.

## Home Screen Theme Source

`HomeScreen` defines its own colors and theme-aware getters inside `lib/screens/home_screen.dart`.

```dart
static const _darkBgTop = Color(0xFF071B35);
static const _darkBgBottom = Color(0xFF020811);
static const _darkCard = Color(0xAA0C1A2A);
static const _darkCard2 = Color(0xCC0B1726);
static const _line = Color(0xFF0D7DFF);
static const _blue = Color(0xFF2D8CFF);
static const _green = Color(0xFF22C55E);
static const _red = Color(0xFFFF4444);
static const _purple = Color(0xFFA855F7);
static const _orange = Color(0xFFF59E0B);
static const _cyan = Color(0xFF20D7E8);
static const _darkTextMain = Colors.white;
static const _darkTextSub = Color(0xFFB8C2CF);
static const _aiIconAsset = 'assets/icons/ai_agent_option_2_icon.png';

bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
Color get _pageBackground =>
    _isDarkMode ? _darkBgBottom : Colors.white;
Color get _card => _isDarkMode ? _darkCard : Colors.white;
Color get _card2 =>
    _isDarkMode ? _darkCard2 : const Color(0xFFF8FAFC);
Color get _textMain =>
    _isDarkMode ? _darkTextMain : const Color(0xFF111827);
Color get _textSub =>
    _isDarkMode ? _darkTextSub : const Color(0xFF5F6B7A);
Color get _cardBorder => _isDarkMode
    ? Colors.white.withValues(alpha: 0.08)
    : const Color(0xFFE2E8F0);
Color get _dividerColor => _isDarkMode
    ? Colors.white.withValues(alpha: 0.08)
    : const Color(0xFFE5E7EB);
Color get _verticalDividerColor => _isDarkMode
    ? Colors.white.withValues(alpha: 0.06)
    : const Color(0xFFE5E7EB);
```

## Current Dark Mode Color Values

- Background top: `Color(0xFF071B35)`
- Background bottom / scaffold dark base: `Color(0xFF020811)`
- Primary glass card: `Color(0xAA0C1A2A)`
- Secondary dark card / bottom nav: `Color(0xCC0B1726)`
- Main blue/accent line: `Color(0xFF0D7DFF)`
- Blue action: `Color(0xFF2D8CFF)`
- Green: `Color(0xFF22C55E)`
- Red: `Color(0xFFFF4444)`
- Purple: `Color(0xFFA855F7)`
- Orange: `Color(0xFFF59E0B)`
- Cyan: `Color(0xFF20D7E8)`
- Main text: `Colors.white`
- Secondary text: `Color(0xFFB8C2CF)`
- Card border in dark mode: `Colors.white.withValues(alpha: 0.08)`
- Divider in dark mode: `Colors.white.withValues(alpha: 0.08)`
- Vertical divider in dark mode: `Colors.white.withValues(alpha: 0.06)`

## Current Background Code

```dart
return Scaffold(
  backgroundColor: _pageBackground,
  body: _loading
      ? const Center(child: CircularProgressIndicator(color: _blue))
      : RefreshIndicator(
          onRefresh: _load,
          color: _blue,
          child: Container(
            decoration: BoxDecoration(
              color: _pageBackground,
              gradient: _isDarkMode
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_darkBgTop, _darkBgBottom],
                    )
                  : null,
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 112),
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
                          // Summary rows, quick actions, and recent transactions.
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
```

## Header Flutter Code

Do not change the header height, decorative wave height, icon sizes, font sizes, or positioning.

```dart
Widget _header(BuildContext context) {
  return SizedBox(
    height: 70,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -64,
          left: -50,
          right: -50,
          child: IgnorePointer(
            child: SizedBox(
              height: 130,
              child: CustomPaint(painter: _WavePainter()),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Expense Tracker',
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                padding: const EdgeInsets.only(top: 0),
                constraints: const BoxConstraints.tightFor(
                  width: 42,
                  height: 42,
                ),
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.settings),
                icon: Icon(Icons.settings, color: _textMain, size: 32),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

## Accounts Header Flutter Code

```dart
Widget _accountsHeader() {
  return Row(
    children: [
      Expanded(
        child: Text(
          'Accounts',
          style: TextStyle(
            color: _textMain,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      InkWell(
        onTap: _chooseHomeAccounts,
        child: Row(
          children: [
            Icon(Icons.edit_rounded, color: _blue, size: 16),
            const SizedBox(width: 3),
            Text(
              'Choose',
              style: TextStyle(
                color: _blue,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
```

## Accounts Section Flutter Code

```dart
Widget _accountsSection() {
  if (_homeAccounts.isEmpty) {
    return _glassCard(
      height: 90,
      child: Center(
        child: Text(
          'No accounts yet',
          style: TextStyle(color: _textSub, fontSize: 15),
        ),
      ),
    );
  }

  final shown = _homeAccounts.take(2).toList();
  return _glassCard(
    height: 90,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    child: Column(
      children: [
        for (int i = 0; i < shown.length; i++) ...[
          Expanded(child: _accountRow(shown[i], i == 0 ? _blue : _green)),
          if (i != shown.length - 1)
            Divider(color: _dividerColor, height: 2),
        ],
      ],
    ),
  );
}
```

## Account Row Flutter Code

```dart
Widget _accountRow(Map<String, dynamic> account, Color color) {
  final id = account['id'] as int;
  final summary = _homeAccountSummaries[id];
  final balance = summary?['currentBalance'] ??
      (account['balance'] as num?)?.toDouble() ??
      0.0;

  return InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () => Navigator.pushNamed(context, AppRoutes.accounts)
        .then((_) => _load()),
    child: Row(
      children: [
        _iconBox(Icons.account_balance_wallet_rounded, color,
            size: 26, iconSize: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            account['name']?.toString() ?? 'Account',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textMain,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              _money(balance),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: _textMain,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right_rounded,
            color: _textSub.withValues(alpha: 0.85), size: 18),
      ],
    ),
  );
}
```

## Summary Card Flutter Code

```dart
Widget _summaryCard({
  required String title,
  required String amount,
  required IconData icon,
  required Color color,
  required Color amountColor,
}) {
  return _glassCard(
    height: 86,
    borderColor: color.withValues(alpha: 0.55),
    padding: const EdgeInsets.all(8),
    child: Stack(
      children: [
        Positioned(
          left: -6,
          right: -6,
          bottom: -2,
          height: 20,
          child: CustomPaint(
            painter: _SmallWavePainter(color.withValues(alpha: 0.85)),
          ),
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
                    style: TextStyle(
                      color: _textSub,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: amountColor,
                  fontSize: 18,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ],
    ),
  );
}
```

## Mini Summary Card Flutter Code

```dart
Widget _miniCard({
  required String title,
  required String amount,
  required IconData icon,
  required Color color,
}) {
  return _glassCard(
    height: 55,
    borderColor: color.withValues(alpha: 0.42),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

## Quick Actions Flutter Code

```dart
Widget _quickActions() {
  return _glassCard(
    height: 120,
    padding: EdgeInsets.zero,
    child: Row(
      children: [
        _quickAction(Icons.add_rounded, 'Add Money', _green, AppRoutes.addMoney),
        _dividerVertical(),
        _quickAction(Icons.remove_circle_rounded, 'Add Expense', _red,
            AppRoutes.addExpense),
        _dividerVertical(),
        _quickAction(Icons.swap_horiz_rounded, 'Transfer', _blue,
            AppRoutes.transfer),
        _dividerVertical(),
        _quickAction(Icons.bar_chart_rounded, 'Reports', _purple,
            AppRoutes.reports),
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
                colors: [
                  color.withValues(alpha: 0.95),
                  color.withValues(alpha: 0.70),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.20),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
```

## Recent Transactions Flutter Code

```dart
Widget _recentSection() {
  if (_recent.isEmpty) {
    return _glassCard(
      height: 86,
      child: Center(
        child: Text(
          'No transactions yet',
          style: TextStyle(color: _textSub, fontSize: 15),
        ),
      ),
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
            Divider(color: _dividerColor, height: 12),
        ],
      ],
    ),
  );
}

Widget _txTile(Map<String, dynamic> t) {
  final type = t['type'] as String? ?? 'expense';
  final rawAmount = (t['amount'] as num?)?.toDouble() ?? 0.0;
  final color = (type == 'income' || type == 'transfer_in') ? _green : _red;
  final desc = (t['description'] as String?)?.trim();
  final title = desc != null && desc.isNotEmpty
      ? desc
      : (t['category_name'] as String? ?? 'Transaction');

  return InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () => Navigator.pushNamed(context, AppRoutes.transactions)
        .then((_) => _load()),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          _iconBox(_txIcon(type), color, size: 36, iconSize: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(t['date']?.toString()),
                  style: TextStyle(color: _textSub, fontSize: 12),
                ),
              ],
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${_txSign(type)}${_money(rawAmount)}',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              color: _textSub.withValues(alpha: 0.8), size: 24),
        ],
      ),
    ),
  );
}
```

## Bottom Navigation Flutter Code

Do not change height, width, icon sizes, text sizes, padding, or routes.

```dart
Widget _bottomNav(BuildContext context) {
  return SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(12, 0, 12, 6),
    child: Container(
      height: 54,
      decoration: BoxDecoration(
        color: _darkCard2,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, 'Home', _blue, () {}),
          _navItem(
            Icons.smart_toy_outlined,
            'AI',
            _darkTextSub,
            () => Navigator.pushNamed(context, AppRoutes.ai).then((_) => _load()),
            assetPath: _aiIconAsset,
          ),
          _navItem(Icons.sync_rounded, 'Sync', _darkTextSub, _syncPhonePe),
        ],
      ),
    ),
  );
}

Widget _navItem(
  IconData icon,
  String label,
  Color color,
  VoidCallback onTap, {
  String? assetPath,
}) {
  final active = color == _blue;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      width: 78,
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? _blue.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? _blue.withValues(alpha: 0.42) : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (assetPath == null)
            Icon(icon, color: color, size: 21)
          else
            SizedBox(
              width: 24,
              height: 24,
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(icon, color: color, size: 21),
              ),
            ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 11,
              height: 1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
```

## Shared Card and Icon Helpers

```dart
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
      border: Border.all(color: borderColor ?? _cardBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: _isDarkMode ? 0.28 : 0.10),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
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
        colors: [
          color.withValues(alpha: 0.95),
          color.withValues(alpha: 0.55),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.15),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: iconSize),
  );
}

Widget _dividerVertical() =>
    Container(width: 1, height: 24, color: _verticalDividerColor);
```

## Main App Theme Code

`lib/main.dart` controls app theme mode with `ThemeMode.dark` or `ThemeMode.light`.

```dart
themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
  useMaterial3: true,
  cardTheme: const CardThemeData(elevation: 2),
),
darkTheme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1A237E),
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  cardTheme: const CardThemeData(elevation: 2),
),
```

## Assets Used On Home Screen

- `assets/icons/ai_agent_option_2_icon.png`

Registered in `pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/icons/ai_agent_option_2_icon.png
```

## Dimensions and Layout Values That Must Not Change

- Outer scroll padding: `EdgeInsets.fromLTRB(14, 6, 14, 112)`
- Constrained min height offset: `constraints.maxHeight - 112`
- Header height: `70`
- Decorative header wave height: `130`
- Header top padding: `EdgeInsets.only(top: 6)`
- Header title font size: `30`
- Header title line height: `1`
- Settings icon button constraints: `42 x 42`
- Settings icon size: `32`
- Gap after header: `2`
- Gap after accounts header: `4`
- Gap after accounts section: `6`
- Summary card row gap: `10`
- Mini card row gaps: `9`
- Section title font size: `18`
- Quick Actions title gap: `4`
- Recent Transactions section gap: `4`
- Accounts empty card height: `90`
- Accounts populated card height: `90`
- Accounts card padding: horizontal `10`, vertical `2`
- Account row icon box: `26 x 26`
- Account row icon size: `15`
- Account name font size: `14`
- Account amount font size: `18`
- Account chevron size: `18`
- Summary card height: `86`
- Summary card padding: `EdgeInsets.all(8)`
- Summary wave height: `20`
- Summary icon box: `26 x 26`
- Summary icon size: `15`
- Summary title font size: `11`
- Summary amount font size: `18`
- Summary amount line height: `1`
- Summary bottom gap: `10`
- Mini summary card height: `55`
- Mini summary card padding: horizontal `6`, vertical `3`
- Mini title font size: `14`
- Mini amount font size: `18`
- Mini title/amount gap: `1`
- Quick actions card height: `120`
- Quick action item border radius: `20`
- Quick action circular icon: `46 x 46`
- Quick action icon size: `26`
- Quick action icon/label gap: `8`
- Quick action label font size: `14`
- Empty recent transaction card height: `86`
- Recent transaction card padding: horizontal `12`, vertical `8`
- Recent transaction tile vertical padding: `5`
- Recent transaction icon box: `36 x 36`
- Recent transaction icon size: `19`
- Recent transaction title font size: `16`
- Recent transaction date font size: `12`
- Recent transaction amount font size: `18`
- Recent transaction chevron size: `24`
- Recent transaction divider height: `12`
- Bottom nav SafeArea minimum: `EdgeInsets.fromLTRB(12, 0, 12, 6)`
- Bottom nav container height: `54`
- Bottom nav border radius: `15`
- Bottom nav shadow blur radius: `18`
- Bottom nav item width: `78`
- Bottom nav item height: `45`
- Bottom nav item padding: horizontal `6`, vertical `2`
- Bottom nav item border radius: `18`
- Bottom nav icon size: `21`
- Bottom nav AI image size: `24 x 24`
- Bottom nav icon/label gap: `1`
- Bottom nav label font size: `11`
- Bottom nav label line height: `1.0`
- Shared glass card border radius: `20`
- Shared glass card default padding: `EdgeInsets.all(12)`
- Shared glass card border width: `1`
- Shared glass card shadow blur: `14`
- Shared glass card shadow offset: `Offset(0, 8)`
- Default icon box size: `44`
- Default icon size: `24`
- Default icon border radius formula: `size * 0.28`
- Vertical divider size: width `1`, height `24`

## Current Bottom Navigation Colors

- Container background: `_darkCard2` = `Color(0xCC0B1726)`
- Container border: `Colors.white.withValues(alpha: 0.08)`
- Container shadow: `Colors.black.withValues(alpha: 0.45)`
- Selected Home icon/label: `_blue` = `Color(0xFF2D8CFF)`
- Unselected AI and Sync icon/label: `_darkTextSub` = `Color(0xFFB8C2CF)`
- Active nav item background: `_blue.withValues(alpha: 0.18)`
- Inactive nav item background: `Colors.white.withValues(alpha: 0.05)`
- Active nav item border: `_blue.withValues(alpha: 0.42)`
- Inactive nav item border: `Colors.transparent`

## Hardcoded Colors That Affect Light Mode

These are the main color locations Claude may need to make theme-aware. Change colors only, not sizes or widget structure.

- Bottom nav container uses `_darkCard2` directly.
- Bottom nav border uses `Colors.white.withValues(alpha: 0.08)`.
- Bottom nav shadow uses `Colors.black.withValues(alpha: 0.45)`.
- Inactive nav item background uses `Colors.white.withValues(alpha: 0.05)`.
- Quick action icons use `Colors.white` for icon glyphs.
- `_iconBox(...)` uses `Colors.white` for icon glyphs.
- `_WavePainter` uses blue gradient colors and glow:
  - `Color(0xFF2D8CFF)`
  - `Color(0xFF0D7DFF)`
  - `Color(0xFF5CE1FF)`

## What Claude Must Not Change

- Do not change routes.
- Do not change `_load()`.
- Do not change account calculations.
- Do not change PhonePe sync.
- Do not change AI navigation.
- Do not change Local Data Vault.
- Do not change Google Sheet sync.
- Do not change `_money(...)` or amount formatting.
- Do not change account selection logic.
- Do not change the bottom navigation behavior.
- Do not change dimensions listed above.

## Claude Instruction Block

Change only colors/theme. Do not change dimensions/layout/functionality.

You may make dark/light color values theme-aware. You may replace hardcoded dark-only color usage with theme-aware getters. Do not rename widgets. Do not reorder widgets. Do not change sizes, padding, margins, font sizes, gaps, card heights, bottom navigation height, or behavior.

## Claude Prompt

Convert this Home screen from dark theme to light theme.

Rules:

- Change only colors/theme.
- Do not change layout.
- Do not change dimensions.
- Do not change spacing.
- Do not change card heights.
- Do not change font sizes.
- Do not change navigation height.
- Do not change functionality.
- Light mode background must be white.
- Cards should be light and readable.
- Text should be dark/readable.
- Keep all current widgets and structure.
- Return the updated code with explanation of color changes only.

Use the Flutter code sections and exact dimension list above as the source of truth. If you modify a color, explain which color changed and why. If a requested change would require layout, sizing, navigation, logic, or functionality changes, do not make it.
