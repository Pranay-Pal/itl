import 'package:flutter/material.dart';
import 'package:itl/src/services/download_util.dart';
import 'package:itl/src/shared/screens/pdf_viewer_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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
      // Ideally this base URL should be in a global constant, but using the specific one found in code
      fullUrl =
          "https://mediumslateblue-hummingbird-258203.hostingersite.com/$url";
      // Handle double slashes if url started with /
      if (url.startsWith('/')) {
        fullUrl =
            "https://mediumslateblue-hummingbird-258203.hostingersite.com$url";
      }
    }

    final ext = fullUrl.split('.').last.split('?').first.toLowerCase();

    if (ext == 'pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: fullUrl,
            title: title,
          ),
        ),
      );
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
