/// Web implementation of CSV delivery using a browser download.
library;

import 'dart:html' as html;

Future<String?> saveCsvBytes(String csvContent, String filename) async {
  final blob = html.Blob([
    csvContent,
  ], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return filename;
}