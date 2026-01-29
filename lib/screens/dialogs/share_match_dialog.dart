import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();
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

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (!kIsWeb) {
          _logoImage = io.File(image.path);
        } else {
          // On web, handle differently or skip native File object
          _logoImage = image; // Use XFile directly maybe?
          // For now, simpler to just skip native io.File
        }
      });
    }
  }

  // New Method for Footer Images
  Future<void> _pickBottomImage() async {
    if (_bottomImages.length >= 4) return;

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (!kIsWeb) {
          _bottomImages.add(FooterImageData(io.File(image.path)));
        } else {
          _bottomImages.add(FooterImageData(image));
        }
      });
    }
  }

  void _removeBottomImage(int index) {
    setState(() {
      _bottomImages.removeAt(index);
    });
  }

  void _toggleImageFit(int index) {
    setState(() {
      final current = _bottomImages[index];
      final newFit = current.fit == BoxFit.contain
          ? BoxFit.fill
          : BoxFit.contain;
      _bottomImages[index] = FooterImageData(current.file, fit: newFit);
    });
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

            // Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _headingController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Tournament Name',
                      filled: true,
                      fillColor: AppColors.inputBackground,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            _logoImage == null ? 'Top Logo' : 'Change Top',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentGreen,
                            side: const BorderSide(
                              color: AppColors.accentGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _bottomImages.length < 4
                              ? _pickBottomImage
                              : null,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: Text('Add Footer (${_bottomImages.length}/4)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentGreen,
                            side: const BorderSide(
                              color: AppColors.accentGreen,
                            ),
                            disabledForegroundColor: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Footer Images Preview List
                  if (_bottomImages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _bottomImages.length,
                        itemBuilder: (context, index) {
                          final imgData = _bottomImages[index];
                          return Stack(
                            children: [
                              GestureDetector(
                                onTap: () => _toggleImageFit(index),
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    right: 8,
                                    top: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: imgData.fit == BoxFit.fill
                                          ? AppColors.accentGreen
                                          : Colors.white54,
                                      width: imgData.fit == BoxFit.fill ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: (!kIsWeb && imgData.file is io.File)
                                        ? Image.file(
                                            imgData.file as io.File,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(
                                            Icons.image,
                                            color: Colors.white24,
                                          ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => _removeBottomImage(index),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              // Fit Icon Indicator
                              Positioned(
                                bottom: 0,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    imgData.fit == BoxFit.fill
                                        ? Icons.expand
                                        : Icons.compress,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

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
