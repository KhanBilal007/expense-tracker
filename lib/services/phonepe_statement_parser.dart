import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Represents a single parsed transaction from a PhonePe statement.
class PhonePeTransaction {
  final String? transactionId;
  final DateTime dateTime; // full date + time (real transaction time)
  final double amount;
  final String type; // 'expense' or 'income'
  final String description; // merchant / person name

  PhonePeTransaction({
    this.transactionId,
    required this.dateTime,
    required this.amount,
    required this.type,
    required this.description,
  });

  /// Unique key for duplicate detection.
  /// Prefers transaction ID; falls back to date+amount+type+description.
  String get dedupeKey {
    final id = transactionId;
    if (id != null && id.isNotEmpty) {
      return 'txn_$id';
    }

    final d = dateTime;
    final dateStr =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}'
        '${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}';

    final amtStr = amount.toStringAsFixed(2).replaceAll('.', '_');
    final descKey = description
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    return '${dateStr}_${amtStr}_${descKey}_$type';
  }

  Map<String, dynamic> toMap() => {
        'transaction_id': transactionId,
        'date': dateTime.toIso8601String(),
        'amount': amount,
        'type': type,
        'description': description,
        'dedupe_key': dedupeKey,
        'source': 'phonepe',
      };

  @override
  String toString() =>
      'PhonePeTxn($dateTime, $type, ₹$amount, "$description", id=$transactionId)';
}

/// Parses PhonePe PDF statements using syncfusion_flutter_pdf for text
/// extraction. CSV/text export support is kept as a fallback.
///
/// This parser supports the PhonePe PDF layout where each transaction is
/// extracted line-by-line, for example:
///
///   Jun 14, 2026
///   10
///   DEBIT
///   ₹4,120
///   Paid to SAMREEN BEGUM SHAIKH SADEQ
///   Transaction ID T2606142233150843583987
///   UTR No. 889935511184
///   Paid by
///   XXXXXX8433
///
/// DEBIT/CREDIT is used only to choose the app transaction type:
///   DEBIT  -> expense
///   CREDIT -> income
///
/// The UI should then show red/green using the app's existing type logic.
class PhonePeStatementParser {
  // ─── Public entry points ────────────────────────────────────────────────

  /// Parses a PhonePe statement PDF file. Returns the list of transactions
  /// found, sorted newest-first by actual transaction date/time.
  static Future<List<PhonePeTransaction>> parsePdf(File file) async {
    debugPrint('[PhonePeParser] parsePdf() called with path: ${file.path}');
    final ext = file.path.split('.').last.toLowerCase();
    debugPrint('[PhonePeParser] File extension detected: .$ext');

    debugPrint('[PhonePeParser] Reading file bytes...');
    final bytes = await file.readAsBytes();
    debugPrint('[PhonePeParser] File size: ${bytes.length} bytes');

    debugPrint(
      '[PhonePeParser] Starting PDF text extraction (syncfusion_flutter_pdf)...',
    );
    final document = PdfDocument(inputBytes: bytes);
    debugPrint('[PhonePeParser] PDF opened. Page count: ${document.pages.count}');

    final buffer = StringBuffer();
    for (int i = 0; i < document.pages.count; i++) {
      final pageText = PdfTextExtractor(document).extractText(
        startPageIndex: i,
        endPageIndex: i,
      );
      buffer.writeln(pageText);
      debugPrint(
        '[PhonePeParser] Extracted page ${i + 1}/${document.pages.count}: ${pageText.length} chars',
      );
    }
    document.dispose();

    final text = buffer.toString();
    debugPrint('[PhonePeParser] PDF text extraction finished.');
    debugPrint(
      '[PhonePeParser] Total extracted text length: ${text.length} characters',
    );

    final preview = text.length > 3000 ? text.substring(0, 3000) : text;
    debugPrint('[PhonePeParser] ===== First 3000 chars of extracted PDF text =====');
    debugPrint(preview);
    debugPrint('[PhonePeParser] ===== End of text preview =====');

    debugPrint('[PhonePeParser] Starting line-by-line matching on extracted text...');
    final txns = _parseText(text);

    if (txns.isEmpty) {
      debugPrint('[PhonePeParser] NO TRANSACTIONS PARSED - RAW TEXT SAMPLE:');
      debugPrint(preview);
    }

    txns.sort((a, b) => b.dateTime.compareTo(a.dateTime)); // newest first
    debugPrint('[PhonePeParser] Number of parsed transactions: ${txns.length}');
    if (txns.isNotEmpty) {
      debugPrint('[PhonePeParser] First parsed transaction sample: ${txns.first}');
    }
    return txns;
  }

