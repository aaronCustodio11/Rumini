import 'dart:typed_data';
import 'dart:convert';
import 'package:rumini/pages(admin)/forms/utils/file_saver_stub.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:archive/archive.dart';

class AnalyticsExporter {
  static Future<void> exportFormAnalytics({
    required String? formId,
    required String format, // 'pdf' or 'docx'
  }) async {
    if (formId == null || formId.isEmpty) {
      debugPrint('⚠️ No formId provided for export.');
      return;
    }

    if (format.toLowerCase() == 'pdf') {
      await _exportAsPDF(formId);
    } else if (format.toLowerCase() == 'docx') {
      await _exportAsDOCX(formId);
    } else {
      debugPrint('⚠️ Unsupported format: $format');
    }
  }

  // ==================== PDF EXPORT ====================
  static Future<void> _exportAsPDF(String formId) async {
    try {
      // 🔹 Fetch form details
      final formSnapshot = await FirebaseFirestore.instance
          .collection('forms')
          .doc(formId)
          .get();

      final formTitle = formSnapshot.data()?['title'] ?? 'Untitled Form';
      final formDescription =
          formSnapshot.data()?['description'] ?? 'No description provided';

      // 🔹 Fetch ordered questions
      final questionsSnapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('formId', isEqualTo: formId)
          .orderBy('order')
          .get();

      // 🔹 Fetch answers
      final answersSnapshot = await FirebaseFirestore.instance
          .collection('answer_form')
          .where('formId', isEqualTo: formId)
          .get();

      final pdf = pw.Document();

      // ✅ Load fonts
      final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
      final ttf = pw.Font.ttf(fontData);

      pw.Font? ttfBold;
      try {
        final boldFontData = await rootBundle.load(
          "assets/fonts/Roboto-Bold.ttf",
        );
        ttfBold = pw.Font.ttf(boldFontData);
      } catch (_) {
        ttfBold = ttf;
      }

      // ✅ Helper: Bar Chart (for checkboxes)
      pw.Widget buildBarChart(Map<String, int> responseCounts) {
        if (responseCounts.isEmpty) {
          return pw.Text("No responses yet.", style: pw.TextStyle(font: ttf));
        }

        final maxCount = responseCounts.values.reduce((a, b) => a > b ? a : b);
        const chartWidth = 250.0;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Bar Chart Summary',
              style: pw.TextStyle(
                font: ttfBold,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            ...responseCounts.entries.map((entry) {
              final barWidth = (entry.value / maxCount) * chartWidth;
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(
                      width: 100,
                      child: pw.Text(entry.key, style: pw.TextStyle(font: ttf)),
                    ),
                    pw.Container(
                      width: barWidth,
                      height: 14,
                      color: PdfColors.blue,
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      entry.value.toString(),
                      style: pw.TextStyle(font: ttf),
                    ),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 12),
          ],
        );
      }

      // ✅ Helper: Pie Chart (for multiple choice / dropdown)
      pw.Widget buildPieChart(Map<String, int> responseCounts) {
        if (responseCounts.isEmpty) {
          return pw.Text(
            "No data available for pie chart.",
            style: pw.TextStyle(font: ttf),
          );
        }

        final total = responseCounts.values.fold<int>(0, (a, b) => a + b);
        final colors = [
          PdfColors.blue,
          PdfColors.red,
          PdfColors.green,
          PdfColors.orange,
          PdfColors.purple,
          PdfColors.cyan,
          PdfColors.amber,
          PdfColors.pink,
        ];

        int colorIndex = 0;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Pie Chart Summary',
              style: pw.TextStyle(
                font: ttfBold,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            ...responseCounts.entries.map((entry) {
              final color = colors[colorIndex++ % colors.length];
              final percent = ((entry.value / total) * 100).toStringAsFixed(1);
              return pw.Row(
                children: [
                  pw.Container(width: 14, height: 14, color: color),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    "${entry.key} - $percent%",
                    style: pw.TextStyle(font: ttf),
                  ),
                ],
              );
            }),
            pw.SizedBox(height: 12),
          ],
        );
      }

