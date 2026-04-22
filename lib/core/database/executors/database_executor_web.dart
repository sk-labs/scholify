import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor createDatabaseExecutor() {
  return WebDatabase('scholify_offline');
}