  /// CSV / TSV / plain-text fallback parser.
  static Future<List<PhonePeTransaction>> parseCsv(File file) async {
    debugPrint('[PhonePeParser] parseCsv() called with path: ${file.path}');
    final ext = file.path.split('.').last.toLowerCase();
    debugPrint('[PhonePeParser] File extension detected: .$ext');

    final lines = await file.readAsLines();
    debugPrint('[PhonePeParser] CSV/text file read: ${lines.length} lines');

    final preview = lines.take(30).join('\n');
    debugPrint('[PhonePeParser] ===== First 30 lines of CSV/text =====');
    debugPrint(preview);
    debugPrint('[PhonePeParser] ===== End of preview =====');

    debugPrint('[PhonePeParser] Starting CSV block matching...');
    final txns = _parseCsvLines(lines);

    if (txns.isEmpty) {
      debugPrint('[PhonePeParser] NO TRANSACTIONS PARSED - RAW TEXT SAMPLE:');
      debugPrint(preview);
    }

    txns.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    debugPrint('[PhonePeParser] Number of parsed transactions: ${txns.length}');
    return txns;
  }

  // ─── PDF text parser: real PhonePe line-by-line layout ─────────────────

  static List<PhonePeTransaction> _parseText(String text) {
    final lines = text
        .replaceAll('\u0000', '')
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    debugPrint('[PhonePeParser] Total non-empty lines extracted: ${lines.length}');

    final dateOnlyPattern = RegExp(
      r'^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2},\s+\d{4}$',
      caseSensitive: false,
    );

    final typePattern = RegExp(r'^(DEBIT|CREDIT)$', caseSensitive: false);
    final amountPattern = RegExp(r'(?:₹|Rs\.?|INR)?\s*([\d,]+(?:\.\d{1,2})?)');

    final transactions = <PhonePeTransaction>[];
    int dateLinesMatched = 0;
    int candidateBlocks = 0;

    for (int i = 0; i < lines.length; i++) {
      final dateLine = lines[i];

      if (!dateOnlyPattern.hasMatch(dateLine)) {
        continue;
      }

      dateLinesMatched++;

      try {
        final dateOnly = _parseDateOnly(dateLine);

        // In the real extracted layout:
        // date line -> time/hour line -> DEBIT/CREDIT -> amount -> name line.
        // Still, search a small window to tolerate minor PDF extraction noise.
        int typeIndex = -1;
        final typeSearchEnd = _minInt(lines.length, i + 8);
        for (int j = i + 1; j < typeSearchEnd; j++) {
          if (typePattern.hasMatch(lines[j])) {
            typeIndex = j;
            break;
          }
        }

        if (typeIndex == -1) {
          debugPrint(
            '[PhonePeParser] Date line matched but DEBIT/CREDIT not found near line $i: "$dateLine"',
          );
          continue;
        }

        candidateBlocks++;

        final timeLine = typeIndex > i + 1 ? lines[typeIndex - 1] : '';
        final rawType = lines[typeIndex].toUpperCase();
        final appType = rawType == 'CREDIT' ? 'income' : 'expense';

        int amountIndex = -1;
        double? amount;
        final amountSearchEnd = _minInt(lines.length, typeIndex + 4);
        for (int j = typeIndex + 1; j < amountSearchEnd; j++) {
          final parsedAmount = _parseAmount(lines[j], amountPattern);
          if (parsedAmount != null) {
            amountIndex = j;
            amount = parsedAmount;
            break;
          }
        }

        if (amountIndex == -1 || amount == null) {
          debugPrint(
            '[PhonePeParser] Skipped candidate block: amount not found after ${lines[typeIndex]} at line $typeIndex',
          );
          continue;
        }

        final description = _findDescription(lines, amountIndex + 1);

        String? txnId;
        final metadataSearchEnd = _minInt(lines.length, amountIndex + 12);
        for (int j = amountIndex + 1; j < metadataSearchEnd; j++) {
          txnId = _extractTransactionId(lines[j]);
          if (txnId != null) break;
        }

        DateTime dateTime = dateOnly;

        // Best source of exact time is PhonePe Transaction ID:
        // T260614223315... -> 2026-06-14 22:33:15
        final txnDateTime = txnId == null ? null : _dateTimeFromTransactionId(txnId);
        if (txnDateTime != null) {
          dateTime = txnDateTime;
        } else {
          dateTime = _applyTimeHint(dateOnly, timeLine);
        }

        transactions.add(
          PhonePeTransaction(
            transactionId: txnId,
            dateTime: dateTime,
            amount: amount.abs(),
            type: appType,
            description:
                description.isEmpty ? 'PhonePe Transaction' : description,
          ),
        );
      } catch (e) {
        debugPrint('[PhonePeParser] Error parsing date block at line $i: $e');
        continue;
      }
    }

    transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    debugPrint('[PhonePeParser] Date lines matched: $dateLinesMatched');
    debugPrint('[PhonePeParser] Candidate transaction blocks: $candidateBlocks');
    debugPrint('[PhonePeParser] Successfully parsed transactions: ${transactions.length}');
    if (transactions.isNotEmpty) {
      debugPrint('[PhonePeParser] First parsed transaction sample: ${transactions.first}');
    }

    return transactions;
  }

