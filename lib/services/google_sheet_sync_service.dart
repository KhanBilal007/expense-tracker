import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'local_data_vault_service.dart';
import 'sync_settings_service.dart';

class GoogleSheetSyncService {
  final LocalDataVaultService _vault;
  final SyncSettingsService _settings;
  final http.Client _client;

  GoogleSheetSyncService({
    LocalDataVaultService? vault,
    SyncSettingsService? settings,
    http.Client? client,
  })  : _vault = vault ?? LocalDataVaultService(),
        _settings = settings ?? SyncSettingsService(),
        _client = client ?? http.Client();

  Future<void> syncFromLocalVault() async {
    final attemptAt = DateTime.now().toIso8601String();
    debugPrint('GOOGLE_SHEET_SYNC_STARTED');

    try {
      final endpoint = await _settings.getGoogleSheetEndpoint();
      final endpointConfigured = endpoint.isNotEmpty;

      if (!endpointConfigured) {
        await _vault.updateGoogleSheetSyncStatus(
          lastAttemptAt: attemptAt,
          endpointConfigured: false,
          pendingCount: 0,
          lastError: 'no_endpoint_configured',
        );
        debugPrint('GOOGLE_SHEET_SYNC_SKIPPED=no_endpoint_configured');
        return;
      }

      final payload = await buildPayload();
      await _vault.updateGoogleSheetSyncStatus(
        lastAttemptAt: attemptAt,
        endpointConfigured: true,
        pendingCount: 0,
      );

      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('http_${response.statusCode}');
      }

      await _vault.updateGoogleSheetSyncStatus(
        lastAttemptAt: attemptAt,
        lastSuccessAt: DateTime.now().toIso8601String(),
        endpointConfigured: true,
        pendingCount: 0,
      );
      debugPrint('GOOGLE_SHEET_SYNC_SUCCESS');
    } catch (e) {
      final safeError = _safeError(e);
      await _vault.updateGoogleSheetSyncStatus(
        lastAttemptAt: attemptAt,
        endpointConfigured: await _settings.isGoogleSheetEndpointConfigured(),
        pendingCount: 1,
        lastError: safeError,
      );
      debugPrint('GOOGLE_SHEET_SYNC_FAILED=$safeError');
    }
  }

  Future<Map<String, dynamic>> buildPayload() async {
    final metadata = await _vault.readMetadata();

    return {
      'schemaVersion': 1,
      'exportedAt':
          metadata['lastExportAt']?.toString() ?? DateTime.now().toIso8601String(),
      'accounts': await _vault.readAccounts(),
      'transactions': await _vault.readTransactions(),
      'expenses': await _vault.readExpenses(),
      'moneyAdded': await _vault.readMoneyAdded(),
      'transfers': await _vault.readTransfers(),
      'summaries': await _vault.readSummaries(),
      'metadata': metadata,
    };
  }

  String _safeError(Object error) {
    final raw = error.toString();
    return raw
        .replaceAll(RegExp(r'https?://\S+'), '[endpoint]')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
