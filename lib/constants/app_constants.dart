import 'package:flutter/material.dart';

// App Theme Colors - Dark Green and White
class AppColors {
  // Primary Colors
  static const Color primaryGreen = Color(0xFF1B5E20); // Dark Green
  static const Color primaryGreenDark = Color(0xFF0D3D13); // Darker Green
  static const Color primaryGreenLight = Color(0xFF2E7D32); // Lighter Green
  static const Color accentGreen = Color(0xFF4CAF50); // Accent Green

  // Background Colors
  static const Color backgroundDark = Color(0xFF0A1F0F); // Very Dark Green
  static const Color backgroundLight = Color(0xFFFFFFFF); // White
  static const Color cardBackground = Color(0xFF1A3520); // Dark Green Card
  static const Color inputBackground = Color(0xFF2E4A34); // Input fields

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFB0BEC5); // Light Grey
  static const Color textDark = Color(
    0xFF1B5E20,
  ); // Dark Green for light backgrounds

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF29B6F6);

  // UI Elements
  static const Color divider = Color(0xFF2E4A34);
  static const Color shadow = Color(0x40000000);
  static const Color shimmerBase = Color(0xFF1A3520);
  static const Color shimmerHighlight = Color(0xFF2E4A34);

  // Aliases
  static const Color cardColor = cardBackground;
  static const Color dividerColor = divider;
}

// App Theme
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryGreen,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryGreen,
        secondary: AppColors.accentGreen,
        surface: AppColors.cardBackground,
        error: AppColors.error,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentGreen,
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryGreenLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryGreenLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accentGreen, width: 2),
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
    );
  }
}

// App Constants
class AppConstants {
  static const String appName = 'Winniko';
  static const String defaultCompetitionLogo = 'assets/images/app_logo.png';
  static const String defaultCompetitionBackground =
      'assets/images/default_background.png';

  // Location Restrictions
  static const double radius20km = 20.0;
  static const double radius50km = 50.0;
  static const double radius100km = 100.0;

  // Points System
  static const int pointsCorrectWinner = 3;
  static const int pointsCorrectScore = 2;

  // Match Status
  static const String matchStatusScheduled = 'scheduled';
  static const String matchStatusUpcoming = 'upcoming';
  static const String matchStatusLive = 'live';
  static const String matchStatusCompleted = 'completed';

  // Location Restriction Types
  static const String restrictionNone = 'none';
  static const String restriction20km = '20km';
  static const String restriction50km = '50km';
  static const String restriction100km = '100km';
  static const String restrictionState = 'state';
  static const String restrictionCountry = 'country';

  // Organizer Types
  static const String organizerFree = 'free';
  static const String organizerPaid = 'paid';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String competitionsCollection = 'competitions';
  static const String predictionsCollection = 'predictions';
  static const String teamsCollection = 'teams';
  static const String matchesCollection = 'matches';
  static const String participantsCollection = 'participants';

  // Sport Types
  static const String sportCricket = 'Cricket';
  static const String sportFootball = 'Football';
  static const String sportHockey = 'Hockey';
  static const String sportBasketball = 'Basketball';
  static const String sportBadminton = 'Badminton';
  static const String sportVolleyball = 'Volleyball';
  static const String sportHandball = 'Handball';
  static const String sportOther = 'Other';

  static const List<String> sports = [
    sportCricket,
    sportFootball,
    sportHockey,
    sportBasketball,
    sportBadminton,
    sportVolleyball,
    sportHandball,
    sportOther,
  ];

  // Competition Formats
  static const String formatLeague = 'League';
  static const String formatKnockout = 'Knockout';
  static const String formatLeagueKnockout = 'League + Knockout';
  static const String formatGroupsKnockout = 'Groups + Knockout';
  static const String formatSingleMatch = 'Single Match';
  static const String formatCustom = 'Custom';

  // Fixture Types
  static const String fixtureTypeRunning = 'running'; // Generate round by round
  static const String fixtureTypeFull = 'full'; // Generate all rounds upfront

  // Cricket Prediction Margins
  static const List<String> cricketRunMargins = [
    '1-5',
    '6-10',
    '11-20',
    '21-30',
    '31-40',
    '41-50',
    '51-60',
    '61-70',
    '71-80',
    '81-90',
    '91-100',
    '101-110',
    '111-120',
    '121-130',
    '131-140',
    '141-150',
    '151-160',
    '161-170',
    '171-180',
    '181-190',
    '191-200',
    '201+',
  ];

  static const List<String> cricketWicketMargins = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
  ];

  static const List<String> cricketScoreRanges = [
    '0-10',
    '11-20',
    '21-30',
    '31-40',
    '41-50',
    '51-60',
    '61-70',
    '71-80',
    '81-90',
    '91-100',
    '101-110',
    '111-120',
    '121-130',
    '131-140',
    '141-150',
    '151-160',
    '161-170',
    '171-180',
    '181-190',
    '191-200',
    '201-210',
    '211-220',
    '221-230',
    '231-240',
    '241-250',
    '251-260',
    '261-270',
    '271-280',
    '281-290',
    '291-300',
    '301-310',
    '311-320',
    '321-330',
    '331-340',
    '341-350',
    '351-360',
    '361-370',
    '371-380',
    '381-390',
    '391-400',
    '401-410',
    '411-420',
    '421-430',
    '431-440',
    '441-450',
    '451-460',
    '461-470',
    '471-480',
    '481-490',
    '491-500',
    '500+',
  ];

  static const List<String> cricketWicketCounts = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
  ];

  // Tie Breaker Rules
  static const String tieBreakerPoints = 'points';
  static const String tieBreakerWins = 'wins';
  static const String tieBreakerNrr = 'nrr';
  static const String tieBreakerGoalDiff = 'goal_difference';
  static const String tieBreakerGoalsScored = 'goals_scored';
  static const String tieBreakerHeadToHead = 'head_to_head';
}
