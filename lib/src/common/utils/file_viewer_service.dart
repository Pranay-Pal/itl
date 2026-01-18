import 'package:flutter/material.dart';
import 'package:itl/src/services/download_util.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:itl/src/config/base_url.dart' as config;

class FileViewerService {
  const FileViewerService._();

  /// Handle file view based on extension or context
  /// [url] - The full or relative URL
  /// [title] - Title for PDF viewer
  static void viewFile(BuildContext context, String url,
      {String title = 'Document'}) async {
    if (url.isEmpty) {
      _showError(context, 'Invalid file URL');
      return;
    }

    // Fix relative URLs if needed (Legacy logic from Reports/Bookings)
    String fullUrl = url;
    if (!url.startsWith('http')) {
      // Using the host logic seen in Bookings/Reports
      final host = config.baseUrl;
      fullUrl = host.endsWith('/') ? "$host$url" : "$host/$url";

      // Handle double slashes if url started with /
      if (url.startsWith('/')) {
        fullUrl = host.endsWith('/') ? "$host${url.substring(1)}" : "$host$url";
      }
    }

    final ext = fullUrl.split('.').last.split('?').first.toLowerCase();

    _showLoader(context);
    try {
      if (ext == 'pdf') {
        await downloadAndOpen(fullUrl);
      } else if (['jpg', 'jpeg', 'png'].contains(ext)) {
        // For images, we could do an image viewer, but for now download/open
        await downloadAndOpen(fullUrl);
      } else {
        // Fallback for others
        await _launchUrl(context, fullUrl);
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Could not open file: $e');
      }
    } finally {
      if (context.mounted) {
        _hideLoader(context);
      }
    }
  }

  static Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch URL');
    }
  }

  static void _showLoader(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  static void _hideLoader(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  static void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
