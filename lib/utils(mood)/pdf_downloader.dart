import 'dart:typed_data';

import 'pdf_downloader_web.dart'
    if (dart.library.io) 'pdf_downloader_android.dart';

abstract class PdfDownloader {
  static Future<void> download(Uint8List pdfBytes) =>
      downloadPdf(pdfBytes);
}
