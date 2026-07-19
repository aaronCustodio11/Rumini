import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for date formatting

class AnswerForms extends StatefulWidget {
  final String formId;
  final Map<String, dynamic> userData;
  const AnswerForms({super.key, required this.formId, required this.userData});

  @override
  State<AnswerForms> createState() => _AnswerFormsState();
}

class _AnswerFormsState extends State<AnswerForms> {
  Map<String, dynamic>? formData;
  List<DocumentSnapshot> questions = [];
  bool isLoading = true;
  Map<String, dynamic> answers = {};
  Map<String, TextEditingController> textControllers = {};
  
  // Add variables to track previous submission
  bool hasSubmittedBefore = false;
  String? submissionDate;

  // Colors - Updated to green theme
  final Color primaryColor = const Color(0xFF2E7D32); // Green
  final Color accentColor = const Color(0xFF66BB6A); // Light green
  final Color secondaryColor = const Color(0xFF4CAF50); // Medium green
  final Color requiredColor = const Color(0xFFFFCDD2); // Light red
  final Color requiredTextColor = const Color(0xFFE57373); // Light red text
  final Color cardShadowColor = Colors.black.withOpacity(0.08);

  @override
  void initState() {
    super.initState();
    _checkPreviousSubmission();
  }

  // New method to check if user has previously submitted this form
  Future<void> _checkPreviousSubmission() async {
    try {
      // First load the form data to get the title
      final formDoc = await FirebaseFirestore.instance
          .collection('forms')
          .doc(widget.formId)
          .get();
      
      setState(() {
        formData = formDoc.data();
      });
      
      // Check if the user has already submitted this form
      final previousSubmissions = await FirebaseFirestore.instance
          .collection('answer_form')
          .where('formId', isEqualTo: widget.formId)
          .where('studId', isEqualTo: widget.userData['studId'])
          .get();
      
      if (previousSubmissions.docs.isNotEmpty) {
        // User has already submitted this form
        final submission = previousSubmissions.docs.first.data();
        final submittedAt = submission['submittedAt'] as Timestamp;
        
        setState(() {
          hasSubmittedBefore = true;
          submissionDate = DateFormat('MMMM d, yyyy - h:mm a')
              .format(submittedAt.toDate());
          isLoading = false;
        });
      } else {
        // No previous submission, load the questions
        _loadFormAndQuestions();
      }
    } catch (e) {
      debugPrint('Error checking previous submission: $e');
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Error loading form. Please try again.');
    }
  }

