import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WelcomeDialog extends StatefulWidget {
  final Map<String, dynamic> userData;
  const WelcomeDialog({super.key, required this.userData});

  @override
  State<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog> {
  int currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  final _recoveryEmailController = TextEditingController();
  final _answerController = TextEditingController();
  String? selectedQuestion;
  bool hasAgreed = false;
  bool isSaving = false;

  // Check if user is counselor or admin
  bool get isCounselorOrAdmin {
    final role = widget.userData['role']?.toString().toLowerCase() ?? '';
    return role == 'counselor' || role == 'admin';
  }

  final List<String> securityQuestions = [
    'What is your favorite color?',
    'What is your mother maiden name?',
    'What was your first pet name?',
    'What city were you born in?',
    'What is the name of your first school?',
    'What is your favorite movie?',
    'What is your favorite subject in high school?',
    'What is your dream job?',
    'What is the name of your childhood best friend?',
  ];

  bool _isValidGmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$');
    return regex.hasMatch(email);
  }

  Future<void> _saveRecoveryInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final usersRef = firestore.collection('Users');

      // Use counId for Counselor/Admin, studId for Student
      final idField = isCounselorOrAdmin ? 'counId' : 'studId';
      final idValue = widget.userData[idField];

      final querySnapshot = await usersRef
          .where(idField, isEqualTo: idValue)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;

        await usersRef.doc(docId).update({
          'recoveryEmail': _recoveryEmailController.text.trim().toLowerCase(),
          'securityQuestion': selectedQuestion,
          'securityAnswer': _answerController.text.trim(),
          'welcome': true,
        });
      } else {
        debugPrint('⚠️ No user found for $idField: $idValue');
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('❌ Error saving recovery info: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving information: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showPrivacyDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Full Data Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            isCounselorOrAdmin
                ? '''
This app collects, stores, and manages data solely for the purpose of providing counseling and mental health support services to PLV students.

As an authorized PLV guidance counselor/administrator, you have access to student information and session data for the purpose of providing professional counseling services.

All stored information is encrypted and must be handled in compliance with professional ethics and the Data Privacy Act of 2012.

By continuing, you acknowledge and accept that:
- You will handle all student data with utmost confidentiality.
- You will only access student information for legitimate counseling purposes.
- You understand your responsibilities under the Data Privacy Act of 2012.
- Your recovery email and security question are for account recovery verification only.

Thank you for your dedication to student well-being.
            '''
                : '''
This app collects, stores, and manages personal data solely for the purpose of providing counseling and mental health support services to PLV students.

All stored information (including names, recovery data, and session logs) is encrypted and accessible only to authorized PLV guidance counselors. No data is shared externally.

By continuing, you acknowledge and accept that:
- Your data will be processed in compliance with the Data Privacy Act of 2012.
- You can request data deletion or correction at any time.
- The system uses your recovery email and question only for account recovery verification.

Thank you for your trust in Rumini — your well-being matters most.
            ''',
            textAlign: TextAlign.justify,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.green[700]),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (currentStep == 1 && !hasAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please confirm that you have read and agreed to the policy.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (currentStep == 2) {
      _saveRecoveryInfo();
    } else {
      setState(() => currentStep++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 400 ? screenWidth * 0.9 : 420.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(24),
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 550),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStepContent(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: currentStep == 0
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (currentStep > 0)
                  TextButton(
                    onPressed: () => setState(() => currentStep--),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green[700],
                    ),
                    child: const Text('Back'),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSaving ? null : _nextStep,
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          currentStep == 2 ? 'Complete' : 'Next',
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    final image = Image.asset(
      'assets/images/enjoyment.png',
      width: 180,
      height: 180,
      fit: BoxFit.contain,
    );

    switch (currentStep) {
      case 0: // Welcome page
        return Column(
          key: const ValueKey(0),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            image,
            const SizedBox(height: 16),
            Text(
              isCounselorOrAdmin
                  ? 'Welcome to Rumini, Counselor!'
                  : 'Welcome to Rumini!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isCounselorOrAdmin
                  ? 'Your professional platform for providing guidance and counseling services to PLV students — designed to help you manage sessions, track student well-being, and deliver support safely and efficiently.'
                  : 'Your mental health companion app — designed to help PLV students connect with guidance and counseling services easily, safely, and privately.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
            ),
          ],
        );

      case 1: // Privacy page
        return SingleChildScrollView(
          key: const ValueKey(1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.privacy_tip_outlined,
                size: 100,
                color: Colors.green,
              ),
              const SizedBox(height: 10),
              const Text(
                'Data Privacy and Security',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isCounselorOrAdmin
                    ? 'As a counselor/administrator, you have access to sensitive student information. All data must be handled with confidentiality and in compliance with the Data Privacy Act of 2012.'
                    : 'Your information is handled securely and accessible only to authorized PLV guidance counselors. Please read and agree before continuing.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _showPrivacyDetails,
                icon: const Icon(Icons.info_outline, color: Colors.green),
                label: const Text(
                  'Learn More',
                  style: TextStyle(color: Colors.green),
                ),
              ),
              const Divider(height: 30),
              CheckboxListTile(
                title: Text(
                  isCounselorOrAdmin
                      ? 'I have read and agree to the Data Privacy Policy and understand my professional responsibilities in handling student information confidentially.'
                      : 'I have read and agree to the Data Privacy Policy and confirm that my provided information is accurate.',
                  style: const TextStyle(fontSize: 14),
                ),
                value: hasAgreed,
                onChanged: (val) => setState(() => hasAgreed = val ?? false),
                activeColor: Colors.green,
                checkboxShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );

      case 2: // Recovery info page
        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            key: const ValueKey(2),
            child: Column(
              children: [
                const Icon(
                  Icons.lock_reset_outlined,
                  size: 100,
                  color: Colors.green,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set Your Recovery Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recoveryEmailController,
                  onChanged: (val) => _recoveryEmailController.value =
                      _recoveryEmailController.value.copyWith(
                    text: val.toLowerCase(),
                    selection: TextSelection.collapsed(offset: val.length),
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Recovery Email (Gmail only)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final email = value?.trim().toLowerCase() ?? '';
                    if (email.isEmpty) {
                      return 'Please enter your recovery email';
                    }
                    if (!_isValidGmail(email)) {
                      return 'Please enter a valid Gmail address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Security Question',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.security_outlined),
                  ),
                  isExpanded: true,
                  menuMaxHeight: 300,
                  items: securityQuestions.map((q) {
                    return DropdownMenuItem(
                      value: q,
                      child: Text(
                        q,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedQuestion = val),
                  validator: (value) =>
                      value == null ? 'Please select a security question' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _answerController,
                  decoration: const InputDecoration(
                    labelText: 'Answer',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.question_answer_outlined),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter your answer'
                      : null,
                ),
              ],
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}