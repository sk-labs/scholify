import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scholify/core/constants/branding.dart';

void main() {
  testWidgets('Scholify brand renders in basic shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text(AppBranding.appName))),
    );

    expect(find.text(AppBranding.appName), findsOneWidget);
  });
}