  Future<void> _submitForm() async {
    // Check if all required fields are filled
    bool allRequiredFieldsFilled = true;
    String missingFields = '';
    
    for (final doc in questions) {
      final q = doc.data() as Map<String, dynamic>;
      final questionId = q['questionId'];
      final isRequired = q['isRequired'] ?? false;
      
      if (isRequired && (answers[questionId] == null || 
          (answers[questionId] is String && answers[questionId].isEmpty) ||
          (answers[questionId] is List && answers[questionId].isEmpty))) {
        allRequiredFieldsFilled = false;
        missingFields += '\n- ${q['question']}';
      }
    }
    
    if (!allRequiredFieldsFilled) {
      _showErrorSnackBar('Please fill in all required fields:$missingFields');
      return;
    }
    
    try {
      Map<String, dynamic> dataToSave = {
        'formId': widget.formId,
        'studId': widget.userData['studId'],
        'title': formData?['title'] ?? '',
        'submittedAt': Timestamp.now(),
      };

      for (int i = 0; i < questions.length; i++) {
        final q = questions[i].data() as Map<String, dynamic>;
        final questionId = q['questionId'];
        final questionType = q['questionType'];
        final answer = answers[questionId];

        dataToSave['question${i + 1}'] = questionId;

        if (questionType == 'Short Answer' || questionType == 'Long Answer') {
          dataToSave['answer${i + 1}'] = answer?.toString() ?? '';
        } else if (questionType == 'Multiple Choice' ||
            questionType == 'Dropdown') {
          dataToSave['answer${i + 1}'] = answer?.toString() ?? '';
        } else if (questionType == 'Checkboxes') {
          if (answer is List) {
            dataToSave['answer${i + 1}'] = answer.join(', ');
          } else {
            dataToSave['answer${i + 1}'] = '';
          }
        } else if (questionType == 'Date Picker') {
          dataToSave['answer${i + 1}'] =
              answer != null ? Timestamp.fromDate(DateTime.parse(answer)) : null;
        } else if (questionType == 'Time Picker') {
          dataToSave['answer${i + 1}'] = answer?.toString() ?? '';
        } else {
          dataToSave['answer${i + 1}'] = answer?.toString() ?? '';
        }
      }

      await FirebaseFirestore.instance.collection('answer_form').add(dataToSave);

      _showSuccessSnackBar('Form submitted successfully!');
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error submitting form: $e');
      _showErrorSnackBar('Error submitting form. Please try again.');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: secondaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadFormAndQuestions() async {
    try {
      final questionsQuery = await FirebaseFirestore.instance
          .collection('questions')
          .where('formId', isEqualTo: widget.formId)
          .orderBy('order')
          .get();

      setState(() {
        questions = questionsQuery.docs;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading questions: $e');
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Error loading questions. Please try again.');
    }
  }

  // Get icon based on question type
  IconData _getQuestionTypeIcon(String questionType) {
    switch (questionType) {
      case 'Short Answer':
        return Icons.short_text;
      case 'Long Answer':
        return Icons.notes;
      case 'Multiple Choice':
        return Icons.radio_button_checked;
      case 'Checkboxes':
        return Icons.check_box;
      case 'Dropdown':
        return Icons.arrow_drop_down_circle;
      case 'Date Picker':
        return Icons.calendar_today;
      case 'Time Picker':
        return Icons.access_time;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Answer Form'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        color: const Color(0xFFF5F7FA),
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : hasSubmittedBefore
                ? _buildAlreadySubmittedView()
                : _buildFormView(),
      ),
    );
  }

  // New method to show the "already submitted" view
  Widget _buildAlreadySubmittedView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24.0),
        padding: const EdgeInsets.all(32.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: cardShadowColor,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 72,
                color: secondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Form Already Submitted",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              formData?['title'] ?? 'Form',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    submissionDate ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Return'),
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Method to build the form view (original functionality)
  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          /// Title & Description
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: cardShadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: primaryColor.withOpacity(0.1), width: 1),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.assignment,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        formData?['title'] ?? 'No Title',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (formData?['description'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[500], size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formData?['description'] ?? 'No Description',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          /// Questions
          ...questions.map((doc) {
            final q = doc.data() as Map<String, dynamic>;
            final questionId = q['questionId'];
            final question = q['question'] ?? 'No question text';
            final questionType = q['questionType'] ?? 'Unknown';
            final isRequired = q['isRequired'] ?? false;
            final options = q['options'] != null
                ? List<String>.from(q['options'])
                : [];

            textControllers.putIfAbsent(
                questionId, () => TextEditingController());

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: cardShadowColor,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question header with icon and number
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getQuestionTypeIcon(questionType),
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Question ${((q['order'] ?? 0) + 1)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        if (isRequired)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: requiredColor.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Required',
                              style: TextStyle(
                                fontSize: 11,
                                color: requiredTextColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Question text
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        question,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    /// Answer Input based on type with improved styling
                    if (questionType == 'Short Answer') ...[
                      TextField(
                        controller: textControllers[questionId],
                        onChanged: (val) => answers[questionId] = val,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: primaryColor, width: 1.5),
                          ),
                          hintText: 'Enter short answer',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      )
                    ] else if (questionType == 'Long Answer') ...[
                      TextField(
                        controller: textControllers[questionId],
                        onChanged: (val) => answers[questionId] = val,
                        maxLines: 5,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: primaryColor, width: 1.5),
                          ),
                          hintText: 'Enter long answer',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          contentPadding: const EdgeInsets.all(16),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      )
                    ] else if (questionType == 'Multiple Choice') ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: options.map((opt) {
                            return RadioListTile(
                              title: Text(
                                opt,
                                style: const TextStyle(fontSize: 15),
                              ),
                              value: opt,
                              groupValue: answers[questionId],
                              activeColor: primaryColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              onChanged: (val) {
                                setState(() => answers[questionId] = val);
                              },
                            );
                          }).toList(),
                        ),
                      )
                    ] else if (questionType == 'Checkboxes') ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: options.map((opt) {
                            final selectedOptions =
                                answers[questionId] ?? <String>[];
                            final isChecked =
                                selectedOptions.contains(opt);
                            return CheckboxListTile(
                              title: Text(
                                opt,
                                style: const TextStyle(fontSize: 15),
                              ),
                              value: isChecked,
                              activeColor: primaryColor,
                              checkColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    if (answers[questionId] == null) {
                                      answers[questionId] = [opt];
                                    } else {
                                      answers[questionId] = [
                                        ...selectedOptions,
                                        opt
                                      ];
                                    }
                                  } else {
                                    answers[questionId] = [
                                      ...selectedOptions
                                    ]..remove(opt);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      )
                    ] else if (questionType == 'Dropdown') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: answers[questionId],
                            hint: const Text('Select an option'),
                            isExpanded: true,
                            icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                            items: options
                                .map<DropdownMenuItem<String>>((opt) {
                              return DropdownMenuItem<String>(
                                  value: opt, child: Text(opt));
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                answers[questionId] = val;
                              });
                            },
                          ),
                        ),
                      )
                    ] else if (questionType == 'Date Picker') ...[
                      ElevatedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: primaryColor,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              answers[questionId] =
                                  picked.toIso8601String();
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          answers[questionId] != null
                              ? 'Selected: ${DateFormat('MMMM d, yyyy').format(DateTime.parse(answers[questionId]))}'
                              : 'Pick a date',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryColor,
                          elevation: 0,
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20), // Updated to 20
                          ),
                        ),
                      )
                    ] else if (questionType == 'Time Picker') ...[
                      ElevatedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: primaryColor,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              answers[questionId] =
                                  picked.format(context);
                            });
                          }
                        },
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text(
                          answers[questionId] != null
                              ? 'Selected: ${answers[questionId]}'
                              : 'Pick a time',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryColor,
                          elevation: 0,
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20), // Updated to 20
                          ),
                        ),
                      )
                    ]
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 32),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _submitForm,
              icon: const Icon(Icons.send),
              label: const Text(
                'Submit Form',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: primaryColor.withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}