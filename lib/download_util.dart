import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

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
    final dir = await getTemporaryDirectory();
    final name = fileName ?? await _filenameFromUrl(url);
    final filePath = '${dir.path}/$name';
    await Dio().download(_sanitizeUrl(url), filePath);
    return filePath;
  } catch (_) {
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

Future<void> downloadFile(String url) async {
  final dir = await getApplicationDocumentsDirectory();
  final name = await _filenameFromUrl(url);
  final filePath = '${dir.path}/$name';
  await Dio().download(_sanitizeUrl(url), filePath);
}
