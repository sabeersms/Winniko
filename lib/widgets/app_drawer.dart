import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../screens/competition_create_screen.dart';
import '../screens/organizer_dashboard_screen.dart';
import '../screens/join_competition_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/team_library_screen.dart';
import '../screens/info_screens.dart';
import '../screens/contact_screen.dart';
import '../utils/share_util.dart';

class AppDrawer extends StatelessWidget {
  final UserModel? user;

  const AppDrawer({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: AppColors.backgroundDark,
        child: Column(
          children: [
            // User Header
            GestureDetector(
              onTap: () {
                if (user != null) {
                  Navigator.pop(context); // Close drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UserProfileScreen(user: user!, isCurrentUser: true),
                    ),
                  );
                }
              },
              child: UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: AppColors.cardColor),
                accountName: Text(
                  user?.name ?? 'Guest',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                accountEmail: Text(
                  user?.phone ?? '',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: AppColors.accentGreen,
                  backgroundImage: user?.photoUrl != null
                      ? CachedNetworkImageProvider(user!.photoUrl!)
                      : null,
                  child: user?.photoUrl == null
                      ? Text(
                          user?.name.isNotEmpty == true
                              ? user!.name[0].toUpperCase()
                              : 'G',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.add_circle_outline,
                    title: 'Create Competition',
                    onTap: () {
                      Navigator.pop(context); // Close drawer

                      // Show Public/Private Selection Dialog
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return SimpleDialog(
                            title: const Text('Select Competition Type'),
                            backgroundColor: AppColors.cardBackground,
                            titleTextStyle: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            children: [
                              SimpleDialogOption(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CompetitionCreateScreen(
                                        organizerId: user?.id ?? '',
                                        organizerName: user?.name ?? '',
                                        organizerLocation: user?.location,
                                        isPublic: false,
                                      ),
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Custom Tournament',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            color: Colors.lightGreenAccent,
                                            size: 16,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Create Your Own',
                                            style: TextStyle(
                                              color: Colors.lightGreenAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Setup teams, matches and rules manually.',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(color: AppColors.dividerColor),
                              SimpleDialogOption(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CompetitionCreateScreen(
                                        organizerId: user?.id ?? '',
                                        organizerName: user?.name ?? '',
                                        organizerLocation: user?.location,
                                        isPublic: true,
                                      ),
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Major Tournaments',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Select from official leagues like Premier League, La Liga, World Cup, etc.',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.dashboard,
                    title: 'My Competitions',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MyCompetitionsScreen(organizerId: user?.id ?? ''),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.library_books,
                    title: 'Team Library',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TeamLibraryScreen(organizerId: user?.id ?? ''),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.group_add,
                    title: 'Join Competition',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please sign in first')),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JoinCompetitionScreen(
                            userId: user!.id,
                            userName: user!.name,
                            userPhone: user!.phone,
                            userPhotoUrl: user!.photoUrl,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(color: AppColors.dividerColor),
                  _buildDrawerItem(
                    context,
                    icon: Icons.logout,
                    title: 'Sign Out',
                    onTap: () async {
                      final authService = Provider.of<AuthService>(
                        context,
                        listen: false,
                      );

                      // 1. Close drawer
                      Navigator.pop(context);

                      // 2. pop back to home (root) to stop active streams on pushed screens
                      while (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }

                      // 3. Sign out
                      await authService.signOut();
                    },
                  ),
                  const Divider(color: AppColors.dividerColor),
                  _buildDrawerItem(
                    context,
                    icon: Icons.info_outline,
                    title: 'About Us',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutUsPage()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.contact_support_outlined,
                    title: 'Contact Us',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContactScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.share_outlined,
                    title: 'Share App',
                    onTap: () {
                      Navigator.pop(context);
                      ShareUtil.shareText(
                        text:
                            'Check out Winniko - The ultimate sports tournament management app! Join my competition and win! 🏆\n\nDownload Now (Android): https://winniko-real.web.app/winniko.apk\nJoin via Web: https://winniko-real.web.app/',
                      );
                    },
                  ),
                  if (kIsWeb)
                    _buildDrawerItem(
                      context,
                      icon: Icons.android,
                      title: 'Download on Play Store',
                      onTap: () async {
                        Navigator.pop(context);
                        final url = Uri.parse(
                          'https://play.google.com/store/apps/details?id=com.winniko.winniko',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.description_outlined,
                    title: 'Terms & Conditions',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TermsPage()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyPage(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.help_outline,
                    title: 'Tutorial',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TutorialPage()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.system_update_outlined,
                    title: 'Update App',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You are on the latest version!'),
                          backgroundColor: AppColors.accentGreen,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Version 1.0.1",
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accentGreen),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      onTap: onTap,
    );
  }
}
