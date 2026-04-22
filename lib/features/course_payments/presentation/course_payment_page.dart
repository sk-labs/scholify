import 'package:flutter/material.dart';

import '../../../app/app_runtime.dart';
import '../../../core/constants/branding.dart';
import 'payment_webview_page.dart';

class CoursePaymentPage extends StatefulWidget {
  const CoursePaymentPage({super.key, required this.course});

  final Map<String, dynamic> course;

  @override
  State<CoursePaymentPage> createState() => _CoursePaymentPageState();
}

class _CoursePaymentPageState extends State<CoursePaymentPage> {
  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final courseName = course['course_name']?.toString() ?? 'Course';
    final instructor = course['teacher_name']?.toString() ?? '';
    final finalPrice = _resolvePrice(course);
    final gatewayFee = _resolveGatewayFee(course);
    final totalAmount = finalPrice + gatewayFee;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Course Payment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CourseHeader(course: course),
                    const SizedBox(height: 20),
                    Text(
                      courseName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (instructor.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Instructor: $instructor',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _AmountTile(
                      label: 'Course amount',
                      value: finalPrice.toStringAsFixed(2),
                    ),
                    const SizedBox(height: 12),
                    _AmountTile(
                      label: 'Gateway fee',
                      value: gatewayFee.toStringAsFixed(2),
                    ),
                    const SizedBox(height: 12),
                    _AmountTile(
                      label: 'Total payable',
                      value: totalAmount.toStringAsFixed(2),
                      emphasized: true,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _startPayment(
                          context: context,
                          amount: finalPrice,
                        ),
                        icon: const Icon(Icons.payment),
                        label: const Text('Continue to payment'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _resolvePrice(Map<String, dynamic> course) {
    final candidates = [
      course['discounted_price'],
      course['final_amount'],
      course['final_price'],
      course['course_amount'],
      course['price'],
      course['original_price'],
    ];
    for (final candidate in candidates) {
      final amount = _parseAmount(candidate);
      if (amount > 0) return amount;
    }
    return 0;
  }

  double _resolveGatewayFee(Map<String, dynamic> course) {
    final candidates = [
      course['processing_fee'],
      course['processing_fees'],
      course['gateway_charge'],
      course['gateway_processing_charge'],
    ];
    for (final candidate in candidates) {
      final amount = _parseAmount(candidate);
      if (amount > 0) return amount;
    }
    return 18.0;
  }

  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    final str = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(str) ?? 0.0;
  }

  Future<void> _startPayment({
    required BuildContext context,
    required double amount,
  }) async {
    final tenantContext = AppRuntime.tenantContext;
    final studentId = tenantContext?.tenantId ?? '';
    if (studentId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student account is not available.')),
      );
      return;
    }

    final courseId =
        widget.course['id']?.toString() ??
        widget.course['course_id']?.toString() ??
        widget.course['courseId']?.toString() ??
        '';
    if (courseId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course ID missing. Unable to open payment.'),
        ),
      );
      return;
    }

    final baseUrl = AppBranding.defaultPocketBaseUrl;
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final amountStr = amount.toStringAsFixed(2);
    final paymentUrl =
        '$cleanBaseUrl/api/course_payment/course_payment/payment/$courseId/$studentId?amount=$amountStr&total=$amountStr';
    final encodedUrl = Uri.encodeFull(paymentUrl);

    if (!mounted) return;
    final navigator = Navigator.of(context);
    final result = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (context) => PaymentWebViewPage(
          url: encodedUrl,
          title: 'Course Payment',
          amount: amount,
        ),
      ),
    );

    if (result == true && mounted) {
      navigator.pop(true);
    }
  }
}

class _CourseHeader extends StatelessWidget {
  const _CourseHeader({required this.course});

  final Map<String, dynamic> course;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = course['course_thumbnail']?.toString() ?? '';
    if (thumbnailUrl.isNotEmpty && thumbnailUrl != 'null') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          thumbnailUrl,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackHeader(),
        ),
      );
    }
    return _fallbackHeader();
  }

  Widget _fallbackHeader() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.school, size: 72, color: Colors.white),
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? Colors.grey.shade900 : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: emphasized ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: color,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
