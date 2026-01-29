import 'dart:io' show File;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../constants/app_constants.dart';
import '../../widgets/loading_spinner.dart';

class ProfileImageAdjustmentDialog extends StatefulWidget {
  final XFile imageFile;

  const ProfileImageAdjustmentDialog({super.key, required this.imageFile});

  @override
  State<ProfileImageAdjustmentDialog> createState() =>
      _ProfileImageAdjustmentDialogState();
}

class _ProfileImageAdjustmentDialogState
    extends State<ProfileImageAdjustmentDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _transformationController =
      TransformationController();
  bool _isProcessing = false;

  void _resetView() {
    setState(() {
      _transformationController.value = Matrix4.identity();
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

      XFile resultFile;

      if (kIsWeb) {
        // On Web, create XFile directly from bytes
        resultFile = XFile.fromData(
          buffer,
          mimeType: 'image/png',
          name: 'profile_adjusted_${DateTime.now().millisecondsSinceEpoch}.png',
        );
      } else {
        // On Mobile, write to temp file
        final tempDir = await getTemporaryDirectory();
        final fileName =
            'profile_adjusted_${DateTime.now().millisecondsSinceEpoch}.png';
        final path = p.join(tempDir.path, fileName);
        await File(path).writeAsBytes(buffer);
        resultFile = XFile(path);
      }

      if (mounted) {
        Navigator.pop(context, resultFile);
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
    final size = MediaQuery.of(context).size;
    final cropSize = size.width * 0.8;

    ImageProvider imageProvider;
    if (kIsWeb) {
      imageProvider = NetworkImage(widget.imageFile.path);
    } else {
      imageProvider = FileImage(File(widget.imageFile.path));
    }

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
                    'Zoom and drag to fit within the circle',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),

                // This is the "Preview Area"
                Container(
                  width: cropSize,
                  height: cropSize,
                  decoration: const BoxDecoration(
                    color: AppColors.cardBackground,
                    shape: BoxShape.circle,
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
                            child: Image(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Zoom Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.zoom_out,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        _transformationController.value =
                            _transformationController.value *
                            (Matrix4.identity()..scale(0.9));
                      },
                    ),
                    const SizedBox(width: 32),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _resetView,
                    ),
                    const SizedBox(width: 32),
                    IconButton(
                      icon: const Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 28,
                      ),
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
          ),

          // Circle Outline Overlay (Outside of RepaintBoundary)
          Center(
            child: IgnorePointer(
              child: Container(
                width: cropSize,
                height: cropSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentGreen, width: 2),
                ),
              ),
            ),
          ),

          // Darkened Background outside the circle
          IgnorePointer(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.7),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: cropSize,
                      height: cropSize,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
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
                    'Update Profile Picture',
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
                            'Save',
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
}
