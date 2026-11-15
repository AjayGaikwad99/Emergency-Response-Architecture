import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';

class CallUtils {
  static Future<void> callUser(BuildContext context, String phoneNumber) async {
    final String normalized = _normalizeNumber(phoneNumber);
    if (normalized.isEmpty) {
      _showError(context, 'Invalid phone number');
      return;
    }

    final Uri telUri = Uri(scheme: 'tel', path: normalized);

    try {
      if (await canLaunchUrl(telUri)) {
        final ok = await launchUrl(
          telUri,
          mode: LaunchMode.externalApplication,
        );
        if (ok) return;
      }
    } catch (_) {}

    if (Platform.isAndroid) {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.DIAL',
          data: 'tel:$normalized',
        );
        await intent.launch();
        return;
      } catch (e) {
        _showError(context, 'Failed to open dialer: $e');
        return;
      }
    }

    _showError(context, 'Could not launch dialer for $normalized');
  }

  static String _normalizeNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final buf = StringBuffer();
    for (final ch in trimmed.runes) {
      final c = String.fromCharCode(ch);
      final isDigit = c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
      final isPlusAllowed = c == '+' && buf.isEmpty;
      if (isDigit || isPlusAllowed) buf.write(c);
    }
    return buf.toString();
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
