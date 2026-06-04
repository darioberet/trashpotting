import 'package:image_picker/image_picker.dart';

class MediaPickerService {
  MediaPickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<String?> pickImagePath(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
    );
    return file?.path;
  }
}
