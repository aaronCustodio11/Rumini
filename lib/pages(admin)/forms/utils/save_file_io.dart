import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

Future<void> saveFile(Uint8List bytes, String fileName, String mimeType) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/$fileName';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('✅ Saved locally: $path');
}