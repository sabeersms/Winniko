import 'dart:io' as io;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';

class ShareUtil {
  static const platform = MethodChannel('com.winniko.winniko/share');

  static Future<void> shareWidgetAsImage({
    required GlobalKey key,
    required String fileName,
    String? text,
  }) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Could not find render boundary');
    }

    // debugNeedsPaint check removed as it causes LateInitializationError in Release mode
    // The caller (ShareMatchDialog) already waits 100ms before calling this, which is sufficient.

    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw Exception('Failed to generate image data');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final directory = await getTemporaryDirectory();
    final imagePath = io.File('${directory.path}/$fileName.png');
    if (!kIsWeb) {
      await imagePath.create();
      await imagePath.writeAsBytes(pngBytes);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await platform.invokeMethod('shareImage', {
        'path': imagePath.path,
        'text': text,
      });
    } else if (kIsWeb) {
      // Handle web sharing (e.g., download or copy)
      debugPrint('Web sharing: $text');
    } else {
      // Temporarily disabled for debugging
      throw Exception(
        'Non-Android sharing temporarily disabled for debugging.',
      );
    }
  }

  static Future<void> shareText({required String text}) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await platform.invokeMethod('shareText', {'text': text});
      } else if (kIsWeb) {
        // Fallback for web - copy to clipboard or just log
        await Clipboard.setData(ClipboardData(text: text));
        debugPrint('Web text share - copied to clipboard: $text');
      }
    } catch (e) {
      debugPrint('Error sharing text: $e');
    }
  }

  static Future<void> shareFile({
    required dynamic file, // dynamic to avoid dart:io crash on web
    String? text,
    required String mimeType,
  }) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await platform.invokeMethod('shareFile', {
          'path': file.path,
          'text': text,
          'mimeType': mimeType,
        });
      } else if (kIsWeb) {
        debugPrint('Web file share: $text');
      } else {
        // Fallback or implementation for other platforms if needed
        // For now, throwing error as requested to focus on Android native
        throw Exception(
          'Non-Android sharing temporarily disabled for debugging.',
        );
      }
    } catch (e) {
      debugPrint('Error sharing file: $e');
      rethrow;
    }
  }

  static Future<void> shareImage({
    required dynamic imageFile,
    String? text,
  }) async {
    return shareFile(file: imageFile, text: text, mimeType: 'image/png');
  }
}
