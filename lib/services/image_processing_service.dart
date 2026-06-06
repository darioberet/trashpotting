import 'dart:io';

import 'package:image/image.dart' as img;

class ImageProcessingService {
  const ImageProcessingService({
    this.maxWidth = 1600,
    this.maxHeight = 1600,
    this.jpegQuality = 78,
  });

  final int maxWidth;
  final int maxHeight;
  final int jpegQuality;

  Future<int?> estimateCompressedSizeBytes(String localPath) async {
    final prepared = await _prepareImage(localPath);
    if (prepared == null) return null;

    final outputBytes = img.encodeJpg(prepared, quality: jpegQuality);
    return outputBytes.length;
  }

  Future<String> resizeAndCompress(String localPath) async {
    final processed = await _prepareImage(localPath);
    if (processed == null) return localPath;

    final outputBytes = img.encodeJpg(processed, quality: jpegQuality);

    final outputName =
        'trashpotting_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final outputPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}$outputName';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(outputBytes, flush: true);
    return outputFile.path;
  }

  Future<img.Image?> _prepareImage(String localPath) async {
    final source = File(localPath);
    if (!await source.exists()) return null;

    final sourceBytes = await source.readAsBytes();
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) return null;

    final oriented = img.bakeOrientation(decoded);
    return _resizeIfNeeded(oriented);
  }

  img.Image _resizeIfNeeded(img.Image source) {
    final width = source.width;
    final height = source.height;

    if (width <= maxWidth && height <= maxHeight) {
      return source;
    }

    final widthRatio = maxWidth / width;
    final heightRatio = maxHeight / height;
    final ratio = widthRatio < heightRatio ? widthRatio : heightRatio;

    final targetWidth = (width * ratio).round();
    final targetHeight = (height * ratio).round();

    return img.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );
  }
}
