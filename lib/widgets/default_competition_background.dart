import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class DefaultCompetitionBackground extends StatelessWidget {
  final double? height;
  final double? width;

  const DefaultCompetitionBackground({super.key, this.height, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.backgroundDark, AppColors.primaryGreenDark],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Faded Pattern or Texture (Optional - strictly kept clean as per request)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Winniko App Logo
                Image.asset(
                  AppConstants.defaultCompetitionLogo,
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                // App Name
                const Text(
                  'WINNIKO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    shadows: [
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black45,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Tagline
                const Text(
                  'Predict. Compete. Rise.',
                  style: TextStyle(
                    color: Color(0xFFFFD700), // Gold
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black26,
                        offset: Offset(0, 2),
                      ),
                    ],
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
