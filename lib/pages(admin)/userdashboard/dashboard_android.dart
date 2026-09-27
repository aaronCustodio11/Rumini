import 'dart:typed_data';

import 'package:flutter/material.dart';

Future<void> downloadCsvWeb(String csv, String filename) async {
  throw UnsupportedError('downloadCsvWeb is only available on the web');
}

void pickCsvWebFlow({
  required BuildContext context,
  required Map<String, dynamic> userData,
  required Future<void> Function(String, Map<String, dynamic>) onCsv,
}) {
  throw UnsupportedError('pickCsvWebFlow is only available on the web');
}

void pickImageWeb({required void Function(Uint8List) onBytes}) {
  throw UnsupportedError('pickImageWeb is only available on the web');
}
