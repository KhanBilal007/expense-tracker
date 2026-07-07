import 'package:shared_preferences/shared_preferences.dart';

class SyncSettingsService {
  static const developerEndpointForTesting =
      'https://script.google.com/macros/s/AKfycbwLQL774SgM2hEszgwZyn2SZ-17zofRdzOun5b3YYY8HqWWHtsfhEfCa3Fqj-4628MOBg/exec';
  static const configuredGoogleSheetEndpoint = developerEndpointForTesting;

  static const statusDisabled = 'disabled';
  static const statusReady = 'ready';
  static const statusSyncing = 'syncing';
  static const statusConnected = 'connected';
  static const statusFailed = 'failed';
  static const statusNotConfigured = 'not_configured';

  static const _enabledKey = 'google_sheet_sync_enabled';
  static const _endpointKey = 'google_sheet_sync_endpoint';
  static const _lastSyncAtKey = 'google_sheet_last_sync_at';
  static const _lastSyncErrorKey = 'google_sheet_last_sync_error';
  static const _syncStatusKey = 'google_sheet_sync_status';

  Future<bool> isGoogleSheetSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setGoogleSheetSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    await prefs.setString(
      _syncStatusKey,
      enabled ? statusReady : statusDisabled,
    );
    if (!enabled) {
      await prefs.remove(_lastSyncErrorKey);
    }
  }

  Future<String> getGoogleSheetEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    final endpoint = prefs.getString(_endpointKey)?.trim() ?? '';
    if (isValidGoogleSheetEndpoint(endpoint)) return endpoint;
    return '';
  }

  Future<void> setGoogleSheetEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final value = endpoint.trim();
    if (value.isEmpty) {
      await prefs.remove(_endpointKey);
      return;
    }
    await prefs.setString(_endpointKey, value);
  }

  bool isValidGoogleSheetEndpoint(String endpoint) {
    final value = endpoint.trim();
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        value.endsWith('/exec');
  }

  Future<bool> isGoogleSheetEndpointConfigured() async {
    return (await getGoogleSheetEndpoint()).isNotEmpty;
  }

  Future<void> updateGoogleSheetSyncState({
    required String syncStatus,
    String? lastSyncAt,
    String? lastSyncError,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncStatusKey, syncStatus);
    if (lastSyncAt != null) {
      await prefs.setString(_lastSyncAtKey, lastSyncAt);
    }
    if (lastSyncError == null || lastSyncError.isEmpty) {
      await prefs.remove(_lastSyncErrorKey);
    } else {
      await prefs.setString(_lastSyncErrorKey, lastSyncError);
    }
  }

  Future<Map<String, dynamic>> getGoogleSheetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final endpoint = await getGoogleSheetEndpoint();
    final savedStatus = prefs.getString(_syncStatusKey);
    final effectiveStatus = !enabled
        ? statusDisabled
        : endpoint.isEmpty
            ? statusNotConfigured
            : savedStatus == statusNotConfigured
                ? statusReady
                : savedStatus ?? statusReady;

    return {
      'googleSheetSyncEnabled': enabled,
      'googleSheetEndpointUrl': endpoint,
      'lastSyncAt': prefs.getString(_lastSyncAtKey),
      'lastSyncError': prefs.getString(_lastSyncErrorKey),
      'syncStatus': effectiveStatus,
    };
  }
}
