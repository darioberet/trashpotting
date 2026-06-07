import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'image_processing_service.dart';

class PhotoUploadService {
  PhotoUploadService({
    FirebaseStorage? storage,
    ImageProcessingService? imageProcessingService,
  }) : _storage = storage ?? FirebaseStorage.instance,
       _imageProcessingService = imageProcessingService;

  final FirebaseStorage _storage;
  final ImageProcessingService? _imageProcessingService;

  Future<String> uploadReportPhoto({
    required String localPath,
    required String ownerId,
  }) async {
    return _uploadPhoto(
      localPath: localPath,
      ownerId: ownerId,
      folder: 'report_photos',
    );
  }

  Future<String> uploadCleanupPhoto({
    required String localPath,
    required String ownerId,
    required String reportId,
  }) async {
    return _uploadPhoto(
      localPath: localPath,
      ownerId: ownerId,
      folder: 'cleanup_photos/$reportId',
    );
  }

  Future<String> _uploadPhoto({
    required String localPath,
    required String ownerId,
    required String folder,
  }) async {
    var uploadPath = localPath;
    var isTempFile = false;

    try {
      final optimizedPath =
          await (_imageProcessingService ?? const ImageProcessingService())
              .resizeAndCompress(localPath);
      if (optimizedPath != localPath) {
        uploadPath = optimizedPath;
        isTempFile = true;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final path = '$folder/$ownerId/$now.jpg';
      final file = File(uploadPath);

      final task = await _storage
          .ref(path)
          .putFile(file, SettableMetadata(contentType: 'image/jpeg'));

      return task.ref.getDownloadURL();
    } finally {
      if (isTempFile) {
        unawaited(_deleteTempFile(uploadPath));
      }
    }
  }

  Future<void> _deleteTempFile(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      // Best-effort cleanup: ignore temp file delete failures.
    }
  }
}
