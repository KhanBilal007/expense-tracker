import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../main.dart';
import '../navigation/app_routes.dart';
import '../services/sync_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper();
  final _syncSettings = SyncSettingsService();
  final _sheetsCtrl = TextEditingController();
  bool _darkMode = false, _isHindi = false;
  bool _googleSheetSyncEnabled = false;
  bool _syncingGoogleSheet = false;
  String _googleSheetSyncStatus = SyncSettingsService.statusDisabled;
  String? _lastGoogleSheetSyncAt;
  String? _lastGoogleSheetSyncError;
  int? _defaultAccId;
  List<Map<String, dynamic>> _accounts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sheetsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await _db.getAccounts();
    final defId = await _db.getDefaultAccountId();
    final syncSettings = await _syncSettings.getGoogleSheetSettings();
    if (!mounted) return;
    final validDefId = (defId != null && accounts.any((a) => a['id'] == defId))
        ? defId
        : (accounts.isNotEmpty ? accounts.first['id'] as int : null);
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
      _isHindi = prefs.getBool('hindi') ?? false;
      _accounts = accounts;
      _defaultAccId = validDefId;
      _googleSheetSyncEnabled =
          syncSettings['googleSheetSyncEnabled'] as bool? ?? false;
      _googleSheetSyncStatus = syncSettings['syncStatus']?.toString() ??
          SyncSettingsService.statusDisabled;
      _lastGoogleSheetSyncAt = syncSettings['lastSyncAt']?.toString();
      _lastGoogleSheetSyncError =
          syncSettings['lastSyncError']?.toString();
      _sheetsCtrl.text =
          syncSettings['googleSheetEndpointUrl']?.toString() ?? '';
    });
    if (validDefId != null && validDefId != defId) {
      await _db.setDefaultAccountId(validDefId);
    }
  }

  Future<void> _refreshGoogleSheetSettings() async {
    final syncSettings = await _syncSettings.getGoogleSheetSettings();
    if (!mounted) return;
    setState(() {
      _googleSheetSyncEnabled =
          syncSettings['googleSheetSyncEnabled'] as bool? ?? false;
      _googleSheetSyncStatus = syncSettings['syncStatus']?.toString() ??
          SyncSettingsService.statusDisabled;
      _lastGoogleSheetSyncAt = syncSettings['lastSyncAt']?.toString();
      _lastGoogleSheetSyncError =
          syncSettings['lastSyncError']?.toString();
      _sheetsCtrl.text =
          syncSettings['googleSheetEndpointUrl']?.toString() ?? '';
    });
  }

  Future<void> _toggleGoogleSheetSync(bool enabled) async {
    await _syncSettings.setGoogleSheetSyncEnabled(enabled);
    final endpoint = await _syncSettings.getGoogleSheetEndpoint();
    await _syncSettings.updateGoogleSheetSyncState(
      syncStatus: !enabled
          ? SyncSettingsService.statusDisabled
          : endpoint.isEmpty
              ? SyncSettingsService.statusNotConfigured
              : SyncSettingsService.statusReady,
      lastSyncError:
          enabled && endpoint.isEmpty ? 'no_endpoint_configured' : null,
    );
    await _refreshGoogleSheetSettings();
  }

  Future<void> _saveGoogleSheetEndpoint() async {
    final endpoint = _sheetsCtrl.text.trim();
    if (endpoint.isNotEmpty &&
        !_syncSettings.isValidGoogleSheetEndpoint(endpoint)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid HTTPS Apps Script URL ending in /exec.'),
        ),
      );
      return;
    }

    await _syncSettings.setGoogleSheetEndpoint(endpoint);
    final effectiveEndpoint = await _syncSettings.getGoogleSheetEndpoint();
    await _syncSettings.updateGoogleSheetSyncState(
      syncStatus: !_googleSheetSyncEnabled
          ? SyncSettingsService.statusDisabled
          : effectiveEndpoint.isEmpty
              ? SyncSettingsService.statusNotConfigured
              : SyncSettingsService.statusReady,
      lastSyncError: _googleSheetSyncEnabled && effectiveEndpoint.isEmpty
          ? 'no_endpoint_configured'
          : null,
    );
    await _refreshGoogleSheetSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(endpoint.isEmpty
            ? 'Google Sheet endpoint cleared. Configured endpoint will be used.'
            : 'Google Sheet endpoint saved.'),
      ),
    );
  }

  Future<void> _syncGoogleSheetNow() async {
    if (!_googleSheetSyncEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable Google Sheet Sync first.')),
      );
      return;
    }
    final endpoint = await _syncSettings.getGoogleSheetEndpoint();
    if (!mounted) return;
    if (endpoint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter and save an Apps Script URL first.')),
      );
      return;
    }

    setState(() => _syncingGoogleSheet = true);
    try {
      await _db.exportAllDataToLocalVault();
      await _refreshGoogleSheetSettings();
      if (!mounted) return;
      final succeeded =
          _googleSheetSyncStatus == SyncSettingsService.statusConnected;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(succeeded
              ? 'Google Sheet sync completed.'
              : 'Google Sheet sync did not complete. Check the status below.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncingGoogleSheet = false);
    }
  }

  String get _googleSheetStatusLabel {
    switch (_googleSheetSyncStatus) {
      case SyncSettingsService.statusConnected:
        return 'Connected';
      case SyncSettingsService.statusFailed:
        return 'Failed';
      case SyncSettingsService.statusNotConfigured:
        return 'Endpoint required';
      case SyncSettingsService.statusSyncing:
        return 'Syncing';
      case SyncSettingsService.statusReady:
        return 'Ready';
      default:
        return 'Disabled';
    }
  }

  String? get _formattedLastSyncAt {
    final parsed = DateTime.tryParse(_lastGoogleSheetSyncAt ?? '');
    if (parsed == null) return null;
    return parsed.toLocal().toString().split('.').first;
  }

  // Item 11: Reset with mandatory backup prompt
  Future<void> _showResetDialog() async {
    // Step 1: offer backup
    final wantsBackup = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Backup First?'),
        content: const Text(
            'Before resetting, do you want to copy your data to clipboard as CSV? This is your only backup option.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Skip Backup')),
          ElevatedButton(
            onPressed: () async {
              final csv = await _db.exportCsv();
              await Clipboard.setData(ClipboardData(text: csv));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data copied to clipboard!')));
                Navigator.pop(context, true);
              }
            },
            child: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
    if (wantsBackup == null) return;

    // Step 2: confirm reset
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:
            const Text('Reset All Data?', style: TextStyle(color: Colors.red)),
        content: const Text(
            'This will set ALL account balances to ₹0 and delete ALL transactions. This CANNOT be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _db.resetAllData();
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data reset to zero.')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary),
      body:
          ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
        _header('APPEARANCE'),
        Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('Dark Mode'),
                value: _darkMode,
                onChanged: (v) {
                  setState(() => _darkMode = v);
                  ExpenseApp.of(context)?.toggleTheme(v);
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              // Item 4: Hindi / English toggle
              SwitchListTile(
                secondary: const Text('अ',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                title: const Text('Hindi Language'),
                subtitle: Text(_isHindi ? 'हिंदी में' : 'In English'),
                value: _isHindi,
                onChanged: (v) {
                  setState(() => _isHindi = v);
                  ExpenseApp.of(context)?.toggleLanguage(v);
                },
              ),
            ])),

        _header('DEFAULT ACCOUNT'),
        Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Default Account for UPI / PhonePe',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    const Text(
                        'Auto SMS and new transactions start with this account.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                      isExpanded: true,
                      value: _defaultAccId,
                      hint: const Text('Select account'),
                      items: _accounts
                          .map((a) => DropdownMenuItem<int>(
                              value: a['id'] as int,
                              child: Text(a['name'] as String)))
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        await _db.setDefaultAccountId(v);
                        setState(() => _defaultAccId = v);
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Default account saved')));
                      },
                    )),
                  ]),
            )),

        _header('GOOGLE SHEET SYNC'),
        Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.cloud_sync_outlined),
                      title: const Text('Enable Google Sheet Sync'),
                      subtitle: const Text(
                        'Off by default. Enable only with your own Apps Script URL.',
                      ),
                      value: _googleSheetSyncEnabled,
                      onChanged: _toggleGoogleSheetSync,
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    const Text('Apps Script Web App URL',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    const Text(
                        'Your data is sent only while sync is enabled.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _sheetsCtrl,
                      enabled: _googleSheetSyncEnabled,
                      decoration: const InputDecoration(
                          hintText: 'https://script.google.com/macros/s/…',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8)),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _googleSheetSyncEnabled
                                ? _saveGoogleSheetEndpoint
                                : null,
                            child: const Text('Save URL'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _googleSheetSyncEnabled &&
                                    !_syncingGoogleSheet
                                ? _syncGoogleSheetNow
                                : null,
                            child: _syncingGoogleSheet
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Sync Now'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Status: $_googleSheetStatusLabel',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _googleSheetSyncStatus ==
                                SyncSettingsService.statusFailed
                            ? Colors.red
                            : _googleSheetSyncStatus ==
                                    SyncSettingsService.statusConnected
                                ? Colors.green
                                : Colors.grey,
                      ),
                    ),
                    if (_formattedLastSyncAt != null)
                      Text(
                        'Last synced: $_formattedLastSyncAt',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    if (_lastGoogleSheetSyncError != null)
                      Text(
                        'Last error: $_lastGoogleSheetSyncError',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    const SizedBox(height: 6),
                    const Text(
                        'How to set up: Create a Google Sheet → Extensions → Apps Script → paste the doPost script → Deploy as Web App → copy URL here.',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
            )),

        // Item 8: Budgets removed from settings (still accessible via home grid)
        _header('MANAGE DATA'),
        Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              _navTile(Icons.account_balance_wallet, 'Accounts', Colors.indigo,
                  AppRoutes.accounts),
              _div(),
              _navTile(Icons.category, 'Categories', Colors.pink,
                  AppRoutes.categories),
              _div(),
              _navTile(Icons.repeat, 'Recurring', Colors.orange,
                  AppRoutes.recurring),
              _div(),
              _navTile(
                  Icons.savings, 'Budgets', Colors.teal, AppRoutes.budgets),
              _div(),
              _navTile(Icons.auto_fix_high, 'Smart Rules', Colors.purple,
                  AppRoutes.rules),
            ])),

        // Item 11: Reset section
        _header('DANGER ZONE'),
        Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.restore, color: Colors.red),
              title: const Text('Reset App Data',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w500)),
              subtitle:
                  const Text('Set all balances to ₹0, clear all transactions'),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
              onTap: _showResetDialog,
            )),

        _header('ABOUT'),
        Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Version'),
              trailing: Text('1.0.0', style: TextStyle(color: Colors.grey)),
            )),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(t,
          style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              letterSpacing: 1)));
  Widget _div() => const Divider(height: 1, indent: 16, endIndent: 16);
  Widget _navTile(IconData icon, String title, Color color, String route) =>
      ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, route).then((_) => _load()),
      );
}
