import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor createDatabaseExecutor() {
  return LazyDatabase(() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final databaseFile = File(p.join(supportDirectory.path, 'scholify.sqlite'));
    return NativeDatabase.createInBackground(databaseFile);
  });
}
