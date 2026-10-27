import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Immagine di una foto appena scelta, non ancora caricata. Su Android
/// [path] è un file del telefono; sul web è un indirizzo `blob:` del browser,
/// che si apre come un'immagine di rete.
ImageProvider localPhotoProvider(String path) =>
    kIsWeb ? NetworkImage(path) : FileImage(File(path));
