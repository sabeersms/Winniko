import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import '../constants/app_constants.dart';
import '../utils/share_util.dart';
import 'loading_spinner.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

class ShareCompetitionDialog extends StatefulWidget {
  final String competitionName;
  final String joinCode;
  final String? sponsorName;
  final String? cardBackgroundImageUrl;

  const ShareCompetitionDialog({
    super.key,
    required this.competitionName,
    required this.joinCode,
    this.sponsorName,
    this.cardBackgroundImageUrl,
  });

  @override
  State<ShareCompetitionDialog> createState() => _ShareCompetitionDialogState();
}

class _ShareCompetitionDialogState extends State<ShareCompetitionDialog> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSharing = false;

  Future<dynamic> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath =
            '${directory.path}/share_bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
        if (kIsWeb) return null; // No local File on web
        final file = io.File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
    }
    return null;
  }

  Future<void> _share() async {
    setState(() => _isSharing = true);

    try {
      final message = _messageController.text.trim();

      String shareContent =
          '''
${message.isNotEmpty ? '$message\n\n' : ''}🔥 JOIN THE ACTION & TOP THE LEADERBOARD! 🔥

🏆 Competition: "${widget.competitionName}"
''';

      if (widget.sponsorName != null && widget.sponsorName!.isNotEmpty) {
        shareContent += '🤝 Sponsored by: ${widget.sponsorName}\n';
      }

      shareContent +=
          '''

Use Code: ${widget.joinCode}

📲 Tap here to join now:
https://winniko-real.web.app/join?code=${widget.joinCode}
''';

      dynamic imageFile;
      if (widget.cardBackgroundImageUrl != null &&
          widget.cardBackgroundImageUrl!.isNotEmpty) {
        imageFile = await _downloadImage(widget.cardBackgroundImageUrl!);
      } else {
        // Use Default Asset
        try {
          final byteData = await rootBundle.load(
            AppConstants.defaultCompetitionBackground,
          );
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/default_share_bg.jpg';
          if (!kIsWeb) {
            final file = io.File(filePath);
            await file.writeAsBytes(byteData.buffer.asUint8List());
            imageFile = file;
          }
        } catch (e) {
          debugPrint('Error loading default asset: $e');
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Close dialog

      if (imageFile != null) {
        await ShareUtil.shareImage(imageFile: imageFile, text: shareContent);
      } else {
        await ShareUtil.shareText(text: shareContent);
      }
    } catch (e) {
      debugPrint('Share failed: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: const Text(
        'Share Competition',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Say something...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: AppColors.backgroundDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSharing ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isSharing ? null : _share,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentGreen,
            foregroundColor: Colors.white,
          ),
          child: _isSharing
              ? const LoadingSpinner(size: 20, color: Colors.white)
              : const Text('Share'),
        ),
      ],
    );
  }
}

// Helper to show the dialog easily
void showShareCompetitionDialog(
  BuildContext context,
  String name,
  String code,
  String? sponsorName,
  String? bgUrl,
) {
  showDialog(
    context: context,
    builder: (context) => ShareCompetitionDialog(
      competitionName: name,
      joinCode: code,
      sponsorName: sponsorName,
      cardBackgroundImageUrl: bgUrl,
    ),
  );
}
