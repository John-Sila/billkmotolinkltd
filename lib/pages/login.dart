import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }


   // Load saved credentials on app start
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (savedEmail != null && rememberMe) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
    if (savedPassword != null && rememberMe) {
      setState(() {
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = 'User not found. Please register first.';
        });
        return;
      }

      // Check isActive status
      final userDoc = querySnapshot.docs.first;
      final data = userDoc.data();
      final isActive = data['isActive'] as bool? ?? false;

      // BLOCK LOGIN IF NOT ACTIVE
      if (!isActive) {
        setState(() {
          _errorMessage = 'Your account has been deactivated. Contact support.';
        });
        return;
      }

      // NOW sign in with Firebase Auth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Save credentials if "Remember me" checked
      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_email', _emailController.text.trim());
        await prefs.setString('saved_password', _passwordController.text.trim());
        await prefs.setBool('remember_me', true);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);
      }

      widget.onLogin();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Authentication failed';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController emailController = TextEditingController();
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isResetLoading = false;
            
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: Colors.orange[600], size: 28),
                  const SizedBox(width: 12),
                  const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter your email address and we\'ll send you a reset link.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[600]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter your email';
                      if (!RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").hasMatch(value)) {
                        return 'Enter valid email';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (emailController.text.isEmpty) return;
                    
                    setDialogState(() => isResetLoading = true);
                    
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(
                        email: emailController.text.trim(),
                      );
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Password reset link sent to ${emailController.text.trim()}'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                      Navigator.of(context).pop();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to send reset email. Check email address.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        setDialogState(() => isResetLoading = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(32.0),
                  child: SingleChildScrollView(

                    child: Column(                    
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo & Title
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[600]!, Colors.blue[400]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.two_wheeler_outlined,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                        const SizedBox(height: 32),

                        const Text(
                          'Welcome to BILLK MOTOLINK LTD',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your credentials to continue',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),

                        // Email Field
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'Enter your email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            final emailValid = RegExp(
                              r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
                            ).hasMatch(value);
                            if (!emailValid) return 'Enter a valid email address';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Enter your password',
                          icon: Icons.lock_outlined,
                          obscureText: !_isPasswordVisible,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Remember Me Checkbox
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _rememberMe
                                          ? [Colors.blue.shade600, Colors.blue.shade700]
                                          : [Colors.transparent, Colors.transparent],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _rememberMe 
                                        ? Colors.blue.shade600 
                                        : Colors.grey.shade400,
                                      width: _rememberMe ? 2 : 1.5,
                                    ),
                                    boxShadow: [
                                      if (_rememberMe)
                                        BoxShadow(
                                          color: Colors.blue.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                    ],
                                  ),
                                  child: _rememberMe
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black26,
                                              offset: Offset(0, 1),
                                              blurRadius: 3,
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              Text(
                                'Remember me',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                  letterSpacing: 0.2,
                                  height: 1.3,
                                ),
                              ),
                              
                              const SizedBox(width: 8),
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: Colors.grey[500],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Error Message
                        if (_errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (_errorMessage != null) const SizedBox(height: 24),

                        // Sign In Button
                        SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                              shadowColor: Colors.blue[200],
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        GestureDetector(
                          onTap: _showForgotPasswordDialog, // ✅ New function
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[600],
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.blue[600],
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),







                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.blue[600]),
        suffixIcon: suffixIcon,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        labelStyle: TextStyle(color: Colors.grey[700]),
      ),
    );
  }
}
