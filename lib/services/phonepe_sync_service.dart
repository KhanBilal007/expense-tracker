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
    required Future<double?> Function(String accountName)
        onNeedCurrentPhonePeBalance,
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

      final importAccount = await _db.ensureDefaultPhonePeAccount();
      final accountId = importAccount['id'] as int;
      final accountName = importAccount['name'] as String;
      final firstSyncCompleted =
          await _db.isPhonePeFirstSyncCompleted(accountId);

      if (!firstSyncCompleted) {
        final realPhonePeBalance =
            await onNeedCurrentPhonePeBalance(accountName);
        if (realPhonePeBalance == null) {
          return const PhonePeSyncResult(
            importedCount: 0,
            skippedCount: 0,
            dataChanged: false,
            isError: true,
            message:
                'PhonePe sync cancelled. Current PhonePe balance is required for first-time sync.',
          );
        }

        final openingBalanceCount =
            await _db.insertFirstTimePhonePeOpeningBalance(
          accountId: accountId,
          amount: realPhonePeBalance,
          refreshVault: false,
        );
        await _db.markPhonePeFirstSyncCompleted(
          accountId: accountId,
          syncStartAt: DateTime.now(),
        );
        await _db.exportAllDataToLocalVault();
        debugPrint(
          '[PhonePeSync] First-time setup completed for $accountName ($accountId), balance=$realPhonePeBalance, opening inserted=$openingBalanceCount',
        );

        return const PhonePeSyncResult(
          importedCount: 0,
          skippedCount: 0,
          dataChanged: true,
          isError: false,
          message:
              'PhonePe setup completed. Your current balance is set.\n\nFrom now, only new PhonePe transactions will be added to your PhonePe account in the app.\n\nPlease make one new PhonePe transaction, then download a fresh PhonePe statement, then tap Sync again.\n\nOld PhonePe transactions before this setup will not be imported.',
        );
      }

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

      final syncStartAt = await _db.getPhonePeSyncStartAt(accountId);
      if (syncStartAt == null) {
        return const PhonePeSyncResult(
          importedCount: 0,
          skippedCount: 0,
          dataChanged: false,
          isError: true,
          message:
              'PhonePe setup date is missing. Please reset PhonePe setup or contact support before syncing.',
        );
      }
      final effectiveSyncStartAt = syncStartAt;
      final eligibleTransactions = parsed
          .where((transaction) =>
              transaction.dateTime.isAfter(effectiveSyncStartAt))
          .toList();

      if (eligibleTransactions.isEmpty) {
        return PhonePeSyncResult(
          importedCount: 0,
          skippedCount: parsed.length,
          dataChanged: false,
          isError: false,
          message:
              'No new PhonePe transactions found after setup. Skipped ${parsed.length} old transaction${parsed.length == 1 ? '' : 's'}.',
        );
      }

      final allKeys =
          eligibleTransactions.map((transaction) => transaction.dedupeKey).toList();
      final newKeySet = await _db.filterNewDedupeKeys(allKeys);
      final newTransactions = eligibleTransactions
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

      debugPrint(
          '[PhonePeSync] Importing into $accountName ($accountId): ${newTransactions.length} new transaction(s).');
      final savedCount = await _db.insertPhonePeTransactions(
        newTransactions.map((transaction) => transaction.toMap()).toList(),
        accountId: accountId,
        refreshVault: false,
      );
      if (savedCount > 0) {
        await _db.exportAllDataToLocalVault();
      }

      return PhonePeSyncResult(
        importedCount: savedCount,
        skippedCount: skippedCount,
        dataChanged: savedCount > 0,
        isError: false,
        message:
            'Synced $savedCount new transaction${savedCount == 1 ? '' : 's'}. Skipped $skippedCount duplicate/old transaction${skippedCount == 1 ? '' : 's'}.',
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
