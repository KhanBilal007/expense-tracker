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
    Map<String, dynamic>? payload;
    Map<String, int>? payloadCounts;

    try {
      final endpoint = await _settings.getGoogleSheetEndpoint();
      final endpointConfigured = endpoint.isNotEmpty;
      final existingStatus = await _vault.readGoogleSheetSyncStatus();
      final existingPendingCount =
          (existingStatus['pendingCount'] as num?)?.toInt() ?? 0;

      if (!endpointConfigured) {
        await _vault.updateGoogleSheetSyncStatus(
          lastAttemptAt: attemptAt,
          endpointConfigured: false,
          pendingCount: existingPendingCount,
          lastError: 'no_endpoint_configured',
          isLastSyncSuccessful: false,
        );
        debugPrint('GOOGLE_SHEET_SYNC_SKIPPED=no_endpoint_configured');
        return;
      }

      payload = await buildPayload();
      payloadCounts = _payloadCounts(payload);
      await _vault.updateGoogleSheetSyncStatus(
        lastAttemptAt: attemptAt,
        endpointConfigured: true,
        pendingCount: existingPendingCount,
        lastPayloadCounts: payloadCounts,
        isLastSyncSuccessful: false,
      );

      final response = await _postJsonFollowingRedirects(
        Uri.parse(endpoint),
        jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('http_${response.statusCode}');
      }

      await _vault.updateGoogleSheetSyncStatus(
        lastAttemptAt: attemptAt,
        lastSuccessAt: DateTime.now().toIso8601String(),
        endpointConfigured: true,
        pendingCount: 0,
        lastPayloadCounts: payloadCounts,
        isLastSyncSuccessful: true,
      );
      debugPrint('GOOGLE_SHEET_SYNC_SUCCESS');
    } catch (e) {
      final safeError = _safeError(e);
      final existingStatus = await _vault.readGoogleSheetSyncStatus();
      final existingPendingCount =
          (existingStatus['pendingCount'] as num?)?.toInt() ?? 0;
      await _vault.updateGoogleSheetSyncStatus(
        lastAttemptAt: attemptAt,
        endpointConfigured: await _settings.isGoogleSheetEndpointConfigured(),
        pendingCount: existingPendingCount > 0 ? existingPendingCount : 1,
        lastError: safeError,
        lastPayloadCounts: payloadCounts,
        isLastSyncSuccessful: false,
      );
      debugPrint('GOOGLE_SHEET_SYNC_FAILED=$safeError');
    }
  }

  Future<void> retryPendingGoogleSheetSync() async {
    final status = await _vault.readGoogleSheetSyncStatus();
    final pendingCount = (status['pendingCount'] as num?)?.toInt() ?? 0;

    if (pendingCount <= 0) {
      debugPrint('GOOGLE_SHEET_SYNC_RETRY_SKIPPED=no_pending_sync');
      return;
    }

    debugPrint('GOOGLE_SHEET_SYNC_RETRY_STARTED');
    await syncFromLocalVault();
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

  Future<http.Response> _postJsonFollowingRedirects(
    Uri uri,
    String body,
  ) async {
    final response = await _postJson(uri, body);
    debugPrint('GOOGLE_SHEET_SYNC_HTTP_STATUS=${response.statusCode}');

    if (_isSuccess(response.statusCode)) {
      debugPrint('GOOGLE_SHEET_SYNC_RESPONSE=${_safeResponse(response.body)}');
      return response;
    }

    if (!_isRedirect(response.statusCode)) {
      debugPrint('GOOGLE_SHEET_SYNC_RESPONSE=${_safeResponse(response.body)}');
      return response;
    }

    final location = response.headers['location'];
    if (location == null || location.trim().isEmpty) {
      debugPrint('GOOGLE_SHEET_SYNC_FAILED=redirect_without_location');
      throw Exception('redirect_without_location');
    }

    final redirectUri = uri.resolve(location.trim());
    debugPrint('GOOGLE_SHEET_SYNC_REDIRECT=$redirectUri');

    final redirectedResponse = await _getRedirect(redirectUri);
    debugPrint(
      'GOOGLE_SHEET_SYNC_REDIRECT_STATUS=${redirectedResponse.statusCode}',
    );
    debugPrint(
      'GOOGLE_SHEET_SYNC_RESPONSE=${_safeResponse(redirectedResponse.body)}',
    );

    if (_isSuccess(redirectedResponse.statusCode)) {
      return redirectedResponse;
    }

    throw Exception('http_${redirectedResponse.statusCode}');
  }

  Future<http.Response> _postJson(Uri uri, String body) async {
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..followRedirects = false
      ..body = body;

    final streamedResponse =
        await _client.send(request).timeout(const Duration(seconds: 20));
    return http.Response.fromStream(streamedResponse);
  }

  Future<http.Response> _getRedirect(Uri uri) async {
    final request = http.Request('GET', uri)..followRedirects = false;
    final streamedResponse =
        await _client.send(request).timeout(const Duration(seconds: 20));
    return http.Response.fromStream(streamedResponse);
  }

  bool _isSuccess(int statusCode) {
    return statusCode == 200 || statusCode == 201;
  }

  bool _isRedirect(int statusCode) {
    return statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 303 ||
        statusCode == 307 ||
        statusCode == 308;
  }

  String _safeError(Object error) {
    final raw = error.toString();
    return raw
        .replaceAll(RegExp(r'https?://\S+'), '[endpoint]')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _safeResponse(String responseBody) {
    final safe = responseBody
        .replaceAll(RegExp(r'https?://\S+'), '[endpoint]')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (safe.length <= 220) return safe;
    return '${safe.substring(0, 220)}...';
  }

  Map<String, int> _payloadCounts(Map<String, dynamic> payload) {
    return {
      'accounts': _count(payload['accounts']),
      'transactions': _count(payload['transactions']),
      'expenses': _count(payload['expenses']),
      'moneyAdded': _count(payload['moneyAdded']),
      'transfers': _count(payload['transfers']),
    };
  }

  int _count(Object? value) {
    return value is List ? value.length : 0;
  }
}
