import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanResult {
  final File? file;
  final String? error;
  const ScanResult.found(File f)
      : file = f,
        error = null;
  const ScanResult.notFound(String msg)
      : file = null,
        error = msg;
  bool get success => file != null;
}

/// Scans the Downloads folder for the latest PhonePe statement (PDF first,
/// CSV/text as fallback). Designed so the user never has to manually browse
/// for the file on repeat syncs:
///
///   1. Try the remembered folder first (fastest, no permission dialogs).
///   2. Try direct filesystem access to /storage/emulated/0/Download.
///   3. Last resort: ask the user to pick the file ONCE, then remember the
///      parent folder for all future syncs.
class DownloadsScannerService {
  static const _prefKey = 'phonepe_folder_path';

  static final _keywords = [
    'phonepe',
    'phone_pe',
    'phone-pe',
    'statement',
    'transaction',
    'transactions',
    'history'
  ];
  static final _exts = {'.pdf', '.csv', '.txt'};

  // ── Public API ────────────────────────────────────────────────────────────

  static Future<ScanResult> findLatestStatement({
    required Future<bool> Function() onNeedFolderPick,
  }) async {
    debugPrint('[DownloadsScanner] ===== Downloads scan started =====');

    // 1. Try remembered folder first
    debugPrint('[DownloadsScanner] Checking remembered folder...');
    final remembered = await _tryRemembered();
    if (remembered.success) {
      debugPrint('[DownloadsScanner] Found via remembered folder.');
      return remembered;
    }

    // 2. Try direct OS-level access to the default Downloads path
    debugPrint(
        '[DownloadsScanner] Remembered folder unavailable. Trying direct Downloads access...');
    final direct = await _tryDirect();
    if (direct.success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, '/storage/emulated/0/Download');
      debugPrint(
          '[DownloadsScanner] Found via direct access. Remembered path for next time.');
      return direct;
    }

    // 3. Last resort: ask the user to pick the folder/file ONCE.
    debugPrint('[DownloadsScanner] Direct access failed: ${direct.error}');
    debugPrint(
        '[DownloadsScanner] Falling back to manual one-time file picker...');
    final go = await onNeedFolderPick();
    if (!go) {
      debugPrint('[DownloadsScanner] User cancelled folder picker dialog.');
      return const ScanResult.notFound('Cancelled by user.');
    }
    return _pickAndRemember();
  }

  static Future<void> forgetSavedFolder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    debugPrint('[DownloadsScanner] Saved folder forgotten.');
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static Future<ScanResult> _tryDirect() async {
    PermissionStatus status = await Permission.storage.status;
    debugPrint('[DownloadsScanner] Permission.storage status: $status');
    if (!status.isGranted) {
      status = await Permission.storage.request();
      debugPrint(
          '[DownloadsScanner] Permission.storage requested, result: $status');
    }
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.status;
      debugPrint(
          '[DownloadsScanner] Permission.manageExternalStorage status: $status');
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        debugPrint(
            '[DownloadsScanner] Permission.manageExternalStorage requested, result: $status');
      }
    }
    if (!status.isGranted) {
      debugPrint('[DownloadsScanner] Storage permission NOT granted.');
      return const ScanResult.notFound('Storage permission denied.');
    }

    final dir = Directory('/storage/emulated/0/Download');
    debugPrint(
        '[DownloadsScanner] Checking default Downloads path: ${dir.path}');
    if (!await dir.exists()) {
      debugPrint(
          '[DownloadsScanner] Default Downloads folder does NOT exist at ${dir.path}');
      return const ScanResult.notFound('Default Downloads folder not found.');
    }
    return _scanDir(dir);
  }

  static Future<ScanResult> _tryRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefKey);
    if (path == null) {
      debugPrint('[DownloadsScanner] No remembered folder path saved.');
      return const ScanResult.notFound('No saved folder.');
    }
    debugPrint('[DownloadsScanner] Remembered folder path: $path');

    final dir = Directory(path);
    if (!await dir.exists()) {
      debugPrint(
          '[DownloadsScanner] Remembered folder no longer exists. Clearing it.');
      await prefs.remove(_prefKey);
      return const ScanResult.notFound('Saved folder no longer exists.');
    }
    return _scanDir(dir);
  }

  static Future<ScanResult> _pickAndRemember() async {
    debugPrint(
        '[DownloadsScanner] Opening file picker for manual selection...');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'csv', 'txt'],
      dialogTitle: 'Select your PhonePe statement (one-time setup)',
    );
    if (result == null || result.files.isEmpty) {
      debugPrint('[DownloadsScanner] User did not select any file.');
      return const ScanResult.notFound('No file selected.');
    }
    final path = result.files.single.path;
    if (path == null) {
      debugPrint('[DownloadsScanner] Selected file has no accessible path.');
      return const ScanResult.notFound('Cannot access selected file.');
    }

    debugPrint('[DownloadsScanner] User selected file: $path');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, File(path).parent.path);
    debugPrint('[DownloadsScanner] Remembered parent folder: ${File(path).parent.path}');

    return ScanResult.found(File(path));
  }

  static ScanResult _scanDir(Directory dir) {
    try {
      debugPrint('[DownloadsScanner] Scanning directory: ${dir.path}');
      final allFiles =
          dir.listSync(followLinks: false).whereType<File>().toList();

      debugPrint(
          '[DownloadsScanner] Total files found in folder: ${allFiles.length}');
      for (final f in allFiles) {
        debugPrint('[DownloadsScanner]   - ${f.path.split('/').last}');
      }

      final matches = allFiles.where((f) {
        final name = f.path.split('/').last.toLowerCase();
        final ext = '.${name.split('.').last}';
        return _exts.contains(ext) && _keywords.any((k) => name.contains(k));
      }).toList()
        ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      debugPrint(
          '[DownloadsScanner] Candidate PhonePe files (name+extension matched): ${matches.length}');
      for (final f in matches) {
        debugPrint(
            '[DownloadsScanner]   candidate -> ${f.path} (modified: ${f.statSync().modified})');
      }

      if (matches.isEmpty) {
        debugPrint(
            '[DownloadsScanner] NO MATCHING PHONEPE FILE FOUND in ${dir.path}');
        return const ScanResult.notFound(
          'No PhonePe statement found in Downloads. Please download the latest PhonePe statement and try again.',
        );
      }

      // Prefer PDF over CSV/TXT if both exist among the newest matches
      final pdfMatches = matches.where((f) => f.path.toLowerCase().endsWith('.pdf')).toList();
      final selected = pdfMatches.isNotEmpty ? pdfMatches.first : matches.first;

      debugPrint(
          '[DownloadsScanner] Selected latest statement file: ${selected.path}');
      return ScanResult.found(selected);
    } catch (e) {
      debugPrint('[DownloadsScanner] Error scanning folder: $e');
      return ScanResult.notFound('Error reading folder: $e');
    }
  }
}