      // ✅ Build question widgets
      final questionWidgets = <pw.Widget>[];

      for (var qDoc in questionsSnapshot.docs) {
        final question = qDoc['question'] ?? '';
        final questionType = qDoc['questionType'] ?? '';
        final questionId = qDoc['questionId'] ?? '';
        final responses = <String>[];

        // 🔹 Collect responses
        for (var aDoc in answersSnapshot.docs) {
          final data = aDoc.data() as Map<String, dynamic>;
          final entries =
              data.entries.where((e) => e.key.startsWith('question')).toList()
                ..sort((a, b) {
                  final aNum =
                      int.tryParse(a.key.replaceAll('question', '')) ?? 0;
                  final bNum =
                      int.tryParse(b.key.replaceAll('question', '')) ?? 0;
                  return aNum.compareTo(bNum);
                });

          for (var entry in entries) {
            final index = entry.key.replaceAll('question', '');
            final answerKey = 'answer$index';
            if (data[entry.key] == questionId && data.containsKey(answerKey)) {
              final ans = data[answerKey];
              if (ans is List) {
                responses.addAll(
                  ans.map((e) {
                    if (e is Timestamp) {
                      final date = e.toDate();
                      return DateFormat('MMMM dd, yyyy • hh:mm a').format(date);
                    }
                    return e.toString();
                  }),
                );
              } else if (ans is Timestamp) {
                final date = ans.toDate();
                responses.add(
                  DateFormat('MMMM dd, yyyy • hh:mm a').format(date),
                );
              } else {
                responses.add(ans.toString());
              }
            }
          }
        }

        // 🔹 Count totals and build graph logic
        final Map<String, int> responseCounts = {};
        for (var r in responses) {
          responseCounts[r] = (responseCounts[r] ?? 0) + 1;
        }

        final totalResponses = responses.length;

        pw.Widget? graphWidget;
        if (questionType == 'Multiple Choice' || questionType == 'Dropdown') {
          graphWidget = buildPieChart(responseCounts);
        } else if (questionType == 'Checkboxes') {
          graphWidget = buildBarChart(responseCounts);
        }

        // 🔹 Add question section
        questionWidgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  question,
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  "Type: $questionType",
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 11,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  "Total Responses: $totalResponses",
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 11,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 8),

                // 🔹 Conditional output
                if (graphWidget != null)
                  graphWidget
                else if (responses.isEmpty)
                  pw.Text("No responses yet.", style: pw.TextStyle(font: ttf))
                else
                  ...responses.map(
                    (r) => pw.Bullet(
                      text: r,
                      style: pw.TextStyle(font: ttf, fontSize: 12),
                    ),
                  ),

