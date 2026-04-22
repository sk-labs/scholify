import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'payment_success_page.dart';

class PaymentWebViewPage extends StatefulWidget {
  const PaymentWebViewPage({
    super.key,
    required this.url,
    this.title = 'Payment Gateway',
    this.amount,
  });

  final String url;
  final String title;
  final double? amount;

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
            if (_isSuccessUrl(url)) {
              _navigateToSuccess(url);
            }
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            if (_isSuccessUrl(url)) {
              _navigateToSuccess(url);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_isSuccessUrl(request.url)) {
              _navigateToSuccess(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  bool _isSuccessUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('success') ||
        lowerUrl.contains('callback') ||
        lowerUrl.contains('complete') ||
        lowerUrl.contains('thanks') ||
        lowerUrl.contains('thank_you') ||
        lowerUrl.contains('payment_success') ||
        lowerUrl.contains('gateway/success');
  }

  void _navigateToSuccess(String url) {
    if (!mounted) return;

    double? amount = widget.amount;
    String? reference;

    try {
      final uri = Uri.parse(url);
      amount ??= double.tryParse(uri.queryParameters['amount'] ?? uri.queryParameters['total'] ?? '');
      reference =
          uri.queryParameters['reference'] ??
          uri.queryParameters['transaction_id'] ??
          uri.queryParameters['order_id'];
    } catch (_) {}

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PaymentSuccessPage(
          amount: amount,
          reference: reference,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}