import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

Future<void> showAddQuestionDialog(
  BuildContext context, {
  Map<String, dynamic>? existingQuestion, required String currentformId,
}) async {
  final TextEditingController questionController =
      TextEditingController(text: existingQuestion?['question'] ?? '');

  final List<String> questionTypes = [
    'Short Answer',
    'Long Answer',
    'Multiple Choice',
    'Checkboxes',
    'Dropdown',
    'Date Picker',
    'Time Picker',
  ];

  String? selectedType = existingQuestion?['questionType'];
  bool isRequired = existingQuestion?['isRequired'] ?? false;

  List<TextEditingController> optionControllers = [];

  if (existingQuestion != null &&
      (selectedType == 'Multiple Choice' ||
          selectedType == 'Checkboxes' ||
          selectedType == 'Dropdown')) {
    List options = existingQuestion['options'] ?? [];
    optionControllers = options
        .map<TextEditingController>(
          (opt) => TextEditingController(text: opt.toString()),
        )
        .toList();
  }

  return showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Widget buildDynamicContent() {
            if (selectedType == 'Short Answer') {
              return const Text("Short Answer");
            } else if (selectedType == 'Long Answer') {
              return const Text("Long Answer");
            } else if (selectedType == 'Date Picker') {
              return const Text("Date Picker");
            } else if (selectedType == 'Time Picker') {
              return const Text("Time Picker");
            } else if (selectedType == 'Multiple Choice' ||
                selectedType == 'Checkboxes' ||
                selectedType == 'Dropdown') {
              return Column(
                children: [
                  ...List.generate(optionControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          if (selectedType == 'Multiple Choice')
                            const Radio(
                                value: null, groupValue: null, onChanged: null),
                          if (selectedType == 'Checkboxes')
                            const Checkbox(value: false, onChanged: null),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: optionControllers[index],
                              decoration: InputDecoration(
                                labelText: 'Option ${index + 1}',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                optionControllers.removeAt(index);
                              });
                            },
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          optionControllers.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: Text(selectedType == 'Dropdown'
                          ? 'Add Value'
                          : 'Add Option'),
                    ),
                  ),
                ],
              );
            } else {
              return const SizedBox.shrink();
            }
          }

          return AlertDialog(
            contentPadding: const EdgeInsets.all(24),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
            title: Text(
              existingQuestion != null
                  ? "Update Question"
                  : "Question Creation",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
                minWidth: 500,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Question Type',
                              border: OutlineInputBorder(),
                            ),
                            items: questionTypes.map((type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedType = value;
                                optionControllers.clear();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 150,
                          child: Row(
                            children: [
                              const Text("Required",
                                  style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Transform.scale(
                                scale: 0.8,
                                child: Switch(
                                  value: isRequired,
                                  onChanged: (value) {
                                    setState(() {
                                      isRequired = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: questionController,
                      enabled: selectedType != null,
                      decoration: const InputDecoration(
                        labelText: 'Question',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    buildDynamicContent(),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
               onPressed: () async {
 if (selectedType == null || questionController.text.trim().isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Please fill out the question.")),
  );
  return;
}

if ((selectedType == 'Multiple Choice' ||
     selectedType == 'Checkboxes' ||
     selectedType == 'Dropdown') &&
    optionControllers.every((controller) => controller.text.trim().isEmpty)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Please add at least one option.")),
  );
  return;
}


  final String questionId = existingQuestion?['questionId'] ?? const Uuid().v4();

 int newOrder = 0;

if (existingQuestion == null) {
  final querySnapshot = await FirebaseFirestore.instance
      .collection('questions')
      .where('formId', isEqualTo: currentformId)
      .orderBy('order', descending: true)
      .limit(1)
      .get();

  if (querySnapshot.docs.isNotEmpty) {
    final lastOrder = querySnapshot.docs.first.data()['order'];
    newOrder = (lastOrder is int) ? lastOrder + 1 : 0;
  }
}


  final Map<String, dynamic> questionData = {
    'questionId': questionId,
    'questionType': selectedType,
    'question': questionController.text.trim(),
    'isRequired': isRequired,
    'order': existingQuestion?['order'] ?? newOrder, // Keep existing order if editing
    'formId': currentformId,
  };

  if (selectedType == 'Multiple Choice' ||
      selectedType == 'Checkboxes' ||
      selectedType == 'Dropdown') {
    questionData['options'] = optionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }

  try {
    await FirebaseFirestore.instance
        .collection('questions')
        .doc(questionId)
        .set(questionData, SetOptions(merge: true));

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existingQuestion != null
            ? "Question updated successfully!"
            : "Question saved successfully!"),
      ),
    );
  } catch (e) {
    debugPrint("Error saving question: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to save question.")),
    );
  }
},
                child: Text(existingQuestion != null ? "Update" : "Add"),
              ),
            ],
          );
        },
      );
    },
  );
}
