import 'package:shared_preferences/shared_preferences.dart';

class SyncSettingsService {
  static const _googleSheetEndpointKey = 'google_sheet_sync_endpoint';

  Future<String> getGoogleSheetEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_googleSheetEndpointKey)?.trim() ?? '';
  }

  Future<void> setGoogleSheetEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_googleSheetEndpointKey, endpoint.trim());
  }

  Future<bool> isGoogleSheetEndpointConfigured() async {
    return (await getGoogleSheetEndpoint()).isNotEmpty;
  }
}
