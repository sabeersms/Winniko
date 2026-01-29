import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../constants/app_constants.dart';
import '../../widgets/loading_spinner.dart';

class ImageAdjustmentDialog extends StatefulWidget {
  final File imageFile;
  final String competitionName;
  final String? sponsorName;

  const ImageAdjustmentDialog({
    super.key,
    required this.imageFile,
    required this.competitionName,
    this.sponsorName,
  });

  @override
  State<ImageAdjustmentDialog> createState() => _ImageAdjustmentDialogState();
}

class _ImageAdjustmentDialogState extends State<ImageAdjustmentDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _transformationController =
      TransformationController();
  BoxFit _currentFit = BoxFit.cover;
  bool _isProcessing = false;

  void _resetView() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  void _toggleFit(BoxFit fit) {
    setState(() {
      _currentFit = fit;
      _resetView();
    });
  }

  Future<void> _onDone() async {
    setState(() => _isProcessing = true);
    try {
      // Capture the adjusted image from the RepaintBoundary
      RenderRepaintBoundary boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      var buffer = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final fileName = 'adjusted_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = await File(
        p.join(tempDir.path, fileName),
      ).writeAsBytes(buffer);

      if (mounted) {
        Navigator.pop(context, file);
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process image')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // The interactive adjustment area
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Zoom and drag to adjust background',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),

                // This is the "Preview Area"
                Container(
                  width: MediaQuery.of(context).size.width - 32,
                  height: 220, // Approximate height of a competition card
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // The zooming image - Wrapped in RepaintBoundary for capture
                      Positioned.fill(
                        child: RepaintBoundary(
                          key: _boundaryKey,
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            minScale: 0.1,
                            maxScale: 5.0,
                            boundaryMargin: const EdgeInsets.all(
                              double.infinity,
                            ),
                            child: Image.file(
                              widget.imageFile,
                              fit: _currentFit,
                              width: _currentFit == BoxFit.fill
                                  ? double.infinity
                                  : null,
                              height: _currentFit == BoxFit.fill
                                  ? double.infinity
                                  : null,
                            ),
                          ),
                        ),
                      ),

                      // Card Overlay (Gradient) - Not captured
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.5),
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Fake Card Content for preview - Not captured
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: IgnorePointer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.sports_soccer,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.competitionName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (widget.sponsorName != null)
                                          Text(
                                            'By ${widget.sponsorName}',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.people,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '0 Participants',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.stars,
                                      color: AppColors.accentGreen,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Points Rules Preview',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.accentGreen,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'View Details',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Controls
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildControlButton(
                          icon: Icons.aspect_ratio,
                          label: 'Cover',
                          isActive: _currentFit == BoxFit.cover,
                          onPressed: () => _toggleFit(BoxFit.cover),
                        ),
                        const SizedBox(width: 16),
                        _buildControlButton(
                          icon: Icons.fit_screen,
                          label: 'Stretch',
                          isActive: _currentFit == BoxFit.fill,
                          onPressed: () => _toggleFit(BoxFit.fill),
                        ),
                        const SizedBox(width: 16),
                        _buildControlButton(
                          icon: Icons.refresh,
                          label: 'Reset',
                          isActive: false,
                          onPressed: _resetView,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_out, color: Colors.white),
                          onPressed: () {
                            _transformationController.value =
                                _transformationController.value *
                                (Matrix4.identity()..scale(0.9));
                          },
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(Icons.zoom_in, color: Colors.white),
                          onPressed: () {
                            _transformationController.value =
                                _transformationController.value *
                                (Matrix4.identity()..scale(1.1));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Toolbar
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const Text(
                    'Adjust Card View',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: _isProcessing ? null : _onDone,
                    child: _isProcessing
                        ? const LoadingSpinner(size: 20)
                        : const Text(
                            'Done',
                            style: TextStyle(
                              color: AppColors.accentGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? AppColors.accentGreen : Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.textPrimary : Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.accentGreen : Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
