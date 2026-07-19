import 'dart:convert';
import 'package:rumini/helper/helper_functions.dart';
import 'package:rumini/main.dart';
import 'package:rumini/pages(user)/home/welcome.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rumini/components/sidebar.dart';
import 'package:rumini/pages(admin)/profilePage/greetings.dart';

class ProfileAd extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileAd({super.key, required this.userData});

  @override
  State<ProfileAd> createState() => _ProfileAdState();
}

class _ProfileAdState extends State<ProfileAd> {

   @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkAndShowWelcomeDialog(widget.userData);
  });
}

  Future<void> _checkAndShowWelcomeDialog(Map<String, dynamic> userData) async {
  try {
    final uid = userData['uid'];
    if (uid == null) return;

    final docRef =
        FirebaseFirestore.instance.collection('Users').doc(uid);

    final docSnap = await docRef.get();
    if (!docSnap.exists) return;

    final data = docSnap.data() ?? {};

    // If 'welcome' doesn't exist, create it with false
    if (!data.containsKey('welcome')) {
      await docRef.update({'welcome': false});
    }

    // If 'welcome' is false (or just created), show the dialog
    if (data['welcome'] == false || !data.containsKey('welcome')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => WelcomeDialog(userData: widget.userData),
        ).then((_) async {
          // After dialog completes, mark welcome and first login as true
          await docRef.update({
            'welcome': true,
          });
        });
      });
    }
  } catch (e) {
    debugPrint('⚠️ Error checking welcome dialog: $e');
  }
}
  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final _formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    double passwordStrength = 0.0;
    String strengthLabel = "Enter a password";

    showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            void checkPasswordStrength(String password) {
              double strength = 0;
              if (password.isEmpty) {
                strength = 0;
                strengthLabel = "Enter a password";
              } else {
                if (password.length >= 6) strength += 0.3;
                if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
                if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.2;
                if (RegExp(r'[!@#\$&*~]').hasMatch(password)) strength += 0.3;

                if (strength < 0.3) {
                  strengthLabel = "Weak";
                } else if (strength < 0.7) {
                  strengthLabel = "Medium";
                } else {
                  strengthLabel = "Strong";
                }
              }

              setState(() {
                passwordStrength = strength.clamp(0.0, 1.0);
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Change Password",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: obscureOld,
                        decoration: InputDecoration(
                          labelText: "Current Password",
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.green.shade600),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureOld ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () => setState(() => obscureOld = !obscureOld),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.green.shade600),
                          ),
                          labelStyle: TextStyle(color: Colors.grey.shade500),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Enter your current password';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        onChanged: (value) => checkPasswordStrength(value),
                        decoration: InputDecoration(
                          labelText: "New Password",
                          prefixIcon: Icon(Icons.lock_reset, color: Colors.green.shade600),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () => setState(() => obscureNew = !obscureNew),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.green.shade600),
                          ),
                          labelStyle: TextStyle(color: Colors.grey.shade500),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Enter a new password';
                          if (value.length < 6)
                            return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: passwordStrength,
                        backgroundColor: Colors.grey[300],
                        color: passwordStrength < 0.3
                            ? Colors.red
                            : passwordStrength < 0.7
                                ? Colors.orange
                                : Colors.green,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strengthLabel,
                        style: TextStyle(
                          color: passwordStrength < 0.3
                              ? Colors.red
                              : passwordStrength < 0.7
                                  ? Colors.orange
                                  : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: "Confirm Password",
                          prefixIcon: Icon(Icons.check, color: Colors.green.shade600),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.green.shade600),
                          ),
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                        ),
                        validator: (value) {
                          if (value != newPasswordController.text)
                            return 'Passwords do not match';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: Colors.green.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() => isSaving = true);
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null || user.email == null) {
                                throw Exception("No authenticated user found");
                              }

                              final cred = EmailAuthProvider.credential(
                                email: user.email!,
                                password: currentPasswordController.text.trim(),
                              );

                              await user.reauthenticateWithCredential(cred);
                              await user.updatePassword(
                                newPasswordController.text.trim(),
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text("Password updated successfully"),
                                    backgroundColor: Colors.green.shade600,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } on FirebaseAuthException catch (e) {
                              String msg;
                              if (e.code == 'wrong-password') {
                                msg = "Incorrect current password.";
                              } else if (e.code == 'weak-password') {
                                msg = "The new password is too weak.";
                              } else {
                                msg = "Error: ${e.message}";
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(msg),
                                    backgroundColor: Colors.red.shade600,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } finally {
                              setState(() => isSaving = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Save",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showRecoveryOptionDialog(
  BuildContext context,
  DocumentSnapshot userDoc,
) async {
  final user = userDoc.data() as Map<String, dynamic>;

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

  final recoveryEmailController =
      TextEditingController(text: user['recoveryEmail'] ?? '');
  String selectedQuestion = user['securityQuestion'] ?? securityQuestions.first;
  final securityAnswerController =
      TextEditingController(text: user['securityAnswer'] ?? '');

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Text('Recovery Options'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: recoveryEmailController,
                decoration: const InputDecoration(
                  labelText: 'Recovery Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedQuestion,
                items: securityQuestions
                    .map((question) => DropdownMenuItem(
                          value: question,
                          child: Text(question),
                        ))
                    .toList(),
                onChanged: (value) {
                  selectedQuestion = value!;
                },
                decoration: const InputDecoration(
                  labelText: 'Security Question',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: securityAnswerController,
                decoration: const InputDecoration(
                  labelText: 'Security Answer',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final recoveryEmail = recoveryEmailController.text.trim();
              final securityAnswer = securityAnswerController.text.trim();

              if (recoveryEmail.isEmpty ||
                  selectedQuestion.isEmpty ||
                  securityAnswer.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('Users')
                    .doc(userDoc.id)
                    .update({
                  'recoveryEmail': recoveryEmail,
                  'securityQuestion': selectedQuestion,
                  'securityAnswer': securityAnswer,
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Recovery information updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFF5F7FA),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Sidebar(userData: widget.userData),
            Expanded(
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: const Color.fromARGB(255, 232, 232, 232),
                    title: const Row(
                      children: [
                        Icon(Icons.person, color: Color(0xFF345F00)),
                        SizedBox(width: 8),
                        Text("Profile"),
                      ],
                    ),
                    titleTextStyle: const TextStyle(
                      color: Color(0xFF345F00),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30.0,
                        vertical: 20.0,
                      ),
                      child: _buildWideLayout(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 260,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: buildInformationCard(widget.userData, context),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DynamicGreetingCard(userData: widget.userData),
              _buildNotificationCard(),
              const SizedBox(height: 12),
              _buildScheduleCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildInformationCard(
    Map<String, dynamic> userData,
    BuildContext context,
  ) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('Users')
          .where('counId', isEqualTo: userData['counId'])
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.green.shade600),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No counselor information found."));
        }

        final userDoc = snapshot.data!.docs.first;
        final user = userDoc.data() as Map<String, dynamic>;

        ImageProvider profileImage;
        try {
          if (user['image'] != null && user['image'] != '') {
            profileImage = MemoryImage(base64Decode(user['image']));
          } else {
            profileImage = const AssetImage('assets/default_profile.png');
          }
        } catch (e) {
          profileImage = const AssetImage('assets/default_profile.png');
        }

        String capitalize(String s) => s.isNotEmpty
            ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}'
            : '';

        final firstName = capitalize(user['firstName'] ?? '');
        final middleName = user['middleName'] ?? '';
        final middleInitial = middleName.isNotEmpty
            ? '${capitalize(middleName[0])}.'
            : '';
        final lastName = capitalize(user['lastName'] ?? '');
        final extensionName = capitalize(user['extensionName'] ?? '');
        final fullName =
            '$firstName ${middleInitial.isNotEmpty ? '$middleInitial ' : ''}$lastName${extensionName.isNotEmpty ? ' $extensionName' : ''}';

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: profileImage,
                    backgroundColor: Colors.green.shade100,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.badge,
                  "Counselor ID",
                  user['counId'] ?? 'N/A',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.work_outline,
                  "Role",
                  user['role'] ?? 'N/A',
                ),
                const SizedBox(height: 12),
                Text(
                  "Full Name:",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fullName,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Text(
                  "Assigned College:",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user['assignedCollege'] ?? 'N/A',
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Text(
                  "Description:",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user['description'] ?? 'No description available.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
  onPressed: () async {
    await _showRecoveryOptionDialog(context, userDoc);
  },
  icon: Icon(
    Icons.security_outlined,
    color: Colors.green.shade600,
  ),
  label: Text(
    "Recovery Option",
    style: TextStyle(color: const Color.fromARGB(255, 53, 88, 133)),
  ),
  style: OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 12),
    side: BorderSide(color: const Color.fromARGB(255, 67, 130, 160)),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
),
const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () async {
                        await _showChangePasswordDialog(context);
                      },
                      icon: Icon(
                        Icons.lock_outline,
                        color: Colors.green.shade600,
                      ),
                      label: Text(
                        "Change Password",
                        style: TextStyle(color: Colors.green.shade600),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.green.shade600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Text("Confirm Logout"),
                            content: const Text(
                              "Are you sure you want to log out?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text("Logout"),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          try {
                            await FirebaseAuth.instance.signOut();

                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const MyApp(),
                                ),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Logout failed: $e'),
                                  backgroundColor: Colors.red.shade600,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.green.shade700, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard() {
    final scheduleStream = FirebaseFirestore.instance
        .collection('templates')
        .where('counId', isEqualTo: widget.userData['counId'])
        .where('templateType', isEqualTo: 'Schedule')
        .snapshots();

    final days = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return StreamBuilder<QuerySnapshot>(
      stream: scheduleStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: Colors.green.shade600),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Schedule",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          showEditSchedule(
                            context,
                            widget.userData['counId'],
                          );
                        },
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: const Text(
                          "Edit",
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 24, thickness: 1, color: Colors.grey.shade300),
                  Text(
                    "No schedule data found for this counselor.",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Schedule",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        showEditSchedule(context, widget.userData['counId']);
                      },
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: const Text(
                        "Edit",
                        style: TextStyle(fontSize: 13, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                Divider(height: 24, thickness: 1, color: Colors.grey.shade300),
                Column(
                  children: days.map((day) {
                    final slots = (data[day.toLowerCase()] as List?) ?? [];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              day.substring(0, 3),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            child: slots.isEmpty
                                ? Text(
                                    "No schedule for this day.",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: slots
                                        .map<Widget>(
                                          (time) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.green.shade200,
                                              ),
                                            ),
                                            child: Text(
                                              time.toString(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

 bool _showAllNotifications = false;

Widget _buildNotificationCard() {
  final counId = widget.userData['counId']?.toString();

  print('🟢 Counselor ID from userData: $counId (${widget.userData['counId'].runtimeType})');

  final notifStream = FirebaseFirestore.instance
      .collection('notifications')
      .where('counId', isEqualTo: counId)
      .where('notifType', isEqualTo: 'Request')
      .orderBy('createdAt', descending: true)
      .snapshots();

  return StreamBuilder<QuerySnapshot>(
    stream: notifStream,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildNotifCardWrapper(
          Center(child: CircularProgressIndicator(color: Colors.green.shade600)),
        );
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return _buildNotifCardWrapper(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Notifications",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "No new notifications.",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      }

      final notifications = snapshot.data!.docs;
      final limitedList = _showAllNotifications
          ? notifications
          : notifications.take(5).toList();

      return _buildNotifCardWrapper(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Notifications",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: limitedList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notif = limitedList[index].data() as Map<String, dynamic>;
                final notifId = limitedList[index].id;
                final message = notif['message'] ?? 'No message';
                final seen = notif['seen'] ?? false;
                final path = notif['path'] ?? '/';
                final timestamp = notif['createdAt'];

                String formattedDate = 'Unknown date';
                if (timestamp is Timestamp) {
                  final date = timestamp.toDate();
                  formattedDate =
                      "${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                }

                return InkWell(
                  onTap: () async {
                    // Mark notification as seen
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(notifId)
                        .update({'seen': true});

                    // Navigate with userData
                    if (context.mounted) {
                      Navigator.pushNamed(
                        context,
                        path,
                        arguments: widget.userData,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: seen ? Colors.grey[100] : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: seen
                            ? Colors.grey.shade300
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: seen
                                ? Colors.grey.shade200
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            seen
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: seen
                                ? Colors.grey.shade600
                                : Colors.green.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: seen
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                  color: seen
                                      ? Colors.black87
                                      : Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (notifications.length > 5) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showAllNotifications = !_showAllNotifications;
                    });
                  },
                  child: Text(
                    _showAllNotifications ? "Show less" : "Show more",
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

Widget _buildNotifCardWrapper(Widget child) {
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: child,
    ),
  );
}
}