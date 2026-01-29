import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/competition_model.dart';
import '../models/participant_model.dart';
import '../services/firestore_service.dart';
import 'competition_detail_screen.dart';
import '../widgets/loading_spinner.dart';

import 'package:translator/translator.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  final CompetitionModel competition;
  final ParticipantModel participant;

  const TermsAndConditionsScreen({
    super.key,
    required this.competition,
    required this.participant,
  });

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  bool _isLoading = false;
  bool _isTranslating = false;
  String? _errorMessage;

  final GoogleTranslator _translator = GoogleTranslator();
  String _currentLanguage = 'en';

  // Static Text State
  String _introText =
      'Please review and agree to the following terms and conditions set by the organizer to join this competition:';
  String _agreeButtonText = 'Agree & Join';

  // Structured Terms State
  List<Map<String, String>> _displayTerms = [];

  final Map<String, String> _languages = {
    'en': 'English',
    'hi': 'Hindi',
    'ml': 'Malayalam',
    'ta': 'Tamil',
    'te': 'Telugu',
    'kn': 'Kannada',
    'mr': 'Marathi',
    'bn': 'Bengali',
    'gu': 'Gujarati',
    'pa': 'Punjabi',
    'ur': 'Urdu',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
  };

  @override
  void initState() {
    super.initState();
    _initializeTerms();

    // Auto-translate if organizer set a default language other than English
    final defaultLang = widget.competition.termsLanguage;
    if (defaultLang != null && defaultLang != 'en') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _translateAll(defaultLang);
      });
    }
  }

  void _initializeTerms() {
    if (widget.competition.termsMetadata != null &&
        widget.competition.termsMetadata!.isNotEmpty) {
      _displayTerms = widget.competition.termsMetadata!
          .where((t) => t['isVisible'] == true)
          .map(
            (t) => {
              'title': t['title'].toString(),
              'content': t['content'].toString(),
            },
          )
          .toList();
    } else {
      // Fallback for legacy data
      _displayTerms = [
        {
          'title': 'General Terms',
          'content':
              widget.competition.termsAndConditions ??
              'No specific terms provided.',
        },
      ];
    }
  }

  Future<void> _translateAll(String targetLang) async {
    if (targetLang == 'en') {
      setState(() {
        _currentLanguage = 'en';
        _introText =
            'Please review and agree to the following terms and conditions set by the organizer to join this competition:';
        _agreeButtonText = 'Agree & Join';
        _initializeTerms(); // Reset content
      });
      return;
    }

    setState(() => _isTranslating = true);

    try {
      // 1. Translate Static Text
      final tIntro = await _translator.translate(
        'Please review and agree to the following terms and conditions set by the organizer to join this competition:',
        to: targetLang,
      );
      final tButton = await _translator.translate(
        'Agree & Join',
        to: targetLang,
      );

      // 2. Translate Terms List
      final List<Map<String, String>> newTerms = [];

      // Re-init from source to ensure clean translation
      List<Map<String, String>> sourceTerms;
      if (widget.competition.termsMetadata != null &&
          widget.competition.termsMetadata!.isNotEmpty) {
        sourceTerms = widget.competition.termsMetadata!
            .where((t) => t['isVisible'] == true)
            .map(
              (t) => {
                'title': t['title'].toString(),
                'content': t['content'].toString(),
              },
            )
            .toList();
      } else {
        sourceTerms = [
          {
            'title': 'General Terms',
            'content':
                widget.competition.termsAndConditions ??
                'No specific terms provided.',
          },
        ];
      }

      for (var term in sourceTerms) {
        final tTitle = await _translator.translate(
          term['title']!,
          to: targetLang,
        );
        final tContent = await _translator.translate(
          term['content']!,
          to: targetLang,
        );
        newTerms.add({'title': tTitle.text, 'content': tContent.text});
      }

      if (mounted) {
        setState(() {
          _currentLanguage = targetLang;
          _introText = tIntro.text;
          _agreeButtonText = tButton.text;
          _displayTerms = newTerms;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranslating = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Translation failed. Please check internet.'),
            ),
          );
        });
      }
    }
  }

  Future<void> _agreeAndJoin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);

      await firestore.joinCompetition(
        widget.competition.id,
        widget.participant,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CompetitionDetailScreen(competitionId: widget.competition.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currentLanguage,
                dropdownColor: AppColors.cardBackground,
                icon: const Icon(Icons.translate, color: Colors.white),
                items: _languages.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) _translateAll(val);
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isTranslating
                ? const Center(child: LoadingSpinner(size: 40))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.competition.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _introText,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Structured List
                        ..._displayTerms.asMap().entries.map((entry) {
                          final index = entry.key;
                          final term = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${index + 1}. ${term['title']}',
                                  style: const TextStyle(
                                    color: AppColors.accentGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  term['content']!.replaceAll('\\n', '\n'),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 24),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _agreeAndJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const LoadingSpinner(size: 20, color: Colors.white)
                      : Text(
                          _agreeButtonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
