// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';
import 'package:image_picker/image_picker.dart';
// import 'dart:io'; // Removed unconditional import
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'info_screens.dart';
import '../widgets/loading_spinner.dart';
import 'dialogs/profile_image_adjustment_dialog.dart';
import '../services/auth_service.dart';

class UserProfileScreen extends StatefulWidget {
  final UserModel user;
  final bool isCurrentUser;

  const UserProfileScreen({
    super.key,
    required this.user,
    this.isCurrentUser = false,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  late UserModel _user;
  int _totalPoints = 0;
  int _competitionCount = 0;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final stats = await firestoreService.getUserCompetitionsAndStats(
      widget.user.id,
    );

    if (mounted) {
      setState(() {
        _totalPoints = stats['totalPoints'] as int;
        _competitionCount = stats['competitionCount'] as int;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (widget.isCurrentUser)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _showEditProfileDialog();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingSpinner(color: AppColors.accentGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Header
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Hero(
                              tag: 'profile_${_user.id}',
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: AppColors.cardBackground,
                                backgroundImage: _user.photoUrl != null
                                    ? CachedNetworkImageProvider(
                                        _user.photoUrl!,
                                      )
                                    : null,
                                child: _user.photoUrl == null
                                    ? Text(
                                        _user.name.isNotEmpty
                                            ? _user.name[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 40,
                                          color: AppColors.accentGreen,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            if (widget.isCurrentUser)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _isUploading
                                      ? null
                                      : _pickAndUploadImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGreen,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.backgroundDark,
                                        width: 2,
                                      ),
                                    ),
                                    child: _isUploading
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _user.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_user.address != null &&
                            _user.address!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: AppColors.textSecondary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _user.address!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        'Competitions',
                        _competitionCount.toString(),
                      ),
                      _buildStatItem('Total Points', _totalPoints.toString()),
                      // _buildStatItem('Wins', '0'), // Placeholder for future
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Compliance Section
                  if (widget.isCurrentUser) ...[
                    const SizedBox(height: 32),
                    const Divider(color: AppColors.dividerColor),
                    ListTile(
                      leading: const Icon(
                        Icons.privacy_tip_outlined,
                        color: AppColors.textSecondary,
                      ),
                      title: const Text(
                        'Privacy Policy',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      trailing: const Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyPage(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                      ),
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      onTap: _confirmDeleteAccount,
                    ),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image == null) return;

      if (!context.mounted) return;
      // 1. Show Adjustment Dialog (Now returns XFile)
      final XFile? adjustedImage = await showDialog<XFile>(
        context: context,
        builder: (_) => ProfileImageAdjustmentDialog(imageFile: image),
      );

      if (adjustedImage == null) return;

      if (!context.mounted) return;
      setState(() => _isUploading = true);
      final storageService = StorageService();
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final authService = Provider.of<AuthService>(context, listen: false);

      // 2. Upload to Storage
      final photoUrl = await storageService.uploadUserPhoto(
        adjustedImage,
        _user.id,
      );

      // 3. Update Firestore
      final updatedUser = _user.copyWith(photoUrl: photoUrl);
      await firestoreService.updateUser(updatedUser);

      // 4. Sync Auth Service (updates drawer)
      await authService.syncUserProfile();

      if (mounted) {
        setState(() {
          _user = updatedUser;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _user.name);
    final addressController = TextEditingController(text: _user.address);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Edit Profile',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Address',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                final newAddress = addressController.text.trim();

                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name cannot be empty')),
                  );
                  return;
                }

                if (!context.mounted) return;
                final firestoreService = Provider.of<FirestoreService>(
                  context,
                  listen: false,
                );

                try {
                  final updatedUser = _user.copyWith(
                    name: newName,
                    address: newAddress,
                  );

                  await firestoreService.updateUser(updatedUser);

                  if (context.mounted) {
                    setState(() {
                      _user = updatedUser;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.accentGreen,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: const Text(
          'This action is irreversible. All your data, including created competitions and participation history, will be permanently deleted.',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performAccountDeletion();
            },
            child: const Text(
              'Delete Forever',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      // 1. Delete Firestore Data
      await firestoreService.deleteUser(_user.id);

      // 2. Delete Auth Account & Sign Out
      await authService.deleteAccount();

      // Navigation handled by auth state change in main.dart or standard wrapper
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deletion Failed: $e. Please re-login and try again.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
