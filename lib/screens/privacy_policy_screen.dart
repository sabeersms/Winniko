import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                _buildSection(
                  '1. Introduction',
                  'Welcome to Winniko. Your privacy is important to us. This Privacy Policy explains how we collect, use, and protect your information when you use our mobile application and website.',
                ),
                _buildSection(
                  '2. Information We Collect',
                  'We collect the following types of information:\n\n'
                      '• Account Information: When you sign up, we verify you using your phone number or email address via Firebase Authentication.\n'
                      '• Profile Data: We may collect your name and profile picture (optional) to display to other users in competitions.\n'
                      '• Usage Data: We collect information about how you interact with the app, such as the tournaments you join and the matches you follow.',
                ),
                _buildSection(
                  '3. How We Use Your Information',
                  'We use your information to:\n\n'
                      '• Provide and manage the Winniko service.\n'
                      '• Allow you to create and join tournaments.\n'
                      '• Facilitate communication between organizers and participants.\n'
                      '• Improve app performance and user experience.',
                ),
                _buildSection(
                  '4. Data Security',
                  'We implement appropriate technical and organizational measures to protect your personal data against unauthorized access, alteration, disclosure, or destruction. We use Google Firebase services which are industry-standard secure platforms.',
                ),
                _buildSection(
                  '5. Third-Party Services',
                  'We may use third-party services such as:\n\n'
                      '• Google Firebase (Authentication, Database, Analytics)\n'
                      '• Google AdMob (for displaying ads)\n\n'
                      'These third parties have their own privacy policies governing their use of your data.',
                ),
                _buildSection(
                  '6. Account Deletion',
                  'You have the right to request the deletion of your account and associated data at any time.\n\n'
                      '1. In-App Deletion: Go to Settings > Delete Account to instantly remove your data.\n'
                      '2. Email Request: Contact us at sabeersms@gmail.com with the subject "Delete Account".\n\n'
                      'Data that will be deleted:\n'
                      '• Personal Information (Name, Email, Phone)\n'
                      '• Profile Photos and Team Logos\n'
                      '• Authentication Credentials\n\n'
                      'Data retention: once requested, data is permanently removed from our active databases immediately.',
                ),
                _buildSection(
                  '7. Contact Us',
                  'If you have any questions about this Privacy Policy, please contact us at:\n\nEmail: sabeersms@gmail.com',
                ),
                const SizedBox(height: 60),
                Center(
                  child: Text(
                    'Last Updated: January 2025',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.accentGreen,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
