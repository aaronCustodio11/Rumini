import 'dart:async';
import 'package:rumini/components/questionAlert.dart';
import 'package:rumini/components/sidebar.dart';
import 'package:rumini/pages(admin)/forms/formsAnalytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Formscreate extends StatefulWidget {
  final String currentformId;
  final Map<String, dynamic> userData;
  const Formscreate({super.key, required this.currentformId, required this.userData});

  @override
  State<Formscreate> createState() => _FormscreateState();
}

class _FormscreateState extends State<Formscreate> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? selectedQuestionId;
  List<QueryDocumentSnapshot> cachedQuestions = [];
  late final StreamSubscription<QuerySnapshot> _questionSub;
  String formStatus =
      'close'; // default; you'll fetch the real value from Firestore

  @override
  void initState() {
    super.initState();

    // Fetch form details
    FirebaseFirestore.instance
        .collection('forms')
        .doc(widget.currentformId)
        .get()
        .then((docSnapshot) {
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        _titleController.text = data?['title'] ?? '';
        _descriptionController.text = data?['description'] ?? '';
      }
    });

    // Listen for question changes
    _questionSub = FirebaseFirestore.instance
        .collection('questions')
        .where('formId', isEqualTo: widget.currentformId)
        .orderBy('order')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        cachedQuestions = snapshot.docs;
      });
    });
    fetchFormStatus();
  }

  void saveForm() async {
    final String formId = widget.currentformId;
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in both title and description')),
      );
      return;
    }

    try {
      // ✅ Step 1: collect all questionIds in order
      final List<String> orderedQuestionIds =
          cachedQuestions.map((doc) => doc.id).toList();

      // ✅ Step 2: write the form data including questionIds
      await FirebaseFirestore.instance.collection('forms').doc(formId).set({
        'formId': formId,
        'title': title,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'status': formStatus.isEmpty ? 'Unpublish' : formStatus,
        'questionIds': orderedQuestionIds,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form saved to Firestore!')),
      );
    } catch (e) {
      print('Error saving form: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving form')),
      );
    }
  }
// void saveForm() async {
//     final String formId = widget.currentformId;
//     final String title = _titleController.text.trim();
//     final String description = _descriptionController.text.trim();

//     if (title.isEmpty || description.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please fill in both title and description')),
//       );
//       return;
//     }

//     try {
//       await FirebaseFirestore.instance.collection('forms').doc(formId).set({
//         'formId': formId,
//         'title': title,
//         'description': description,
//         'timestamp': FieldValue.serverTimestamp(),
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Form saved to Firestore!')),
//       );
//     } catch (e) {
//       print('Error saving form: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error saving form')),
//       );
//     }
//   }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose(); // Dispose scroll controller
    _questionSub.cancel(); // Cancel the subscription
    super.dispose();
  }

  Future<void> swapQuestionOrder(int index1, int index2) async {
    if (index1 < 0 ||
        index2 < 0 ||
        index1 >= cachedQuestions.length ||
        index2 >= cachedQuestions.length) {
      return;
    }

    final doc1 = cachedQuestions[index1];
    final doc2 = cachedQuestions[index2];

    final order1 = doc1['order'] ?? 0;
    final order2 = doc2['order'] ?? 0;

    final batch = FirebaseFirestore.instance.batch();

    batch.update(doc1.reference, {'order': order2});
    batch.update(doc2.reference, {'order': order1});

    await batch.commit();
  }

  Future<void> duplicateSelectedQuestion() async {
    if (selectedQuestionId == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('questions')
          .doc(selectedQuestionId);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) return;

      final originalData = docSnapshot.data() as Map<String, dynamic>;

      // Get latest order for this form
      final lastOrderQuery = await FirebaseFirestore.instance
          .collection('questions')
          .where('formId', isEqualTo: widget.currentformId)
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      final lastOrder = lastOrderQuery.docs.isNotEmpty
          ? (lastOrderQuery.docs.first.data()['order'] ?? 0) as int
          : 0;

      final newOrder = lastOrder + 1;

      // Create a new question document
      final newQuestionData = Map<String, dynamic>.from(originalData);
      newQuestionData['question'] = '${originalData['question']} (copy)';
      newQuestionData['order'] = newOrder;
      newQuestionData['timestamp'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection('questions')
          .add(newQuestionData);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Question duplicated')));
    } catch (e) {
      print('Error duplicating question: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to duplicate question')));
    }
  }

  void fetchFormStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('forms')
        .doc(widget.currentformId)
        .get();

    if (doc.exists && doc.data()?['status'] != null) {
      setState(() {
        formStatus = doc.data()!['status'].toString().toLowerCase();
      });
    }
  }

  void toggleFormStatus() async {
    final docRef = FirebaseFirestore.instance
        .collection('forms')
        .doc(widget.currentformId);

    try {
      final docSnapshot = await docRef.get();

// 🛑 Case: form not saved yet (doc doesn't exist)
      if (!docSnapshot.exists) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Form Not Saved'),
            content:
                const Text('You need to save this form before publishing it.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // close dialog
                  saveForm(); // Call your existing save function
                },
                child: const Text('Save Now'),
              ),
            ],
          ),
        );
        return;
      }

