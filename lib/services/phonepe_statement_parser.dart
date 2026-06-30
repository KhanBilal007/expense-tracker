import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Represents a single parsed transaction from a PhonePe statement.
class PhonePeTransaction {
  final String? transactionId;
  final DateTime dateTime;   // full date + time (real transaction time)
  final double amount;
  final String type;         // 'expense' or 'income'
  final String description;  // merchant / person name

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
    if (transactionId != null && transactionId!.isNotEmpty) {
      return 'txn_$transactionId';
    }
    final d = dateTime;
    final dateStr = '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}'
        '${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}';
    final amtStr  = amount.toStringAsFixed(2).replaceAll('.', '_');
    final descKey = description.toLowerCase().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return '${dateStr}_${amtStr}_${descKey}_$type';
  }

  Map<String, dynamic> toMap() => {
    'transaction_id': transactionId,
    'date'          : dateTime.toIso8601String(),
    'amount'        : amount,
    'type'          : type,
    'description'   : description,
    'dedupe_key'    : dedupeKey,
    'source'        : 'phonepe',
  };

  @override
  String toString() => 'PhonePeTxn($dateTime, $type, ₹$amount, "$description", id=$transactionId)';
}

/// Parses PhonePe PDF statements using syncfusion_flutter_pdf for text
/// extraction. CSV/text export support is kept as a fallback.
///
/// IMPORTANT — verified against a real PhonePe statement PDF, each
/// transaction renders as a 4-line block once text is extracted:
///
///   Line A: "Jun 27, 2026 Paid to Shirin Bhabi DEBIT ₹1"
///   Line B: "02\x0026 am Transaction ID T2606270226050698516013"
///            (the "\x0026" is a non-breaking/control char PhonePe's PDF
///             renderer puts where a colon would visually appear — it is
///             NOT a literal ":" character, so date/time regex must use
///             \D or similar instead of a literal colon)
///   Line C: "UTR No. 536633558478"
///   Line D: "Paid by UPI Lite"   (or "Paid by XXXXXX8433" / "Credited to ...")
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

    debugPrint('[PhonePeParser] Starting PDF text extraction (syncfusion_flutter_pdf)...');
    final document = PdfDocument(inputBytes: bytes);
    debugPrint('[PhonePeParser] PDF opened. Page count: ${document.pages.count}');

    final buffer = StringBuffer();
    for (int i = 0; i < document.pages.count; i++) {
      final pageText = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
      buffer.writeln(pageText);
      debugPrint('[PhonePeParser] Extracted page ${i + 1}/${document.pages.count}: ${pageText.length} chars');
    }
    document.dispose();

    final text = buffer.toString();
    debugPrint('[PhonePeParser] PDF text extraction finished.');
    debugPrint('[PhonePeParser] Total extracted text length: ${text.length} characters');

    final preview = text.length > 3000 ? text.substring(0, 3000) : text;
    debugPrint('[PhonePeParser] ===== First 3000 chars of extracted PDF text ===== ');
    debugPrint(preview);
    debugPrint('[PhonePeParser] ===== End of text preview ===== ');

    debugPrint('[PhonePeParser] Starting block/regex matching on extracted text...');
    final txns = _parseText(text);

    if (txns.isEmpty) {
      debugPrint('[PhonePeParser] NO TRANSACTIONS PARSED - RAW TEXT SAMPLE:');
      debugPrint(preview);
    }

    txns.sort((a, b) => b.dateTime.compareTo(a.dateTime)); // newest first
    debugPrint('[PhonePeParser] Number of parsed transactions: ${txns.length}');
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
    debugPrint('[PhonePeParser] ===== First 30 lines of CSV/text ===== ');
    debugPrint(preview);
    debugPrint('[PhonePeParser] ===== End of preview ===== ');

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

  // ─── PDF text parser (block-based, matches verified PhonePe layout) ─────
  //
  // Each transaction occupies a small group of consecutive lines. The
  // FIRST line of the group always contains date + merchant + DEBIT/CREDIT
  // + amount. The line immediately after contains the time + Transaction
  // ID. We match line-by-line rather than merging windows, since merging
  // produced false negatives/garbled text on real statements.

  static List<PhonePeTransaction> _parseText(String text) {
    final rawLines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    debugPrint('[PhonePeParser] Total non-empty lines extracted: ${rawLines.length}');

    // Line A pattern: "Jun 27, 2026 Paid to Shirin Bhabi DEBIT ₹1"
    //   - also tolerates "Electricity bill paid 490010120028 DEBIT ₹13,283"
    //     (no "Paid to"/"Received from" prefix)
    final dateLinePattern = RegExp(
      r'^([A-Za-z]{3})\s+(\d{1,2}),?\s+(\d{4})\s+(.+?)\s+(DEBIT|CREDIT)\s+₹\s*([\d,]+\.?\d*)\s*$',
    );

    // Line B pattern: "02\x0026 am Transaction ID T2606270226050698516013"
    //   - the separator between hour/minute can be a colon, a control
    //     character, or nothing visible at all (\D handles all of these)
    //   - also tolerates "NX26062212241732134487781" style alphanumeric IDs
    final timeLinePattern = RegExp(
      r'^(\d{1,2})\D(\d{2})\s*(am|pm)\b.*?(?:Transaction\s*ID|Txn\s*ID)\s*([A-Za-z0-9]+)',
      caseSensitive: false,
    );

    int blockCount = 0;
    final transactions = <PhonePeTransaction>[];

    for (int i = 0; i < rawLines.length; i++) {
      final m = dateLinePattern.firstMatch(rawLines[i]);
      if (m == null) continue;
      blockCount++;

      try {
        final monthStr = m.group(1)!;
        final day      = int.parse(m.group(2)!);
        final year     = int.parse(m.group(3)!);
        final merchantRaw = m.group(4)!;
        final txType   = m.group(5)!; // DEBIT or CREDIT
        final amount   = double.parse(m.group(6)!.replaceAll(',', ''));

        final month = _monthFromName(monthStr);
        if (month == null) {
          debugPrint('[PhonePeParser] Skipped block $blockCount: unrecognized month "$monthStr"');
          continue;
        }

        // Look at the next line for time + transaction ID
        int hour = 0, minute = 0;
        String? txnId;
        if (i + 1 < rawLines.length) {
          final tMatch = timeLinePattern.firstMatch(rawLines[i + 1]);
          if (tMatch != null) {
            hour = int.parse(tMatch.group(1)!);
            minute = int.parse(tMatch.group(2)!);
            final meridiem = tMatch.group(3)!.toLowerCase();
            if (meridiem == 'pm' && hour != 12) hour += 12;
            if (meridiem == 'am' && hour == 12) hour = 0;
            txnId = tMatch.group(4);
          } else {
            debugPrint('[PhonePeParser] Block $blockCount: no time/txnID match on next line: "${rawLines[i + 1]}"');
          }
        }

        final dateTime = DateTime(year, month, day, hour, minute);
        final merchant = merchantRaw
            .replaceAll(RegExp(r'^(paid\s+to|received\s+from|sent\s+to)\s*', caseSensitive: false), '')
            .trim();
        final type = txType.toUpperCase() == 'CREDIT' ? 'income' : 'expense';

        transactions.add(PhonePeTransaction(
          transactionId: txnId,
          dateTime     : dateTime,
          amount       : amount,
          type         : type,
          description  : merchant.isEmpty ? 'PhonePe Transaction' : merchant,
        ));
      } catch (e) {
        debugPrint('[PhonePeParser] Error parsing block $blockCount (line: "${rawLines[i]}"): $e');
        continue;
      }
    }

    debugPrint('[PhonePeParser] Raw transaction blocks found (date-line matches): $blockCount');
    debugPrint('[PhonePeParser] Successfully parsed transactions: ${transactions.length}');

    return transactions;
  }

  // ─── CSV parser (fallback) ──────────────────────────────────────────────

  static List<PhonePeTransaction> _parseCsvLines(List<String> lines) {
    if (lines.isEmpty) {
      debugPrint('[PhonePeParser] CSV file is empty');
      return [];
    }
    final delimiter = lines.first.contains('\t') ? '\t' : ',';
    debugPrint('[PhonePeParser] CSV delimiter detected: "${delimiter == '\t' ? '\\t' : delimiter}"');

    int headerIdx = -1;
    List<String> headers = [];
    for (int i = 0; i < lines.length && i < 10; i++) {
      final cols  = _splitCsv(lines[i], delimiter);
      final lower = cols.map((c) => c.toLowerCase().trim()).toList();
      if (lower.any((c) => c.contains('date')) && lower.any((c) => c.contains('amount'))) {
        headerIdx = i; headers = lower; break;
      }
    }
    if (headerIdx == -1) {
      debugPrint('[PhonePeParser] CSV header row (date + amount columns) not found in first 10 lines');
      return [];
    }
    debugPrint('[PhonePeParser] CSV header found at line $headerIdx: $headers');

    final dateIdx = _col(headers, ['date', 'transaction date']);
    final timeIdx = _col(headers, ['time']);
    final amtIdx  = _col(headers, ['amount', 'transaction amount']);
    final typeIdx = _col(headers, ['type', 'dr/cr', 'debit/credit', 'txn type']);
    final descIdx = _col(headers, ['description', 'remarks', 'narration', 'merchant', 'name']);
    final txnIdx  = _col(headers, ['transaction id', 'txn id', 'reference', 'utr']);

    final transactions = <PhonePeTransaction>[];
    int blockCount = 0;
    for (int i = headerIdx + 1; i < lines.length; i++) {
      final row = _splitCsv(lines[i], delimiter);
      if (row.length <= amtIdx) continue;
      blockCount++;

      try {
        final timeStr = (timeIdx != -1 && timeIdx < row.length) ? row[timeIdx].trim() : null;
        final dateTime = _parseDateTime(row[dateIdx].trim(), timeStr);
        final rawAmt = row[amtIdx].trim().replaceAll(RegExp(r'[₹,\s]'), '').replaceAll('"', '');
        if (rawAmt.isEmpty) continue;
        final amount = double.parse(rawAmt);
        if (amount <= 0) continue;

        String type = 'expense';
        if (typeIdx != -1 && typeIdx < row.length) {
          final t = row[typeIdx].toLowerCase();
          type = (t.contains('cr') || t.contains('received') || t.contains('credit')) ? 'income' : 'expense';
        }

        final desc  = (descIdx != -1 && descIdx < row.length) ? row[descIdx].trim().replaceAll('"', '') : 'PhonePe Transaction';
        final txnId = (txnIdx != -1 && txnIdx < row.length && row[txnIdx].trim().isNotEmpty) ? row[txnIdx].trim() : null;

        transactions.add(PhonePeTransaction(
          transactionId: txnId,
          dateTime     : dateTime,
          amount       : amount,
          type         : type,
          description  : desc.isEmpty ? 'PhonePe Transaction' : desc,
        ));
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
    final result = <String>[]; final buffer = StringBuffer(); bool inQuote = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') { inQuote = !inQuote; }
      else if (c == delimiter && !inQuote) { result.add(buffer.toString()); buffer.clear(); }
      else { buffer.write(c); }
    }
    result.add(buffer.toString());
    return result;
  }

  // ─── Date / time parsing (CSV path) ─────────────────────────────────────

  static final _monthMap = {
    'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,
    'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12,
  };

  static DateTime _parseDateTime(String dateRaw, String? timeRaw) {
    final date = _parseDateOnly(dateRaw.trim());
    if (timeRaw == null || timeRaw.trim().isEmpty) return date;

    final t = timeRaw.trim().toUpperCase();
    final timeMatch = RegExp(r'(\d{1,2})\D(\d{2})(?:\D(\d{2}))?\s*(AM|PM)?').firstMatch(t);
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

    var m = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})$').firstMatch(raw);
    if (m != null) {
      final month = _monthFromName(m.group(2)!);
      if (month != null) return DateTime(int.parse(m.group(3)!), month, int.parse(m.group(1)!));
    }

    m = RegExp(r'^([A-Za-z]{3,9})\s+(\d{1,2})\s+(\d{4})$').firstMatch(raw);
    if (m != null) {
      final month = _monthFromName(m.group(1)!);
      if (month != null) return DateTime(int.parse(m.group(3)!), month, int.parse(m.group(2)!));
    }

    m = RegExp(r'^(\d{1,2})[\-/](\d{1,2})[\-/](\d{4})$').firstMatch(raw);
    if (m != null) {
      return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
    }

    m = RegExp(r'^(\d{4})[\-/](\d{1,2})[\-/](\d{1,2})$').firstMatch(raw);
    if (m != null) {
      return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
    }

    throw FormatException('Cannot parse date: $raw');
  }

  static int? _monthFromName(String name) {
    if (name.length < 3) return null;
    return _monthMap[name.toLowerCase().substring(0, 3)];
  }
}
