import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Helper to upload file/data
  Future<String> _uploadData(
    Uint8List data,
    String path,
    String contentType,
  ) async {
    Reference ref = _storage.ref().child(path);
    SettableMetadata metadata = SettableMetadata(contentType: contentType);
    UploadTask uploadTask = ref.putData(data, metadata);

    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Optimized image processing
  Future<Uint8List> _processImage(
    XFile file, {
    required int maxWidth,
    required int maxHeight,
    int quality = 85,
  }) async {
    final Uint8List bytes = await file.readAsBytes();
    final img.Image? image = img.decodeImage(bytes);

    if (image == null) return bytes;

    // Only resize if original is larger than targets
    if (image.width > maxWidth || image.height > maxHeight) {
      final img.Image resized = img.copyResize(
        image,
        width: image.width > image.height ? maxWidth : null,
        height: image.height >= image.width ? maxHeight : null,
      );
      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }

    // Still compress if it's already small enough but in a heavy format
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  // Upload user profile photo
  Future<String> uploadUserPhoto(XFile file, String userId) async {
    try {
      final data = await _processImage(file, maxWidth: 512, maxHeight: 512);
      String fileName = '${_uuid.v4()}.jpg';
      return await _uploadData(data, 'users/$userId/$fileName', 'image/jpeg');
    } catch (e) {
      throw Exception('Failed to upload user photo: ${e.toString()}');
    }
  }

  // Upload competition logo
  Future<String> uploadCompetitionLogo(XFile file, String competitionId) async {
    try {
      final data = await _processImage(file, maxWidth: 512, maxHeight: 512);
      String fileName = '${_uuid.v4()}.jpg';
      return await _uploadData(
        data,
        'competitions/$competitionId/logo/$fileName',
        'image/jpeg',
      );
    } catch (e) {
      throw Exception('Failed to upload competition logo: ${e.toString()}');
    }
  }

  // Upload competition background image
  Future<String> uploadCompetitionBackground(
    XFile file,
    String competitionId,
  ) async {
    try {
      final data = await _processImage(file, maxWidth: 1280, maxHeight: 720);
      String fileName = '${_uuid.v4()}.jpg'; // Preferred over png for size
      return await _uploadData(
        data,
        'competitions/$competitionId/background/$fileName',
        'image/jpeg',
      );
    } catch (e) {
      throw Exception(
        'Failed to upload competition background: ${e.toString()}',
      );
    }
  }

  // Upload team logo (Competition Scope)
  Future<String> uploadCompetitionTeamLogo(
    XFile file,
    String competitionId,
    String teamId,
  ) async {
    try {
      final data = await _processImage(file, maxWidth: 512, maxHeight: 512);
      String fileName = '${_uuid.v4()}.jpg';
      return await _uploadData(
        data,
        'competitions/$competitionId/teams/$teamId/$fileName',
        'image/jpeg',
      );
    } catch (e) {
      throw Exception('Failed to upload team logo: ${e.toString()}');
    }
  }

  // Upload team logo (Global Scope - Organizer Library)
  Future<String> uploadGlobalTeamLogo(
    XFile file,
    String organizerId,
    String teamId,
  ) async {
    try {
      final data = await _processImage(file, maxWidth: 512, maxHeight: 512);
      String fileName = '${_uuid.v4()}.jpg';
      return await _uploadData(
        data,
        'organizers/$organizerId/team_library/$teamId/$fileName',
        'image/jpeg',
      );
    } catch (e) {
      throw Exception('Failed to upload global team logo: ${e.toString()}');
    }
  }

  // Deprecated: Old insecure path (Keep temporarily if needed, but we are refactoring usages)
  // Future<String> uploadTeamLogo...

  // Upload custom competition images (for paid organizers)
  Future<String> uploadCustomImage(XFile file, String competitionId) async {
    try {
      final data = await _processImage(file, maxWidth: 1280, maxHeight: 1280);
      String fileName = '${_uuid.v4()}.jpg';
      return await _uploadData(
        data,
        'competitions/$competitionId/custom/$fileName',
        'image/jpeg',
      );
    } catch (e) {
      throw Exception('Failed to upload custom image: ${e.toString()}');
    }
  }

  // Delete file from storage
  Future<void> deleteFile(String downloadUrl) async {
    try {
      Reference ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete file: ${e.toString()}');
    }
  }

  // Delete all files in a directory
  Future<void> deleteDirectory(String path) async {
    try {
      Reference ref = _storage.ref().child(path);
      ListResult result = await ref.listAll();

      for (Reference fileRef in result.items) {
        await fileRef.delete();
      }

      for (Reference folderRef in result.prefixes) {
        await deleteDirectory(folderRef.fullPath);
      }
    } catch (e) {
      throw Exception('Failed to delete directory: ${e.toString()}');
    }
  }

  // Upload message attachment (image)
  Future<String> uploadChatMessage({
    required XFile file,
    required String competitionId,
    required String participantId,
  }) async {
    try {
      final data = await _processImage(file, maxWidth: 800, maxHeight: 800);
      String fileName = '${_uuid.v4()}.jpg';
      return await _uploadData(
        data,
        'competitions/$competitionId/chats/$participantId/$fileName',
        'image/jpeg',
      );
    } catch (e) {
      throw Exception('Failed to upload chat image: ${e.toString()}');
    }
  }
}
