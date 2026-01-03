import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:itl/src/services/api_service.dart';

String _sanitizeUrl(String url) => url.replaceAll('\\', '');

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
    debugPrint('Download complete: $filePath');
    return filePath;
  } catch (e) {
    debugPrint('Download error: $e');
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