// ✅ Case: form exists — proceed with confirmation dialog
      final currentStatus =
          docSnapshot.data()?['status']?.toString().toLowerCase() ?? 'close';
      final newStatus = currentStatus == 'open' ? 'close' : 'open';

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(newStatus == 'open' ? 'Open Form?' : 'Close Form?'),
          content: Text(
            newStatus == 'open'
                ? 'Are you sure you want to set the form as OPEN?'
                : 'Are you sure you want to set the form as CLOSED?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                newStatus == 'open' ? 'Open' : 'Close',
                style: TextStyle(
                  color: newStatus == 'open' ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      await docRef.update({'status': newStatus});

      setState(() {
        formStatus = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Form status set to "$newStatus"')),
      );
    } catch (e) {
      print('Error toggling status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Something went wrong while updating status.')),
      );
    }
    saveForm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar on the left
          Sidebar(userData: widget.userData),

          // Main content area
          Expanded(
            child: Column(
              children: [
                // 🌟 Custom AppBar inside the column
                AppBar(
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  title: const Row(
                    children: [
                      Icon(Icons.note_add, color: Color(0xFF345F00)),
                      SizedBox(width: 8),
                      Text("Forms Creation"),
                    ],
                  ),
                  titleTextStyle: const TextStyle(
                    color: Color(0xFF345F00),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Buttons card
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            ElevatedButton(
                              onPressed: saveForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[800], // Dark green background
                              ),
                              child: const Text(
                                'Save Form',
                                style: TextStyle(
                                  color: Colors.white, // White text
                                  fontWeight: FontWeight.bold, // Bold font
                                ),
                              ),
                            ),

                           ElevatedButton(
                            onPressed: () {
                              showAddQuestionDialog(
                                context,
                                currentformId: widget.currentformId,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan[600], // Cyan/light green-blue color
                            ),
                            child: const Text(
                              'Add Question',
                              style: TextStyle(
                                color: Colors.white,         // White text
                                fontWeight: FontWeight.bold, // Bold font
                              ),
                            ),
                          ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Formsanalytics(
                                      currentformId: widget.currentformId,
                                      userData: widget.userData,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[300], // Light orange color
                              ),
                              child: const Text(
                                'View Analytics',
                                style: TextStyle(
                                  color: Colors.white,         // White text
                                  fontWeight: FontWeight.bold, // Bold font
                                ),
                              ),
                            ),

                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: formStatus == 'open'
                                    ? Colors.green
                                    : Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: toggleFormStatus,
                              icon: Icon(formStatus == 'open'
                                  ? Icons.lock_open
                                  : Icons.lock,
                                  color: Colors.white,),
                              label: Text(
                                formStatus == 'open'
                                    ? 'Form is Open'
                                    : 'Form is Closed',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Expanded scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    controller: _scrollController,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🧱 Left Column (your current content)
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              // 🟩 Title + Description Card (NO CHANGES)
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: _titleController,
                                        decoration: InputDecoration(
                                          labelText: 'Form Title',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      TextField(
                                        controller: _descriptionController,
                                        decoration: InputDecoration(
                                          labelText: 'Form Description',
                                          border: OutlineInputBorder(),
                                        ),
                                        maxLines: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              cachedQuestions.isEmpty
                                  ? Text('No questions found for this form.')
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: cachedQuestions.length,
                                      separatorBuilder: (_, __) =>
                                          SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final doc = cachedQuestions[index];
                                        final data =
                                            doc.data() as Map<String, dynamic>;
                                        final questionId = doc.id;
                                        final questionText =
                                            data['question'] ?? '';
                                        final questionType =
                                            data['questionType'] ?? '';
                                        final options =
                                            data['options'] as List<dynamic>?;

                                        final isOptionType =
                                            questionType == 'Multiple Choice' ||
                                                questionType == 'Checkboxes' ||
                                                questionType == 'Dropdown';

                                        return Card(
                                          elevation: 4,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // 🟢 Top Row: Question number + up/down buttons
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Question ${data['order'] ?? index + 1}',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black
                                                            .withOpacity(0.6),
                                                      ),
                                                    ),
                                                    Row(
                                                      children: [
                                                        IconButton(
                                                          icon: Icon(Icons
                                                              .arrow_upward),
                                                          onPressed: index > 0
                                                              ? () =>
                                                                  swapQuestionOrder(
                                                                      index,
                                                                      index - 1)
                                                              : null,
                                                          tooltip: 'Move Up',
                                                        ),
                                                        IconButton(
                                                          icon: Icon(Icons
                                                              .arrow_downward),
                                                          onPressed: index <
                                                                  cachedQuestions
                                                                          .length -
                                                                      1
                                                              ? () =>
                                                                  swapQuestionOrder(
                                                                      index,
                                                                      index + 1)
                                                              : null,
                                                          tooltip: 'Move Down',
                                                        ),
                                                      ],
                                                    )
                                                  ],
                                                ),

                                                const SizedBox(height: 4),

                                                // 🔵 Question text + required toggle
                                                  Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          questionText,
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        children: [
                                                          Text("Required",
                                                              style: TextStyle(fontSize: 12)),
                                                          Switch(
                                                            value: data['isRequired'] ?? false,
                                                            onChanged: null,
                                                            // Add custom colors to show green when toggled on
                                                            activeColor: Colors.green,         // Thumb color when active
                                                            activeTrackColor: Colors.green.withOpacity(0.5), // Track color when active
                                                          ),
                                                        ],
                                                      )
                                                    ],
                                                  ),

                                                const SizedBox(height: 8),

                                                // 🟡 Question type
                                                Text(
                                                  'Type: $questionType',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),

                                                // 🔻 Option rendering
                                                if (isOptionType &&
                                                    options != null &&
                                                    options.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 8.0),
                                                    child: Column(
                                                      children:
                                                          options.map((opt) {
                                                        Widget optionWidget;

                                                        if (questionType ==
                                                            'Multiple Choice') {
                                                          optionWidget = Row(
                                                            children: [
                                                              Radio(
                                                                  value: null,
                                                                  groupValue:
                                                                      null,
                                                                  onChanged:
                                                                      null),
                                                              Text(opt
                                                                  .toString()),
                                                            ],
                                                          );
                                                        } else if (questionType ==
                                                            'Checkboxes') {
                                                          optionWidget = Row(
                                                            children: [
                                                              Checkbox(
                                                                  value: false,
                                                                  onChanged:
                                                                      null),
                                                              Text(opt
                                                                  .toString()),
                                                            ],
                                                          );
                                                        } else if (questionType ==
                                                            'Dropdown') {
                                                          optionWidget = Row(
                                                            children: [
                                                              Icon(Icons
                                                                  .arrow_drop_down),
                                                              Text(opt
                                                                  .toString()),
                                                            ],
                                                          );
                                                        } else {
                                                          optionWidget =
                                                              SizedBox.shrink();
                                                        }

                                                        return Align(
                                                          alignment: Alignment
                                                              .centerLeft,
                                                          child: optionWidget,
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),

                                                const SizedBox(height: 12),

                                                // 🟣 Bottom Row: Action buttons (Edit, Duplicate, Remove)
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Wrap(
                                                    spacing: 8,
                                                    children: [
                                                      // ✏️ Edit
                                                      IconButton(
                                                        icon: Icon(Icons.edit,
                                                            color: Colors.blue),
                                                        tooltip:
                                                            'Edit Question',
                                                        onPressed: () {
                                                          final selectedData =
                                                              data;
                                                          selectedData[
                                                                  'questionId'] =
                                                              questionId;

                                                          showAddQuestionDialog(
                                                            context,
                                                            existingQuestion:
                                                                selectedData,
                                                            currentformId: widget
                                                                .currentformId,
                                                          );
                                                        },
                                                      ),

                                                      // 📄 Duplicate
                                                      IconButton(
                                                        icon: Icon(Icons.library_add,
                                                            color:
                                                                Colors.orange),
                                                        tooltip:
                                                            'Duplicate Question',
                                                        onPressed: () async {
                                                          try {
                                                            final lastOrderQuery = await FirebaseFirestore
                                                                .instance
                                                                .collection(
                                                                    'questions')
                                                                .where('formId',
                                                                    isEqualTo:
                                                                        widget
                                                                            .currentformId)
                                                                .orderBy(
                                                                    'order',
                                                                    descending:
                                                                        true)
                                                                .limit(1)
                                                                .get();

                                                            final lastOrder = lastOrderQuery
                                                                    .docs
                                                                    .isNotEmpty
                                                                ? (lastOrderQuery
                                                                            .docs
                                                                            .first
                                                                            .data()[
                                                                        'order'] ??
                                                                    0) as int
                                                                : 0;

                                                            final newOrder =
                                                                lastOrder + 1;

                                                            final newQuestionData =
                                                                Map<String,
                                                                        dynamic>.from(
                                                                    data);
                                                            newQuestionData[
                                                                    'question'] =
                                                                '${data['question']} (copy)';
                                                            newQuestionData[
                                                                    'order'] =
                                                                newOrder;
                                                            newQuestionData[
                                                                    'timestamp'] =
                                                                FieldValue
                                                                    .serverTimestamp();

                                                            await FirebaseFirestore
                                                                .instance
                                                                .collection(
                                                                    'questions')
                                                                .add(
                                                                    newQuestionData);

                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                  content: Text(
                                                                      'Question duplicated')),
                                                            );
                                                          } catch (e) {
                                                            print(
                                                                'Error duplicating question: $e');
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                  content: Text(
                                                                      'Failed to duplicate question')),
                                                            );
                                                          }
                                                        },
                                                      ),

                                                      // ❌ Remove
                                                      IconButton(
                                                        icon: Icon(Icons.delete,
                                                            color: Colors.red),
                                                        tooltip:
                                                            'Delete Question',
                                                        onPressed: () async {
                                                          try {
                                                            final docRef =
                                                                FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                        'questions')
                                                                    .doc(
                                                                        questionId);
                                                            final deletedDoc =
                                                                await docRef
                                                                    .get();
                                                            final formId =
                                                                deletedDoc
                                                                        .data()?[
                                                                    'formId'];

                                                            await docRef
                                                                .delete();

                                                            final remainingQuestions =
                                                                await FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                        'questions')
                                                                    .where(
                                                                        'formId',
                                                                        isEqualTo:
                                                                            formId)
                                                                    .orderBy(
                                                                        'order')
                                                                    .get();

                                                            final batch =
                                                                FirebaseFirestore
                                                                    .instance
                                                                    .batch();
                                                            for (int i = 0;
                                                                i <
                                                                    remainingQuestions
                                                                        .docs
                                                                        .length;
                                                                i++) {
                                                              final doc =
                                                                  remainingQuestions
                                                                      .docs[i];
                                                              batch.update(
                                                                  doc.reference,
                                                                  {'order': i});
                                                            }

                                                            await batch
                                                                .commit();
                                                          } catch (e) {
                                                            print(
                                                                "Error while deleting and reordering: $e");
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                  content: Text(
                                                                      "Failed to delete or reorder.")),
                                                            );
                                                          }
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    )
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // 🆕 Right Column (Empty card)
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(16.0),
                                  width: double.infinity,
                                  height: 300, // or any height you want
                                  child: Center(
                                    child: Text(
                                      "Empty Card",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
