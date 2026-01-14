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
      {String title = 'Document'}) {
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

    if (ext == 'pdf') {
      downloadAndOpen(fullUrl);
    } else if (['jpg', 'jpeg', 'png'].contains(ext)) {
      // For images, we could do an image viewer, but for now download/open
      downloadAndOpen(fullUrl);
    } else {
      // Fallback for others
      _launchUrl(context, fullUrl);
    }
  }

  static Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      _showError(context, 'Could not launch URL');
    }
  }

  static void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
