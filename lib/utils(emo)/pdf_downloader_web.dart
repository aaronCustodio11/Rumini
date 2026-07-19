import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

Future<void> downloadPdf(Uint8List pdfBytes) async {
  final jsArray = pdfBytes.toJS;
  final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: 'application/pdf'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = 'emotion_logs.pdf'
    ..click();
  web.URL.revokeObjectURL(url);
}