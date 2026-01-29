import 'dart:io' show File;
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/loading_spinner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../models/competition_model.dart';
import 'competition_format_screen.dart';
import 'tournament_selection_screen.dart';
import 'dialogs/image_adjustment_dialog.dart';
import '../widgets/default_competition_background.dart';
import 'terms_editor_screen.dart';

class CompetitionCreateScreen extends StatefulWidget {
  final String organizerId;
  final String organizerName;
  final GeoPoint? organizerLocation;
  final bool isPublic; // New Parameter
  final CompetitionModel? competition; // For Edit Mode

  const CompetitionCreateScreen({
    super.key,
    required this.organizerId,
    required this.organizerName,
    this.organizerLocation,
    this.isPublic = true, // Default to true if not specified
    this.competition,
  });

  @override
  State<CompetitionCreateScreen> createState() =>
      _CompetitionCreateScreenState();
}

class _CompetitionCreateScreenState extends State<CompetitionCreateScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sponsorController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _logoImage;
  XFile? _backgroundImage;
  String _selectedSport = AppConstants.sportFootball;
  int _correctWinnerPoints = AppConstants.pointsCorrectWinner;
  int _correctScorePoints = AppConstants.pointsCorrectScore;
  List<String> _tieBreakerRules = [AppConstants.tieBreakerGoalDiff];

  // Terms Data
  // Terms Data
  List<Map<String, dynamic>> _termsMetadata = [];
  String _termsLanguage = 'en';

  bool _isPublic = true;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _spinController;
  String _statusText = 'Loading...';

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (widget.competition != null) {
      _loadExistingData();
    } else {
      _isPublic = widget.isPublic;
    }
  }

  void _loadExistingData() {
    final c = widget.competition!;
    _nameController.text = c.name;
    _sponsorController.text = c.sponsorName ?? '';
    _selectedSport = c.sport;

    _correctWinnerPoints =
        c.rules['correctWinner'] ?? AppConstants.pointsCorrectWinner;
    _correctScorePoints =
        c.rules['correctScore'] ?? AppConstants.pointsCorrectScore;
    _tieBreakerRules = c.tieBreakerRules;
    _isPublic = c.isPublic;

    if (c.termsMetadata != null) {
      _termsMetadata = List<Map<String, dynamic>>.from(c.termsMetadata!);
    } else if (c.termsAndConditions != null &&
        c.termsAndConditions!.isNotEmpty) {
      // Migrate legacy string-only T&C to a single rule
      _termsMetadata = [
        {
          'title': 'General Terms',
          'content': c.termsAndConditions!,
          'isVisible': true,
        },
      ];
    }

    _termsLanguage = c.termsLanguage ?? 'en';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sponsorController.dispose();
    // _descriptionController.dispose(); // Removed
    // _termsController.dispose(); // Removed

    _spinController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _logoImage = image;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick image');
    }
  }

  Future<void> _pickBackground() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          // Web: Bypass adjustment dialog for now as it relies on dart:io File
          setState(() {
            _backgroundImage = image;
          });
        } else {
          // Mobile: Use adjustment dialog
          final pickedFile = File(image.path);

          if (!mounted) return;

          // Show adjustment dialog
          final File? adjustedFile = await showDialog<File>(
            context: context,
            barrierDismissible: false,
            builder: (context) => ImageAdjustmentDialog(
              imageFile: pickedFile,
              competitionName: _nameController.text.trim().isEmpty
                  ? 'Competition Name'
                  : _nameController.text.trim(),
              sponsorName: _sponsorController.text.trim().isEmpty
                  ? null
                  : _sponsorController.text.trim(),
            ),
          );

          if (adjustedFile != null) {
            setState(() {
              _backgroundImage = XFile(adjustedFile.path);
            });
          }
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick background image');
    }
  }

  // ... inside State class
  CompetitionModel? _draftCompetition;

  Future<void> _openTermsEditor() async {
    // result is now a Map or null
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TermsEditorScreen(
          initialTerms: _termsMetadata,
          initialLanguage: _termsLanguage,
        ),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        _termsMetadata = List<Map<String, dynamic>>.from(result['terms']);
        _termsLanguage = result['language'] as String? ?? 'en';
      });
    }
  }

  Future<void> _submitForm() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter competition name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusText = 'Checking connectivity...';
    });

    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final storageService = Provider.of<StorageService>(
        context,
        listen: false,
      );
      final authService = Provider.of<AuthService>(context, listen: false);

      final user = await authService.getUserProfile(authService.currentUserId!);
      if (user == null) throw Exception('User not found');

      // 1. Prepare Initial Model (Without new Image URLs initially)
      final bool isRealEditing = widget.competition != null;
      final competitionId = isRealEditing
          ? widget.competition!.id
          : (_draftCompetition?.id ?? const Uuid().v4());

      // Get existing URLs or null
      String? logoUrl = isRealEditing
          ? widget.competition!.logoUrl
          : _draftCompetition?.logoUrl;
      String? backgroundUrl = isRealEditing
          ? widget.competition!.cardBackgroundImageUrl
          : _draftCompetition?.cardBackgroundImageUrl;

      // Compile T&C
      String? compiledTerms;
      if (_termsMetadata.isNotEmpty) {
        final buffer = StringBuffer();
        for (var rule in _termsMetadata) {
          if (rule['isVisible'] == true) {
            buffer.writeln('### ${rule['title']}');
            buffer.writeln(rule['content']);
            buffer.writeln();
          }
        }
        compiledTerms = buffer.toString().trim();
      }

      // Create standard model instance
      // We create this EARLY to ensure we can save a "stub" if needed for Storage Rules
      var competition = CompetitionModel(
        id: competitionId,
        organizerId: isRealEditing ? widget.competition!.organizerId : user.id,
        organizerName: isRealEditing
            ? widget.competition!.organizerName
            : user.name,
        sponsorName: _sponsorController.text.trim().isEmpty
            ? null
            : _sponsorController.text.trim(),
        name: _nameController.text.trim(),
        sport: _selectedSport,
        isPublic: isRealEditing ? widget.competition!.isPublic : _isPublic,
        format: isRealEditing
            ? widget.competition!.format
            : (_draftCompetition?.format ?? AppConstants.formatLeague),
        description: null,
        logoUrl: logoUrl, // Old URL or null
        cardBackgroundImageUrl: backgroundUrl, // Old URL or null
        organizerLocation: widget.organizerLocation,
        locationRestrictionType: AppConstants.restrictionNone,
        restrictionRadius: null,
        rules: {
          'correctWinner': _correctWinnerPoints,
          'correctScore': _correctScorePoints,
        },
        joinCode: isRealEditing
            ? widget.competition!.joinCode
            : (_draftCompetition?.joinCode ?? ''),
        isPaid: isRealEditing ? widget.competition!.isPaid : false,
        participantCount: isRealEditing
            ? widget.competition!.participantCount
            : 0,
        createdAt: isRealEditing
            ? widget.competition!.createdAt
            : (_draftCompetition?.createdAt ?? DateTime.now()),
        pointsForWin: isRealEditing ? widget.competition!.pointsForWin : 3,
        pointsForDraw: isRealEditing ? widget.competition!.pointsForDraw : 1,
        pointsForLoss: isRealEditing ? widget.competition!.pointsForLoss : 0,
        tieBreakerRules: isRealEditing
            ? widget.competition!.tieBreakerRules
            : _tieBreakerRules,
        leagueId: isRealEditing
            ? widget.competition!.leagueId
            : _draftCompetition?.leagueId,
        termsAndConditions: compiledTerms?.isEmpty == true
            ? null
            : compiledTerms,
        termsMetadata: _termsMetadata,
        termsLanguage: _termsLanguage,
        status: isRealEditing ? widget.competition!.status : 'active',
      );

      // SECURITY CRITICAL:
      // If we are creating a NEW competition (not editing existing, and no draft saved yet),
      // we MUST save the document to Firestore FIRST.
      // Why? Because Storage Rules now check 'firestore.get(...)' to verify the organizer.
      // If the doc doesn't exist, the upload will fail with Permission Denied.
      if (!isRealEditing && _draftCompetition == null) {
        setState(() => _statusText = 'Establishing secure draft...');
        await firestoreService.createCompetition(competition);
        _draftCompetition = competition; // Now it exists in DB!
      }

      // 2. Upload Images (Now safe to do)
      bool imagesUpdated = false;

      if (_logoImage != null) {
        setState(() => _statusText = 'Uploading logo...');
        try {
          logoUrl = await storageService
              .uploadCompetitionLogo(_logoImage!, competitionId)
              .timeout(const Duration(seconds: 15));
          imagesUpdated = true;
        } catch (e) {
          debugPrint('Logo upload failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Logo upload failed. Using default.'),
              ),
            );
          }
        }
      }

      if (_backgroundImage != null) {
        setState(() => _statusText = 'Uploading background...');
        try {
          backgroundUrl = await storageService
              .uploadCompetitionBackground(_backgroundImage!, competitionId)
              .timeout(const Duration(seconds: 15));
          imagesUpdated = true;
        } catch (e) {
          debugPrint('Background upload failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Background upload failed. Using default.'),
              ),
            );
          }
        }
      }

      // 3. Final Save (Update with new URLs if needed)
      setState(() => _statusText = 'Saving details...');

      // Update model with new URLs if they changed
      if (imagesUpdated) {
        competition = competition.copyWith(
          logoUrl: logoUrl,
          cardBackgroundImageUrl: backgroundUrl,
        );
      }

      // Save to Firestore (Update/Overwrite)
      if (isRealEditing) {
        await firestoreService
            .updateCompetition(competition)
            .timeout(const Duration(seconds: 15));

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        // Create/Update Draft
        // We already created it above if it was new, so 'update' is cleaner,
        // but 'create' (set) is safe too. Let's use update to be semantic since it exists.
        if (_draftCompetition != null) {
          // It definitely is null or not null logic handled above
          await firestoreService
              .updateCompetition(competition)
              .timeout(const Duration(seconds: 15));
        } else {
          // Should not be reachable given logic above, but safe fallback
          await firestoreService
              .createCompetition(competition)
              .timeout(const Duration(seconds: 15));
        }

        _draftCompetition = competition;

        if (!mounted) return;

        setState(() => _statusText = 'Opening next screen...');

        // Proceed to next screen
        if (competition.isPublic) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TournamentSelectionScreen(competitionPrototype: competition),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CompetitionFormatScreen(competition: competition),
            ),
          );
        }

        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              '$_statusText timed out (15s). Please check your connection and try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.competition != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Competition' : 'Create Competition'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGreenLight),
                  ),
                  child: _buildLogoWidget(isEditing),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Competition Logo',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 24),

            // Card Background Image
            const Text(
              'Card Background Image (Optional)',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickBackground,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGreenLight),
                ),
                child: _buildBackgroundWidget(isEditing),
              ),
            ),
            const SizedBox(height: 24),

            // Public / Private Toggle removed (handled in Drawer)
            const SizedBox(height: 24),

            // Template Import (Only for Private)

            // Name
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Competition Name',
                prefixIcon: Icon(
                  Icons.emoji_events,
                  color: AppColors.accentGreen,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sponsor Name
            TextField(
              controller: _sponsorController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Sponsor Name',
                prefixIcon: Icon(Icons.business, color: AppColors.accentGreen),
              ),
            ),
            const SizedBox(height: 16),

            // Sport Selection
            DropdownButtonFormField<String>(
              value: _selectedSport,
              dropdownColor: AppColors.cardBackground,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Sport',
                prefixIcon: Icon(Icons.category, color: AppColors.accentGreen),
              ),
              items: AppConstants.sports.map((sport) {
                IconData icon;
                switch (sport) {
                  case AppConstants.sportFootball:
                    icon = Icons.sports_soccer;
                    break;
                  case AppConstants.sportCricket:
                    icon = Icons.sports_cricket;
                    break;
                  case AppConstants.sportBasketball:
                    icon = Icons.sports_basketball;
                    break;
                  case AppConstants.sportHockey:
                    icon = Icons.sports_hockey;
                    break;
                  case AppConstants.sportVolleyball:
                    icon = Icons.sports_volleyball;
                    break;
                  case AppConstants.sportHandball:
                    icon = Icons.sports_handball;
                    break;
                  case AppConstants.sportBadminton:
                    icon =
                        Icons.sports_tennis; // Closest available generic racket
                    break;
                  default:
                    icon = Icons.sports;
                }
                return DropdownMenuItem(
                  value: sport,
                  child: Row(
                    children: [
                      Icon(icon, color: AppColors.accentGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(sport),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSport = value!;
                  if (_selectedSport == AppConstants.sportCricket) {
                    _correctWinnerPoints =
                        3; // Standard: 3 pts for win (as requested)
                    _correctScorePoints = 2;
                    _tieBreakerRules = [
                      AppConstants.tieBreakerWins,
                      AppConstants.tieBreakerNrr,
                    ];
                  } else {
                    _correctWinnerPoints = 3;
                    _correctScorePoints = 2;
                    _tieBreakerRules = [AppConstants.tieBreakerGoalDiff];
                  }
                });
              },
            ),
            const SizedBox(height: 24),
            // Terms and Conditions Section (Replaced Description)
            const Text(
              'Terms & Conditions',
              style: TextStyle(
                color: AppColors.accentGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                icon: const Icon(
                  Icons.description,
                  color: AppColors.textPrimary,
                ),
                label: Text(
                  _termsMetadata.isEmpty
                      ? 'Add Terms & Conditions'
                      : 'Edit Terms & Conditions (${_termsMetadata.where((e) => e['isVisible'] == true).length} active roles)',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.textSecondary),
                ),
                onPressed: _openTermsEditor,
              ),
            ),
            if (_termsMetadata.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Adding T&C is recommended for organizing a fair competition.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // Prediction Points
            Text(
              'Prediction Points',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Per Winner',
                      hintText: '$_correctWinnerPoints pts',
                    ),
                    onChanged: (v) => _correctWinnerPoints =
                        int.tryParse(v) ?? _correctWinnerPoints,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: _selectedSport == AppConstants.sportCricket
                          ? 'Per Exact Runs'
                          : 'Per Exact Score',
                      hintText: '$_correctScorePoints pts',
                    ),
                    onChanged: (v) => _correctScorePoints =
                        int.tryParse(v) ?? _correctScorePoints,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 24),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                color: AppColors.error.withValues(alpha: 0.2),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),

            // Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: LoadingSpinner(
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(_statusText),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isEditing ? 'Save Changes' : 'Next: Add Teams',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoWidget(bool isEditing) {
    Widget imageContent;

    if (_logoImage != null) {
      imageContent = kIsWeb
          ? Image.network(_logoImage!.path, fit: BoxFit.cover)
          : Image.file(File(_logoImage!.path), fit: BoxFit.cover);
    } else if (isEditing && widget.competition?.logoUrl != null) {
      imageContent = CachedNetworkImage(
        imageUrl: widget.competition!.logoUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const Center(child: LoadingSpinner(size: 20)),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      );
    } else {
      // Show Default Logo
      imageContent = Image.asset(
        AppConstants.defaultCompetitionLogo,
        fit: BoxFit.cover,
      );
    }

    return Stack(
      fit: StackFit.expand, // Fill the parent container
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: imageContent),
        // Overlay Icon
        Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_a_photo, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundWidget(bool isEditing) {
    Widget imageContent;

    if (_backgroundImage != null) {
      imageContent = kIsWeb
          ? Image.network(_backgroundImage!.path, fit: BoxFit.cover)
          : Image.file(File(_backgroundImage!.path), fit: BoxFit.cover);
    } else if (isEditing &&
        widget.competition?.cardBackgroundImageUrl != null) {
      imageContent = CachedNetworkImage(
        imageUrl: widget.competition!.cardBackgroundImageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(child: LoadingSpinner()),
        errorWidget: (context, url, error) =>
            const DefaultCompetitionBackground(),
      );
    } else {
      // Show Default Background with Tagline
      imageContent = const DefaultCompetitionBackground();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: imageContent),
        // Overlay Icon
        Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_a_photo, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }
}
