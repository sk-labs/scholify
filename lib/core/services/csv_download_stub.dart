/// Non-web implementation of CSV delivery.
///
/// Desktop/mobile targets write the file to a local directory via path_provider.
/// Returns the path where the file was written, or null if no filesystem access.
library;

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> saveCsvBytes(String csvContent, String filename) async {
  try {
    final dir =
        await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$filename');
    await file.writeAsString(csvContent, encoding: utf8, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}