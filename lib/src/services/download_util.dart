import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:itl/src/services/api_service.dart';

String _sanitizeUrl(String url) {
  var clean = url.replaceAll('\\', '');
  // Fix for file downloads: The API returns /superadmin/ URLs which are web-auth protected.
  // We need to switch to /api/ to use Bearer auth.
  if (clean.contains('/superadmin/') && clean.contains('/show/')) {
    clean = clean.replaceFirst('/superadmin/', '/api/');
  }
  return clean;
}

Future<String> _filenameFromUrl(String url) async {
  final clean = _sanitizeUrl(url);
  final name = clean.split('/').last.split('?').first;
  return name.isEmpty
      ? 'download_${DateTime.now().millisecondsSinceEpoch}'
      : name;
}

Future<String?> downloadToCache(String url, {String? fileName}) async {
  try {
    debugPrint('Checking cache for $url...');
    final dir = await getTemporaryDirectory();
    final name = fileName ?? await _filenameFromUrl(url);
    final filePath = '${dir.path}/$name';

    final file = File(filePath);

    if (await file.exists()) {
      // Check if file is likely valid (PDFs are usually > 1KB)
      // If it's small, it might be a 401/404 HTML response from previous failed attempts.
      final len = await file.length();
      if (len > 2048) {
        debugPrint('Cache hit: $filePath ($len bytes)');
        return filePath;
      } else {
        debugPrint(
            'Cache hit but file too small ($len bytes) - possibly corrupt. Deleting and re-downloading.');
        await file.delete();
      }
    }

    debugPrint('Downloading to $filePath...');

    // Get token
    final token = ApiService().token;
    final options = Options(
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: token != null ? {'Authorization': 'Bearer $token'} : null,
    );

    await Dio().download(
      _sanitizeUrl(url),
      filePath,
      options: options,
    );

    // Validate the downloaded file
    final downloadedFile = File(filePath);
    if (await downloadedFile.exists()) {
      final len = await downloadedFile.length();
      // 1. Size Check: HTML 404s are usually small (< 2KB)
      if (len < 100) {
        debugPrint('File too small ($len bytes). Likely error response.');
        await downloadedFile.delete();
        throw Exception('File too small (likely error page)');
      }

      // 2. Content Check: Read first few bytes for Magic Number
      // This prevents "Blank White Screen" from rendering HTML as PDF
      try {
        final openFile = await downloadedFile.open();
        final bytes = await openFile.read(5);
        await openFile.close();
        final header = String.fromCharCodes(bytes);
        debugPrint('File Header: $header');

        // Simple check: most error pages start with < or <! or {
        // Real PDFs start with %PDF-
        // We won't be too strict, but we can catch obvious HTML
        if (header.startsWith('<') ||
            header.startsWith('{') ||
            header.contains('HTML')) {
          debugPrint('File appears to be HTML/JSON, not a document. Deleting.');
          await downloadedFile.delete();
          throw Exception('Invalid file format (Server returned text/html)');
        }
      } catch (e) {
        debugPrint('Error validating file header: $e');
        // If we can't read it, proceed with caution or fail?
        // Let's allow it but log.
      }
    }

    debugPrint('Download complete: $filePath');
    return filePath;
  } catch (e) {
    debugPrint('Download error: $e');
    // If it was a 404, Dio usually throws DioException
    if (e is DioException) {
      if (e.response?.statusCode == 404) {
        // It's a 404
        return null;
      }
    }
    return null;
  }
}

Future<void> downloadAndOpen(String url) async {
  final path = await downloadToCache(url);
  if (path != null) {
    await OpenFilex.open(path);
  }
}

Future<void> shareFileFromUrl(String url, {String? text}) async {
  final path = await downloadToCache(url);
  if (path != null) {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: text,
      ),
    );
  }
}

Future<String> downloadFile(String url) async {
  String? savePath;
  final name = await _filenameFromUrl(url);

  if (Platform.isAndroid) {
    // Check permissions
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    // Fallback or explicit path
    // Note: On Android 11+ scoped storage usually allows writing to Downloads without dangerous permissions
    // if using MediaStore, but direct path writing might need MANAGE_EXTERNAL_STORAGE or just work for public dirs.
    // We'll try the standard legacy path first which works on most phones for this use case.
    savePath = '/storage/emulated/0/Download/$name';
  } else {
    final dir = await getApplicationDocumentsDirectory();
    savePath = '${dir.path}/$name';
  }

  debugPrint('downloadFile: Saving to $savePath');

  final token = ApiService().token;
  final options = Options(
      headers: token != null ? {'Authorization': 'Bearer $token'} : null);

  await Dio().download(_sanitizeUrl(url), savePath, options: options,
      onReceiveProgress: (rec, total) {
    if (total != -1) {
      debugPrint('Downloading: ${(rec / total * 100).toStringAsFixed(0)}%');
    }
  });

  return savePath;
}
