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

  Future<String> uploadProfilePhoto({
    required String localPath,
    required String ownerId,
  }) async {
    return _uploadPhoto(
      localPath: localPath,
      ownerId: ownerId,
      folder: 'profile_photos',
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

  /// Comprime in memoria e carica i byte (`putData`): niente file
  /// temporanei, così funziona uguale su Android e sul web.
  Future<String> _uploadPhoto({
    required String localPath,
    required String ownerId,
    required String folder,
  }) async {
    final bytes =
        await (_imageProcessingService ?? const ImageProcessingService())
            .resizeAndCompress(localPath);

    final now = DateTime.now().millisecondsSinceEpoch;
    final task = await _storage
        .ref('$folder/$ownerId/$now.jpg')
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return task.ref.getDownloadURL();
  }
}
