import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class PhotoUploadService {
  PhotoUploadService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadReportPhoto({
    required String localPath,
    required String ownerId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final path = 'report_photos/$ownerId/$now.jpg';
    final file = File(localPath);

    final task = await _storage.ref(path).putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );

    return task.ref.getDownloadURL();
  }
}
