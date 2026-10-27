import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' show XFile;

/// La foto non è un'immagine leggibile: non si carica, perché caricare il
/// file originale ne pubblicherebbe i metadati (GPS, modello del telefono).
class ImageProcessingException implements Exception {
  const ImageProcessingException();

  @override
  String toString() => 'Foto non valida o danneggiata. Scegline un\'altra.';
}

/// Lavora sui byte, non su file temporanei: così funziona anche sul web, dove
/// il "percorso" della foto scelta è un indirizzo `blob:` del browser.
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

  /// Ridimensiona, comprime e **rimuove tutti i metadati EXIF** (coordinate
  /// GPS, modello del telefono, data): le foto sono visibili a tutti gli
  /// utenti e il GPS di una foto profilo può rivelare dove abita qualcuno.
  /// Restituisce il JPEG pronto da caricare. Lancia
  /// [ImageProcessingException] se la foto non è leggibile.
  Future<Uint8List> resizeAndCompress(String localPath) async {
    final processed = await _prepareImage(localPath);
    if (processed == null) throw const ImageProcessingException();
    return img.encodeJpg(processed, quality: jpegQuality);
  }

  Future<img.Image?> _prepareImage(String localPath) async {
    final Uint8List sourceBytes;
    try {
      sourceBytes = await XFile(localPath).readAsBytes();
    } catch (_) {
      return null; // file sparito o non leggibile
    }
    img.Image? decoded;
    try {
      decoded = img.decodeImage(sourceBytes);
    } catch (_) {
      // File troncato o non immagine: alcuni decoder lanciano invece di
      // restituire null.
      return null;
    }
    if (decoded == null) return null;

    // bakeOrientation applica la rotazione ai pixel ma lascia il resto
    // dell'EXIF, che encodeJpg riscriverebbe nel file finale.
    final oriented = img.bakeOrientation(decoded)..exif = img.ExifData();
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
