import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:trashpotting_v3/services/image_processing_service.dart';

/// JPEG con EXIF come quelli scattati da un telefono: coordinate GPS e
/// modello del dispositivo.
Future<String> _jpegWithGps(Directory dir) async {
  final image = img.Image(width: 64, height: 48);
  image.exif.imageIfd
    ..make = 'Google'
    ..model = 'Pixel 9 Pro';
  image.exif.gpsIfd.setGpsLocation(latitude: 43.9472, longitude: 12.7945);
  final file = File('${dir.path}/with_gps.jpg');
  await file.writeAsBytes(img.encodeJpg(image));
  return file.path;
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('trashpotting_test');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('la foto di partenza contiene davvero il GPS', () async {
    final path = await _jpegWithGps(dir);
    final exif = img.decodeJpgExif(await File(path).readAsBytes());
    expect(exif?.gpsIfd.gpsLatitude, closeTo(43.9472, 0.001));
    expect(exif?.imageIfd.hasModel, isTrue);
  });

  test('la foto caricata non contiene GPS né modello del telefono', () async {
    final path = await _jpegWithGps(dir);

    final output = await const ImageProcessingService().resizeAndCompress(path);
    final exif = img.decodeJpgExif(await File(output).readAsBytes());

    expect(output, isNot(path));
    expect(exif == null || exif.gpsIfd.isEmpty, isTrue);
    expect(exif == null || !exif.imageIfd.hasModel, isTrue);
  });

  test("se il file non è un'immagine valida non viene caricato l'originale",
      () async {
    final file = File('${dir.path}/broken.jpg')
      ..writeAsBytesSync([1, 2, 3]);

    expect(
      () => const ImageProcessingService().resizeAndCompress(file.path),
      throwsA(isA<ImageProcessingException>()),
    );
  });
}
