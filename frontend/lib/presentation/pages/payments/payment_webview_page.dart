import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewPage extends StatefulWidget {
  final String checkoutUrl;
  final String? successUrlPrefix; // optional pattern to detect success
  final String? cancelUrlPrefix; // optional pattern to detect cancel

  const PaymentWebViewPage({
    super.key,
    required this.checkoutUrl,
    this.successUrlPrefix,
    this.cancelUrlPrefix,
  });

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          onNavigationRequest: (req) {
            final url = req.url;
            if (widget.successUrlPrefix != null && (url.startsWith(widget.successUrlPrefix!) || url.contains(widget.successUrlPrefix!))) {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            if (widget.cancelUrlPrefix != null && (url.startsWith(widget.cancelUrlPrefix!) || url.contains(widget.cancelUrlPrefix!))) {
              Navigator.of(context).pop(false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        actions: [
          if (_progress > 0 && _progress < 100)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
              child: Center(child: Text('$_progress%')),
            )
        ],
      ),
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }
}
