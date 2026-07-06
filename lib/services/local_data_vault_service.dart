import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LocalDataVaultService {
  static const folderName = 'expense_tracker_data';

  static const accountsFile = 'accounts.json';
  static const transactionsFile = 'transactions.json';
  static const expensesFile = 'expenses.json';
  static const moneyAddedFile = 'money_added.json';
  static const transfersFile = 'transfers.json';
  static const summariesFile = 'summaries.json';
  static const metadataFile = 'metadata.json';
  static const syncQueueFile = 'sync_queue.json';

  Future<Directory> getVaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> getVaultPath() async {
    return (await getVaultDirectory()).path;
  }

  Future<void> exportAll(Map<String, dynamic> snapshot) async {
    final dir = await getVaultDirectory();

    await _writeJsonFile(dir, accountsFile, snapshot['accounts'] ?? []);
    await _writeJsonFile(dir, transactionsFile, snapshot['transactions'] ?? []);
    await _writeJsonFile(dir, expensesFile, snapshot['expenses'] ?? []);
    await _writeJsonFile(dir, moneyAddedFile, snapshot['money_added'] ?? []);
    await _writeJsonFile(dir, transfersFile, snapshot['transfers'] ?? []);
    await _writeJsonFile(dir, summariesFile, snapshot['summaries'] ?? {});
    await _writeJsonFile(dir, metadataFile, snapshot['metadata'] ?? {});
    await _ensureSyncQueueFile(dir);
    await _printVerificationLog(dir, snapshot);
  }

  Future<List<Map<String, dynamic>>> readAccounts() {
    return _readJsonList(accountsFile);
  }

  Future<List<Map<String, dynamic>>> readTransactions() {
    return _readJsonList(transactionsFile);
  }

  Future<List<Map<String, dynamic>>> readExpenses() {
    return _readJsonList(expensesFile);
  }

  Future<List<Map<String, dynamic>>> readMoneyAdded() {
    return _readJsonList(moneyAddedFile);
  }

  Future<List<Map<String, dynamic>>> readTransfers() {
    return _readJsonList(transfersFile);
  }

  Future<Map<String, dynamic>> readSummaries() {
    return _readJsonMap(summariesFile);
  }

  Future<Map<String, dynamic>> readMetadata() {
    return _readJsonMap(metadataFile);
  }

  Future<Map<String, dynamic>> readSyncQueue() {
    return _readJsonMap(syncQueueFile);
  }

  Future<Map<String, dynamic>> readGoogleSheetSyncStatus() async {
    final syncQueue = await readSyncQueue();
    final status = syncQueue['googleSheetSync'];
    if (status is Map) {
      return Map<String, dynamic>.from(status);
    }
    return <String, dynamic>{};
  }

  Future<void> updateGoogleSheetSyncStatus({
    required String lastAttemptAt,
    String? lastSuccessAt,
    required bool endpointConfigured,
    required int pendingCount,
    String? lastError,
    Map<String, int>? lastPayloadCounts,
    bool? isLastSyncSuccessful,
  }) async {
    final dir = await getVaultDirectory();
    final existing = await readSyncQueue();
    final pendingItems = existing['pendingItems'] is List
        ? existing['pendingItems'] as List
        : <dynamic>[];
    final existingGoogleSheetSync = existing['googleSheetSync'] is Map
        ? Map<String, dynamic>.from(existing['googleSheetSync'] as Map)
        : <String, dynamic>{};

    await _writeJsonFile(dir, syncQueueFile, {
      'schemaVersion': 1,
      'pendingItems': pendingItems,
      'lastExportAt': existing['lastExportAt'] ?? DateTime.now().toIso8601String(),
      'target': 'google_sheets_future',
      'googleSheetSync': {
        'lastAttemptAt': lastAttemptAt,
        'lastSuccessAt': lastSuccessAt ?? existingGoogleSheetSync['lastSuccessAt'],
        'pendingCount': pendingCount,
        'lastError': lastError,
        'endpointConfigured': endpointConfigured,
        'lastPayloadCounts':
            lastPayloadCounts ?? existingGoogleSheetSync['lastPayloadCounts'] ?? {},
        'isLastSyncSuccessful': isLastSyncSuccessful ??
            existingGoogleSheetSync['isLastSyncSuccessful'] ??
            false,
      },
    });
  }

  Future<void> _ensureSyncQueueFile(Directory dir) async {
    final existing = await readSyncQueue();
    final pendingItems = existing['pendingItems'] is List
        ? existing['pendingItems'] as List
        : <dynamic>[];
    final existingGoogleSheetSync = existing['googleSheetSync'] is Map
        ? Map<String, dynamic>.from(existing['googleSheetSync'] as Map)
        : null;

    await _writeJsonFile(dir, syncQueueFile, {
      'schemaVersion': 1,
      'pendingItems': pendingItems,
      'lastExportAt': DateTime.now().toIso8601String(),
      'target': 'google_sheets_future',
      'googleSheetSync': existingGoogleSheetSync ??
          {
            'lastAttemptAt': null,
            'lastSuccessAt': null,
            'pendingCount': pendingItems.length,
            'lastError': null,
            'endpointConfigured': false,
            'lastPayloadCounts': {},
            'isLastSyncSuccessful': false,
          },
    });
  }

  Future<List<Map<String, dynamic>>> _readJsonList(String fileName) async {
    final value = await _readJson(fileName);
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> _readJsonMap(String fileName) async {
    final value = await _readJson(fileName);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  Future<dynamic> _readJson(String fileName) async {
    try {
      final dir = await getVaultDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      if (!await file.exists()) return null;

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;

      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeJsonFile(
    Directory dir,
    String fileName,
    Object value,
  ) async {
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    final temp = File('${file.path}.tmp');
    const encoder = JsonEncoder.withIndent('  ');

    await temp.writeAsString(encoder.convert(value));
    if (await file.exists()) {
      await file.delete();
    }
    await temp.rename(file.path);
  }

  Future<void> _printVerificationLog(
    Directory dir,
    Map<String, dynamic> snapshot,
  ) async {
    debugPrint('LOCAL_DATA_VAULT_PATH=${dir.path}');
    await _printFileExists(dir, accountsFile);
    await _printFileExists(dir, transactionsFile);
    await _printFileExists(dir, expensesFile);
    await _printFileExists(dir, moneyAddedFile);
    await _printFileExists(dir, summariesFile);
    await _printFileExists(dir, syncQueueFile);
    await _printFileExists(dir, metadataFile);

    debugPrint('LOCAL_DATA_VAULT_COUNT accounts=${_count(snapshot['accounts'])}');
    debugPrint(
      'LOCAL_DATA_VAULT_COUNT transactions=${_count(snapshot['transactions'])}',
    );
    debugPrint('LOCAL_DATA_VAULT_COUNT expenses=${_count(snapshot['expenses'])}');
    debugPrint(
      'LOCAL_DATA_VAULT_COUNT money_added=${_count(snapshot['money_added'])}',
    );
  }

  Future<void> _printFileExists(Directory dir, String fileName) async {
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    debugPrint(
      'LOCAL_DATA_VAULT_FILE $fileName exists=${await file.exists()}',
    );
  }

  int _count(dynamic value) {
    return value is List ? value.length : 0;
  }
}
