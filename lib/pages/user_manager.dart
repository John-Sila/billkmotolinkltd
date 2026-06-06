import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FullScreenLoader extends StatelessWidget {
  const FullScreenLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}


class UserManager extends StatefulWidget {
  const UserManager({super.key});

  @override
  State<UserManager> createState() => _UserManagerState();
}

class _UserManagerState extends State<UserManager> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  String? gender;
  String? role;

  final List<String> genders = ["Male", "Female"];
  final List<String> roles = ["Manager", "Rider", "Human Resource", "Store Keeper", "Technician"];
  final InputBorder fullBorder = OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: const BorderSide(width: 1, color: Colors.grey),
  );

  Future<void> createUserFlow({
    required BuildContext context,
    required String fullName,
    required String email,
    required String password,
    required String idNumber,
    required String phoneNumber,
    required String userRank,
    required String userGender,
    VoidCallback? onComplete,
  }) async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    final adminUser = auth.currentUser!;
    final adminEmail = adminUser.email!;

    final adminPasswordController = TextEditingController();

    String capitalizeFullName(String fullName) {
      return fullName
          .trim()
          .split(RegExp(r'\s+'))
          .map((word) {
            if (word.isEmpty) return word;
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          })
          .join(' ');
    }


    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your password to authorize."),
            TextField(
              controller: adminPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Continue")),
        ],
      ),
    );

    if (confirmed != true) return;

    final adminPassword = adminPasswordController.text.trim();
    if (adminPassword.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FullScreenLoader()),
    );

    try {
      await adminUser.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: adminEmail,
          password: adminPassword,
        ),
      );

      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final newUID = cred.user!.uid;
      await firestore.collection("users").doc(newUID).set({
        "userName": capitalizeFullName(fullName),
        "email": email,
        "idNumber": idNumber,
        "phoneNumber": phoneNumber,
        "userRank": userRank,
        "createdAt": Timestamp.now(),
        "isVerified": false,
        "isDeleted": false,
        "isActive": true,
        "pendingAmount": 0,
        "lastClockDate": Timestamp.now(),
        "currentInAppBalance": 0,
        "dailyTarget": 2200,
        "gender": userGender,
        "sundayTarget": 670,
        "isWorkingOnSunday": false,
        "hrsPerShift": 8,
      });

      await auth.signOut();

      await auth.signInWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );

      ToastService.success("${fullName.split(" ")[0]} can log in to the platform now!");

      Navigator.of(context, rootNavigator: true).pop();

      if (onComplete != null) {
        onComplete();
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      debugPrint("Error: $e");
    }
  }


@override
Widget build(BuildContext context) {
  return Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // Header
              const Text(
                'Create New User',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fill in all details to create a new user account',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              // Full Name
              _buildTextField(
                controller: fullNameController,
                label: 'Full Name',
                hint: 'Enter first and last name',
                icon: Icons.person_outline,
                keyboardType: TextInputType.name,
                validator: (v) => v == null || v.isEmpty || v.split(" ").length < 2 
                    ? 'Please enter full name (first & last)' 
                    : null,
              ),
              const SizedBox(height: 20),

              // Email
              _buildTextField(
                controller: emailController,
                label: 'Email Address',
                hint: 'Enter your email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || !v.contains("@") 
                    ? 'Please enter a valid email' 
                    : null,
              ),
              const SizedBox(height: 20),

              // Password
              _buildTextField(
                controller: passwordController,
                label: 'Password',
                hint: 'Enter secure password',
                icon: Icons.lock_outline,
                obscureText: true,
                validator: (v) => v == null || v.length < 6 
                    ? 'Password must be at least 6 characters' 
                    : null,
              ),
              const SizedBox(height: 20),

              // ID Number
              _buildTextField(
                controller: idNumberController,
                label: 'ID Number',
                hint: 'Enter ID number',
                icon: Icons.card_membership_outlined,
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty 
                    ? 'ID number is required' 
                    : null,
              ),
              const SizedBox(height: 20),

              // Phone Number
              _buildTextField(
                controller: phoneController,
                label: 'Phone Number',
                hint: '+254 7XX XXX XXX',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.length < 9 
                    ? 'Please enter valid phone number' 
                    : null,
              ),
              const SizedBox(height: 20),

              // Gender Dropdown
              _buildDropdownField<String>(
                value: gender,
                label: 'Gender',
                hint: 'Select gender',
                icon: Icons.wc,
                items: genders
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => gender = v),
                validator: (v) => v == null ? 'Please select gender' : null,
              ),
              const SizedBox(height: 20),

              // Role Dropdown
              _buildDropdownField<String>(
                value: role,
                label: 'Role',
                hint: 'Select user role',
                icon: Icons.badge_outlined,
                items: roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => role = v),
                validator: (v) => v == null ? 'Please select role' : null,
              ),
              const SizedBox(height: 32),

              // Create Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      await createUserFlow(
                        context: context,
                        fullName: fullNameController.text.trim(),
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                        idNumber: idNumberController.text.trim(),
                        phoneNumber: phoneController.text.trim(),
                        userRank: role!,
                        userGender: gender!,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: Colors.blue[200],
                  ),
                  child: const Text(
                    'Create User Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Reusable TextField Widget
Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  TextInputType? keyboardType,
  bool obscureText = false,
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
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      labelStyle: TextStyle(color: Colors.grey[700]),
    ),
  );
}

// Reusable Dropdown Widget
Widget _buildDropdownField<T>({
  required T? value,
  required String label,
  required String hint,
  required IconData icon,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?>? onChanged,
  String? Function(T?)? validator,
}) {
  return DropdownButtonFormField<T>(
    initialValue: value,
    items: items,
    onChanged: onChanged,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.blue[600]),
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
    ),
  );
}



}