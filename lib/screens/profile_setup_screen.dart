import 'dart:io' show File;
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';
import '../widgets/loading_spinner.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String userId;

  const ProfileSetupScreen({super.key, required this.userId});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedImage;
  GeoPoint? _userLocation;
  String? _address;
  bool _isLoading = false;
  bool _isGettingLocation = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: ${e.toString()}';
      });
    }
  }

  Future<void> _captureImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to capture image: ${e.toString()}';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _errorMessage = null;
    });

    final locationService = Provider.of<LocationService>(
      context,
      listen: false,
    );

    try {
      final position = await locationService.getCurrentPosition();
      final address = await locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _userLocation = GeoPoint(position.latitude, position.longitude);
        _address = address;
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name';
      });
      return;
    }

    if (_userLocation == null) {
      setState(() {
        _errorMessage = 'Please get your location';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final storageService = Provider.of<StorageService>(
        context,
        listen: false,
      );

      String? photoUrl;
      if (_selectedImage != null) {
        photoUrl = await storageService.uploadUserPhoto(
          _selectedImage!,
          widget.userId,
        );
      }

      final user = UserModel(
        id: widget.userId,
        email: authService.currentUser?.email ?? '',
        phone: authService.currentUser?.phoneNumber ?? '',
        name: _nameController.text.trim(),
        photoUrl: photoUrl,
        location: _userLocation!,
        address: _address,
        createdAt: DateTime.now(),
      );

      await authService.createUserProfile(user);

      // AuthWrapper will handle navigation.
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Setup Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // Profile Photo
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.cardBackground,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.camera_alt,
                              color: AppColors.accentGreen,
                            ),
                            title: const Text(
                              'Take Photo',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _captureImage();
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.photo_library,
                              color: AppColors.accentGreen,
                            ),
                            title: const Text(
                              'Choose from Gallery',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _pickImage();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.cardBackground,
                  backgroundImage: _selectedImage != null
                      ? (kIsWeb
                                ? NetworkImage(_selectedImage!.path)
                                : FileImage(File(_selectedImage!.path)))
                            as ImageProvider
                      : null,
                  child: _selectedImage == null
                      ? const Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: AppColors.accentGreen,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to add photo',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              // Name Input
              TextField(
                key: const ValueKey('profile_setup_name_field'),
                controller: _nameController,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  hintText: 'Enter your name',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: Icon(Icons.person, color: AppColors.accentGreen),
                ),
              ),
              const SizedBox(height: 24),

              // Location Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGreenLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.accentGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Location',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_address != null) ...[
                      Text(
                        _address!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isGettingLocation
                            ? null
                            : _getCurrentLocation,
                        icon: _isGettingLocation
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: LoadingSpinner(
                                  size: 16,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                          _userLocation == null
                              ? 'Get Current Location'
                              : 'Update Location',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: LoadingSpinner(
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : const Text('Continue', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
