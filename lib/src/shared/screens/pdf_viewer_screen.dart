import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:itl/src/config/constants.dart';
import 'package:itl/src/services/download_util.dart';
import 'dart:io';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const PdfViewerScreen({super.key, required this.url, required this.title});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? localPath;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    debugPrint('PdfViewer: Loading URL: ${widget.url}');
    try {
      // Reuse downloadToCache helper if possible, or manual to ensure we have path for view
      final path = await downloadToCache(widget.url);
      debugPrint('PdfViewer: Downloaded to: $path');

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.length();
          debugPrint('PdfViewer: File size: $bytes bytes');
          if (bytes < 1000) {
            final content = await file.readAsString();
            debugPrint('PdfViewer: File content (sneak peek): $content');
          }
        }
      }

      if (mounted) {
        setState(() {
          localPath = path;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('PdfViewer Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final path = await downloadFile(widget.url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: kBlueGradient),
        ),
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download',
            onPressed: () => _downloadPdf(),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () => shareFileFromUrl(widget.url),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text('Error: $_errorMessage'));
    }
    if (localPath != null) {
      return PDFView(
        filePath: localPath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: false,
        onError: (error) {
          debugPrint(error.toString());
        },
        onPageError: (page, error) {
          debugPrint('$page: ${error.toString()}');
        },
      );
    }
    return const Center(child: Text('Failed to load PDF'));
  }
}
