import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog>
    with SingleTickerProviderStateMixin {
  int step = 1;
  bool isLoading = false;
  bool isSuccess = false;
  String? docId;
  String? securityQuestion;

  final TextEditingController idController = TextEditingController();
  final TextEditingController recoveryEmailController = TextEditingController();
  final TextEditingController answerController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  /// STEP 2: Verify Recovery Email
  Future<void> verifyRecoveryEmail() async {
    final email = recoveryEmailController.text.trim();
    if (email.isEmpty) return _showError('Please enter your recovery email.');

    setState(() => isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(docId)
          .get();

      await Future.delayed(const Duration(milliseconds: 600));

      if (doc.exists && doc.data()?['recoveryEmail'] == email) {
        securityQuestion = doc.data()?['securityQuestion'];
        setState(() {
          step = 3;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        _showError('Recovery email does not match.');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Error verifying email: $e');
    }
  }

  // Add these helper variables at the class level
  String? userIdField; // Will be 'studId' or 'counId'
  String? userRole; // Will store the user's role

  /// Helper method to determine if input is studId or counId
  Future<Map<String, dynamic>?> getUserByAnyId(String userId) async {
    try {
      // First, try to find by studId
      final studIdQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('studId', isEqualTo: userId)
          .limit(1)
          .get();

      if (studIdQuery.docs.isNotEmpty) {
        final userData = studIdQuery.docs.first.data();
        userData['docId'] = studIdQuery.docs.first.id;
        userData['idField'] = 'studId';
        return userData;
      }

      // If not found, try counId
      final counIdQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('counId', isEqualTo: userId)
          .limit(1)
          .get();

      if (counIdQuery.docs.isNotEmpty) {
        final userData = counIdQuery.docs.first.data();
        userData['docId'] = counIdQuery.docs.first.id;
        userData['idField'] = 'counId';
        return userData;
      }

      return null; // User not found
    } catch (e) {
      print('❌ Error finding user: $e');
      return null;
    }
  }

  /// STEP 3: Verify Security Answer
  Future<void> verifySecurityAnswer() async {
    final answer = answerController.text.trim();
    if (answer.isEmpty) {
      return _showError('Please answer the security question.');
    }

    setState(() => isLoading = true);

    try {
      // 🔍 Get the user document
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(docId)
          .get();

      await Future.delayed(const Duration(milliseconds: 600));

      // ✅ Verify the security answer
      if (doc.exists && doc.data()?['securityAnswer'] == answer) {
        try {
          final userId = idController.text.trim();
          if (userId.isEmpty) {
            setState(() => isLoading = false);
            return _showError('User ID is missing.');
          }

          // 🔍 Determine if this is studId or counId
          final userData = await getUserByAnyId(userId);

          if (userData == null) {
            setState(() => isLoading = false);
            return _showError('User not found.');
          }

          final idField = userData['idField'] as String;
          final role = userData['role'] as String?;

          print('📘 User ID: $userId, Field: $idField, Role: $role');

          // Store for later use
          userIdField = idField;
          userRole = role;

          // ✅ Call Firebase Function to send OTP with the correct ID field
          final callData = idField == 'studId'
              ? {'studId': userId}
              : {'counId': userId};

          final result = await FirebaseFunctions.instance
              .httpsCallable('sendPasswordResetOTP')
              .call(callData);

          // ✅ Access only the data portion safely
          final message = result.data?['message'] ?? 'OTP sent successfully.';
          _showSuccess(message);

          await Future.delayed(const Duration(seconds: 1));

          setState(() {
            step = 4; // Go to OTP step
            isLoading = false;
          });
        } catch (e) {
          setState(() => isLoading = false);
          _showError('Failed to send OTP: $e');
        }
      } else {
        setState(() => isLoading = false);
        _showError('Security answer incorrect.');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Error verifying answer: $e');
    }
  }

  Future<void> verifyOTP() async {
    final otpInput = otpController.text.trim();
    final userId = idController.text.trim();

    if (otpInput.isEmpty) return _showError('Please enter the OTP.');

    setState(() => isLoading = true);

    try {
      // If userIdField is not set, determine it again
      if (userIdField == null) {
        final userData = await getUserByAnyId(userId);
        if (userData == null) {
          setState(() => isLoading = false);
          return _showError('User not found.');
        }
        userIdField = userData['idField'] as String;
        userRole = userData['role'] as String?;
      }

      print('🔍 Checking OTP for $userIdField: $userId');

      // ✅ Get OTP document (the document ID is the userId)
      final otpDoc = await FirebaseFirestore.instance
          .collection('OTP')
          .doc(userId)
          .get();

      if (!otpDoc.exists) {
        setState(() => isLoading = false);
        return _showError('No OTP found. Please request again.');
      }

      final data = otpDoc.data()!;
      final savedOtp = data['otp'];
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      final used = data['used'] ?? false;

      // ✅ Check if OTP was already used
      if (used) {
        setState(() => isLoading = false);
        return _showError('This OTP has already been used.');
      }

      // ✅ Check if OTP has expired
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        setState(() => isLoading = false);
        return _showError('OTP has expired. Please request again.');
      }

      // ✅ Verify OTP
      if (otpInput == savedOtp) {
        // Mark OTP as used
        await FirebaseFirestore.instance.collection('OTP').doc(userId).update({
          'used': true,
        });

        setState(() {
          isSuccess = true;
          isLoading = false;
        });

        await Future.delayed(const Duration(seconds: 2));

        // ✅ Move to password reset step
        if (mounted) {
          setState(() {
            step = 5; // Move to password reset
          });
        }
      } else {
        setState(() => isLoading = false);
        _showError('Invalid OTP. Please try again.');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Error verifying OTP: $e');
    }
  }

  Future<void> resetPassword() async {
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final userId = idController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      return _showError('Please fill in all password fields.');
    }

    if (newPassword != confirmPassword) {
      return _showError('Passwords do not match.');
    }

    if (newPassword.length < 6) {
      return _showError('Password must be at least 6 characters long.');
    }

    setState(() => isLoading = true);

    try {
      // If userIdField is not set, determine it again
      if (userIdField == null) {
        final userData = await getUserByAnyId(userId);
        if (userData == null) {
          setState(() => isLoading = false);
          return _showError('User not found.');
        }
        userIdField = userData['idField'] as String;
        userRole = userData['role'] as String?;
      }

      print(
        '🔒 Resetting password for $userIdField: $userId (Role: $userRole)',
      );

      // 🔒 Securely reset via Cloud Function with the correct ID field
      final callData = {
        'newPassword': newPassword,
        if (userIdField == 'studId') 'studId': userId,
        if (userIdField == 'counId') 'counId': userId,
      };

      final result = await FirebaseFunctions.instance
          .httpsCallable('resetUserPassword')
          .call(callData);

      final message = result.data?['message'] ?? 'Password reset successful.';

      setState(() {
        isLoading = false;
        isSuccess = true;
      });

      _showSuccess(message);

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        // Reset the stored values
        userIdField = null;
        userRole = null;
        Navigator.pop(context); // ✅ Close dialog
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to reset password: $e');
    }
  }

  // Optional: You might also want to update the initial ID verification step
  // This should be called when user first enters their ID (Step 1 or 2)
  Future<void> verifyUserId() async {
    final userId = idController.text.trim();

    if (userId.isEmpty) {
      return _showError('Please enter your ID.');
    }

    setState(() => isLoading = true);

    try {
      final userData = await getUserByAnyId(userId);

      if (userData == null) {
        setState(() => isLoading = false);
        return _showError('No user found with this ID.');
      }

      final role = userData['role'] as String?;
      final idField = userData['idField'] as String;

      // Validate role matches ID type
      if (idField == 'counId' && role != 'Counselor' && role != 'Admin') {
        setState(() => isLoading = false);
        return _showError('Invalid counselor/admin ID.');
      }

      if (idField == 'studId' && role != 'Student') {
        setState(() => isLoading = false);
        return _showError('Invalid student ID.');
      }

      // Store document ID and other info for later use
      docId = userData['docId'];
      userIdField = idField;
      userRole = role;

      // After successful ID verification
      setState(() {
        isLoading = false;
        step = 2; // ✅ go to Step 2 (verify recovery email)
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Error verifying ID: $e');
    }
  }

  // Snackbars
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : MediaQuery.of(context).size.width * 0.3,
        vertical: isMobile ? 20 : 40,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(28),
        width: isMobile ? double.infinity : 480,
        height: isMobile ? 420 : 460,
        child: isLoading
            ? _buildLoading()
            : isSuccess
            ? _buildStep5()
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: step == 1
                    ? _buildStep1()
                    : step == 2
                    ? _buildStep2()
                    : step == 3
                    ? _buildStep3()
                    : _buildStep4(),
              ),
      ),
    );
  }

  // Step 1
  Widget _buildStep1() => Column(
    key: const ValueKey('Step1'),
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SizedBox(height: 10),
      const Text(
        "Forgot Password",
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E7D32),
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      const Text(
        "Enter your Counselor ID or Student ID number.",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Colors.black54),
      ),
      const SizedBox(height: 24),

      _styledTextField(
        controller: idController,
        label: 'ID Number',
        icon: Icons.badge_outlined,
      ),

      const Spacer(),

      ElevatedButton(
        onPressed: verifyUserId,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 50),
          elevation: 3,
        ),
        child: const Text(
          "Next",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      const SizedBox(height: 16),

      // 🟢 Add this new note here
      const Text(
        "If you also forgot your recovery email or security answer,\n"
        "please visit the PLV Guidance Office personally to reset your password\n"
        "and retrieve your account.",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
      ),
    ],
  );

  // Step 2
  Widget _buildStep2() => _buildStepTemplate(
    title: "Verify Recovery Email",
    description:
        "Please enter the recovery email associated with your account.",
    child: _styledTextField(
      controller: recoveryEmailController,
      label: 'Recovery Email',
      icon: Icons.email_outlined,
    ),
    onPressed: verifyRecoveryEmail,
    buttonText: "Next",
  );

  // Step 3
  Widget _buildStep3() => _buildStepTemplate(
    title: "Security Question",
    description: securityQuestion ?? "Question not found",
    child: _styledTextField(
      controller: answerController,
      label: 'Your Answer',
      icon: Icons.lock_person_outlined,
    ),
    onPressed: verifySecurityAnswer,
    buttonText: "Submit",
  );

  // Step 4: Verify OTP
  Widget _buildStep4() => _buildStepTemplate(
    title: "Enter OTP",
    description:
        "We’ve sent a 6-digit OTP to your recovery email. Please enter it below to verify.",
    child: _styledTextField(
      controller: otpController,
      label: 'Enter OTP',
      icon: Icons.password_outlined,
    ),
    onPressed: verifyOTP,
    buttonText: "Verify OTP",
  );

  // Template for steps
  Widget _buildStepTemplate({
    required String title,
    required String description,
    required Widget child,
    required VoidCallback onPressed,
    required String buttonText,
  }) {
    return Column(
      key: ValueKey(title),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 24),
        child,
        const Spacer(),
        AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 300),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size(double.infinity, 50),
              elevation: 3,
            ),
            child: Text(
              buttonText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Custom styled text field
  Widget _styledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
        filled: true,
        fillColor: Colors.grey.shade100,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // Loading animation
  Widget _buildLoading() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        CircularProgressIndicator(color: Color(0xFF2E7D32), strokeWidth: 3),
        SizedBox(height: 24),
        Text(
          "Verifying, please wait...",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    ),
  );

  Widget _buildStep5() => _buildStepTemplate(
    title: "Reset Password",
    description: "Enter your new password below to complete the reset process.",
    child: Column(
      children: [
        _styledTextField(
          controller: newPasswordController,
          label: 'New Password',
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 16),
        _styledTextField(
          controller: confirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_reset,
        ),
      ],
    ),
    onPressed: resetPassword,
    buttonText: "Reset Password",
  );
}
