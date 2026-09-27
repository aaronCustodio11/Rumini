import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> downloadPdf(Uint8List pdfBytes) async {
  try {
    var status = await Permission.storage.request();

    if (status.isGranted) {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }

      // 🕒 Generate readable timestamp
      final now = DateTime.now();
      final formatted = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
      final fileName = 'emotion_logs_$formatted.pdf';

      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      print("✅ PDF saved at: ${file.path}");
    } else {
      print("❌ Storage permission denied");
    }
  } catch (e) {
    print("❌ Error saving PDF: $e");
  }
}
