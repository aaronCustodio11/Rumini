import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Future<void> downloadCsvWeb(String csv, String filename) async {
  final bytes = utf8.encode(csv);
  final jsArray = bytes.toJS;
  final blob = web.Blob([jsArray].toJS);
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..click();
  web.URL.revokeObjectURL(url);
}

void pickCsvWebFlow({
  required BuildContext context,
  required Map<String, dynamic> userData,
  required Future<void> Function(String, Map<String, dynamic>) onCsv,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Selecting File..."),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Please select a CSV file"),
          ],
        ),
      );
    },
  );

  final uploadInput = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.csv';
  uploadInput.click();

  uploadInput.addEventListener(
    'change',
    ((web.Event event) {
      // Close the loading dialog
      Navigator.pop(context);

      final files = uploadInput.files;
      if (files == null || files.length == 0) return;

      // Show processing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Processing..."),
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Uploading and processing CSV data"),
              ],
            ),
          );
        },
      );

      try {
        final file = files.item(0);
        if (file == null) {
          Navigator.pop(context);
          return;
        }

        // Validate file type
        if (!file.name.toLowerCase().endsWith('.csv')) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text("Please select a valid CSV file"),
            ),
          );
          return;
        }

        final reader = web.FileReader();

        reader.addEventListener(
          'loadend',
          ((web.Event e) {
            try {
              Navigator.pop(context);

              // Get the result - CRITICAL FIX HERE
              final result = reader.result;
              if (result == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red,
                    content: Text("Failed to read file"),
                  ),
                );
                return;
              }

              // Convert JSString to Dart String for WASM
              final csvString = (result as JSString).toDart;

              if (csvString.isNotEmpty) {
                Future.microtask(() => onCsv(csvString, userData));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red,
                    content: Text("CSV file is empty"),
                  ),
                );
              }
            } catch (e) {
              print('Error in loadend: $e');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.red,
                  content: Text("Error reading file: $e"),
                ),
              );
            }
          }).toJS,
        );

        reader.addEventListener(
          'error',
          ((web.Event e) {
            print('FileReader error event');
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red,
                content: Text("Error loading file"),
              ),
            );
          }).toJS,
        );

        // Read the file as text
        reader.readAsText(file);
      } catch (e) {
        print('Error in change event: $e');
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("Error selecting file: $e"),
          ),
        );
      }
    }).toJS,
  );
}

void pickImageWeb({required void Function(Uint8List) onBytes}) {
  final uploadInput = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*';
  uploadInput.click();

  uploadInput.addEventListener(
    'change',
    ((web.Event event) {
      final files = uploadInput.files;
      if (files == null || files.length == 0) return;

      final file = files.item(0);
      if (file == null) return;

      final reader = web.FileReader();
      reader.readAsArrayBuffer(file);

      reader.addEventListener(
        'loadend',
        ((web.Event e) {
          final result = reader.result;
          if (result != null) {
            onBytes((result as JSArrayBuffer).toDart.asUint8List());
          }
        }).toJS,
      );
    }).toJS,
  );
}
