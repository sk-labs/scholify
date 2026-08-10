/// Conditional export for CSV file delivery.
///
/// Web imports the `dart:html`-based implementation; all other targets use the
/// stub (desktop saves directly, mobile writes via path_provider).
library;

export 'csv_download_stub.dart'
    if (dart.library.html) 'csv_download_web.dart';