                pw.Divider(thickness: 0.3, color: PdfColors.grey400),
              ],
            ),
          ),
        );
      }

      // ✅ Build final layout
      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Center(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    formTitle,
                    style: pw.TextStyle(
                      font: ttfBold,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    formDescription,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    "Generated on ${DateFormat('MMMM dd, yyyy • hh:mm a').format(DateTime.now())}",
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 10,
                      color: PdfColors.grey600,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 1, color: PdfColors.grey600),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            ...questionWidgets,
          ],
        ),
      );

      // ✅ Save PDF
      final fileName =
          "Form_Analytics_Report_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final pdfBytes = await pdf.save();

      await saveFile(pdfBytes, fileName, 'application/pdf');
      debugPrint("✅ PDF exported successfully");

    } catch (e, stack) {
      debugPrint("❌ Error exporting PDF: $e\n$stack");
    }
  }

  // ==================== DOCX EXPORT ====================
  static Future<void> _exportAsDOCX(String formId) async {
    try {
      // 🔹 Fetch form details
      final formSnapshot = await FirebaseFirestore.instance
          .collection('forms')
          .doc(formId)
          .get();

      final formTitle = formSnapshot.data()?['title'] ?? 'Untitled Form';
      final formDescription =
          formSnapshot.data()?['description'] ?? 'No description provided';

      // 🔹 Fetch ordered questions
      final questionsSnapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('formId', isEqualTo: formId)
          .orderBy('order')
          .get();

      // 🔹 Fetch answers
      final answersSnapshot = await FirebaseFirestore.instance
          .collection('answer_form')
          .where('formId', isEqualTo: formId)
          .get();

      // ✅ Build content for DOCX
      StringBuffer docContent = StringBuffer();
      
      // Header
      docContent.writeln('═══════════════════════════════════════════════════════');
      docContent.writeln(formTitle.toUpperCase());
      docContent.writeln('═══════════════════════════════════════════════════════');
      docContent.writeln();
      docContent.writeln(formDescription);
      docContent.writeln();
      docContent.writeln('Generated on ${DateFormat('MMMM dd, yyyy • hh:mm a').format(DateTime.now())}');
      docContent.writeln();
      docContent.writeln('───────────────────────────────────────────────────────');
      docContent.writeln();
      
      int questionNumber = 1;
      
      for (var qDoc in questionsSnapshot.docs) {
        final question = qDoc['question'] ?? '';
        final questionType = qDoc['questionType'] ?? '';
        final questionId = qDoc['questionId'] ?? '';
        final responses = <String>[];

        // 🔹 Collect responses
        for (var aDoc in answersSnapshot.docs) {
          final data = aDoc.data() as Map<String, dynamic>;
          final entries =
              data.entries.where((e) => e.key.startsWith('question')).toList()
                ..sort((a, b) {
                  final aNum =
                      int.tryParse(a.key.replaceAll('question', '')) ?? 0;
                  final bNum =
                      int.tryParse(b.key.replaceAll('question', '')) ?? 0;
                  return aNum.compareTo(bNum);
                });

          for (var entry in entries) {
            final index = entry.key.replaceAll('question', '');
            final answerKey = 'answer$index';
            if (data[entry.key] == questionId && data.containsKey(answerKey)) {
              final ans = data[answerKey];
              if (ans is List) {
                responses.addAll(
                  ans.map((e) {
                    if (e is Timestamp) {
                      final date = e.toDate();
                      return DateFormat('MMMM dd, yyyy • hh:mm a').format(date);
                    }
                    return e.toString();
                  }),
                );
              } else if (ans is Timestamp) {
                final date = ans.toDate();
                responses.add(
                  DateFormat('MMMM dd, yyyy • hh:mm a').format(date),
                );
              } else {
                responses.add(ans.toString());
              }
            }
          }
        }

        // 🔹 Count responses
        final Map<String, int> responseCounts = {};
        for (var r in responses) {
          responseCounts[r] = (responseCounts[r] ?? 0) + 1;
        }

        final totalResponses = responses.length;
        final total = responseCounts.values.fold<int>(0, (a, b) => a + b);

        // Add question to document
        docContent.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        docContent.writeln('QUESTION $questionNumber');
        docContent.writeln(question);
        docContent.writeln();
        docContent.writeln('Type: $questionType');
        docContent.writeln('Total Responses: $totalResponses');
        docContent.writeln();

        // 🔹 Add visual indicators and summaries based on question type
        if (questionType == 'Multiple Choice' || questionType == 'Dropdown') {
          // PIE CHART INDICATOR
          docContent.writeln('📊 PIE CHART SUMMARY');
          docContent.writeln('─────────────────────────────────────────────────────');
          docContent.writeln();
          
          if (responseCounts.isEmpty) {
            docContent.writeln('  No responses yet.');
          } else {
            responseCounts.forEach((option, count) {
              final percent = total > 0 ? ((count / total) * 100).toStringAsFixed(1) : '0.0';
              final barLength = (percent.isNotEmpty) ? (double.parse(percent) / 5).round() : 0;
              final visualBar = '█' * barLength;
              
              docContent.writeln('  🔵 $option');
              docContent.writeln('     $visualBar $percent% ($count responses)');
              docContent.writeln();
            });
          }
        } else if (questionType == 'Checkboxes') {
          // BAR CHART INDICATOR
          docContent.writeln('📊 BAR CHART SUMMARY');
          docContent.writeln('─────────────────────────────────────────────────────');
          docContent.writeln();
          
          if (responseCounts.isEmpty) {
            docContent.writeln('  No responses yet.');
          } else {
            final maxCount = responseCounts.values.reduce((a, b) => a > b ? a : b);
            
            responseCounts.forEach((option, count) {
              final barLength = maxCount > 0 ? ((count / maxCount) * 20).round() : 0;
              final visualBar = '▓' * barLength;
              
              docContent.writeln('  $option');
              docContent.writeln('  $visualBar $count');
              docContent.writeln();
            });
          }
        } else {
          // TEXT RESPONSES
          if (responses.isEmpty) {
            docContent.writeln('📝 No responses yet.');
          } else {
            docContent.writeln('📝 INDIVIDUAL RESPONSES');
            docContent.writeln('─────────────────────────────────────────────────────');
            docContent.writeln();
            for (var i = 0; i < responses.length; i++) {
              docContent.writeln('  ${i + 1}. ${responses[i]}');
            }
          }
        }
        
        docContent.writeln();
        docContent.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        docContent.writeln();
        
        questionNumber++;
      }

      // ✅ Create DOCX
      final docBytes = _createSimpleDOCX(docContent.toString());

      // ✅ Save DOCX
      final fileName =
          "Form_Analytics_Report_${DateTime.now().millisecondsSinceEpoch}.docx";

      await saveFile(docBytes, fileName,
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      debugPrint("✅ DOCX exported successfully");

    } catch (e, stack) {
      debugPrint("❌ Error exporting DOCX: $e\n$stack");
    }
  }

  // Helper method to create a simple DOCX file structure
  static Uint8List _createSimpleDOCX(String content) {
    // Basic DOCX XML structure with proper namespaces
    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" 
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
${_convertTextToParagraphs(content)}
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
    </w:sectPr>
  </w:body>
</w:document>''';

    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

    final relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    final wordRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';

    // Create ZIP archive (DOCX is a ZIP file)
    final archive = Archive();
    
    // Convert strings to UTF-8 bytes
    final contentTypesBytes = Uint8List.fromList(utf8.encode(contentTypesXml));
    final relsBytes = Uint8List.fromList(utf8.encode(relsXml));
    final documentBytes = Uint8List.fromList(utf8.encode(documentXml));
    final wordRelsBytes = Uint8List.fromList(utf8.encode(wordRelsXml));
    
    // Create archive files with proper structure
    // FIX: Use InputStream.bytes() instead of passing raw bytes
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesBytes.length, InputStream(contentTypesBytes)));
    archive.addFile(ArchiveFile('_rels/.rels', relsBytes.length, InputStream(relsBytes)));
    archive.addFile(ArchiveFile('word/document.xml', documentBytes.length, InputStream(documentBytes)));
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', wordRelsBytes.length, InputStream(wordRelsBytes)));
    
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    
    return Uint8List.fromList(zipData!);
  }

  // Convert plain text to Word XML paragraphs
  static String _convertTextToParagraphs(String text) {
    final lines = text.split('\n');
    final buffer = StringBuffer();
    
    for (var line in lines) {
      final escapedLine = _escapeXml(line);
      buffer.writeln('    <w:p>');
      buffer.writeln('      <w:r>');
      buffer.writeln('        <w:t xml:space="preserve">$escapedLine</w:t>');
      buffer.writeln('      </w:r>');
      buffer.writeln('    </w:p>');
    }
    
    return buffer.toString();
  }

  // Escape special XML characters
  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}