import 'dart:async';
import 'package:flutter/material.dart';
import '../models/competition_model.dart';
import '../constants/app_constants.dart';
import 'featured_competition_card.dart';
import '../screens/competition_detail_screen.dart';

class FeaturedCarousel extends StatefulWidget {
  final List<CompetitionModel> competitions;
  final int initialPage;

  const FeaturedCarousel({
    super.key,
    required this.competitions,
    this.initialPage = 0,
  });

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  late int _currentIndex;
  late PageController _pageController;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (widget.competitions.length <= 1) return;

    // Give the center card (initialPage) more time
    final duration = _currentIndex == widget.initialPage
        ? const Duration(seconds: 8)
        : const Duration(seconds: 5);

    _autoPlayTimer = Timer(duration, () {
      if (!mounted) return;
      if (_pageController.hasClients) {
        int nextPage = _currentIndex + 1;
        if (nextPage >= widget.competitions.length) {
          nextPage = 0;
        }

        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });
    _startAutoPlay();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.competitions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.competitions.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final competition = widget.competitions[index];
              return FeaturedCompetitionCard(
                competition: competition,
                onTap: () {
                  _autoPlayTimer?.cancel();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompetitionDetailScreen(
                        competitionId: competition.id,
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Dots Indicator (Overlaid)
          Positioned(
            bottom: 12, // Distance from bottom edge of the image
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.competitions.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentIndex == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? AppColors.accentGreen
                        : Colors.white.withValues(
                            alpha: 0.5,
                          ), // White transparent for background
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
