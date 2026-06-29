class SmsParser {
  static Map<String, dynamic>? parse(String sms) {
    final debitPatterns = [
      RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:debited|deducted|paid|sent)', caseSensitive: false),
      RegExp(r'debited[^₹\d]*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    ];
    final creditPatterns = [
      RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:credited|received|added)', caseSensitive: false),
      RegExp(r'credited[^₹\d]*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    ];
    for (final pat in debitPatterns) {
      final m = pat.firstMatch(sms);
      if (m != null) {
        final amount = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (amount != null) return {'amount': amount, 'merchant': _extractMerchant(sms), 'type': 'expense'};
      }
    }
    for (final pat in creditPatterns) {
      final m = pat.firstMatch(sms);
      if (m != null) {
        final amount = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (amount != null) return {'amount': amount, 'merchant': _extractMerchant(sms), 'type': 'income'};
      }
    }
    return null;
  }

  static String _extractMerchant(String sms) {
    final patterns = [
      RegExp(r'\bto\s+([A-Za-z0-9 &._-]{2,30}?)(?:\s+on|\s+ref|\s+upi|\s+vpa|\.|$)', caseSensitive: false),
      RegExp(r'\bfrom\s+([A-Za-z0-9 &._-]{2,30}?)(?:\s+on|\s+ref|\s+upi|\s+vpa|\.|$)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(sms);
      if (m != null) return m.group(1)!.trim();
    }
    return 'UPI Transaction';
  }
}
