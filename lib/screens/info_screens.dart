import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoPage extends StatelessWidget {
  final String title;
  final Widget content;

  const InfoPage({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: content,
      ),
    );
  }
}

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoPage(
      title: 'About Us',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Winniko!',
            style: TextStyle(
              color: AppColors.accentGreen,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Winniko is the ultimate platform for sports enthusiasts to organize, manage, and participate in tournaments. Whether you are a local club organizer or a professional league manager, Winniko provides the tools you need to create a seamless experience for your participants.',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          SizedBox(height: 16),
          Text(
            'Our Mission',
            style: TextStyle(
              color: AppColors.accentGreen,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'To empower sports communities by providing a robust, user-friendly mobile platform that makes competition management accessible to everyone, everywhere.',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          SizedBox(height: 24),
          Text(
            'Developed by the Winniko Team with support from Google Deepmind Advanced Agentic Coding.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoPage(
      title: 'Terms & Conditions',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terms of Service',
            style: TextStyle(
              color: AppColors.accentGreen,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Last Updated: January 2026',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 24),

          _TermsSection(
            title: '1. Acceptance of Terms',
            content:
                'By accessing or using the Winniko mobile application ("App"), you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree to these Terms, do not use the App.',
          ),

          _TermsSection(
            title: '2. No Gambling / No Real Money',
            content:
                'Winniko is a social platform for organizing and managing sports tournaments. IT IS NOT A GAMBLING APP.\n\n'
                '• No Purchase Necessary: No purchase or payment of any kind is necessary to enter or win any contest or promotion hosted on this App.\\n'
                '• No Real Money Gaming: The App does not facilitate any form of real money gambling, betting, or wagering. Any "points" or "scores" are virtual and have no monetary value.\n'
                '• Non-Sponsorship: Contests are organized solely by third-party organizers. Apple Inc., Google LLC, and their affiliates are strictly NOT sponsors of, and are in no way involved with, any contest or promotion within this App.',
          ),

          _TermsSection(
            title: '3. User Conduct & Content',
            content:
                'You are solely responsible for the competitions you create and the content you post. You agree not to use the App to:\n'
                '• Organize illegal gambling or betting activities.\n'
                '• Harass, abuse, or harm other users.\n'
                '• Post content that is offensive, defamatory, or violates the rights of others.',
          ),

          _TermsSection(
            title: '4. Intellectual Property',
            content:
                'All rights, title, and interest in and to the App (excluding user-generated content) are and will remain the exclusive property of Winniko and its licensors.',
          ),

          _TermsSection(
            title: '5. Disclaimers & Limitation of Liability',
            content:
                'The App is provided on an "AS IS" and "AS AVAILABLE" basis. Winniko makes no warranties regarding the accuracy or reliability of the App. To the fullest extent permitted by law, Winniko shall not be liable for any indirect, incidental, special, or consequential damages.',
          ),

          _TermsSection(
            title: '6. Termination',
            content:
                'We reserve the right to suspend or terminate your access to the App at our sole discretion, without notice, for conduct that we believe violates these Terms.',
          ),

          _TermsSection(
            title: '7. Governing Law',
            content:
                'These Terms shall be governed by and construed in accordance with the laws of [Your Jurisdiction], without regard to its conflict of law provisions.',
          ),

          SizedBox(height: 32),
          Center(
            child: Text(
              'Contact us at support@winniko.com for any questions.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String content;

  const _TermsSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.accentGreen,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoPage(
      title: 'Privacy Policy',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Privacy Policy',
            style: TextStyle(
              color: AppColors.accentGreen,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Last Updated: January 2026',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 24),

          _TermsSection(
            title: '1. Information We Collect',
            content:
                'We collect several types of information to provide and improve our service:\n'
                '• Personal Identifiers: Name, email address, and phone number.\n'
                '• Profile Assets: Profile pictures (collected via your Camera or Gallery permissions).\n'
                '• Location Data: Approximate location data to localize competition listings and organizer details.\n'
                '• Usage Activity: Your predictions, competition participation, and app interactions.\n'
                '• Technical Data: Device identifiers, IP address, and crash reports for performance monitoring.',
          ),

          _TermsSection(
            title: '2. Payment Information',
            content:
                'If you participate in paid contests, we use third-party payment processors (specifically Razorpay). '
                'We do not store your credit card or bank details on our servers. All financial transactions are processed securely by Razorpay in compliance with PCI-DSS standards.',
          ),

          _TermsSection(
            title: '3. Third-Party Services & Ads',
            content:
                'We use third-party SDKs that may collect information used to identify you:\n'
                '• Google Mobile Ads (AdMob): Used to serve advertisements. They may collect device identifiers and usage data to personalize your ad experience.\n'
                '• Firebase: Used for authentication, database, storage, and push notifications.',
          ),

          _TermsSection(
            title: '4. How We Use Information',
            content:
                'We use your data to:\n'
                '• Manage your account and competition rankings.\n'
                '• Process entries and score calculations.\n'
                '• Notify you about match results and competition updates.\n'
                '• Prevent fraud and ensure a fair playing field.',
          ),

          _TermsSection(
            title: '5. Data Retention & Deletion',
            content:
                'We retain your data as long as your account is active. \n\n'
                'How to Delete Your Data:\n'
                'You have the right to delete your account and all associated personal data at any time. '
                'Go to **Profile > Settings > Delete Account**. This action is irreversible and will permanently remove your profile, competition history, and indices from our database.',
          ),

          _TermsSection(
            title: '6. Children\'s Privacy',
            content:
                'Winniko does not knowingly collect data from children under the age of 13. If you believe we have inadvertently collected such data, please contact us immediately for deletion.',
          ),

          _TermsSection(
            title: '7. Contact Us',
            content:
                'For any privacy-related inquiries or data requests, please contact us at:\n'
                'Email: support@winniko.com',
          ),

          SizedBox(height: 32),
        ],
      ),
    );
  }
}

class TutorialPage extends StatelessWidget {
  const TutorialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoPage(
      title: 'Guide & Tutorials',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // YouTube Link Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill, color: Colors.red, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Video Tutorials',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Watch how to use Winniko on our YouTube channel.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://youtube.com/@winniko-x1t?si=fm8Z0abpUBswaPEC',
                    ),
                  ),
                  child: const Text(
                    'WATCH',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'App Core Features',
            style: TextStyle(
              color: AppColors.accentGreen,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _buildTutorialStep(
            Icons.add_task,
            'Create Competitions',
            'Start your own tournament! Use "Custom" to set up everything yourself, or "Major Tournaments" to sync real-world fixtures like IPL or Premier League automatically.',
          ),
          _buildTutorialStep(
            Icons.people_alt,
            'Manage Teams & Squads',
            'Add teams manually or select from our pre-defined Library. You can manage team logos, names, and participant lists effortlessly.',
          ),
          _buildTutorialStep(
            Icons.event_note,
            'Dynamic Match Scheduling',
            'Generate round-robin fixtures or knockout brackets with one tap. Set match dates, times, and venues as needed.',
          ),
          _buildTutorialStep(
            Icons.military_tech,
            'Live Predictions & Rankings',
            'Join competitions using a unique code. Predict match scores to earn points and climb the global or private leaderboards.',
          ),
          _buildTutorialStep(
            Icons.chat_bubble_outline,
            'Tournament Chat',
            'Every competition has a dedicated chat room. Discuss matches, share results, and coordinate with participants in real-time.',
          ),
          _buildTutorialStep(
            Icons.picture_as_pdf,
            'Export Match Reports',
            'Generate professional PDF fixtures and result posters to share with your community via WhatsApp or social media.',
          ),
          _buildTutorialStep(
            Icons.notifications_active,
            'Smart Notifications',
            'Stay updated with push notifications for match start times, result updates, and chat messages.',
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.dividerColor),
          const SizedBox(height: 16),

          const Center(
            child: Text(
              'Questions? Contact support@winniko.com',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTutorialStep(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accentGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
