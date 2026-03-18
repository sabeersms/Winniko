import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/match_model.dart';
import '../../utils/share_util.dart';
import '../../widgets/match_result_card.dart';
import '../../constants/app_constants.dart';

class ShareMatchDialog extends StatefulWidget {
  final MatchModel match;
  final String competitionName;
  final String sport;

  const ShareMatchDialog({
    super.key,
    required this.match,
    required this.competitionName,
    required this.sport,
  });

  @override
  State<ShareMatchDialog> createState() => _ShareMatchDialogState();
}

class _ShareMatchDialogState extends State<ShareMatchDialog> {
  late TextEditingController _headingController;
  final GlobalKey _cardKey = GlobalKey();
  dynamic _logoImage; // dynamic for platform compatibility
  final List<FooterImageData> _bottomImages = []; // Updated State
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _headingController = TextEditingController(text: widget.competitionName);
    _loadPreferences();
  }

  @override
  void dispose() {
    _headingController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'share_config_${widget.match.competitionId}';
      final jsonString = prefs.getString(key);

      if (jsonString != null) {
        final Map<String, dynamic> data = jsonDecode(jsonString);

        if (mounted) {
          setState(() {
            // Load Heading
            if (data['heading'] != null) {
              _headingController.text = data['heading'];
            }

            // Load Logo
            if (data['logoPath'] != null) {
              if (!kIsWeb) {
                final file = io.File(data['logoPath']);
                if (file.existsSync()) {
                  _logoImage = file;
                }
              }
            }

            // Load Footer Images
            if (data['footerImages'] != null) {
              _bottomImages.clear();
              final List<dynamic> footerList = data['footerImages'];
              for (var item in footerList) {
                final path = item['path'];
                final fitIndex =
                    item['fitIndex'] ?? 0; // Default to 0 (contain)
                // Map index back to BoxFit: 0 -> contain, 1 -> fill
                final fit = fitIndex == 1 ? BoxFit.fill : BoxFit.contain;

                if (path != null) {
                  if (!kIsWeb) {
                    final file = io.File(path);
                    if (file.existsSync()) {
                      _bottomImages.add(FooterImageData(file, fit: fit));
                    }
                  }
                }
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading share preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'share_config_${widget.match.competitionId}';

      final Map<String, dynamic> data = {
        'heading': _headingController.text,
        'logoPath': !kIsWeb && _logoImage is io.File
            ? (_logoImage as io.File).path
            : null,
        'footerImages': _bottomImages.map((img) {
          return {
            'path': !kIsWeb && img.file is io.File
                ? (img.file as io.File).path
                : null,
            'fitIndex': img.fit == BoxFit.fill ? 1 : 0,
          };
        }).toList(),
      };

      await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving share preferences: $e');
    }
  }



  Future<void> _share() async {
    setState(() => _isSharing = true);
    // Save preferences before sharing
    _savePreferences();

    try {
      // Small delay to ensure UI updates if needed
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      await ShareUtil.shareWidgetAsImage(
        key: _cardKey,
        fileName: 'match_${widget.match.matchNumber ?? "result"}',
        text: 'Check out this result from ${widget.competitionName}!',
      );
    } catch (e, stack) {
      debugPrint('Share failed: $e\n$stack');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sharing Failed'),
            content: SingleChildScrollView(
              child: SelectableText(
                'Error: $e\n\nPlatform: ${kIsWeb ? "Web" : "Mobile"}\n\nStack Trace:\n$stack',
                style: const TextStyle(fontSize: 10),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.backgroundDark,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Customize & Share',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.dividerColor),

            // Preview Area
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: RepaintBoundary(
                key: _cardKey,
                child: MatchResultCard(
                  match: widget.match,
                  heading: _headingController.text, // Dynamic Heading
                  logoFile: _logoImage,
                  competitionName: widget.competitionName,
                  bottomImages: _bottomImages, // Pass List
                  sport: widget.sport,
                ),
              ),
            ),

            const SizedBox(height: 8),

            const SizedBox(height: 24),

            // Action Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _share,
                icon: _isSharing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.share),
                label: Text(_isSharing ? 'Generating...' : 'Share Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
