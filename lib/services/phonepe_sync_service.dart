import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import 'downloads_scanner_service.dart';
import 'phonepe_statement_parser.dart';

class PhonePeSyncResult {
  final int importedCount;
  final int skippedCount;
  final bool dataChanged;
  final bool isError;
  final String message;

  const PhonePeSyncResult({
    required this.importedCount,
    required this.skippedCount,
    required this.dataChanged,
    required this.isError,
    required this.message,
  });
}

class PhonePeSyncService {
  PhonePeSyncService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  final DatabaseHelper _db;

  Future<PhonePeSyncResult> sync({
    required Future<bool> Function() onNeedFolderPick,
  }) async {
    debugPrint('[PhonePeSync] ===== Shared PhonePe sync started =====');
    try {
      final scanResult = await DownloadsScannerService.findLatestStatement(
        onNeedFolderPick: onNeedFolderPick,
      );
      if (!scanResult.success) {
        final message = scanResult.error ??
            DownloadsScannerService.noStatementMessage;
        debugPrint('[PhonePeSync] Scan failed: $message');
        return PhonePeSyncResult(
          importedCount: 0,
          skippedCount: 0,
          dataChanged: false,
          isError: true,
          message: message,
        );
      }

      final file = scanResult.file!;
      final extension = file.path.split('.').last.toLowerCase();
      debugPrint('[PhonePeSync] Statement found: ${file.path}');

      List<PhonePeTransaction> parsed;
      try {
        parsed = extension == 'pdf'
            ? await PhonePeStatementParser.parsePdf(file)
            : await PhonePeStatementParser.parseCsv(file);
      } catch (error) {
        debugPrint('[PhonePeSync] Parser failed: $error');
        return PhonePeSyncResult(
          importedCount: 0,
          skippedCount: 0,
          dataChanged: false,
          isError: true,
          message: 'Could not parse statement: $error',
        );
      }

      if (parsed.isEmpty) {
        return const PhonePeSyncResult(
          importedCount: 0,
          skippedCount: 0,
          dataChanged: false,
          isError: false,
          message: 'Statement found, but no transactions could be detected.',
        );
      }

      final allKeys = parsed.map((transaction) => transaction.dedupeKey).toList();
      final newKeySet = await _db.filterNewDedupeKeys(allKeys);
      final newTransactions = parsed
          .where((transaction) => newKeySet.contains(transaction.dedupeKey))
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      final skippedCount = parsed.length - newTransactions.length;

      if (newTransactions.isEmpty) {
        return PhonePeSyncResult(
          importedCount: 0,
          skippedCount: skippedCount,
          dataChanged: false,
          isError: false,
          message:
              'No new transactions found. Skipped $skippedCount duplicate${skippedCount == 1 ? '' : 's'}.',
        );
      }

      final importAccount = await _db.resolveImportAccount();
      if (importAccount == null) {
        return const PhonePeSyncResult(
          importedCount: 0,
          skippedCount: 0,
          dataChanged: false,
          isError: true,
          message: 'Please create an account first.',
        );
      }

      final accountId = importAccount['id'] as int;
      final accountName = importAccount['name'] as String;
      debugPrint(
          '[PhonePeSync] Importing into $accountName ($accountId): ${newTransactions.length} new transaction(s).');
      final savedCount = await _db.insertPhonePeTransactions(
        newTransactions.map((transaction) => transaction.toMap()).toList(),
        accountId: accountId,
      );

      return PhonePeSyncResult(
        importedCount: savedCount,
        skippedCount: skippedCount,
        dataChanged: savedCount > 0,
        isError: false,
        message:
            'Synced $savedCount new transaction${savedCount == 1 ? '' : 's'}. Skipped $skippedCount duplicate${skippedCount == 1 ? '' : 's'}.',
      );
    } catch (error, stackTrace) {
      debugPrint('[PhonePeSync] Sync failed: $error');
      debugPrint('$stackTrace');
      return PhonePeSyncResult(
        importedCount: 0,
        skippedCount: 0,
        dataChanged: false,
        isError: true,
        message: 'Could not sync PhonePe statement: $error',
      );
    } finally {
      debugPrint('[PhonePeSync] ===== Shared PhonePe sync finished =====');
    }
  }
}