  static int _minInt(int a, int b) => a < b ? a : b;

  static double? _parseAmount(String line, RegExp amountPattern) {
    final match = amountPattern.firstMatch(line);
    if (match == null) return null;

    final numeric = match.group(1)!.replaceAll(',', '').trim();
    if (numeric.isEmpty) return null;

    return double.tryParse(numeric);
  }

  static String _findDescription(List<String> lines, int startIndex) {
    final end = _minInt(lines.length, startIndex + 6);

    for (int i = startIndex; i < end; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (_isMetadataLine(line)) continue;

      final cleaned = _cleanDescription(line);
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    return '';
  }

  static String _cleanDescription(String raw) {
    var value = raw
        .replaceFirst(
          RegExp(r'^(Paid\s+to|Received\s+from|Sent\s+to|Payment\s+to|Refund\s+from)\s+',
              caseSensitive: false),
          '',
        )
        .trim();

    // Remove accidental duplicated spaces.
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();

    return value;
  }

  static bool _isMetadataLine(String line) {
    final lower = line.toLowerCase().trim();

    if (lower.startsWith('transaction id')) return true;
    if (lower.startsWith('txn id')) return true;
    if (lower.startsWith('utr no')) return true;
    if (lower.startsWith('utr')) return true;
    if (lower.startsWith('paid by')) return true;
    if (lower.startsWith('credited to')) return true;
    if (lower == 'debit' || lower == 'credit') return true;
    if (RegExp(r'^x{2,}\d+$', caseSensitive: false).hasMatch(line)) return true;
    if (RegExp(r'^\d{6,}$').hasMatch(line)) return true;
    if (RegExp(r'^(₹|rs\.?|inr)\s*[\d,]+', caseSensitive: false).hasMatch(line)) {
      return true;
    }

    return false;
  }

  static String? _extractTransactionId(String line) {
    final match = RegExp(
      r'(?:Transaction\s*ID|Txn\s*ID)\s*([A-Za-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(line);

    return match?.group(1);
  }

  static DateTime? _dateTimeFromTransactionId(String txnId) {
    // PhonePe IDs often begin like T260614223315...
    // That is YY MM DD HH MM SS.
    final match = RegExp(r'T(\d{12})', caseSensitive: false).firstMatch(txnId);
    if (match == null) return null;

    final raw = match.group(1)!;

    try {
      final year = 2000 + int.parse(raw.substring(0, 2));
      final month = int.parse(raw.substring(2, 4));
      final day = int.parse(raw.substring(4, 6));
      final hour = int.parse(raw.substring(6, 8));
      final minute = int.parse(raw.substring(8, 10));
      final second = int.parse(raw.substring(10, 12));

      if (month < 1 || month > 12) return null;
      if (day < 1 || day > 31) return null;
      if (hour < 0 || hour > 23) return null;
      if (minute < 0 || minute > 59) return null;
      if (second < 0 || second > 59) return null;

      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  static DateTime _applyTimeHint(DateTime dateOnly, String timeLine) {
    if (timeLine.trim().isEmpty) return dateOnly;

    final cleaned = timeLine.trim();

    // Handles "10:33 PM", "08:36 pm", and similar extracted variants.
    final withMinutes = RegExp(
      r'(\d{1,2})\D+(\d{2})\s*(AM|PM)?',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (withMinutes != null) {
      int hour = int.parse(withMinutes.group(1)!);
      final minute = int.parse(withMinutes.group(2)!);
      final meridiem = withMinutes.group(3)?.toLowerCase();

      if (meridiem == 'pm' && hour != 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;

      if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        return DateTime(dateOnly.year, dateOnly.month, dateOnly.day, hour, minute);
      }
    }

    // Handles only-hour lines like "10", "08", "07".
    // If AM/PM is unavailable, keep the hour as provided and minutes as 00.
    final onlyHour = RegExp(r'^(\d{1,2})$').firstMatch(cleaned);
    if (onlyHour != null) {
      final hour = int.parse(onlyHour.group(1)!);
      if (hour >= 0 && hour <= 23) {
        return DateTime(dateOnly.year, dateOnly.month, dateOnly.day, hour, 0);
      }
    }

    return dateOnly;
  }

  // ─── CSV parser (fallback) ──────────────────────────────────────────────

  static List<PhonePeTransaction> _parseCsvLines(List<String> lines) {
    if (lines.isEmpty) {
      debugPrint('[PhonePeParser] CSV file is empty');
      return [];
    }

    final delimiter = lines.first.contains('\t') ? '\t' : ',';
    debugPrint(
      '[PhonePeParser] CSV delimiter detected: "${delimiter == '\t' ? '\\t' : delimiter}"',
    );

    int headerIdx = -1;
    List<String> headers = [];

    for (int i = 0; i < lines.length && i < 10; i++) {
      final cols = _splitCsv(lines[i], delimiter);
      final lower = cols.map((c) => c.toLowerCase().trim()).toList();

      if (lower.any((c) => c.contains('date')) &&
          lower.any((c) => c.contains('amount'))) {
        headerIdx = i;
        headers = lower;
        break;
      }
    }

    if (headerIdx == -1) {
      debugPrint(
        '[PhonePeParser] CSV header row (date + amount columns) not found in first 10 lines',
      );
      return [];
    }

    debugPrint('[PhonePeParser] CSV header found at line $headerIdx: $headers');

    final dateIdx = _col(headers, ['date', 'transaction date']);
    final timeIdx = _col(headers, ['time']);
    final amtIdx = _col(headers, ['amount', 'transaction amount']);
    final typeIdx = _col(headers, ['type', 'dr/cr', 'debit/credit', 'txn type']);
    final descIdx = _col(headers, ['description', 'remarks', 'narration', 'merchant', 'name']);
    final txnIdx = _col(headers, ['transaction id', 'txn id', 'reference', 'utr']);

    final transactions = <PhonePeTransaction>[];
    int blockCount = 0;

    for (int i = headerIdx + 1; i < lines.length; i++) {
      final row = _splitCsv(lines[i], delimiter);
      if (row.length <= amtIdx) continue;
      blockCount++;

      try {
        final timeStr =
            (timeIdx != -1 && timeIdx < row.length) ? row[timeIdx].trim() : null;
        final dateTime = _parseDateTime(row[dateIdx].trim(), timeStr);

        final rawAmt = row[amtIdx]
            .trim()
            .replaceAll(RegExp(r'[₹,\s]'), '')
            .replaceAll('"', '');

        if (rawAmt.isEmpty) continue;

        final amount = double.parse(rawAmt);
        if (amount <= 0) continue;

        String type = 'expense';
        if (typeIdx != -1 && typeIdx < row.length) {
          final t = row[typeIdx].toLowerCase();
          type = (t.contains('cr') || t.contains('received') || t.contains('credit'))
              ? 'income'
              : 'expense';
        }

        final desc = (descIdx != -1 && descIdx < row.length)
            ? row[descIdx].trim().replaceAll('"', '')
            : 'PhonePe Transaction';

        final txnId = (txnIdx != -1 &&
                txnIdx < row.length &&
                row[txnIdx].trim().isNotEmpty)
            ? row[txnIdx].trim()
            : null;

        transactions.add(
          PhonePeTransaction(
            transactionId: txnId,
            dateTime: dateTime,
            amount: amount,
            type: type,
            description: desc.isEmpty ? 'PhonePe Transaction' : desc,
          ),
        );
      } catch (e) {
        debugPrint('[PhonePeParser] Error parsing CSV row $blockCount: $e');
        continue;
      }
    }

    debugPrint('[PhonePeParser] Raw CSV rows processed: $blockCount');
    return transactions;
  }

  static int _col(List<String> headers, List<String> candidates) {
    for (final c in candidates) {
      final idx = headers.indexWhere((h) => h.contains(c));
      if (idx != -1) return idx;
    }
    return 0;
  }

  static List<String> _splitCsv(String line, String delimiter) {
    if (delimiter == '\t') return line.split('\t');

    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuote = false;

    for (int i = 0; i < line.length; i++) {
      final c = line[i];

      if (c == '"') {
        inQuote = !inQuote;
      } else if (c == delimiter && !inQuote) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }

    result.add(buffer.toString());
    return result;
  }

  // ─── Date / time parsing (CSV path) ─────────────────────────────────────

  static final _monthMap = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static DateTime _parseDateTime(String dateRaw, String? timeRaw) {
    final date = _parseDateOnly(dateRaw.trim());

    if (timeRaw == null || timeRaw.trim().isEmpty) {
      return date;
    }

    final t = timeRaw.trim().toUpperCase();
    final timeMatch =
        RegExp(r'(\d{1,2})\D(\d{2})(?:\D(\d{2}))?\s*(AM|PM)?').firstMatch(t);

    if (timeMatch == null) return date;

    int hour = int.parse(timeMatch.group(1)!);
    final minute = int.parse(timeMatch.group(2)!);
    final second = timeMatch.group(3) != null ? int.parse(timeMatch.group(3)!) : 0;
    final meridiem = timeMatch.group(4);

    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;

    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }

  static DateTime _parseDateOnly(String raw) {
    raw = raw.replaceAll(',', '').trim();

    var m = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})$')
        .firstMatch(raw);
    if (m != null) {
      final month = _monthFromName(m.group(2)!);
      if (month != null) {
        return DateTime(
          int.parse(m.group(3)!),
          month,
          int.parse(m.group(1)!),
        );
      }
    }

    m = RegExp(r'^([A-Za-z]{3,9})\s+(\d{1,2})\s+(\d{4})$')
        .firstMatch(raw);
    if (m != null) {
      final month = _monthFromName(m.group(1)!);
      if (month != null) {
        return DateTime(
          int.parse(m.group(3)!),
          month,
          int.parse(m.group(2)!),
        );
      }
    }

    m = RegExp(r'^(\d{1,2})[\-/](\d{1,2})[\-/](\d{4})$').firstMatch(raw);
    if (m != null) {
      return DateTime(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
      );
    }

    m = RegExp(r'^(\d{4})[\-/](\d{1,2})[\-/](\d{1,2})$').firstMatch(raw);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }

    throw FormatException('Cannot parse date: $raw');
  }

  static int? _monthFromName(String name) {
    if (name.length < 3) return null;
    return _monthMap[name.toLowerCase().substring(0, 3)];
  }
}
