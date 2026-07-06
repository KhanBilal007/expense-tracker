import 'package:shared_preferences/shared_preferences.dart';

class SyncSettingsService {
  static const _googleSheetEndpointKey = 'google_sheet_sync_endpoint';
  static const _defaultGoogleSheetEndpoint =
      'https://script.google.com/macros/s/AKfycbwLQL774SgM2hEszgwZyn2SZ-17zofRdzOun5b3YYY8HqWWHtsfhEfCa3Fqj-4628MOBg/exec';

  Future<String> getGoogleSheetEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEndpoint = prefs.getString(_googleSheetEndpointKey)?.trim();
    final endpoint = savedEndpoint == null || savedEndpoint.isEmpty
        ? _defaultGoogleSheetEndpoint
        : savedEndpoint;

    if (!endpoint.endsWith('/exec')) {
      return '';
    }

    return endpoint;
  }

  Future<void> setGoogleSheetEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_googleSheetEndpointKey, endpoint.trim());
  }

  Future<bool> isGoogleSheetEndpointConfigured() async {
    return (await getGoogleSheetEndpoint()).isNotEmpty;
  }
}
