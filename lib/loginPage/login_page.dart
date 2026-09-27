import 'package:rumini/loginPage/forgotPass.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  // Main theme colors
  final Color primaryGreen = const Color(0xFF81BF36);
  final Color darkGreen = const Color(0xFF59842B);
  final Color textColor = const Color(0xFF333333);
  final Color lightGrey = const Color(0xFFE0E0E0);

   Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // ✅ No navigation here → main.dart StreamBuilder will handle role + redirect
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = _getAuthErrorMessage(e.code);
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper function to get error messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return "Enter a valid email.";
      case 'user-not-found':
        return "No account exists with the provided email.";
      case 'wrong-password':
        return "Invalid password. Please try again.";
      case 'user-disabled':
        return "This account has been disabled.";
      case 'too-many-requests':
        return "Too many attempts. Please try again later.";
      case 'network-request-failed':
        return "Network error. Please check your connection.";
      default:
        return "An unexpected error occurred. Please try again.";
    }
  }

 @override
Widget build(BuildContext context) {
  // Get screen dimensions for responsive design
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 600;
  
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          const Color(0xFF2E7D32), // Dark green
          const Color(0xFF81BF36), // Medium green
          Colors.white,
        ],
        stops: const [0.0, 0.4, 1.0],
      ),
    ),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  constraints: BoxConstraints(
                    maxWidth: isSmallScreen ? double.infinity : 900, // Increased max width for row layout
                  ),
                  child: isSmallScreen
                    // Phone layout (vertical)
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Logo
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: 400,
                            ),
                            margin: const EdgeInsets.only(bottom: 20),
                            child: Hero(
                              tag: 'logo',
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          
                          // Login Container with elevation and black border
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  spreadRadius: 3,
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              //border: Border.all(
                             //   color: Colors.black, // Changed to black
                             //   width: 1,
                             // ),
                            ),
                            child: _buildLoginForm(),
                          ),
                        ],
                      )
                    // Website layout (horizontal)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Logo on left (40% width)
                          Expanded(
                            flex: 4,
                            child: Container(
                              constraints: const BoxConstraints(
                                maxHeight: 400,
                              ),
                              child: Hero(
                                tag: 'logo',
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 30),
                          // Login container on right (60% width)
                          Expanded(
                            flex: 6,
                            child: Container(
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    spreadRadius: 3,
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color.fromARGB(255, 76, 76, 76), // Changed to black
                                  width: 1,
                                ),
                              ),
                              child: _buildLoginForm(),
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

Widget _buildLoginForm() {
  return Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome text
        Text(
          'Welcome!',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width < 600 ? 24 : 28,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Log in to continue to your account',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
            color: textColor.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 32),
        
        // Email field with animation
        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email_outlined,
          isPassword: false,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        
        // Password field with animation
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          isPassword: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        
        // Forgot password link
        Align(
  alignment: Alignment.centerRight,
  child: TextButton(
    onPressed: () {
      showDialog(
        context: context,
        barrierDismissible: false, // user can't close without finishing
        builder: (context) => const ForgotPasswordDialog(),
      );
    },
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: const Size(50, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(
      'Forgot Password?',
      style: TextStyle(
        color: primaryGreen,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
),
        
        const SizedBox(height: 8),
        
        // Error message
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12, 
              vertical: 8
            ),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 20),
        
        // Login Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: primaryGreen.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : const Text(
                    'Log In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    ),
  );
}

  // Enhanced text field builder with animations
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isPassword,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      validator: validator,
      style: TextStyle(
        color: textColor,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: textColor.withOpacity(0.7),
          fontSize: 15,
        ),
        prefixIcon: Icon(
          icon,
          color: primaryGreen,
          size: 22,
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: textColor.withOpacity(0.7),
                  size: 22,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: lightGrey.withOpacity(0.1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: lightGrey,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: primaryGreen,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
    );
  }
}