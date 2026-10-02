// Controlla se dei JPEG contengono metadati sensibili (GPS, modello).
//   dart run tool/check_exif.dart <cartella>
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  for (final f in Directory(args.first).listSync().whereType<File>()) {
    final exif = img.decodeJpgExif(f.readAsBytesSync());
    final gps = exif != null && !exif.gpsIfd.isEmpty;
    final model = exif?.imageIfd.model;
    final lat = exif?.gpsIfd.gpsLatitude;
    stdout.writeln(
      '${gps ? 'GPS!' : 'ok  '} ${model ?? '-'} '
      '${lat != null ? 'lat=${lat.toStringAsFixed(4)} ' : ''}'
      '${f.uri.pathSegments.last}',
    );
  }
}
