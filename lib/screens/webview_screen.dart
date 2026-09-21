import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Visor interno para las politicas, terminos y avisos de privacidad.
class WebViewScreen extends StatefulWidget {
  final String titulo;
  final String url;
  const WebViewScreen({super.key, required this.titulo, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) { if (mounted) setState(() => _cargando = true); },
        onPageFinished: (_) { if (mounted) setState(() => _cargando = false); },
        onWebResourceError: (_) { if (mounted) setState(() => _cargando = false); },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_cargando) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
