import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Item 9: Google Sheets integration
/// Uses Google Sheets API v4 with a user-provided script URL (Google Apps Script)
/// User creates a Google Apps Script Web App that accepts POST requests
class SheetsService {
  static final SheetsService _i = SheetsService._();
  factory SheetsService() => _i;
  SheetsService._();

  static const _prefKey = 'sheets_script_url';

  Future<String?> getScriptUrl() async => (await SharedPreferences.getInstance()).getString(_prefKey);
  Future<void> setScriptUrl(String url) async => (await SharedPreferences.getInstance()).setString(_prefKey, url);

  /// Appends a row to the connected Google Sheet
  Future<bool> appendTransaction(Map<String, dynamic> tx) async {
    final url = await getScriptUrl();
    if (url == null || url.isEmpty) return false;
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'date':        tx['date'],
          'type':        tx['type'],
          'amount':      tx['amount'],
          'account':     tx['account_name'] ?? '',
          'category':    tx['category_name'] ?? '',
          'description': tx['description'] ?? '',
        }),
      );
      return resp.statusCode == 200;
    } catch (_) { return false; }
  }
}
