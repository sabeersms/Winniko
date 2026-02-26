import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../widgets/loading_spinner.dart';

import 'package:image_picker/image_picker.dart';
// ignore_for_file: use_build_context_synchronously
import 'dart:io' show File; // Restricted import
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:cloud_firestore/cloud_firestore.dart'; // for GeoPoint
import '../services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _confirmEmailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _completePhoneNumber = '';
  bool _isLoading = false;
  String? _errorMessage;
  XFile? _profileImage; // Changed to XFile
  final ImagePicker _picker = ImagePicker();
  String _statusMessage = 'Creating account...';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _confirmEmailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final name = _nameController.text.trim();
      final phone = _completePhoneNumber;

      // 0. Manual phone check (Extra safety)
      if (phone.isEmpty || _phoneController.text.isEmpty) {
        setState(() {
          _errorMessage = "Mobile number is mandatory";
          _isLoading = false;
        });
        return;
      }

      // 1. Check if phone/email already exists
      final exists = await authService.checkUserExists(phone, email);
      if (exists) {
        setState(() {
          _errorMessage = "This mobile number or email is already registered";
          _isLoading = false;
        });
        return;
      }

      // 2. Sign up with Firebase Auth
      final userCredential = await authService.signUpWithEmail(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;
      String? photoUrl;

      // 3. Upload Profile Image if selected
      if (_profileImage != null) {
        setState(() => _statusMessage = 'Uploading profile picture...');
        if (!context.mounted) return;
        final storageService = Provider.of<StorageService>(
          context,
          listen: false,
        );
        photoUrl = await storageService.uploadUserPhoto(_profileImage!, userId);
      }

      setState(() => _statusMessage = 'Saving profile locally...');

      // 4. Create User Profile Immediately (No Verification Required)
      final newUser = UserModel(
        id: userId,
        email: email,
        phone: phone,
        name: name,
        photoUrl: photoUrl,
        location: const GeoPoint(0, 0),
        createdAt: DateTime.now(),
      );

      await authService.createUserProfile(newUser);

      // Clear legacy cache if any
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('signup_userId');
      await prefs.remove('signup_name');
      await prefs.remove('signup_phone');
      await prefs.remove('signup_photoUrl');

      // 5. Success! Navigate to Home (via AuthWrapper)
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Close Signup Screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      String message = e.toString();
      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text("Sign Up"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.error,
                        size: 16,
                      ),
                      onPressed: () => setState(() => _errorMessage = null),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

            Expanded(child: _buildSignupContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupContent() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Picture Picker
            _buildProfileImagePicker(),
            const SizedBox(height: 32),

            // Name
            TextFormField(
              controller: _nameController,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person, color: AppColors.accentGreen),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Please enter your name'
                  : null,
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email, color: AppColors.accentGreen),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter email';
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirm Email
            TextFormField(
              controller: _confirmEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Confirm Email Address',
                prefixIcon: Icon(
                  Icons.mark_email_read,
                  color: AppColors.accentGreen,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm email';
                }
                if (value != _emailController.text) {
                  return 'Emails do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone
            IntlPhoneField(
              controller: _phoneController,
              initialCountryCode: 'IN',
              style: const TextStyle(color: AppColors.textPrimary),
              dropdownTextStyle: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone, color: AppColors.accentGreen),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (phone) {
                if (phone == null || phone.number.isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
              onChanged: (phone) {
                _completePhoneNumber = phone.completeNumber;
              },
            ),
            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(
                  Icons.lock,
                  color: AppColors.accentGreen,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.accentGreen,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) =>
                  value != null && value.length < 6 ? 'Min 6 chars' : null,
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSignup,
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const LoadingSpinner(
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 12),
                          Text(_statusMessage),
                        ],
                      )
                    : const Text('Sign Up'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImagePicker() {
    ImageProvider? backgroundImage;
    if (_profileImage != null) {
      if (kIsWeb) {
        backgroundImage = NetworkImage(_profileImage!.path);
      } else {
        backgroundImage = FileImage(File(_profileImage!.path));
      }
    }

    return Center(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentGreen, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGreen.withValues(alpha: 0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.cardBackground,
              backgroundImage: backgroundImage,
              child: _profileImage == null
                  ? const Icon(
                      Icons.person,
                      size: 60,
                      color: AppColors.textSecondary,
                    )
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.accentGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _profileImage = image; // Directly assign XFile
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
    }
  }
}
