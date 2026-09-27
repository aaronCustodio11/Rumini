import 'package:rumini/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Profilepage extends StatelessWidget {
  final Map<String, dynamic>? userData;
  const Profilepage({super.key, required this.userData});

  String _formatFullName(Map<String, dynamic> data) {
    String first = (data['firstName'] ?? '').toString();
    String middle = (data['middleName'] ?? '').toString();
    String last = (data['lastName'] ?? '').toString();
    String ext = (data['extensionName'] ?? '').toString();

    String capitalize(String s) => s.isNotEmpty
        ? "${s[0].toUpperCase()}${s.substring(1).toLowerCase()}"
        : "";

    first = capitalize(first);
    middle = capitalize(middle);
    last = capitalize(last);
    ext = capitalize(ext);

    return [
      first,
      middle,
      last,
      ext,
    ].where((part) => part.isNotEmpty).join(" ");
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.green.shade700, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
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
  String selectedQuestion = user['securityQuestion'] ?? '';
  final securityAnswerController =
      TextEditingController(text: user['securityAnswer'] ?? '');

  await showDialog(
    context: context,
    builder: (context) {
      final screenWidth = MediaQuery.of(context).size.width;

      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Text('Recovery Options'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth < 400 ? screenWidth * 0.9 : 400,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Recovery Email
                TextField(
                  controller: recoveryEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Recovery Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                // Security Question (Responsive + Wraps Text)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedQuestion.isNotEmpty ? selectedQuestion : null,
                  items: securityQuestions.map((question) {
                    return DropdownMenuItem<String>(
                      value: question,
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          question,
                          style: const TextStyle(fontSize: 14),
                          softWrap: true,
                          textAlign: TextAlign.start,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedQuestion = value!;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Security Question',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select a security question'),
                ),
                const SizedBox(height: 10),

                // Security Answer
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


  Future<String> _getCounselorName(String counId) async {
    if (counId.isEmpty) return "Not Assigned";

    final snapshot = await FirebaseFirestore.instance
        .collection("Users")
        .where("counId", isEqualTo: counId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      return _formatFullName(data);
    }
    return "Not Assigned";
  }

  void _showChangeCounselorSheet(BuildContext context) {
    final currentCounId = userData?['assignedCounselor'] ?? "";
    final currentStudId = userData?['studId'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String selectedCounId = currentCounId;

        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    "Choose a Counselor",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("Users")
                          .where("role", whereIn: ["Admin", "Counselor"])
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Colors.green.shade600,
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text("No counselors found"),
                          );
                        }

                        final counselors = snapshot.data!.docs;

                        return ListView.builder(
                          itemCount: counselors.length,
                          itemBuilder: (context, index) {
                            final data = counselors[index].data() as Map<String, dynamic>;
                            final fullName = _formatFullName(data);
                            final description = data['description'] ?? '';
                            final assignedCollege = data['assignedCollege'] ?? '';
                            final imageUrl = data['image'];
                            final counId = data['counId'] ?? "";

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.green.shade100,
                                  backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                                      ? NetworkImage(imageUrl)
                                      : null,
                                  child: imageUrl == null || imageUrl.isEmpty
                                      ? Icon(
                                          Icons.person,
                                          size: 25,
                                          color: Colors.green.shade700,
                                        )
                                      : null,
                                ),
                                title: Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      "College: $assignedCollege",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (description.isNotEmpty)
                                      Text(
                                        description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Radio<String>(
                                  value: counId,
                                  groupValue: selectedCounId,
                                  activeColor: Colors.green.shade600,
                                  onChanged: (val) {
                                    setState(() => selectedCounId = val!);
                                  },
                                ),
                                onTap: () {
                                  setState(() => selectedCounId = counId);
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.green.shade600),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(color: Colors.green.shade600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (selectedCounId.isEmpty || selectedCounId == currentCounId) {
                              Navigator.pop(context);
                              return;
                            }

                            try {
                              final studentSnapshot = await FirebaseFirestore
                                  .instance
                                  .collection("Users")
                                  .where("studId", isEqualTo: currentStudId)
                                  .limit(1)
                                  .get();

                              if (studentSnapshot.docs.isNotEmpty) {
                                await studentSnapshot.docs.first.reference.update({
                                  "assignedCounselor": selectedCounId,
                                });

                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text("Counselor updated successfully!"),
                                    backgroundColor: Colors.green.shade600,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error: $e"),
                                  backgroundColor: Colors.red.shade600,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            "Save",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController oldPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    double passwordStrength = 0.0;
    String strengthLabel = "Enter a password";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          height: 4,
                          width: 40,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        "Change Password",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: oldPasswordController,
                        obscureText: obscureOld,
                        decoration: InputDecoration(
                          labelText: "Old Password",
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
                        validator: (value) =>
                            value == null || value.isEmpty ? "Enter old password" : null,
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
                          if (value == null || value.isEmpty) {
                            return "Enter a new password";
                          }
                          if (value.length < 6) {
                            return "Password must be at least 6 characters";
                          }
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
                          if (value != newPasswordController.text) {
                            return "Passwords do not match";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              "Cancel",
                              style: TextStyle(color: Colors.green.shade600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                try {
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user == null || user.email == null) {
                                    throw "No authenticated user found";
                                  }

                                  final credential = EmailAuthProvider.credential(
                                    email: user.email!,
                                    password: oldPasswordController.text,
                                  );
                                  await user.reauthenticateWithCredential(credential);
                                  await user.updatePassword(newPasswordController.text);

                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text("Password updated successfully"),
                                      backgroundColor: Colors.green.shade600,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } catch (e) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error: $e"),
                                      backgroundColor: Colors.red.shade600,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text(
                              "Save",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = userData ?? {};

    return Scaffold(
      backgroundColor: Colors.green.shade600,
      body: SafeArea(
        child: Column(
          children: [
            // Top green section with title and profile info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                      ),
                      const Text(
                        "Profile",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 40), // Balance the row
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Profile card in green section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.green.shade100,
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatFullName(data),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Student ID: ${data['studId'] ?? ''}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // White section with content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 30,
                    horizontal: 20, 
                  ),
                  child: Column(
                    children: [
                      // Student Details Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 0,
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Student Information",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow(Icons.school, "College", data['college'] ?? ''),
                            _buildDetailRow(Icons.menu_book, "Course", data['course'] ?? ''),
                            _buildDetailRow(Icons.calendar_today, "Academic Year", data['academicYear'] ?? ''),
                            _buildDetailRow(Icons.class_, "Section", data['section'] ?? ''),
                            FutureBuilder<String>(
                              future: _getCounselorName(data['assignedCounselor'] ?? ""),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return _buildDetailRow(Icons.person_outline, "Counselor", "Loading...");
                                } else if (snapshot.hasError) {
                                  return _buildDetailRow(Icons.person_outline, "Counselor", "Error");
                                } else {
                                  return _buildDetailRow(Icons.person_outline, "Counselor", snapshot.data ?? "Not Assigned");
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Menu Cards
                      _buildMenuCard(
                        icon: Icons.swap_horiz,
                        title: "Change Assigned Counselor",
                        subtitle: "Update your assigned counselor",
                        onTap: () => _showChangeCounselorSheet(context),
                      ),
                      const SizedBox(height: 16),

                      // Monitoring Status Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 0,
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection("Users")
                              .where("studId", isEqualTo: userData?['studId'])
                              .limit(1)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Text(
                                    "Loading...",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              );
                            }
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.error, color: Colors.red.shade600, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  const Text(
                                    "User not found",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              );
                            }

                            final doc = snapshot.data!.docs.first;
                            final docData = doc.data() as Map<String, dynamic>;
                            final bool isMonitoring = docData['consent'] ?? false;

                            return Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.monitor_heart,
                                    color: Colors.deepPurple.shade600,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Monitoring Status",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isMonitoring
                                            ? "Mood Tracker Monitoring is ON"
                                            : "Mood Tracker Monitoring is OFF",
                                        style: TextStyle(
                                          color: isMonitoring ? Colors.green.shade600 : Colors.red.shade300,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isMonitoring,
                                  activeColor: Colors.green.shade600,
                                  onChanged: (newValue) async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        title: Text(
                                          "Confirm Change",
                                          style: TextStyle(color: Colors.green.shade700),
                                        ),
                                        content: const Text(
                                          "Are you sure you want to change the status of your Mood Tracker Monitoring?\n\n"
                                          "👉 If you turn this ON, the Guidance Office will be able to see your Moods, Emotions, and Journal.\n"
                                          "👉 If you turn this OFF, they will not.",
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
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green.shade600,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text(
                                              "Confirm",
                                              style: TextStyle(color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      try {
                                        await doc.reference.update({"consent": newValue});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(newValue
                                                ? "Monitoring turned ON"
                                                : "Monitoring turned OFF"),
                                            backgroundColor: Colors.green.shade600,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Error updating: $e"),
                                            backgroundColor: Colors.red.shade600,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildMenuCard(
                        icon: Icons.lock,
                        title: "Change Password",
                        subtitle: "Update your account password",
                        onTap: () => _showChangePasswordSheet(context),
                      ),
                      const SizedBox(height: 16),
_buildMenuCard(
  icon: Icons.security,
  title: "Recovery Options",
  subtitle: "Update your recovery email and security question",
  onTap: () async {
    final userSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .where('studId', isEqualTo: userData?['studId'])
        .limit(1)
        .get();

    if (userSnapshot.docs.isNotEmpty) {
      final userDoc = userSnapshot.docs.first;
      _showRecoveryOptionDialog(context, userDoc);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("User not found."),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  },
),

 const SizedBox(height: 16),
                      _buildMenuCard(
                        icon: Icons.logout,
                        title: "Logout",
                        subtitle: "Sign out of your account",
                        isDestructive: true,
                        onTap: () async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text("Confirm Logout"),
      content: const Text("Are you sure you want to log out?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            "Cancel",
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            "Logout",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  if (confirm == true) {
    try {
      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MyApp()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Logout failed: $e"),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
},

                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDestructive 
                        ? Colors.red.shade50 
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive 
                        ? Colors.red.shade600 
                        : Colors.green.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDestructive 
                              ? Colors.red.shade600 
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}