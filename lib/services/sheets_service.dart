import 'package:flutter/foundation.dart';

import 'sync_settings_service.dart';

/// Compatibility shim for existing per-transaction call sites.
/// Network delivery is handled only by the Local Data Vault sync pipeline.
class SheetsService {
  static final SheetsService _instance = SheetsService._();
  factory SheetsService() => _instance;
  SheetsService._();

  final _settings = SyncSettingsService();

  Future<String?> getScriptUrl() async {
    final endpoint = await _settings.getGoogleSheetEndpoint();
    return endpoint.isEmpty ? null : endpoint;
  }

  Future<void> setScriptUrl(String url) {
    return _settings.setGoogleSheetEndpoint(url);
  }

  Future<bool> appendTransaction(Map<String, dynamic> transaction) async {
    if (!await _settings.isGoogleSheetSyncEnabled()) {
      debugPrint('GOOGLE_SHEET_SYNC_SKIPPED=disabled');
      return false;
    }

    final url = await _settings.getGoogleSheetEndpoint();
    if (url.isEmpty) {
      debugPrint('GOOGLE_SHEET_SYNC_SKIPPED=no_endpoint_configured');
      return false;
    }

    debugPrint('GOOGLE_SHEET_SYNC_DEFERRED=local_data_vault');
    return false;
  }
}
