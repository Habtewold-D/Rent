import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:pdfx/pdfx.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../viewmodels/auth_view_model.dart';

class DocumentPreviewPage extends StatefulWidget {
  final String title;
  final String url;

  const DocumentPreviewPage({super.key, required this.title, required this.url});

  @override
  State<DocumentPreviewPage> createState() => _DocumentPreviewPageState();
}

class _DocumentPreviewPageState extends State<DocumentPreviewPage> {
  PdfControllerPinch? _pdfController;
  bool _loading = false;

  bool get _isPdf {
    final u = widget.url.toLowerCase();
    return u.endsWith('.pdf') || u.contains('?format=pdf');
  }

  @override
  void initState() {
    super.initState();
    if (_isPdf) {
      _loadPdf();
    }
  }

  Future<void> _loadPdf() async {
    setState(() => _loading = true);
    try {
      final token = context.read<AuthViewModel?>()?.token;
      final res = await http.get(
        Uri.parse(widget.url),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        _pdfController = PdfControllerPinch(
          document: PdfDocument.openData(res.bodyBytes),
        );
      } else {
        _error(context, 'Failed to load PDF (${res.statusCode})');
      }
    } catch (e) {
      _error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _isPdf
          ? (_loading || _pdfController == null)
              ? const Center(child: CircularProgressIndicator())
              : PdfViewPinch(
                  controller: _pdfController!,
                  onDocumentError: (e) => _error(context, e.toString()),
                )
          : Container(
              color: Colors.black,
              child: Center(
                child: PhotoView(
                  imageProvider: NetworkImage(widget.url),
                  loadingBuilder: (ctx, event) => const CircularProgressIndicator(),
                  errorBuilder: (ctx, err, _) => Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Failed to load image', style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
    );
  }

  void _error(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
