import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

Future<void> saveFile(Uint8List bytes, String fileName, String mimeType) async {
  try {
    // Create blob with proper MIME type
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
    
    // Create object URL
    final url = web.URL.createObjectURL(blob);
    
    // Create anchor element
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.style.display = 'none';
    
    // Append to body, click, and remove
    web.document.body?.appendChild(anchor);
    anchor.click();
    web.document.body?.removeChild(anchor);
    
    // Revoke the object URL to free memory
    web.URL.revokeObjectURL(url);
    
    debugPrint('✅ File saved on Web: $fileName');
  } catch (e) {
    debugPrint('❌ Error saving file: $e');
  }
}