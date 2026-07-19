import 'dart:convert';
import 'dart:ui';
import 'package:rumini/helper/helper_functions.dart';
import 'dart:js_interop';
import 'package:rumini/main.dart';
import 'package:rumini/pages(admin)/userdashboard/userdashboard_Analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:rumini/components/sidebar.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart'; // Import open_file package
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

class UserDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const UserDashboard({super.key, required this.userData});
  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final TextEditingController studIDcontroller = TextEditingController();
  final TextEditingController emailcontroller = TextEditingController();
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController middlenameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController extensionnameController = TextEditingController();
  final TextEditingController collegeController = TextEditingController();
  final TextEditingController counselorIdController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  String selectedUserType = 'Students';
  String? selectedCourse;
  String? selectedAcademicYear;
  String? assignedCounselor;
  String? selectedRole;
  String? assignedCollege;
  String? selectedSection;
  Uint8List? selectedImageBytes;
  bool isExtensionNameNA = false;
  final ScrollController _scrollController = ScrollController();
  bool _isUserListVisible = false;
  bool _isLoadingPassword = false;
  bool _isPasswordVisible = false; // for show/hide password
  final TextEditingController _passwordController = TextEditingController();
  bool showAnalytics = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Uint8List? decodeBase64Image(String? base64Image) {
    if (base64Image == null || base64Image.isEmpty) {
      print('Base64 image is null or empty.');
      return null;
    }
    try {
      // Remove 'data:image/png;base64,' if it's there
      final cleanedBase64 = base64Image.contains(',')
          ? base64Image.split(',').last
          : base64Image;
      return base64Decode(cleanedBase64);
    } catch (e) {
      print('Base64 Decode Error: $e');
      return null;
    }
  }

  final CollectionReference users = FirebaseFirestore.instance.collection(
    "Users",
  );
  final Map<String, List<String>> coursesByCollege = {
    "CEIT": ["BSIT", "BSCE", "BSEE"],
    "CAS": ["BACTA", "BS Psychology", "BS Social Work"],
    "COED": [
      "Bachelor of Early Childhood",
      "BSEd English",
      "BSEd Filipino",
      "BSEd Math",
      "BSEd Science",
      "BSEd Social Studies",
    ],
    "CPAG": ["BS Public Administration"],
    "CABA": [
      "BS Accountancy",
      "BS Financial Management",
      "BS Human Resource Management",
      "BS Marketing Management",
    ],
  };
  final Map<String, List<String>> SectionsByCourse = {
    "BSIT": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BSCE": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BSEE": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "Bachelor of Early Childhood": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BSEd English": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BSEd Filipino": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BSEd Math": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BsEd Science": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BSEd Social Studies": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BS Public Administration": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BS Accountancy": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BS Financial Management": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BS Human Resource Management": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BS Marketing Management": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BACTA": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BS Psychology": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
    "BS Social Work": [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "10",
      "11",
      "12",
      "13",
      "14",
      "15",
    ],
  };
  // Define Academic Year options as a final Map
  final Map<String, String> academicYears = {
    "2018": "2018-2019 AY",
    "2019": "2019-2020 AY",
    "2020": "2020-2021 AY",
    "2021": "2021-2022 AY",
    "2022": "2022-2023 AY",
    "2023": "2023-2024 AY",
    "2024": "2024-2025 AY",
    "2025": "2025-2026 AY",
    "2026": "2026-2027 AY",
    "2027": "2027-2028 AY",
  };
  List<Map<String, dynamic>> counselorsData = [];
  bool isCounselorsLoading = true;
  Future<void> fetchCounselors() async {
    try {
      QuerySnapshot snapshot = await users
          .where('role', whereIn: ['Counselor', 'Admin'])
          .get();
      setState(() {
        counselorsData = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          String fullName =
              "${data['firstName']} ${data['middleName']} ${data['lastName']}";

          return {
            'name': fullName,
            'assignedCollege':
                data['assignedCollege'], // OK if you're using this for college
            'counId':
                data['counId'], // Add counselor ID (You already have this)
            'image': data['image'], // ✅ Add the base64 image field
            'description': data['description'], // ✅ Add the description field
          };
        }).toList();

        isCounselorsLoading = false;
      });
    } catch (e) {
      print("Error fetching counselors: $e");
    }
  }

  // Check if studId already exists
  Future<bool> isStudIdExists(String studId, {String? excludeDocId}) async {
    try {
      QuerySnapshot snapshot = await users
          .where('studId', isEqualTo: studId)
          .get();

      // If updating, exclude the current document
      if (excludeDocId != null) {
        return snapshot.docs.any((doc) => doc.id != excludeDocId);
      }

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error checking studId: $e");
      return false;
    }
  }

  // Check if counId already exists
  Future<bool> isCounIdExists(String counId, {String? excludeDocId}) async {
    try {
      QuerySnapshot snapshot = await users
          .where('counId', isEqualTo: counId)
          .get();

      // If updating, exclude the current document
      if (excludeDocId != null) {
        return snapshot.docs.any((doc) => doc.id != excludeDocId);
      }

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error checking counId: $e");
      return false;
    }
  }

  Future<void> showUserDialog({DocumentSnapshot? documentSnapshot}) async {
    bool isUpdating = documentSnapshot != null;

    // Fetch counselors data immediately when dialog opens
    await fetchCounselors();

    if (isUpdating) {
      print("Firestore Document ID: ${documentSnapshot!.id}");
      // Populate fields for update
      selectedRole = documentSnapshot['role'] ?? '';
      firstnameController.text = documentSnapshot['firstName'] ?? '';
      middlenameController.text = documentSnapshot['middleName'] ?? '';
      lastnameController.text = documentSnapshot['lastName'] ?? '';
      extensionnameController.text = documentSnapshot['extensionName'] ?? '';
      if (selectedRole == "Student") {
        studIDcontroller.text = documentSnapshot['studId'] ?? '';
        collegeController.text = documentSnapshot['college'] ?? '';
        selectedCourse = documentSnapshot['course'] ?? '';
        selectedAcademicYear = documentSnapshot['academicYear'] ?? '';
        assignedCounselor = documentSnapshot['assignedCounselor'] ?? '';
        selectedSection = documentSnapshot['section'] ?? '';
      }
      if (selectedRole == "Counselor" || selectedRole == "Admin") {
        studIDcontroller.text = documentSnapshot['counId'] ?? '';
        assignedCounselor = documentSnapshot['assignedCollege'] ?? '';
        descriptionController.text = documentSnapshot['description'] ?? '';

        final imageString = documentSnapshot['image'];
        if (imageString != null && imageString != '') {
          selectedImageBytes = base64Decode(imageString);
        } else {
          selectedImageBytes = null;
        }
      }
    } else {
      // Clear fields for add
      studIDcontroller.clear();
      firstnameController.clear();
      middlenameController.clear();
      lastnameController.clear();
      extensionnameController.clear();
      collegeController.clear();
      descriptionController.clear();
      selectedCourse = null;
      selectedAcademicYear = null;
      assignedCounselor = null;
      assignedCollege = null;
      selectedRole = null;
      isExtensionNameNA = false;
      selectedImageBytes = null;
      selectedSection = null;
    }

    final parentContext = context;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return myDialogBox(
          title: isUpdating ? "Update User Data" : "Create User",
          condition: isUpdating ? "Update" : "Add User",
          isEmailEditable: !isUpdating,
          isUpdating: isUpdating,
          currentUserData: widget.userData,
          initialRole: selectedRole,
          onPressed: () async {
            // Password confirmation for updates
            if (isUpdating) {
              final TextEditingController passwordController =
                  TextEditingController();
              bool isPasswordVisible = false;

              bool isAuthenticated =
                  await showDialog<bool>(
                    context: parentContext,
                    barrierDismissible: false,
                    builder: (BuildContext dialogContext) {
                      return StatefulBuilder(
                        builder: (context, setState) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            title: Text("Confirm Your Password"),
                            content: TextField(
                              controller: passwordController,
                              obscureText: !isPasswordVisible,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                labelText: 'Password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    isPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      isPasswordVisible = !isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () async {
                                  try {
                                    User? currentUser =
                                        FirebaseAuth.instance.currentUser;
                                    if (currentUser == null ||
                                        currentUser.email == null) {
                                      throw FirebaseAuthException(
                                        code: 'no-user',
                                        message: 'No logged-in user found.',
                                      );
                                    }

                                    AuthCredential credential =
                                        EmailAuthProvider.credential(
                                          email: currentUser.email!,
                                          password: passwordController.text,
                                        );

                                    await currentUser
                                        .reauthenticateWithCredential(
                                          credential,
                                        );
                                    Navigator.of(dialogContext).pop(true);
                                  } on FirebaseAuthException {
                                    ScaffoldMessenger.of(
                                      parentContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text("Incorrect password."),
                                      ),
                                    );
                                  }
                                },
                                child: Text("Confirm"),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ) ??
                  false;

              if (!isAuthenticated) return;
            }

            // Validation and save logic
            String studID = studIDcontroller.text.trim();
            String firstName = firstnameController.text.trim();
            String middleName = middlenameController.text.trim();
            String lastName = lastnameController.text.trim();
            String description = descriptionController.text.trim();
            final String? extensionNameToSave =
                (extensionnameController.text.isEmpty ||
                    extensionnameController.text == "N/A")
                ? null
                : extensionnameController.text.trim();
            String college = collegeController.text.trim();
            String cleanedFirstName = firstName
                .replaceAll(" ", "")
                .toLowerCase();
            String cleanedLastName = lastName.replaceAll(" ", "").toLowerCase();
            String generatedPassword = cleanedLastName + studID;
            String generatedEmail =
                '$cleanedFirstName$cleanedLastName@guidance.com';
            String? imageBase64 = selectedImageBytes != null
                ? base64Encode(selectedImageBytes!)
                : null;

            final bool isCurrentUserCounselor =
                widget.userData['role'] == 'Counselor';

            if (selectedRole == null && !isCurrentUserCounselor) {
              ScaffoldMessenger.of(
                parentContext,
              ).showSnackBar(SnackBar(content: Text("Please select a role")));
              return;
            }

            final String effectiveRole = isCurrentUserCounselor
                ? "Student"
                : selectedRole!;

            if (effectiveRole == "Student") {
              if (studID.isEmpty || firstName.isEmpty || lastName.isEmpty) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Student ID, First Name, and Last Name are required",
                    ),
                  ),
                );
                return;
              }

              // ✅ Check for duplicate studId (only when creating new user)
              if (!isUpdating) {
                bool studIdExists = await isStudIdExists(studID);

                if (studIdExists) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red,
                      content: Text(
                        "Student ID '$studID' already exists. Please use a different ID.",
                      ),
                      duration: Duration(seconds: 4),
                    ),
                  );
                  return;
                }
              }

              String effectiveCollege = college;
              String? effectiveCounselor = assignedCounselor;

              if (isCurrentUserCounselor) {
                effectiveCollege = widget.userData['assignedCollege'] ?? '';
                effectiveCounselor =
                    widget.userData['counId'] ?? widget.userData['uid'] ?? '';

                if (effectiveCollege.isEmpty) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Counselor's college data is missing. Please contact admin.",
                      ),
                    ),
                  );
                  return;
                }
              } else {
                if (selectedCourse == null ||
                    selectedAcademicYear == null ||
                    effectiveCounselor == null ||
                    selectedSection == null ||
                    effectiveCollege.isEmpty) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text("Complete all student fields")),
                  );
                  return;
                }
              }
            }

            if (effectiveRole == "Counselor" || effectiveRole == "Admin") {
              if (assignedCollege == null ||
                  studID.isEmpty ||
                  description.isEmpty) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(content: Text("Complete counselor/admin fields")),
                );
                return;
              }

              // ✅ Check for duplicate counId (only when creating new user)
              if (!isUpdating) {
                bool counIdExists = await isCounIdExists(studID);

                if (counIdExists) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red,
                      content: Text(
                        "Counselor/Admin ID '$studID' already exists. Please use a different ID.",
                      ),
                      duration: Duration(seconds: 4),
                    ),
                  );
                  return;
                }
              }
            }

            try {
              if (isUpdating) {
                // ✅ UPDATE MODE - studId/counId cannot be changed, so we don't include them
                if (effectiveRole == "Student") {
                  await users.doc(documentSnapshot!.id).update({
                    'firstName': firstName,
                    'middleName': middleName,
                    'lastName': lastName,
                    'extensionName': extensionNameToSave,
                    // ❌ NOT UPDATING studId - it stays the same
                    'college': isCurrentUserCounselor
                        ? widget.userData['assignedCollege']
                        : college,
                    'course': selectedCourse,
                    'academicYear': selectedAcademicYear,
                    'assignedCounselor': isCurrentUserCounselor
                        ? widget.userData['counId']
                        : assignedCounselor,
                    'role': effectiveRole,
                    'section': selectedSection,
                  });
                } else if (effectiveRole == "Counselor" ||
                    effectiveRole == "Admin") {
                  await users.doc(documentSnapshot!.id).update({
                    'firstName': firstName,
                    'middleName': middleName,
                    'lastName': lastName,
                    'extensionName': extensionNameToSave,
                    // ❌ NOT UPDATING counId - it stays the same
                    'assignedCollege': assignedCollege,
                    'role': effectiveRole,
                    'image': imageBase64,
                    'description': description,
                  });
                }

                // Show success message
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green,
                    content: Text("User updated successfully!"),
                  ),
                );

                Navigator.pop(context);
              } else {
                // ✅ CREATE MODE - Use Cloud Function
                // Show loading dialog
                showDialog(
                  context: parentContext,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 20),
                          Text("Creating user account..."),
                        ],
                      ),
                    );
                  },
                );

                // Prepare user data based on role
                Map<String, dynamic> newUserData = {
                  'email': generatedEmail,
                  'firstName': firstName,
                  'middleName': middleName,
                  'lastName': lastName,
                  'extensionName': extensionNameToSave,
                  'role': effectiveRole,
                };

                if (effectiveRole == "Student") {
                  newUserData.addAll({
                    'studId': studID,
                    'college': isCurrentUserCounselor
                        ? widget.userData['assignedCollege']
                        : college,
                    'course': selectedCourse,
                    'academicYear': selectedAcademicYear,
                    'assignedCounselor': isCurrentUserCounselor
                        ? widget.userData['counId']
                        : assignedCounselor,
                    'section': selectedSection,
                  });
                } else if (effectiveRole == "Counselor" ||
                    effectiveRole == "Admin") {
                  newUserData.addAll({
                    'counId': studID,
                    'assignedCollege': assignedCollege,
                    'image': imageBase64,
                    'description': description,
                  });
                }

                // Call Cloud Function to create user
                final callable = FirebaseFunctions.instance.httpsCallable(
                  'createUserAccount',
                );
                final result = await callable.call({
                  'email': generatedEmail,
                  'password': generatedPassword,
                  'userData': newUserData,
                });

                // Close loading dialog
                Navigator.of(parentContext).pop();

                if (result.data['success'] == true) {
                  // Show success message
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green,
                      content: Text("User created successfully!"),
                    ),
                  );

                  Navigator.pop(context);
                } else {
                  throw Exception('Failed to create user account');
                }
              }
            } catch (e) {
              // Close loading dialog if it's open
              if (!isUpdating && Navigator.canPop(parentContext)) {
                Navigator.of(parentContext).pop();
              }

              // Show error dialog
              showDialog(
                context: parentContext,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("Error"),
                    content: Text("Error: $e"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("OK"),
                      ),
                    ],
                  );
                },
              );
            }
          },
        );
      },
    );
  }

  //delete function
  Future<void> delete(String userId, DocumentSnapshot documentSnapshot) async {
    final TextEditingController passwordController = TextEditingController();

    // Get the user data to retrieve studId or counId
    final userData = documentSnapshot.data() as Map<String, dynamic>;
    final String? studId = userData['studId'];
    final String? counId = userData['counId'];
    final String? uid =
        userData['uid'] ?? documentSnapshot.id; // Use doc.id as fallback

    // Store the parent context before opening the dialog
    final parentContext = context;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool isPasswordVisible = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Column(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 50),
                  SizedBox(height: 10),
                  Text(
                    "Enter your password to confirm deletion",
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  Text(
                    userId,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: passwordController,
                    obscureText: !isPasswordVisible,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            isPasswordVisible = !isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text("Cancel", style: TextStyle(color: Colors.black)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();

                    // Show loading indicator
                    showDialog(
                      context: parentContext,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return Center(child: CircularProgressIndicator());
                      },
                    );

                    try {
                      User? currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null || currentUser.email == null) {
                        throw FirebaseAuthException(
                          code: 'no-user',
                          message: 'No logged-in user found.',
                        );
                      }

                      // Re-authenticate
                      AuthCredential credential = EmailAuthProvider.credential(
                        email: currentUser.email!,
                        password: passwordController.text,
                      );
                      await currentUser.reauthenticateWithCredential(
                        credential,
                      );

                      // ✅ DELETE ALL RELATED DOCUMENTS FROM ALL COLLECTIONS
                      await deleteUserFromAllCollections(
                        studId,
                        counId,
                        uid,
                        documentSnapshot.id,
                      );

                      // ✅ Delete user from Firebase Authentication
                      if (uid != null && uid.isNotEmpty) {
                        // If deleting own account
                        if (currentUser.uid == uid) {
                          await currentUser.delete();
                          print(
                            "✅ Current user deleted from Firebase Authentication",
                          );
                        } else {
                          // If admin/counselor is deleting another user via Cloud Function
                          try {
                            final callable = FirebaseFunctions.instance
                                .httpsCallable('deleteUser');
                            final result = await callable.call({'uid': uid});
                            print("✅ ${result.data['message']}");
                          } catch (cloudFunctionError) {
                            print(
                              "⚠️ Cloud Function error: $cloudFunctionError",
                            );
                            // Show warning but continue since Firestore data is deleted
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 5),
                                content: Text(
                                  "User data deleted, but couldn't remove from Authentication. The user account may still exist.",
                                ),
                              ),
                            );
                          }
                        }
                      }

                      // Close loading dialog
                      Navigator.of(parentContext).pop();

                      // Show success message
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 8),
                          content: Text(
                            "User '$userId' and all related data have been deleted successfully.",
                          ),
                        ),
                      );

                      // If user deleted their own account, navigate to login
                      if (currentUser.uid == uid) {
                        Navigator.of(
                          parentContext,
                        ).pushReplacementNamed('/login');
                      }
                    } on FirebaseAuthException {
                      // Close loading dialog
                      Navigator.of(parentContext).pop();

                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                          content: Text(
                            "Password incorrect or authentication failed.",
                          ),
                        ),
                      );
                    } catch (e) {
                      // Close loading dialog
                      Navigator.of(parentContext).pop();

                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                          content: Text("Error deleting user: $e"),
                        ),
                      );
                    }
                  },
                  child: Text(
                    "Yes, Delete",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ Helper function to delete user from all collections
  Future<void> deleteUserFromAllCollections(
    String? studId,
    String? counId,
    String? uid,
    String documentId,
  ) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    // List all your collections here
    final collectionsToCheck = [
      'OTP',
      'answer_form',
      'appointments',
      'chatbot_responses',
      'emotionLogs',
      'feedback',
      'forms',
      'inquiry_escalations',
      'moodLogs',
      'notificationRequests',
      'notifications',
      'psychoeduc_ads',
      'questions',
      'templates',
    ];

    for (String collectionName in collectionsToCheck) {
      try {
        // Query and delete documents where studId matches
        if (studId != null && studId.isNotEmpty) {
          QuerySnapshot studSnapshot = await firestore
              .collection(collectionName)
              .where('studId', isEqualTo: studId)
              .get();

          for (var doc in studSnapshot.docs) {
            await doc.reference.delete();
            print("Deleted document from $collectionName with studId: $studId");
          }
        }

        // Query and delete documents where counId matches
        if (counId != null && counId.isNotEmpty) {
          QuerySnapshot counSnapshot = await firestore
              .collection(collectionName)
              .where('counId', isEqualTo: counId)
              .get();

          for (var doc in counSnapshot.docs) {
            await doc.reference.delete();
            print("Deleted document from $collectionName with counId: $counId");
          }
        }

        // Query and delete documents where uid matches
        if (uid != null && uid.isNotEmpty) {
          QuerySnapshot uidSnapshot = await firestore
              .collection(collectionName)
              .where('uid', isEqualTo: uid)
              .get();

          for (var doc in uidSnapshot.docs) {
            await doc.reference.delete();
            print("Deleted document from $collectionName with uid: $uid");
          }
        }
      } catch (e) {
        print("Error deleting from $collectionName: $e");
        // Continue with other collections even if one fails
      }
    }

    // Finally, delete the user document from Users collection
    try {
      await firestore.collection('Users').doc(documentId).delete();
      print(
        "✅ Successfully deleted user document from Users collection with ID: $documentId",
      );
    } catch (e) {
      print("❌ Error deleting user document from Users collection: $e");
    }
  }

  // Also update the processCSVData function to handle quoted section values
  Future<void> processCSVData(
    String csvString,
    Map<String, dynamic> userData,
  ) async {
    try {
      // Parse CSV with more robust settings
      List<List<dynamic>> csvTable = const CsvToListConverter(
        eol: '\n',
        fieldDelimiter: ',',
        allowInvalid: false,
        shouldParseNumbers:
            false, // Keep everything as strings for consistent processing
        textDelimiter: '"', // Add text delimiter to handle quoted strings
        textEndDelimiter: '"', // Add text end delimiter
      ).convert(csvString);

      // Validate headers and structure
      if (csvTable.isEmpty) {
        throw Exception("The CSV file is empty");
      }

      List<String> headers = csvTable[0]
          .map((header) => header.toString().trim())
          .toList();

      // Get current user's role and assigned college (for counselors)
      String currentUserRole = userData['role'] ?? '';
      String? counselorAssignedCollege =
          currentUserRole.toLowerCase() == 'counselor'
          ? userData['assignedCollege']
          : null;

      // Determine file type based on headers (Student or Staff)
      bool isStudentFile =
          headers.contains("Student ID") && headers.contains("Course");
      bool isStaffFile =
          headers.contains("Staff ID") ||
          (headers.contains("Role") &&
              (headers.contains("COUN") ||
                  headers.contains("ADMIN") ||
                  headers.contains("Counselor") ||
                  headers.contains("Admin")));

      // Handle role-based permissions
      if (currentUserRole.toLowerCase() == 'counselor' && !isStudentFile) {
        throw Exception("As a Counselor, you can only upload student data.");
      }

      // Validate expected headers based on detected file type
      List<String> expectedHeaders;
      if (isStudentFile) {
        expectedHeaders = [
          "Student ID",
          "First Name",
          "Middle Name",
          "Last Name",
          "Extension Name",
          "College",
          "Course",
          "Academic Year",
          "Assigned Counselor",
          "Role",
          "Section",
        ];
      } else if (isStaffFile && currentUserRole.toLowerCase() == 'admin') {
        expectedHeaders = [
          "Staff ID",
          "First Name",
          "Middle Name",
          "Last Name",
          "Extension Name",
          "Assigned College",
          "Role",
        ];
      } else {
        throw Exception(
          "Unknown CSV format. Please download and use one of the sample templates.",
        );
      }

      // Validate headers for the detected file type
      for (String header in expectedHeaders) {
        if (!headers.contains(header)) {
          throw Exception(
            "Missing required column: $header. Please download the appropriate sample CSV file for reference.",
          );
        }
      }

      // Get column indices (more robust than assuming positions)
      int idIndex = headers.indexOf(isStudentFile ? "Student ID" : "Staff ID");
      int firstNameIndex = headers.indexOf("First Name");
      int middleNameIndex = headers.indexOf("Middle Name");
      int lastNameIndex = headers.indexOf("Last Name");
      int extensionNameIndex = headers.indexOf("Extension Name");
      int collegeIndex = headers.indexOf(
        isStudentFile ? "College" : "Assigned College",
      );
      int roleIndex = headers.indexOf("Role");

      // Student-specific indices
      int? courseIndex = isStudentFile ? headers.indexOf("Course") : null;
      int? academicYearIndex = isStudentFile
          ? headers.indexOf("Academic Year")
          : null;
      int? counselorIndex = isStudentFile
          ? headers.indexOf("Assigned Counselor")
          : null;
      int? sectionIndex = isStudentFile ? headers.indexOf("Section") : null;

      // Define allowed values for student fields
      final List<String> allowedColleges = [
        "CEIT",
        "CABA",
        "CAS",
        "COED",
        "CPAG",
      ];
      final List<String> allowedCourses = [
        "BSIT",
        "BSCE",
        "BSEE",
        "BS Psychology",
        "BACTA",
        "BS Social Work",
        "Bachelor of Early Childhood",
        "BSEd English",
        "BSEd Filipino",
        "BSEd Math",
        "BSEd Science",
        "BSEd Social Studies",
        "BS Public Administration",
        "BS Accountancy",
        "BS Financial Management",
        "BS Human Resource Management",
        "BS Marketing Management",
      ];

      final List<String> allowedSections = [
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
        "10",
        "11",
        "12",
        "13",
        "14",
        "15",
      ];

      final List<String> allowedAcademicYears = [
        "2018-2019 AY",
        "2019-2020 AY",
        "2020-2021 AY",
        "2021-2022 AY",
        "2022-2023 AY",
        "2023-2024 AY",
        "2024-2025 AY",
        "2025-2026 AY",
        "2026-2027 AY",
        "2027-2028 AY",
      ];

      // Start batch processing
      List<Map<String, dynamic>> usersData = [];
      List<String> errors = [];
      List<String> warnings = [];

      // Process data rows (skip header)
      for (int i = 1; i < csvTable.length; i++) {
        try {
          List<dynamic> row = csvTable[i];

          // Skip empty rows
          if (row.isEmpty ||
              row.every(
                (cell) => cell == null || cell.toString().trim().isEmpty,
              )) {
            continue;
          }

          // Validate row length
          if (row.length < expectedHeaders.length) {
            errors.add(
              "Row ${i + 1}: Not enough columns. Expected ${expectedHeaders.length}, got ${row.length}. Skipping row.",
            );
            continue;
          }

          // Extract data with proper handling of null/empty values
          String id = row[idIndex]?.toString().trim() ?? "";
          String firstName = row[firstNameIndex]?.toString().trim() ?? "";
          String middleName = row[middleNameIndex]?.toString().trim() ?? "";
          String lastName = row[lastNameIndex]?.toString().trim() ?? "";
          String extensionName =
              row[extensionNameIndex]?.toString().trim() ?? "";
          String college = row[collegeIndex]?.toString().trim() ?? "";
          String role = row[roleIndex]?.toString().trim() ?? "";

          // Student-specific data
          String course = isStudentFile
              ? (row[courseIndex!]?.toString().trim() ?? "")
              : "";
          String academicYear = isStudentFile
              ? (row[academicYearIndex!]?.toString().trim() ?? "")
              : "";
          String assignedCounselor = isStudentFile
              ? (row[counselorIndex!]?.toString().trim() ?? "")
              : "";
          String section = isStudentFile
              ? (row[sectionIndex!]?.toString().trim().replaceAll("'", "") ??
                    "")
              : "";

          // Validate required fields
          if (id.isEmpty ||
              firstName.isEmpty ||
              lastName.isEmpty ||
              role.isEmpty) {
            errors.add(
              "Row ${i + 1}: Missing required fields (ID, First Name, Last Name, or Role). Skipping row.",
            );
            continue;
          }

          // For counselors, verify the college matches their assigned college
          if (currentUserRole.toLowerCase() == 'counselor' &&
              college != counselorAssignedCollege) {
            errors.add(
              "Row ${i + 1}: Student college ($college) does not match your assigned college ($counselorAssignedCollege). Skipping row.",
            );
            continue;
          }

          // Validate student-specific fields if this is a student record
          if (isStudentFile && role.toLowerCase() == "student") {
            // Validate College
            if (!allowedColleges.contains(college)) {
              errors.add(
                "Row ${i + 1}: Invalid College '$college'. Must be one of: ${allowedColleges.join(', ')}. Skipping row.",
              );
              continue;
            }

            // Validate Course
            if (!allowedCourses.contains(course)) {
              errors.add(
                "Row ${i + 1}: Invalid Course '$course'. Must be one of: ${allowedCourses.join(', ')}. Skipping row.",
              );
              continue;
            }

            // Validate Section
            if (!allowedSections.contains(section)) {
              errors.add(
                "Row ${i + 1}: Invalid Section '$section'. Must be one of: ${allowedSections.join(', ')}. Skipping row.",
              );
              continue;
            }

            // Validate Academic Year
            if (!allowedAcademicYears.contains(academicYear)) {
              errors.add(
                "Row ${i + 1}: Invalid Academic Year '$academicYear'. Must be one of: ${allowedAcademicYears.join(', ')}. Skipping row.",
              );
              continue;
            }
          }

          // For counselors, auto-assign themselves as the counselor if field is empty
          if (currentUserRole.toLowerCase() == 'counselor' &&
              (assignedCounselor.isEmpty || assignedCounselor == "")) {
            assignedCounselor = userData['counId'] ?? "";
            warnings.add(
              "Row ${i + 1}: Automatically assigned you as the counselor for ${firstName} ${lastName}.",
            );
          }

          // Auto-generate email and password
          String cleanedFirstName = firstName.replaceAll(" ", "").toLowerCase();
          String cleanedLastName = lastName.replaceAll(" ", "").toLowerCase();
          String generatedPassword = cleanedLastName + id;
          String generatedEmail =
              '$cleanedFirstName$cleanedLastName@guidance.com';

          try {
            // 🔍 Check Firestore for duplicate studId or counId
            final existingUserQuery = await FirebaseFirestore.instance
                .collection('Users')
                .where(isStudentFile ? 'studId' : 'counId', isEqualTo: id)
                .get();

            if (existingUserQuery.docs.isNotEmpty) {
              errors.add(
                "Row ${i + 1}: Duplicate ${(isStudentFile ? 'Student ID' : 'Counselor ID')} '$id' already exists in Firestore. Skipping row.",
              );
              continue; // Skip this row
            }

            // Create user in Firebase Authentication
            UserCredential userCredential = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
                  email: generatedEmail,
                  password: generatedPassword,
                );

            String uid = userCredential.user!.uid;

            // Prepare user data for Firestore
            Map<String, dynamic> newUserData = {
              'uid': uid,
              'email': generatedEmail,
              'firstName': firstName,
              'middleName': middleName,
              'lastName': lastName,
              'extensionName': extensionName.isEmpty ? null : extensionName,
              'role': role,
            };

            // Add role-specific fields
            if (role.toLowerCase() == "student") {
              newUserData.addAll({
                'studId': id,
                'college': college,
                'course': course,
                'academicYear': academicYear,
                'assignedCounselor': assignedCounselor,
                'section': section,
              });
            } else if (role.toLowerCase() == "counselor" ||
                role.toLowerCase() == "admin") {
              newUserData.addAll({
                'counId': id,
                'assignedCollege': college,
                'description':
                    "Imported via batch upload", // Default description
                'image': null, // Initialize image field for staff users only
              });
            }

            usersData.add(newUserData);
          } catch (authError) {
            // Handle Firebase Auth errors specifically
            if (authError is FirebaseAuthException) {
              if (authError.code == 'email-already-in-use') {
                errors.add(
                  "Row ${i + 1}: Generated email $generatedEmail already exists. Skipping row.",
                );
              } else {
                errors.add(
                  "Row ${i + 1}: Auth error for $generatedEmail - ${authError.message}",
                );
              }
            } else {
              errors.add(
                "Row ${i + 1}: Error creating user $generatedEmail - $authError",
              );
            }
          }
        } catch (rowError) {
          errors.add("Error processing row ${i + 1}: $rowError");
        }
      }

      // Check if we have any users to add
      if (usersData.isEmpty) {
        throw Exception(
          "No valid users found in CSV file or all users had errors${errors.isNotEmpty ? ':\n' + errors.join('\n') : ''}",
        );
      }

      // Batch Write to Firestore
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var newUser in usersData) {
        DocumentReference userRef = FirebaseFirestore.instance
            .collection("Users")
            .doc(newUser['uid']);
        batch.set(userRef, newUser);
      }

      await batch.commit();

      // Display results to user
      String message = "Successfully imported ${usersData.length} users";
      if (errors.isNotEmpty || warnings.isNotEmpty) {
        message +=
            " with ${errors.length} errors and ${warnings.length} warnings.";

        // Show detailed errors and warnings in a dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Batch Upload Results"),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Successfully imported: ${usersData.length} users"),
                    if (errors.isNotEmpty) Text("Errors: ${errors.length}"),
                    if (warnings.isNotEmpty)
                      Text("Warnings: ${warnings.length}"),
                    SizedBox(height: 10),
                    if (errors.isNotEmpty) ...[
                      Text(
                        "Error Details:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...errors
                          .map(
                            (error) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                "• $error",
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      SizedBox(height: 10),
                    ],
                    if (warnings.isNotEmpty) ...[
                      Text(
                        "Warning Details:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      ...warnings
                          .map(
                            (warning) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                "• $warning",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("OK"),
                ),
              ],
            );
          },
        );
      } else {
        message += ".";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          duration: Duration(seconds: 8),
          content: Text(message),
        ),
      );
    } catch (e) {
      // Show error dialog for complete failure
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Batch Upload Failed"),
            content: Text("Error: ${e.toString()}"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          );
        },
      );
    }
    // 🔒 Auto logout after batch upload
    await FirebaseAuth.instance.signOut();

    // Optional: short delay to let the snackbar show
    await Future.delayed(const Duration(seconds: 1));

    // 🧭 Redirect to login page (replace with your actual login page widget)
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You have been logged out for security after the batch upload.",
          ),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MyApp()),
        (route) => false,
      );
    }
  }

  // Fixed sample file creation function to prevent Excel from converting section formats from "1-2" to dates
  Future<void> createStudentSampleCSVFile(Map<String, dynamic> userData) async {
    // Get current user's role and assigned college (for counselors)
    String currentUserRole = userData['role'] ?? '';
    String? counselorAssignedCollege =
        currentUserRole.toLowerCase() == 'Counselor'
        ? userData['assignedCollege']?.toString() ?? ""
        : null;
    String? counselorId = currentUserRole.toLowerCase() == 'counselor'
        ? userData['counId']?.toString() ?? ""
        : null;

    // Make sure counselor's assigned college is one of the allowed colleges
    final List<String> allowedColleges = [
      "CEIT",
      "CABA",
      "CAS",
      "COED",
      "CPAG",
    ];
    if (counselorAssignedCollege != null &&
        !allowedColleges.contains(counselorAssignedCollege)) {
      counselorAssignedCollege =
          allowedColleges[0]; // Default to first college if invalid
    }

    // Mapping of colleges to appropriate courses for more realistic samples
    Map<String, List<String>> collegeCoursesMap = {
      "CEIT": ["BSIT", "BSCE", "BSEE"],
      "CAS": ["BACTA", "BS Psychology", "BS Social Work"],
      "COED": [
        "Bachelor of Early Childhood",
        "BSEd English",
        "BSEd Filipino",
        "BSEd Math",
        "BSEd Science",
        "BSEd Social Studies",
      ],
      "CPAG": ["BS Public Administration"],
      "CABA": [
        "BS Accountancy",
        "BS Financial Management",
        "BS Human Resource Management",
        "BS Marketing Management",
      ],
    };

    // Create a sample CSV specifically for Student data - tailored for the current user
    List<List<String>> sampleData = [
      // Header row for Students
      [
        "Student ID",
        "First Name",
        "Middle Name",
        "Last Name",
        "Extension Name",
        "College",
        "Course",
        "Academic Year",
        "Assigned Counselor",
        "Role",
        "Section",
      ],
    ];

    // For counselors, include sample data with their assigned college and counselor ID
    if (currentUserRole.toLowerCase() == 'counselor' &&
        counselorAssignedCollege != null) {
      // Get appropriate courses for this college
      List<String> appropriateCourses =
          collegeCoursesMap[counselorAssignedCollege] ?? ["BSIT", "BSCE"];
      if (appropriateCourses.length < 2)
        appropriateCourses = ["BSIT", "BSCE"]; // Fallback if not enough courses

      String course1 = appropriateCourses[0];
      String course2 = appropriateCourses.length > 1
          ? appropriateCourses[1]
          : appropriateCourses[0];

      sampleData.addAll([
        [
          "2023-0001",
          "John",
          "Smith",
          "Doe",
          "",
          counselorAssignedCollege,
          course1,
          "2024-2025 AY",
          counselorId ?? "",
          "Student",
          "'1'",
        ], // Note the quotes to prevent Excel date conversion
        [
          "2023-0002",
          "Jane",
          "Ellen",
          "Smith",
          "",
          counselorAssignedCollege,
          course2,
          "2024-2025 AY",
          counselorId ?? "",
          "Student",
          "'1'",
        ],
        [
          "2023-0003",
          "Michael",
          "David",
          "Johnson",
          "",
          counselorAssignedCollege,
          course1,
          "2023-2024 AY",
          counselorId ?? "",
          "Student",
          "'3'",
        ],
        [
          "2023-0004",
          "Emily",
          "Rose",
          "Williams",
          "Jr.",
          counselorAssignedCollege,
          course2,
          "2023-2024 AY",
          counselorId ?? "",
          "Student",
          "'4'",
        ],
      ]);
    } else {
      // For admins, create sample data with appropriate courses for each college
      sampleData.addAll([
        [
          "2023-0001",
          "John",
          "Smith",
          "Doe",
          "",
          "CEIT",
          "BSIT",
          "2024-2025 AY",
          "COUN-001",
          "Student",
          "'1'",
        ],
        [
          "2023-0002",
          "Jane",
          "Ellen",
          "Smith",
          "",
          "CAS",
          "BS Psychology",
          "2024-2025 AY",
          "COUN-002",
          "Student",
          "'2'",
        ],
        [
          "2023-0003",
          "Michael",
          "David",
          "Johnson",
          "",
          "CEIT",
          "BSCE",
          "2023-2024 AY",
          "COUN-001",
          "Student",
          "'3'",
        ],
        [
          "2023-0004",
          "Emily",
          "Rose",
          "Williams",
          "Jr.",
          "CAS",
          "BACTA",
          "2023-2024 AY",
          "COUN-002",
          "Student",
          "'4'",
        ],
        [
          "2023-0005",
          "Alex",
          "James",
          "Taylor",
          "",
          "COED",
          "Bachelor of Early Childhood",
          "2023-2024 AY",
          "COUN-003",
          "Student",
          "'3'",
        ],
        [
          "2023-0006",
          "Sarah",
          "Lynn",
          "Brown",
          "",
          "CPAG",
          "BS Public Administration",
          "2024-2025 AY",
          "COUN-004",
          "Student",
          "'3'",
        ],
        [
          "2023-0007",
          "Daniel",
          "Thomas",
          "Martin",
          "",
          "CABA",
          "BS Accountancy",
          "2023-2024 AY",
          "COUN-005",
          "Student",
          "'1'",
        ],
        [
          "2023-0008",
          "Olivia",
          "Grace",
          "Wilson",
          "",
          "CABA",
          "BS Marketing Management",
          "2024-2025 AY",
          "COUN-005",
          "Student",
          "'2'",
        ],
      ]);
    }

    // Convert to CSV with double quote option to preserve section format
    String csv = const ListToCsvConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
      textEndDelimiter: '"',
    ).convert(sampleData);

    if (kIsWeb) {
      // Web: Create a downloadable blob
      final bytes = utf8.encode(csv);
      final jsArray = bytes.toJS;
      final blob = web.Blob([jsArray].toJS);
      final url = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = "student_batch_upload_sample.csv"
        ..click();
      web.URL.revokeObjectURL(url);
    } else {
      // Mobile/Desktop: Save to file
      final Directory tempDir = await getTemporaryDirectory();
      final File file = File('${tempDir.path}/student_batch_upload_sample.csv');

      await file.writeAsString(csv, flush: true);
      OpenFile.open(file.path);
    }
  }

  // Also update the sample staff CSV file creation for consistency
  Future<void> createStaffSampleCSVFile() async {
    // Create a sample CSV specifically for Counselor/Admin data
    List<List<String>> sampleData = [
      // Header row for Counselor/Admin
      [
        "Staff ID",
        "First Name",
        "Middle Name",
        "Last Name",
        "Extension Name",
        "Assigned College",
        "Role",
      ],
      // Example counselor data
      ["COUN-001", "Robert", "James", "Johnson", "", "CEIT", "Counselor"],
      ["COUN-002", "Maria", "Elena", "Garcia", "", "CAS", "Counselor"],
      // Example admin data
      ["ADMIN-001", "Susan", "Marie", "Brown", "", "CPAG", "Admin"],
      ["ADMIN-002", "David", "Alan", "Wilson", "Jr", "COED", "Admin"],
    ];

    // Convert to CSV with consistent text delimiter
    String csv = const ListToCsvConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
      textEndDelimiter: '"',
    ).convert(sampleData);

    if (kIsWeb) {
      // Web: Create a downloadable blob
      final bytes = utf8.encode(csv);
      final jsArray = bytes.toJS;
      final blob = web.Blob([jsArray].toJS);
      final url = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = "staff_batch_upload_sample.csv"
        ..click();
      web.URL.revokeObjectURL(url);
    } else {
      // Mobile/Desktop: Save to file
      final Directory tempDir = await getTemporaryDirectory();
      final File file = File('${tempDir.path}/staff_batch_upload_sample.csv');

      await file.writeAsString(csv, flush: true);
      OpenFile.open(file.path);
    }
  }

  // Modified dialog to include information about allowed values
  void showBatchUploadDialog(
    BuildContext context,
    Map<String, dynamic> userData,
  ) {
    // Get current user's role
    String currentUserRole = userData['role'] ?? '';
    String? counselorAssignedCollege =
        currentUserRole.toLowerCase() == 'counselor'
        ? userData['assignedCollege']
        : null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.upload_file, color: Color(0xFFE2C013)),
              SizedBox(width: 10),
              Text("Batch User Upload"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentUserRole.toLowerCase() == 'counselor'
                      ? "Upload a CSV file containing student information for batch processing. As a Counselor, you can only upload students for your assigned college: $counselorAssignedCollege."
                      : "Upload a CSV file containing user information for batch processing.",
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 15),
                Divider(),
                Text(
                  "Student Template Fields:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 5),
                Text(
                  "• Student ID (required)\n• First Name (required)\n• Last Name (required)\n• Middle Name\n• Extension Name\n• College${currentUserRole.toLowerCase() == 'counselor' ? ' (must match your assigned college)' : ''}\n• Course\n• Academic Year\n• Assigned Counselor${currentUserRole.toLowerCase() == 'counselor' ? ' (will default to you if empty)' : ''}\n• Role (must be 'Student')\n• Section",
                ),

                SizedBox(height: 15),
                Text(
                  "⚠️ Required Field Formats:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "• College: Must be one of CEIT, CABA, CAS, COED, CPAG\n"
                  "• Course: Must be one of BSIT, BSCE, BSEE, BS Psychology, BACTA, BS Social Work, Bachelor of Early Childhood, BSEd English, BSEd Filipino,BSEd Math, BSEd Science, BSEd Social Studies, BS Public Administration, BS Accountancy, BS Financial Management, BS Human Resource Management, BS Marketing Management\n"
                  "• Section: Must be one of 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15\n"
                  "• Academic Year: Must be one of 2018-2019 AY, 2019-2020 AY, 2020-2021 AY, 2021-2022 AY, 2022-2023 AY, 2023-2024 AY, 2024-2025 AY, 2025-2026 AY, 2026-2027 AY, 2027-2028 AY",
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),

                // Only show Staff Template fields to Admin users
                if (currentUserRole.toLowerCase() == 'admin') ...[
                  SizedBox(height: 15),
                  Divider(),
                  Text(
                    "Staff Template Fields:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "• Staff ID (required)\n• First Name (required)\n• Last Name (required)\n• Middle Name\n• Extension Name\n• Assigned College\n• Role (must be 'Counselor' or 'Admin')",
                  ),
                ],

                SizedBox(height: 15),
                Divider(),
                Text(
                  "⚠️ Auto-generated fields:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "• Email: [firstname][lastname]@guidance.com\n• Password: [lastname][ID]",
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),
          ),
          actions: [
            if (currentUserRole.toLowerCase() == 'admin')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text(
                        "For Students",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          await createStudentSampleCSVFile(userData);
                        },
                        icon: Icon(Icons.download, color: Colors.blue),
                        label: Text(
                          "Download Template",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        "For Staff",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          await createStaffSampleCSVFile();
                        },
                        icon: Icon(Icons.download, color: Colors.blue),
                        label: Text(
                          "Download Template",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    await createStudentSampleCSVFile(userData);
                  },
                  icon: Icon(Icons.download, color: Colors.blue),
                  label: Text(
                    "Download Student Template",
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ),
            SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  batchUploadCSV(userData);
                },
                icon: Icon(Icons.upload_file, color: Color(0xFFE2C013)),
                label: Text(
                  "Upload CSV",
                  style: TextStyle(color: Color(0xFFE2C013)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Modified batch upload function to pass user data
  Future<void> batchUploadCSV(Map<String, dynamic> userData) async {
    if (kIsWeb) {
      // Web file picker with loading dialog
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
                    Future.microtask(() => processCSVData(csvString, userData));
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
    } else {
      // Mobile/Desktop file picker
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (result != null) {
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
                    Text("Processing CSV data"),
                  ],
                ),
              );
            },
          );

          try {
            String filePath = result.files.single.path!;
            final file = File(filePath);
            final csvString = await file.readAsString();

            // Close the dialog
            Navigator.pop(context);

            // Process the data
            await processCSVData(csvString, userData);
          } catch (e) {
            // Close the dialog
            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red,
                content: Text("Error reading CSV file: $e"),
              ),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("Error selecting file: $e"),
          ),
        );
      }
    }
  }

  // Example of how to call the batch upload functionality with user data
  void initiateUserBatchUpload(
    BuildContext context,
    Map<String, dynamic> userData,
  ) {
    // Check if user is authorized (Admin or Counselor)
    String userRole = userData['role'] ?? '';
    if (userRole.toLowerCase() == 'admin' ||
        userRole.toLowerCase() == 'counselor') {
      showBatchUploadDialog(context, userData);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("You do not have permission to perform batch uploads."),
        ),
      );
    }
  }

  // eto yung table list view of users details (PWEDE I EDIT )
  @override
  Widget build(BuildContext context) {
    final String currentUserRole = widget.userData['role'] ?? '';
    final bool isAdmin = currentUserRole == 'Admin';
    final bool isCounselor = currentUserRole == 'Counselor';

    return Material(
      child: Row(
        children: [
          Sidebar(userData: widget.userData),
          Expanded(
            child: Scaffold(
              backgroundColor: const Color.fromARGB(255, 232, 232, 232),
              appBar: AppBar(
                backgroundColor: const Color.fromARGB(255, 232, 232, 232),
                title: const Row(
                  children: [
                    Icon(Icons.dashboard, color: Color(0xFF345F00)),
                    SizedBox(width: 8),
                    Text("User Dashboard"),
                  ],
                ),
                titleTextStyle: const TextStyle(
                  color: Color(0xFF345F00),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20.0,
                  horizontal: 100.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FIRST CARD - Search + Buttons (hide certain buttons for non-admins)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 300,
                              child: TextField(
                                controller: searchController,
                                decoration: InputDecoration(
                                  hintText: " Search users...",
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30.0),
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    searchQuery = value.toLowerCase();
                                  });
                                },
                              ),
                            ),
                            const Spacer(),
                            // Only show these buttons for Admin users
                            if (isAdmin || isCounselor) ...[
                              ElevatedButton.icon(
                                onPressed: showUserDialog,
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "Add User",
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () => showBatchUploadDialog(
                                  context,
                                  widget.userData,
                                ),
                                icon: const Icon(
                                  Icons.upload_file,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "Batch Upload",
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE2C013),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    showAnalytics =
                                        !showAnalytics; // toggle visibility
                                  });
                                },
                                icon: const Icon(
                                  Icons.analytics,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  showAnalytics
                                      ? "Hide Analytics"
                                      : "Show Analytics",
                                  style: const TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // SECOND CARD - Dashboard Analytics + User Lists (both password-protected)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🔹 Check if unlocked
                            !_isUserListVisible
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "Enter your password to view dashboard analytics and user list",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 15),
                                        SizedBox(
                                          width: 250,
                                          child: TextField(
                                            controller: _passwordController,
                                            obscureText: !_isPasswordVisible,
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                borderSide: const BorderSide(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Colors.green,
                                                  width: 2,
                                                ),
                                              ),
                                              labelText: 'Password',
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _isPasswordVisible
                                                      ? Icons.visibility
                                                      : Icons.visibility_off,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _isPasswordVisible =
                                                        !_isPasswordVisible;
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 15),
                                        _isLoadingPassword
                                            ? const CircularProgressIndicator()
                                            : ElevatedButton(
                                                onPressed: () async {
                                                  setState(
                                                    () => _isLoadingPassword =
                                                        true,
                                                  );
                                                  try {
                                                    User? user = FirebaseAuth
                                                        .instance
                                                        .currentUser;
                                                    if (user == null ||
                                                        user.email == null) {
                                                      throw FirebaseAuthException(
                                                        code: 'user-not-found',
                                                        message:
                                                            'No logged-in user found.',
                                                      );
                                                    }

                                                    AuthCredential credential =
                                                        EmailAuthProvider.credential(
                                                          email: user.email!,
                                                          password:
                                                              _passwordController
                                                                  .text,
                                                        );

                                                    await user
                                                        .reauthenticateWithCredential(
                                                          credential,
                                                        );

                                                    setState(() {
                                                      _isUserListVisible = true;
                                                    });
                                                  } on FirebaseAuthException {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          "Incorrect password",
                                                        ),
                                                      ),
                                                    );
                                                  } finally {
                                                    setState(
                                                      () => _isLoadingPassword =
                                                          false,
                                                    );
                                                  }
                                                },
                                                child: const Text("Unlock"),
                                              ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ✅ Analytics (outside card, still protected)
                                      if (showAnalytics)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                            vertical: 8.0,
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      if (showAnalytics)
                                        UserdashboardAnalytics(
                                          userData: widget.userData,
                                        ),

                                      const SizedBox(height: 25),

                                      // ✅ User List (inside card)
                                      Card(
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(30.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (isAdmin)
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Container(
                                                          decoration:
                                                              const BoxDecoration(
                                                                color: Color(
                                                                  0xFFF7F2FA,
                                                                ),
                                                              ),
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                              ),
                                                          child: DropdownButton<String>(
                                                            value:
                                                                selectedUserType,
                                                            icon: const Icon(
                                                              Icons
                                                                  .arrow_drop_down,
                                                            ),
                                                            elevation: 16,
                                                            dropdownColor:
                                                                Colors.white,
                                                            underline: Container(
                                                              height: 2,
                                                              color:
                                                                  const Color(
                                                                    0xFF81BF36,
                                                                  ),
                                                            ),
                                                            onChanged:
                                                                (
                                                                  String?
                                                                  newValue,
                                                                ) {
                                                                  setState(() {
                                                                    selectedUserType =
                                                                        newValue!;
                                                                  });
                                                                },
                                                            items:
                                                                <String>[
                                                                  'All Users',
                                                                  'Students',
                                                                  'Counselors & Admins',
                                                                ].map<
                                                                  DropdownMenuItem<
                                                                    String
                                                                  >
                                                                >((
                                                                  String value,
                                                                ) {
                                                                  return DropdownMenuItem<
                                                                    String
                                                                  >(
                                                                    value:
                                                                        value,
                                                                    child: Text(
                                                                      value,
                                                                    ),
                                                                  );
                                                                }).toList(),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              const SizedBox(height: 10),

                                              // 🔹 StreamBuilder and list logic (unchanged)
                                              StreamBuilder(
                                                stream: users.snapshots(),
                                                builder:
                                                    (
                                                      context,
                                                      AsyncSnapshot<
                                                        QuerySnapshot
                                                      >
                                                      streamSnapshot,
                                                    ) {
                                                      if (!streamSnapshot
                                                          .hasData) {
                                                        return const Center(
                                                          child:
                                                              CircularProgressIndicator(),
                                                        );
                                                      }

                                                      // 🔹 Your original filtering logic
                                                      final String
                                                      currentUserRole =
                                                          widget
                                                              .userData['role'] ??
                                                          '';
                                                      final String
                                                      currentCounselorId =
                                                          widget
                                                              .userData['counId'] ??
                                                          '';

                                                      var filteredDocs =
                                                          streamSnapshot
                                                              .data!
                                                              .docs;

                                                      if (currentUserRole ==
                                                          'Counselor') {
                                                        filteredDocs = filteredDocs
                                                            .where(
                                                              (doc) =>
                                                                  doc["role"]
                                                                          .toString() ==
                                                                      "Student" &&
                                                                  doc["assignedCounselor"]
                                                                          .toString() ==
                                                                      currentCounselorId &&
                                                                  (doc["firstName"]
                                                                          .toString()
                                                                          .toLowerCase()
                                                                          .contains(
                                                                            searchQuery,
                                                                          ) ||
                                                                      doc["middleName"]
                                                                          .toString()
                                                                          .toLowerCase()
                                                                          .contains(
                                                                            searchQuery,
                                                                          ) ||
                                                                      doc["lastName"]
                                                                          .toString()
                                                                          .toLowerCase()
                                                                          .contains(
                                                                            searchQuery,
                                                                          ) ||
                                                                      doc["studId"]
                                                                          .toString()
                                                                          .toLowerCase()
                                                                          .contains(
                                                                            searchQuery,
                                                                          ) ||
                                                                      doc["college"]
                                                                          .toString()
                                                                          .toLowerCase()
                                                                          .contains(
                                                                            searchQuery,
                                                                          ) ||
                                                                      doc["course"]
                                                                          .toString()
                                                                          .toLowerCase()
                                                                          .contains(
                                                                            searchQuery,
                                                                          )),
                                                            )
                                                            .toList();

                                                        if (selectedUserType !=
                                                            'Students') {
                                                          selectedUserType =
                                                              'Students';
                                                        }
                                                      } else if (currentUserRole ==
                                                          'Admin') {
                                                        if (selectedUserType ==
                                                            'Students') {
                                                          filteredDocs = filteredDocs
                                                              .where(
                                                                (doc) =>
                                                                    doc["role"]
                                                                            .toString() ==
                                                                        "Student" &&
                                                                    (doc["firstName"]
                                                                            .toString()
                                                                            .toLowerCase()
                                                                            .contains(
                                                                              searchQuery,
                                                                            ) ||
                                                                        doc["middleName"]
                                                                            .toString()
                                                                            .toLowerCase()
                                                                            .contains(
                                                                              searchQuery,
                                                                            ) ||
                                                                        doc["lastName"]
                                                                            .toString()
                                                                            .toLowerCase()
                                                                            .contains(
                                                                              searchQuery,
                                                                            ) ||
                                                                        doc["studId"]
                                                                            .toString()
                                                                            .toLowerCase()
                                                                            .contains(
                                                                              searchQuery,
                                                                            ) ||
                                                                        doc["college"]
                                                                            .toString()
                                                                            .toLowerCase()
                                                                            .contains(
                                                                              searchQuery,
                                                                            ) ||
                                                                        doc["course"]
                                                                            .toString()
                                                                            .toLowerCase()
                                                                            .contains(
                                                                              searchQuery,
                                                                            )),
                                                              )
                                                              .toList();
                                                        } else if (selectedUserType ==
                                                            'Counselors & Admins') {
                                                          filteredDocs = filteredDocs
                                                              .where(
                                                                (doc) =>
                                                                    (doc["role"]
                                                                                .toString() ==
                                                                            "Counselor" ||
                                                                        doc["role"]
                                                                                .toString() ==
                                                                            "Admin") &&
                                                                    (doc["firstName"]
                                                                            .toString()
                                                                            .toLowerCase()
                                                                            .contains(
                                                                              searchQuery,
                                                                            ) ||
                                                                        doc["middleName"]
                                                                            .toString()
                                                                            .toLowerCase()
                                                                            .contains(
                                                                              searchQuery,
                                                                            ) ||
                                                                        doc["lastName"]
                                                                            .toString()
                                                                            .toLowerCase()
                                                                            .contains(
                                                                              searchQuery,
                                                                            ) ||
                                                                        doc["counId"]
                                                                            .toString()
                                                                            .toLowerCase()
                                                                            .contains(
                                                                              searchQuery,
                                                                            ) ||
                                                                        doc["assignedCollege"]
                                                                            .toString()
                                                                            .toLowerCase()
                                                                            .contains(
                                                                              searchQuery,
                                                                            ) ||
                                                                        doc["role"]
                                                                            .toString()
                                                                            .toLowerCase()
                                                                            .contains(
                                                                              searchQuery,
                                                                            )),
                                                              )
                                                              .toList();
                                                        } else {
                                                          // All Users filter
                                                          filteredDocs = filteredDocs.where((
                                                            doc,
                                                          ) {
                                                            final data =
                                                                doc.data()
                                                                    as Map<
                                                                      String,
                                                                      dynamic
                                                                    >;

                                                            // Helper function to safely get field value
                                                            String getField(
                                                              String key,
                                                            ) {
                                                              return data
                                                                      .containsKey(
                                                                        key,
                                                                      )
                                                                  ? (data[key]?.toString() ??
                                                                            '')
                                                                        .toLowerCase()
                                                                  : '';
                                                            }

                                                            return getField(
                                                                  'firstName',
                                                                ).contains(
                                                                  searchQuery,
                                                                ) ||
                                                                getField(
                                                                  'middleName',
                                                                ).contains(
                                                                  searchQuery,
                                                                ) ||
                                                                getField(
                                                                  'lastName',
                                                                ).contains(
                                                                  searchQuery,
                                                                ) ||
                                                                getField(
                                                                  'role',
                                                                ).contains(
                                                                  searchQuery,
                                                                ) ||
                                                                getField(
                                                                  'studId',
                                                                ).contains(
                                                                  searchQuery,
                                                                ) ||
                                                                getField(
                                                                  'counId',
                                                                ).contains(
                                                                  searchQuery,
                                                                ) ||
                                                                getField(
                                                                  'college',
                                                                ).contains(
                                                                  searchQuery,
                                                                ) ||
                                                                getField(
                                                                  'assignedCollege',
                                                                ).contains(
                                                                  searchQuery,
                                                                );
                                                          }).toList();
                                                        }
                                                      }

                                                      if (filteredDocs
                                                          .isEmpty) {
                                                        return Text(
                                                          "No ${selectedUserType.toLowerCase()} found.",
                                                        );
                                                      }

                                                      double rowHeight = 60.0;
                                                      int rowCount =
                                                          filteredDocs.length >
                                                              7
                                                          ? 7
                                                          : filteredDocs.length;
                                                      double tableHeight =
                                                          rowCount * rowHeight;

                                                      return Column(
                                                        children: [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  vertical: 15,
                                                                  horizontal: 5,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  const Color(
                                                                    0xFF81BF36,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    7,
                                                                  ),
                                                            ),
                                                            child: _buildTableHeader(
                                                              selectedUserType,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 5,
                                                          ),
                                                          SizedBox(
                                                            height: tableHeight,
                                                            child: ListView.builder(
                                                              itemCount:
                                                                  filteredDocs
                                                                      .length,
                                                              itemBuilder: (context, index) {
                                                                var doc =
                                                                    filteredDocs[index];
                                                                final fullName =
                                                                    "${doc['firstName'] ?? ''} ${doc['middleName'] != null && doc['middleName'].isNotEmpty ? doc['middleName'][0].toUpperCase() + '.' : ''} ${doc['lastName'] ?? ''} ${doc['extensionName'] ?? ''}";

                                                                return Container(
                                                                  height:
                                                                      rowHeight,
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        vertical:
                                                                            10,
                                                                        horizontal:
                                                                            5,
                                                                      ),
                                                                  margin:
                                                                      const EdgeInsets.only(
                                                                        bottom:
                                                                            5,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        index %
                                                                                2 ==
                                                                            0
                                                                        ? Colors
                                                                              .white
                                                                        : Colors
                                                                              .grey[200],
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          7,
                                                                        ),
                                                                  ),
                                                                  child: _buildTableRow(
                                                                    doc,
                                                                    fullName,
                                                                    selectedUserType,
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build appropriate table header based on selected user type
  Widget _buildTableHeader(String userType) {
    if (userType == 'Students') {
      return Row(
        children: const [
          Expanded(
            flex: 2,
            child: Text(
              "  Name",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "Student ID",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "College",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "Course",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "Academic Year",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "Section",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "Assigned Counselor",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "Action",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
        ],
      );
    } else if (userType == 'Counselors & Admins') {
      return Row(
        children: const [
          Expanded(
            flex: 2,
            child: Text(
              " Name",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "Counselor ID",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "Assigned College",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "Role",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "Action",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
        ],
      );
    } else {
      // All Users - Show combined headers
      return Row(
        children: const [
          Expanded(
            flex: 2,
            child: Text(
              "  Name",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "ID",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "College",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "Role",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "Action",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
        ],
      );
    }
  }

  void _showResetPasswordDialog(DocumentSnapshot doc) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final role = doc['role'].toString();
    final id = role == 'Student' ? doc['studId'] : doc['counId'];

    bool verified = false; // Step tracker

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                verified ? 'Set New Password' : 'Verify Your Identity',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!verified) ...[
                    const Text(
                      'Please enter your current password to confirm your identity.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!verified) {
                      // Step 1: Verify current password
                      final currentPassword = currentPasswordController.text
                          .trim();
                      if (currentPassword.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter your current password.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      try {
                        final user = FirebaseAuth.instance.currentUser!;
                        final email = user.email!;
                        final credential = EmailAuthProvider.credential(
                          email: email,
                          password: currentPassword,
                        );

                        // Attempt reauthentication
                        await user.reauthenticateWithCredential(credential);

                        setState(() {
                          verified = true; // Move to password reset step
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Incorrect password: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      // Step 2: Reset target user’s password
                      final newPassword = newPasswordController.text.trim();
                      final confirmPassword = confirmPasswordController.text
                          .trim();

                      if (newPassword.isEmpty || confirmPassword.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill in all fields.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (newPassword != confirmPassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context);
                      await _resetUserPassword(doc, newPassword);
                    }
                  },
                  child: Text(verified ? 'Save' : 'Verify'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _resetUserPassword(
    DocumentSnapshot doc,
    String newPassword,
  ) async {
    try {
      final role = doc['role'].toString();
      final studId = role == 'Student' ? doc['studId'] : null;
      final counId = role != 'Student' ? doc['counId'] : null;

      final callable = FirebaseFunctions.instance.httpsCallable(
        'resetUserPassword',
      );
      await callable.call({
        'studId': studId,
        'counId': counId,
        'newPassword': newPassword,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resetting password: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method to build appropriate table row based on selected user type and document data
  Widget _buildTableRow(
    DocumentSnapshot doc,
    String fullName,
    String userType,
  ) {
    final String currentUserRole = widget.userData['role'] ?? '';
    final String currentCounselorId = widget.userData['counId'] ?? '';
    final bool isAdmin = currentUserRole == 'Admin';
    final bool isCounselor = currentUserRole == 'Counselor';

    // Check if this student is assigned to the current counselor
    final bool isAssignedStudent =
        doc["role"].toString() == "Student" &&
        doc["assignedCounselor"].toString() == currentCounselorId;

    // Determine if user has edit/delete rights
    final bool canEdit = isAdmin || (isCounselor && isAssignedStudent);

    if (userType == 'Students') {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              child: Text(fullName),
            ),
          ),
          Expanded(child: Text(doc['studId']?.toString() ?? '')),
          Expanded(child: Text(doc['college']?.toString() ?? '')),
          Expanded(child: Text(doc['course']?.toString() ?? '')),
          Expanded(child: Text(doc['academicYear']?.toString() ?? '')),
          Expanded(child: Text(doc['section']?.toString() ?? '')),
          Expanded(child: Text(doc['assignedCounselor']?.toString() ?? '')),
          Expanded(
            child: Row(
              children: [
                // Show edit/delete buttons for Admin or if counselor for their students
                if (canEdit) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => showUserDialog(documentSnapshot: doc),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => delete(
                      doc.id,
                      doc,
                    ), // ✅ Changed from passing doc['studId'] to doc
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_reset, color: Colors.orange),
                    onPressed: () {
                      _showResetPasswordDialog(doc);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    } else if (userType == 'Counselors & Admins') {
      // Only Admin can see and edit counselors/admins
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              child: Text(fullName),
            ),
          ),
          Expanded(child: Text(doc['counId']?.toString() ?? '')),
          Expanded(child: Text(doc['assignedCollege']?.toString() ?? '')),
          Expanded(child: Text(doc['role']?.toString() ?? '')),
          Expanded(
            child: Row(
              children: [
                // Only show edit/delete buttons for Admin
                if (isAdmin) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => showUserDialog(documentSnapshot: doc),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => delete(doc.id, doc),
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_reset, color: Colors.orange),
                    onPressed: () {
                      _showResetPasswordDialog(doc);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    } else {
      // All Users view - show generalized information
      // Only visible to Admin anyway
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              child: Text(fullName),
            ),
          ),
          Expanded(
            child: Text(
              doc['role'] == "Student"
                  ? (doc['studId']?.toString() ?? '')
                  : (doc['counId']?.toString() ?? ''),
            ),
          ),
          Expanded(
            child: Text(
              doc['role'] == "Student"
                  ? (doc['college']?.toString() ?? '')
                  : (doc['assignedCollege']?.toString() ?? ''),
            ),
          ),
          Expanded(child: Text(doc['role']?.toString() ?? '')),
          Expanded(
            child: Row(
              children: [
                // Only show edit/delete buttons for Admin or if counselor for their students
                if (canEdit) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => showUserDialog(documentSnapshot: doc),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => delete(
                      doc.id,
                      doc,
                    ), // ✅ Changed from passing doc['studId'] to doc
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_reset, color: Colors.orange),
                    onPressed: () {
                      _showResetPasswordDialog(doc);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }
  }

  Dialog myDialogBox({
    required String title,
    required String condition,
    required bool isEmailEditable,
    required VoidCallback onPressed,
    required Map<String, dynamic>
    currentUserData, // Add current user data as a parameter
    bool isUpdating = false,
    String? initialRole,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: StatefulBuilder(
        builder: (context, setState) {
          // Check if the current user is a Counselor
          final bool isCurrentUserCounselor =
              currentUserData['role'] == 'Counselor';
          final String? currentUserAssignedCollege = isCurrentUserCounselor
              ? currentUserData['assignedCollege']
              : null;
          final String? currentUserCounselorId = isCurrentUserCounselor
              ? currentUserData['counselorId'] ?? currentUserData['studId']
              : null;

          // If user is counselor, automatically set role to Student
          if (isCurrentUserCounselor && selectedRole == null) {
            // Initialize with Student role for counselors
            selectedRole = 'Student';

            // Set college to counselor's assigned college
            if (currentUserAssignedCollege != null) {
              collegeController.text = currentUserAssignedCollege;
            }

            // Set assigned counselor to current user
            assignedCounselor = currentUserCounselorId;
          }

          // Pick image function (web and mobile)
          Future<void> pickImage() async {
            if (kIsWeb) {
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
                        setState(() {
                          selectedImageBytes = (result as JSArrayBuffer).toDart
                              .asUint8List();
                        });
                      }
                    }).toJS,
                  );
                }).toJS,
              );
            } else {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
                allowMultiple: false,
              );
              if (result != null && result.files.single.bytes != null) {
                setState(() {
                  selectedImageBytes = result.files.single.bytes!;
                });
              }
            }
          }

          // Role conditions for editing mode
          bool isEditingStudent = isUpdating && selectedRole == 'Student';
          bool isEditingCounselorOrAdmin =
              isUpdating &&
              (selectedRole == 'Counselor' || selectedRole == 'Admin');

          // Sort counselors by assigned college first
          List<Map<String, dynamic>> orderedCounselors = [
            ...counselorsData.where(
              (c) => c['assignedCollege'] == collegeController.text,
            ),
            ...counselorsData.where(
              (c) => c['assignedCollege'] != collegeController.text,
            ),
          ];

          return Container(
            width: 1000,
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    "Select Role",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // Role selection cards - only show if Admin or editing as Admin
                  if (!isCurrentUserCounselor &&
                      (!isEditingCounselorOrAdmin || !isEditingStudent))
                    Row(
                      children: [
                        if (!isEditingCounselorOrAdmin)
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedRole = 'Student';
                                  fetchCounselors();
                                  assignedCounselor = null;
                                });
                              },
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    color: selectedRole == 'Student'
                                        ? Colors.blue
                                        : Colors.grey.shade300,
                                    width: selectedRole == 'Student' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: selectedRole == 'Student' ? 4 : 1,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16.0,
                                    horizontal: 12.0,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.school, color: Colors.blue),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Student',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: selectedRole == 'Student'
                                              ? Colors.blue
                                              : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (!isCurrentUserCounselor && !isEditingStudent)
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedRole = 'Counselor';
                                  assignedCollege = null;
                                });
                              },
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    color: selectedRole == 'Counselor'
                                        ? Colors.green
                                        : Colors.grey.shade300,
                                    width: selectedRole == 'Counselor' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: selectedRole == 'Counselor' ? 4 : 1,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16.0,
                                    horizontal: 12.0,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.people, color: Colors.green),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Counselor',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: selectedRole == 'Counselor'
                                              ? Colors.green
                                              : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (!isCurrentUserCounselor && !isEditingStudent)
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedRole = 'Admin';
                                  assignedCollege = null;
                                });
                              },
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    color: selectedRole == 'Admin'
                                        ? Colors.orange
                                        : Colors.grey.shade300,
                                    width: selectedRole == 'Admin' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: selectedRole == 'Admin' ? 4 : 1,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16.0,
                                    horizontal: 12.0,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.admin_panel_settings,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Admin',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: selectedRole == 'Admin'
                                              ? Colors.orange
                                              : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  // For counselors, show an indicator that Student role is selected
                  if (isCurrentUserCounselor)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.school, color: Colors.blue),
                            SizedBox(width: 10),
                            Text(
                              'Creating Student Account',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // First Name
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: firstnameController,
                          decoration: InputDecoration(labelText: "First Name"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Middle Name
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: middlenameController,
                          decoration: InputDecoration(labelText: "Middle Name"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Last Name
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: lastnameController,
                          decoration: InputDecoration(labelText: "Last Name"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Extension Name with N/A Checkbox
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: extensionnameController,
                                decoration: InputDecoration(
                                  labelText: "Extension Name",
                                ),
                                enabled: !isExtensionNameNA,
                              ),
                            ),
                            Checkbox(
                              value: isExtensionNameNA,
                              activeColor: Colors.green.shade900,
                              onChanged: (value) {
                                setState(() {
                                  isExtensionNameNA = value!;
                                  if (isExtensionNameNA) {
                                    extensionnameController.text = "N/A";
                                  } else {
                                    extensionnameController.clear();
                                  }
                                });
                              },
                            ),
                            const Text("N/A"),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Student fields - shown for Student role
                  if (selectedRole == "Student") ...[
                    const SizedBox(height: 16),
                    // Row with Student ID, College, Course, Academic Year, Section
                    Row(
                      children: [
                        // Student ID
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: studIDcontroller,
                            decoration: const InputDecoration(
                              labelText: "Student ID",
                            ),
                            enabled: !isUpdating, // Disable when updating
                            style: TextStyle(
                              color: isUpdating ? Colors.grey : Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // College dropdown - for counselors, this is fixed to their assigned college
                        Expanded(
                          flex: 1,
                          child: isCurrentUserCounselor
                              ? TextField(
                                  controller: collegeController,
                                  decoration: const InputDecoration(
                                    labelText: "College",
                                  ),
                                  enabled:
                                      false, // Make it read-only for counselors
                                )
                              : DropdownButtonFormField<String>(
                                  value: collegeController.text.isNotEmpty
                                      ? collegeController.text
                                      : null,
                                  items: ["CEIT", "CAS", "COED", "CABA", "CPAG"]
                                      .map(
                                        (dept) => DropdownMenuItem(
                                          value: dept,
                                          child: Text(dept),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      collegeController.text = value!;
                                      selectedCourse = null;
                                      selectedSection = null;

                                      var filteredCounselors = counselorsData
                                          .where(
                                            (c) =>
                                                c['assignedCollege'] == value,
                                          )
                                          .toList();

                                      assignedCounselor =
                                          filteredCounselors.isNotEmpty
                                          ? filteredCounselors.first['counId']
                                          : null;
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    labelText: "College",
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        // Course
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: selectedCourse,
                            items:
                                (collegeController.text.isNotEmpty &&
                                            coursesByCollege.containsKey(
                                              collegeController.text,
                                            )
                                        ? coursesByCollege[collegeController
                                              .text]!
                                        : [])
                                    .map(
                                      (course) => DropdownMenuItem<String>(
                                        value: course,
                                        child: Text(course),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCourse = value!;
                                selectedSection = null;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: "Course",
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Academic Year
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: selectedAcademicYear,
                            items: academicYears.values
                                .map(
                                  (academicYear) => DropdownMenuItem(
                                    value: academicYear,
                                    child: Text(academicYear),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedAcademicYear = value!;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: "Academic Year",
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Section
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: selectedSection,
                            items:
                                (selectedCourse != null &&
                                            SectionsByCourse.containsKey(
                                              selectedCourse,
                                            )
                                        ? SectionsByCourse[selectedCourse]!
                                        : [])
                                    .map(
                                      (section) => DropdownMenuItem<String>(
                                        value: section,
                                        child: Text(section),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSection = value!;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: "Section",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Only show counselor selection for admin users
                    if (!isCurrentUserCounselor) ...[
                      const Text(
                        "Select Assigned Counselor",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      isCounselorsLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 10),
                                // Scrollable Cards Section
                                SizedBox(
                                  height: 160, // Height to fit cards properly!
                                  child: ScrollConfiguration(
                                    behavior:
                                        WebCustomScrollBehavior(), // Allow mouse drag on web
                                    child: Scrollbar(
                                      thumbVisibility:
                                          true, // Show scrollbar thumb
                                      controller: _scrollController,
                                      child: SingleChildScrollView(
                                        controller: _scrollController,
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: orderedCounselors.map((
                                            counselor,
                                          ) {
                                            final counselorName =
                                                counselor['name'];
                                            final counselorId =
                                                counselor['counId'];
                                            final assignedCollege =
                                                counselor['assignedCollege'] ??
                                                'No College';
                                            final imageBytes =
                                                decodeBase64Image(
                                                  counselor['image'],
                                                );
                                            final isSelected =
                                                assignedCounselor ==
                                                counselorId;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                right: 10,
                                              ),
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    assignedCounselor =
                                                        counselorId;
                                                  });
                                                },
                                                child: Card(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    side: BorderSide(
                                                      color: isSelected
                                                          ? Colors.blue
                                                          : const Color.fromARGB(
                                                              255,
                                                              255,
                                                              255,
                                                              255,
                                                            ),
                                                      width: isSelected ? 2 : 1,
                                                    ),
                                                  ),
                                                  elevation: isSelected ? 4 : 1,
                                                  child: SizedBox(
                                                    width: 300,
                                                    height: 120,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            12.0,
                                                          ),
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            child:
                                                                imageBytes !=
                                                                    null
                                                                ? Image.memory(
                                                                    imageBytes,
                                                                    height: 80,
                                                                    width: 80,
                                                                    fit: BoxFit
                                                                        .cover,
                                                                  )
                                                                : Container(
                                                                    height: 80,
                                                                    width: 80,
                                                                    color: Colors
                                                                        .grey[300],
                                                                    child: const Icon(
                                                                      Icons
                                                                          .person,
                                                                      size: 40,
                                                                      color:
                                                                          Color.fromARGB(
                                                                            255,
                                                                            255,
                                                                            255,
                                                                            255,
                                                                          ),
                                                                    ),
                                                                  ),
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  counselorName ??
                                                                      'No Name',
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        16,
                                                                    color:
                                                                        isSelected
                                                                        ? Colors
                                                                              .blue
                                                                        : Colors
                                                                              .black,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                Text(
                                                                  "ID: $counselorId",
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    color: Colors
                                                                        .black,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                Text(
                                                                  "College: $assignedCollege",
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    color: Colors
                                                                        .black,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ] else if (isCurrentUserCounselor) ...[
                      // For counselors, show a simple notification of automatic assignment
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 10),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person_pin_circle, color: Colors.green),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "This student will be automatically assigned to you as their counselor.",
                                style: TextStyle(color: Colors.green.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  // Counselor/Admin Fields - only for Admin users
                  if ((selectedRole == "Counselor" ||
                          selectedRole == "Admin") &&
                      !isCurrentUserCounselor) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: studIDcontroller,
                            decoration: InputDecoration(
                              labelText: "Counselor/Admin ID",
                            ),
                            enabled: !isUpdating, // Disable when updating
                            style: TextStyle(
                              color: isUpdating ? Colors.grey : Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: assignedCollege,
                            items: ["CEIT", "CAS", "COED", "CABA", "CPAG"]
                                .map(
                                  (college) => DropdownMenuItem(
                                    value: college,
                                    child: Text(college),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                assignedCollege = value!;
                              });
                            },
                            decoration: InputDecoration(
                              labelText: "Assigned College",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: pickImage,
                      icon: Icon(Icons.upload_file, color: Colors.blue),
                      label: Text(
                        selectedImageBytes != null
                            ? "Image Selected"
                            : "Upload Image",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                    if (selectedImageBytes != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.memory(selectedImageBytes!, height: 100),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        labelText: "Description",
                        alignLabelWithHint: true,
                        contentPadding: const EdgeInsets.all(12.0),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onPressed,
                    child: Text(
                      condition,
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.bold,
                      ), // Set text color to green[900]
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
